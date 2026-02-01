extends Node3D
class_name NPCSpawner

const NPC_SCENE := preload("res://scenes/entites/npc.tscn")

@export var npc_count: int = 20
@export var spawn_area: Node3D

# Sync properties
@export var sync_interval: float = 0.5  # How often to sync target positions

var spawned_npcs: Array[NPC] = []
var npc_container: Node3D

# Stores the current navigation targets for each NPC (by index)
var npc_targets: Dictionary = {}

func _ready() -> void:
	add_to_group("npc_spawner")
	# Create container for NPCs
	npc_container = Node3D.new()
	npc_container.name = "NPCs"
	add_child(npc_container)
	
	# Only server spawns NPCs
	if MultiplayerManager.is_server():
		# Wait a frame for everything to be ready
		await get_tree().process_frame
		_spawn_all_npcs()
		# Start syncing targets
		_start_target_sync()

func _spawn_all_npcs() -> void:
	if not MultiplayerManager.is_server():
		return
	
	for i in npc_count:
		var spawn_pos = _get_random_spawn_position()
		
		# Generate random cosmetic data
		var cosmetic_data = _generate_random_cosmetics()
		
		# Spawn on all clients
		_spawn_npc_remote.rpc(i, spawn_pos, cosmetic_data)

func _get_random_spawn_position() -> Vector3:
	if spawn_area:
		# Find the CollisionShape3D child
		var collision_shape: CollisionShape3D = null
		for child in spawn_area.get_children():
			if child is CollisionShape3D:
				collision_shape = child
				break
		
		if collision_shape and collision_shape.shape is BoxShape3D:
			var box_shape := collision_shape.shape as BoxShape3D
			var box_size := box_shape.size
			
			# Generate random point within the box (local space)
			var local_point = Vector3(
				randf_range(-box_size.x / 2, box_size.x / 2),
				randf_range(-box_size.y / 2, box_size.y / 2),
				randf_range(-box_size.z / 2, box_size.z / 2)
			)
			
			# Transform to global space (respects parent rotation and scale)
			var global_point = collision_shape.global_transform * local_point
			
			# Optionally keep Y fixed (adjust to desired height)
			global_point.y = spawn_area.global_position.y
			
			return global_point
	
	# Fallback if no valid spawn area/collision shape found
	return Vector3(randf_range(-15, 25), 0.5, randf_range(-30, 12))

func _generate_random_cosmetics() -> Dictionary:
	return {
		"head_idx": randi() % Robot.HEADS.size(),
		"arms_idx": randi() % Robot.ARMS.size(),
		"body_idx": randi() % Robot.BODIES.size(),
		"bottom_idx": randi() % Robot.BOTTOMS.size(),
		"accessory_idx": randi() % Robot.ACCESSORIES.size(),
		"colors": _generate_color_array()
	}

func _generate_color_array() -> Array:
	var preset_colors = [Color(1,0,0), Color(0,1,0), Color(0,0,1)]
	var colors: Array = []
	for i in 5:
		colors.append(preset_colors[randi() % preset_colors.size()])
	return colors

@rpc("authority", "call_local", "reliable")
func _spawn_npc_remote(npc_index: int, spawn_pos: Vector3, cosmetic_data: Dictionary) -> void:
	var npc := NPC_SCENE.instantiate() as NPC
	npc.name = "NPC_%d" % npc_index
	
	# Set meta BEFORE adding to tree (so _ready can check it)
	npc.set_meta("skip_randomize", true)
	npc.set_meta("cosmetic_data", cosmetic_data)
	npc.set_meta("npc_index", npc_index)
	
	npc_container.add_child(npc, true)
	npc.global_position = spawn_pos
	
	spawned_npcs.append(npc)
	
	# Store initial target
	npc_targets[npc_index] = spawn_pos
	
	# Connect to NPC's movement for server-side tracking
	if MultiplayerManager.is_server():
		npc.navigation_agent.target_reached.connect(_on_npc_target_reached.bind(npc_index))

# Server-side: Track when NPCs reach their target
func _on_npc_target_reached(npc_index: int) -> void:
	if not MultiplayerManager.is_server():
		return
	
	# Generate new random target using the same area logic
	var new_target = _get_random_spawn_position()
	npc_targets[npc_index] = new_target

func _start_target_sync() -> void:
	if not MultiplayerManager.is_server():
		return
	
	# Create a timer for syncing
	var sync_timer = Timer.new()
	sync_timer.wait_time = sync_interval
	sync_timer.autostart = true
	sync_timer.timeout.connect(_sync_all_targets)
	add_child(sync_timer)

func _sync_all_targets() -> void:
	if not MultiplayerManager.is_server():
		return
	
	# Collect all NPC targets and positions
	var sync_data: Array = []
	for i in spawned_npcs.size():
		var npc = spawned_npcs[i]
		if is_instance_valid(npc):
			sync_data.append({
				"index": i,
				"target": npc.navigation_agent.get_target_position(),
				"pos": npc.global_position,
				"rot_y": npc.rotation.y
			})
	
	# Send to all clients (but not server)
	_receive_target_sync.rpc(sync_data)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_target_sync(sync_data: Array) -> void:
	# Clients receive and apply the sync data
	for data in sync_data:
		var index = data.get("index", -1)
		if index >= 0 and index < spawned_npcs.size():
			var npc = spawned_npcs[index]
			if is_instance_valid(npc):
				# Set the navigation target
				var target = data.get("target", Vector3.ZERO)
				npc.navigation_agent.set_target_position(target)
				
				# Smoothly correct position if too far off
				var server_pos: Vector3 = data.get("pos", npc.global_position)
				var distance = npc.global_position.distance_to(server_pos)
				if distance > 2.0:
					# Teleport if too far
					npc.global_position = server_pos
				elif distance > 0.5:
					# Lerp towards correct position
					npc.global_position = npc.global_position.lerp(server_pos, 0.3)
				
				# Apply rotation
				npc.rotation.y = data.get("rot_y", npc.rotation.y)

func get_npc_count() -> int:
	return spawned_npcs.size()

func get_valid_npc_count() -> int:
	var count = 0
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			count += 1
	return count

func get_npcs() -> Array[NPC]:
	return spawned_npcs
