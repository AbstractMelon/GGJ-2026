extends Robot
class_name NPC

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent
@onready var move_timer: Timer = $MoveTimer

@export var minimum_wait_time: float = 1.0
@export var maximum_wait_time: float = 5.0

# When true, this NPC is controlled by server and only receives sync updates
var is_remote_controlled: bool = false

func _ready() -> void:
	# Check if we should skip randomization (spawned by NPCSpawner)
	if has_meta("skip_randomize"):
		# Initialize without randomization, apply cosmetics from meta
		add_to_group("robot")
		_create_hacked_indicator()
		_apply_spawner_cosmetics()
	else:
		# Normal random initialization
		super._ready()
	
	# Only server controls NPC navigation
	is_remote_controlled = not MultiplayerManager.is_server()
	
	if not is_remote_controlled:
		move_timer.wait_time = randf_range(0, maximum_wait_time)
		move_timer.start()
		randomize_target()

func randomize_target() -> void:
	var spawner = get_tree().get_first_node_in_group("npc_spawner")
	if spawner:
		navigation_agent.set_target_position(Vector3(
			randf_range(spawner.spawn_area_min.x, spawner.spawn_area_max.x),
			spawner.spawn_area_min.y,
			randf_range(spawner.spawn_area_min.z, spawner.spawn_area_max.z)
		))
	else:
		navigation_agent.set_target_position(Vector3(randf_range(-15, 25), 0.5, randf_range(-30, 12)))

func _apply_spawner_cosmetics() -> void:
	if not has_meta("cosmetic_data"):
		return
	
	var cosmetic_data: Dictionary = get_meta("cosmetic_data")
	
	# Set the part indices
	current_head_idx = cosmetic_data.get("head_idx", 0)
	current_arms_idx = cosmetic_data.get("arms_idx", 0)
	current_body_idx = cosmetic_data.get("body_idx", 0)
	current_bottom_idx = cosmetic_data.get("bottom_idx", 0)
	current_accessory_idx = cosmetic_data.get("accessory_idx", 0)
	
	# Convert colors array
	var colors_array: Array[Color] = []
	for color in cosmetic_data.get("colors", []):
		if color is Color:
			colors_array.append(color)
	current_colors = colors_array
	
	# Apply parts using the Robot's method but with our specific indices
	_apply_specific_parts()
	
	# Apply skin colors
	if current_colors.size() >= 5:
		ApplySkin(current_colors)

func _apply_specific_parts() -> void:
	# Store transforms from current parts
	var head_transform = $RobotModel/Skin/RobotHead.transform
	var arms_transform = $RobotModel/Skin/RobotArms.transform
	var body_transform = $RobotModel/Skin/RobotBody.transform
	var bottom_transform = $RobotModel/Skin/RobotBottom.transform
	var mask_transform = $RobotModel/Skin/Mask.transform
	
	# Remove old parts
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
	
	# Instantiate new parts using our indices
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
	var accessory_filename = accessory_scene.resource_path.get_file().get_basename()
	if ACCESSORY_TRANSFORMS.has(accessory_filename):
		new_accessory.transform = ACCESSORY_TRANSFORMS[accessory_filename]
	$RobotModel/Skin.add_child(new_accessory)


func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO
	
	if navigation_agent.is_navigation_finished():
		# Only server handles timer-based target selection
		if not is_remote_controlled and move_timer.is_stopped():
			move_timer.wait_time = randf_range(minimum_wait_time, maximum_wait_time)
			move_timer.start()
	
	else:
		var target = navigation_agent.get_next_path_position()
		target.y = position.y
	
		direction = position.direction_to(target)
		
		if target.distance_to(position) > 0.1:
			look_at(target)
	
	if direction.length() > 0:
		velocity = velocity.lerp(direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, friction * delta)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()


func _on_move_timer_timeout() -> void:
	# Only server generates new targets
	if not is_remote_controlled:
		randomize_target()
