extends Robot
class_name NPC

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent

func _ready() -> void:
	navigation_agent.target_position = Vector3(randf() * 20 - 10, 0, randf() * 20 + 10)


func _physics_process(delta: float) -> void:
	
	
	
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	
	move_and_slide()
