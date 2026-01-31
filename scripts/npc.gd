extends Robot
class_name NPC

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent
@onready var move_timer: Timer = $MoveTimer

@export var minimum_wait_time: float = 1.0
@export var maximum_wait_time: float = 5.0

func _ready() -> void:
	move_timer.wait_time = randf_range(0, maximum_wait_time)
	move_timer.start()
	navigation_agent.set_target_position(Vector3(randf() * 20 - 10, 0.5, randf() * 20 - 10))


func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO
	
	if navigation_agent.is_navigation_finished():
		if move_timer.is_stopped():
			move_timer.wait_time = randf_range(minimum_wait_time, maximum_wait_time)
			move_timer.start()
	
	else:
		var target = navigation_agent.get_next_path_position()
		target.y = position.y
	
		direction = position.direction_to(target)
		
		look_at(target)
	
	if direction.length() > 0:
		velocity = velocity.lerp(direction * move_speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, friction * delta)
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()


func _on_move_timer_timeout() -> void:
	navigation_agent.set_target_position(Vector3(randf() * 20 - 10, 0.5, randf() * 20 - 10))
