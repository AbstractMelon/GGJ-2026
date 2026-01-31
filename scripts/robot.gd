extends CharacterBody3D
class_name Robot

@export var move_speed := 5.0
@export var acceleration := 10.0
@export var friction := 8.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $RobotModel/AnimationPlayer

var target_velocity := Vector3.ZERO
var is_mask_removed := false
var is_hacked := false
var is_glitching := false

# Store current part indices for attribute transfer
var current_head_idx := 0
var current_arms_idx := 0
var current_body_idx := 0
var current_bottom_idx := 0
var current_accessory_idx := 0
var current_colors: Array[Color] = []

# Hacked warning indicator
var hacked_indicator: MeshInstance3D = null

@onready var skin := $RobotModel/Skin

# Available robot parts
const HEADS = [
	preload("res://assets/parts/heads/Head1.fbx"),
	preload("res://assets/parts/heads/Head2.fbx"),
	preload("res://assets/parts/heads/Head3.fbx"),
]
const ARMS = [
	preload("res://assets/parts/arms/Arms1.fbx"),
	preload("res://assets/parts/arms/Arms2.fbx"),
	preload("res://assets/parts/arms/Arms3.fbx"),
]
const BODIES = [
	preload("res://assets/parts/bodies/Body1.fbx"),
	preload("res://assets/parts/bodies/Body2.fbx"),
	preload("res://assets/parts/bodies/Body3.fbx"),
]
const BOTTOMS = [
	preload("res://assets/parts/bottoms/Bottom1.fbx"),
	preload("res://assets/parts/bottoms/Bottom2.fbx"),
	preload("res://assets/parts/bottoms/Bottom3.fbx"),
]
const MASKS = [
	preload("res://assets/parts/mask/Mask.fbx"),
	preload("res://assets/parts/mask/Mask2.fbx"),
]
const ACCESSORIES = [
	preload("res://assets/parts/accessories/Bowtie.fbx"),
	preload("res://assets/parts/accessories/Crown.fbx"),
	preload("res://assets/parts/accessories/FancyHat.fbx"),
	preload("res://assets/parts/accessories/Tie.fbx"),
	preload("res://assets/parts/accessories/TopHat.fbx"),
]

# Transform constants for accessories
const ACCESSORY_TRANSFORMS = {
	"Bowtie": Transform3D(Vector3(0, 0, 0.15), Vector3(0, 0.15, 0), Vector3(-0.15, 0, 0), Vector3(0, 1.423, -0.241)),
	"Crown": Transform3D(Vector3(0, 0, 0.15), Vector3(0, 0.15, 0), Vector3(-0.15, 0, 0), Vector3(0.026, 1.972, -0.028)),
	"FancyHat": Transform3D(Vector3(0, 0, 0.15), Vector3(0, 0.15, 0), Vector3(-0.15, 0, 0), Vector3(0.035, 1.928, 0)),
	"Tie": Transform3D(Vector3(0, 0, 0.15), Vector3(0, 0.15, 0), Vector3(-0.15, 0, 0), Vector3(0, 1.398, -0.265)),
	"TopHat": Transform3D(Vector3(0, 0, 0.15), Vector3(0, 0.15, 0), Vector3(-0.15, 0, 0), Vector3(0, 1.933, 0)),
}

func _ready() -> void:
	add_to_group("robot")
	# Use instance ID as random seed to ensure different robots get different parts
	seed(get_instance_id())
	RandomizeParts()
	current_colors = GenerateColorPallete()
	ApplySkin(current_colors)
	_create_hacked_indicator()

func _physics_process(_delta: float) -> void:
	
	move_and_slide()

func _create_hacked_indicator() -> void:
	# Create a floating warning indicator above the robot's head
	hacked_indicator = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	hacked_indicator.mesh = sphere
	
	# Create glowing red material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0, 0, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(1, 0, 0)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hacked_indicator.material_override = mat
	
	hacked_indicator.position = Vector3(0, 2.5, 0)
	hacked_indicator.visible = false
	add_child(hacked_indicator)

func RandomizeParts() -> void:
	# Store transforms
	var head_transform = $RobotModel/Skin/RobotHead.transform
	var arms_transform = $RobotModel/Skin/RobotArms.transform
	var body_transform = $RobotModel/Skin/RobotBody.transform
	var bottom_transform = $RobotModel/Skin/RobotBottom.transform
	var mask_transform = $RobotModel/Skin/Mask.transform
	
	# Remove old parts immediately (not queued)
	var old_head = $RobotModel/Skin/RobotHead
	$RobotModel/Skin.remove_child(old_head)
	old_head.free()
	
	var old_arms = $RobotModel/Skin/RobotArms
	$RobotModel/Skin.remove_child(old_arms)
	old_arms.free()
	
	var old_body = $RobotModel/Skin/RobotBody
	$RobotModel/Skin.remove_child(old_body)
	old_body.free()
	
	var old_bottom = $RobotModel/Skin/RobotBottom
	$RobotModel/Skin.remove_child(old_bottom)
	old_bottom.free()
	
	var old_mask = $RobotModel/Skin/Mask
	$RobotModel/Skin.remove_child(old_mask)
	old_mask.free()
	
	var old_accessory = $RobotModel/Skin/Accessory
	$RobotModel/Skin.remove_child(old_accessory)
	old_accessory.free()
	
	# Randomly pick indices and store them
	current_head_idx = randi() % HEADS.size()
	current_arms_idx = randi() % ARMS.size()
	current_body_idx = randi() % BODIES.size()
	current_bottom_idx = randi() % BOTTOMS.size()
	current_accessory_idx = randi() % ACCESSORIES.size()
	
	# Instantiate parts using stored indices
	var new_head = HEADS[current_head_idx].instantiate()
	new_head.name = "RobotHead"
	new_head.transform = head_transform
	$RobotModel/Skin.add_child(new_head)
	
	var new_arms = ARMS[current_arms_idx].instantiate()
	new_arms.name = "RobotArms"
	new_arms.transform = arms_transform
	$RobotModel/Skin.add_child(new_arms)
	
	var new_body = BODIES[current_body_idx].instantiate()
	new_body.name = "RobotBody"
	new_body.transform = body_transform
	$RobotModel/Skin.add_child(new_body)
	
	var new_bottom = BOTTOMS[current_bottom_idx].instantiate()
	new_bottom.name = "RobotBottom"
	new_bottom.transform = bottom_transform
	$RobotModel/Skin.add_child(new_bottom)
	
	var new_mask = MASKS.pick_random().instantiate()
	new_mask.name = "Mask"
	new_mask.transform = mask_transform
	$RobotModel/Skin.add_child(new_mask)
	
	var accessory_scene = ACCESSORIES[current_accessory_idx]
	var new_accessory = accessory_scene.instantiate()
	new_accessory.name = "Accessory"
	# Get the proper transform based on accessory type
	var accessory_filename = accessory_scene.resource_path.get_file().get_basename()
	if ACCESSORY_TRANSFORMS.has(accessory_filename):
		new_accessory.transform = ACCESSORY_TRANSFORMS[accessory_filename]
	$RobotModel/Skin.add_child(new_accessory)

func ApplyPartColor(node, color):
	# get the MeshInstance3D child
	var mesh_instance = node.find_children("*", "MeshInstance3D", true)[0]

	# get the material of the first surface
	var mat = mesh_instance.get_active_material(0)

	if mat:
		# make a unique copy so other meshes don't change
		mat = mat.duplicate()
		mesh_instance.set_surface_override_material(0, mat)
		# set the color (albedo)
		mat.albedo_color = color
	
var preset_colors = {
	"red": Color(1,0,0),
	"green": Color(0,1,0),
	"blue": Color(0,0,1),
}
func GenerateColorPallete(count: int = 5) -> Array[Color]:
	var colors: Array[Color] = []
	for i in count:
		colors.append(preset_colors.values().pick_random())
	return colors


func ApplySkin(colors: Array[Color]):
	ApplyPartColor($RobotModel/Skin/RobotHead, colors[0])
	ApplyPartColor($RobotModel/Skin/RobotArms, colors[1])
	ApplyPartColor($RobotModel/Skin/RobotBody, colors[2])
	ApplyPartColor($RobotModel/Skin/RobotBottom, colors[3])
	ApplyPartColor($RobotModel/Skin/Accessory, colors[4])

@rpc("any_peer", "call_local", "reliable")
func remove_mask() -> void:
	if is_mask_removed:
		return
	is_mask_removed = true
	animation_player.play("mask-remove")
	
	# Wait 2 seconds then hide the mask
	await get_tree().create_timer(1.0).timeout
	$RobotModel/Skin/Mask.visible = false

@rpc("any_peer", "call_local", "reliable")
func _request_unmask(target_robot_path: String) -> void:
	# Only server processes unmask requests
	if not multiplayer.is_server():
		return
	
	var requester_id = multiplayer.get_remote_sender_id()
	print("Unmask request for robot path: %s, remote_sender_id: %d" % [target_robot_path, requester_id])
	
	# If called locally on server (requester_id is 0), or if it's an RPC to self,
	# use the server's own ID
	if requester_id == 0:
		requester_id = 1  # Server is always peer ID 1
		print("Local call detected, using server ID: %d" % requester_id)
	
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.handle_unmask_request(requester_id, target_robot_path)

@rpc("any_peer", "call_local", "reliable")
func _request_hack(target_robot_path: String) -> void:
	# Only server processes hack requests
	if not multiplayer.is_server():
		return
	
	var requester_id = multiplayer.get_remote_sender_id()
	print("Hack request for robot path: %s, remote_sender_id: %d" % [target_robot_path, requester_id])
	
	if requester_id == 0:
		requester_id = 1
		print("Local call detected, using server ID: %d" % requester_id)
	
	var game = get_tree().get_first_node_in_group("game")
	if game:
		game.handle_hack_request(requester_id, target_robot_path, str(get_path()))

@rpc("authority", "call_local", "reliable")
func apply_hack(hacker_head_idx: int, hacker_arms_idx: int, hacker_body_idx: int, 
				hacker_bottom_idx: int, hacker_accessory_idx: int, hacker_colors: Array) -> void:
	if is_hacked:
		return
	
	is_hacked = true
	
	# Start the hack sequence: delay -> glitch -> warning -> attribute transfer
	_start_hack_sequence(hacker_head_idx, hacker_arms_idx, hacker_body_idx, 
						 hacker_bottom_idx, hacker_accessory_idx, hacker_colors)

func _start_hack_sequence(hacker_head_idx: int, hacker_arms_idx: int, hacker_body_idx: int,
						  hacker_bottom_idx: int, hacker_accessory_idx: int, hacker_colors: Array) -> void:
	# Wait a few seconds before visible effects
	await get_tree().create_timer(randf_range(1.5, 3.0)).timeout
	
	# Glitch effect for 1 second
	await _play_glitch_effect()
	
	# Show hacked warning indicator
	if hacked_indicator:
		hacked_indicator.visible = true
	
	# Transfer 1-2 random attributes from hacker
	_transfer_hacker_attributes(hacker_head_idx, hacker_arms_idx, hacker_body_idx,
								hacker_bottom_idx, hacker_accessory_idx, hacker_colors)

func _play_glitch_effect() -> void:
	is_glitching = true
	var original_pos = skin.position
	var glitch_duration = 1.0
	var glitch_start = Time.get_ticks_msec() / 1000.0
	
	# Rapid position/visibility flickering for glitch effect
	while (Time.get_ticks_msec() / 1000.0) - glitch_start < glitch_duration:
		# Random offset
		skin.position = original_pos + Vector3(
			randf_range(-0.1, 0.1),
			randf_range(-0.05, 0.05),
			randf_range(-0.1, 0.1)
		)
		# Random visibility flicker
		skin.visible = randf() > 0.3
		await get_tree().create_timer(0.05).timeout
	
	# Reset
	skin.position = original_pos
	skin.visible = true
	is_glitching = false

func _transfer_hacker_attributes(hacker_head_idx: int, hacker_arms_idx: int, hacker_body_idx: int,
								 hacker_bottom_idx: int, hacker_accessory_idx: int, hacker_colors: Array) -> void:
	# Decide how many attributes to transfer (1 or 2)
	var num_transfers = randi_range(1, 2)
	
	# Available attribute types
	var attribute_types = ["head", "arms", "body", "bottom", "accessory", "color"]
	attribute_types.shuffle()
	
	for i in num_transfers:
		if i >= attribute_types.size():
			break
		
		var attr_type = attribute_types[i]
		match attr_type:
			"head":
				_replace_part("RobotHead", HEADS, hacker_head_idx)
				current_head_idx = hacker_head_idx
			"arms":
				_replace_part("RobotArms", ARMS, hacker_arms_idx)
				current_arms_idx = hacker_arms_idx
			"body":
				_replace_part("RobotBody", BODIES, hacker_body_idx)
				current_body_idx = hacker_body_idx
			"bottom":
				_replace_part("RobotBottom", BOTTOMS, hacker_bottom_idx)
				current_bottom_idx = hacker_bottom_idx
			"accessory":
				_replace_accessory(hacker_accessory_idx)
				current_accessory_idx = hacker_accessory_idx
			"color":
				# Transfer a random color from hacker
				if hacker_colors.size() > 0:
					var color_idx = randi() % hacker_colors.size()
					var parts = [$RobotModel/Skin/RobotHead, $RobotModel/Skin/RobotArms, 
								 $RobotModel/Skin/RobotBody, $RobotModel/Skin/RobotBottom, 
								 $RobotModel/Skin/Accessory]
					if color_idx < parts.size():
						ApplyPartColor(parts[color_idx], hacker_colors[color_idx])
						if current_colors.size() > color_idx:
							current_colors[color_idx] = hacker_colors[color_idx]

func _replace_part(part_name: String, parts_array: Array, new_idx: int) -> void:
	var old_part = $RobotModel/Skin.get_node_or_null(part_name)
	if not old_part:
		return
	
	var old_transform = old_part.transform
	$RobotModel/Skin.remove_child(old_part)
	old_part.free()
	
	var new_part = parts_array[new_idx].instantiate()
	new_part.name = part_name
	new_part.transform = old_transform
	$RobotModel/Skin.add_child(new_part)
	
	# Re-apply the current color for this part
	var part_to_color_idx = {
		"RobotHead": 0,
		"RobotArms": 1,
		"RobotBody": 2,
		"RobotBottom": 3
	}
	if part_to_color_idx.has(part_name) and current_colors.size() > part_to_color_idx[part_name]:
		ApplyPartColor(new_part, current_colors[part_to_color_idx[part_name]])

func _replace_accessory(new_idx: int) -> void:
	var old_accessory = $RobotModel/Skin.get_node_or_null("Accessory")
	if not old_accessory:
		return
	
	$RobotModel/Skin.remove_child(old_accessory)
	old_accessory.free()
	
	var accessory_scene = ACCESSORIES[new_idx]
	var new_accessory = accessory_scene.instantiate()
	new_accessory.name = "Accessory"
	
	var accessory_filename = accessory_scene.resource_path.get_file().get_basename()
	if ACCESSORY_TRANSFORMS.has(accessory_filename):
		new_accessory.transform = ACCESSORY_TRANSFORMS[accessory_filename]
	$RobotModel/Skin.add_child(new_accessory)
	
	# Re-apply accessory color
	if current_colors.size() > 4:
		ApplyPartColor(new_accessory, current_colors[4])
