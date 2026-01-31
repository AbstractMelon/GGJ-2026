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
	if not has_meta("skip_randomize"):
		super._ready()
	else:
		# Still call base _ready but mark for custom cosmetics
		add_to_group("robot")
		_create_hacked_indicator()
	
	# Only server controls NPC navigation
	is_remote_controlled = not MultiplayerManager.is_server()
	
	if not is_remote_controlled:
		move_timer.wait_time = randf_range(0, maximum_wait_time)
		move_timer.start()
		navigation_agent.set_target_position(Vector3(randf_range(-50, 20), 0.5, randf_range(-15, 15)))


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
		navigation_agent.set_target_position(Vector3(randf_range(-50, 20), 0.5, randf_range(-15, 15)))
