extends Node3D
class_name NPCSpawner

const NPC_SCENE := preload("res://scenes/entites/npc.tscn")

@export var npc_count: int = 10
@export var spawn_area_min: Vector3 = Vector3(-50, 0.5, -15)
@export var spawn_area_max: Vector3 = Vector3(20, 0.5, 15)

# Sync properties
@export var sync_interval: float = 0.5  # How often to sync target positions

var spawned_npcs: Array[NPC] = []
var npc_container: Node3D

# Stores the current navigation targets for each NPC (by index)
var npc_targets: Dictionary = {}

func _ready() -> void:
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
		var spawn_pos = Vector3(
			randf_range(spawn_area_min.x, spawn_area_max.x),
			spawn_area_min.y,
			randf_range(spawn_area_min.z, spawn_area_max.z)
		)
		
		# Generate random cosmetic data
		var cosmetic_data = _generate_random_cosmetics()
		
		# Spawn on all clients
		_spawn_npc_remote.rpc(i, spawn_pos, cosmetic_data)

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
	
	npc_container.add_child(npc, true)
	npc.global_position = spawn_pos
	
	# Apply cosmetics
	_apply_cosmetics_to_npc(npc, cosmetic_data)
	
	spawned_npcs.append(npc)
	
	# Store initial target
	npc_targets[npc_index] = spawn_pos
	
	# Connect to NPC's movement for server-side tracking
	if MultiplayerManager.is_server():
		# Override the NPC's navigation to use synced targets
		npc.set_meta("npc_index", npc_index)
		npc.navigation_agent.target_reached.connect(_on_npc_target_reached.bind(npc_index))

func _apply_cosmetics_to_npc(npc: NPC, cosmetic_data: Dictionary) -> void:
	# Disable the automatic randomization in _ready
	npc.set_meta("skip_randomize", true)
	
	# Apply the specific cosmetics after a frame (to ensure _ready has run)
	await get_tree().process_frame
	
	# Set the part indices
	npc.current_head_idx = cosmetic_data.get("head_idx", 0)
	npc.current_arms_idx = cosmetic_data.get("arms_idx", 0)
	npc.current_body_idx = cosmetic_data.get("body_idx", 0)
	npc.current_bottom_idx = cosmetic_data.get("bottom_idx", 0)
	npc.current_accessory_idx = cosmetic_data.get("accessory_idx", 0)
	
	# Convert colors array
	var colors_array: Array[Color] = []
	for color in cosmetic_data.get("colors", []):
		if color is Color:
			colors_array.append(color)
		elif color is Array:
			# In case it's transmitted as array
			colors_array.append(Color(color[0], color[1], color[2], color[3] if color.size() > 3 else 1.0))
	npc.current_colors = colors_array
	
	# Apply the parts using the stored indices
	_apply_parts_to_npc(npc)
	
	# Apply colors
	if colors_array.size() >= 5:
		npc.ApplySkin(colors_array)

func _apply_parts_to_npc(npc: NPC) -> void:
	var skin = npc.get_node("RobotModel/Skin")
	
	# Store transforms
	var head_transform = skin.get_node("RobotHead").transform
	var arms_transform = skin.get_node("RobotArms").transform
	var body_transform = skin.get_node("RobotBody").transform
	var bottom_transform = skin.get_node("RobotBottom").transform
	var mask_transform = skin.get_node("Mask").transform
	
	# Remove and replace parts
	_replace_npc_part(skin, "RobotHead", Robot.HEADS[npc.current_head_idx], head_transform)
	_replace_npc_part(skin, "RobotArms", Robot.ARMS[npc.current_arms_idx], arms_transform)
	_replace_npc_part(skin, "RobotBody", Robot.BODIES[npc.current_body_idx], body_transform)
	_replace_npc_part(skin, "RobotBottom", Robot.BOTTOMS[npc.current_bottom_idx], bottom_transform)
	
	# Replace accessory with proper transform
	var accessory_scene = Robot.ACCESSORIES[npc.current_accessory_idx]
	var old_accessory = skin.get_node_or_null("Accessory")
	if old_accessory:
		skin.remove_child(old_accessory)
		old_accessory.free()
	
	var new_accessory = accessory_scene.instantiate()
	new_accessory.name = "Accessory"
	var accessory_filename = accessory_scene.resource_path.get_file().get_basename()
	if Robot.ACCESSORY_TRANSFORMS.has(accessory_filename):
		new_accessory.transform = Robot.ACCESSORY_TRANSFORMS[accessory_filename]
	skin.add_child(new_accessory)

func _replace_npc_part(skin: Node3D, part_name: String, part_scene: PackedScene, old_transform: Transform3D) -> void:
	var old_part = skin.get_node_or_null(part_name)
	if old_part:
		skin.remove_child(old_part)
		old_part.free()
	
	var new_part = part_scene.instantiate()
	new_part.name = part_name
	new_part.transform = old_transform
	skin.add_child(new_part)

# Server-side: Track when NPCs reach their target
func _on_npc_target_reached(npc_index: int) -> void:
	if not MultiplayerManager.is_server():
		return
	
	# Generate new random target
	var new_target = Vector3(
		randf_range(spawn_area_min.x, spawn_area_max.x),
		spawn_area_min.y,
		randf_range(spawn_area_min.z, spawn_area_max.z)
	)
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
