extends CharacterBody3D
class_name Player

@export var move_speed := 5.0
@export var mouse_sensitivity := 0.002
@export var acceleration := 10.0
@export var friction := 8.0

@onready var camera: Camera3D = $Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var target_velocity := Vector3.ZERO
var camera_rotation := Vector2.ZERO
var _sync_timer := 0.0

@onready var skin := $Skin

func _ready() -> void:
	# Set up authority - only the owning player controls this character
	if is_multiplayer_authority():
		camera.current = true
<<<<<<< HEAD
		# Small delay for mouse capture to work reliably
		get_tree().create_timer(0.1).timeout.connect(func():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		)
=======
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		skin.visible = false
		
>>>>>>> 96284a7 (its a thing)
	else:
		# Disable camera for non-local players
		skin.visible = true
		camera.current = false
	ApplySkin([])

func _enter_tree() -> void:
	# Set multiplayer authority based on the node name (which is the peer ID)
	set_multiplayer_authority(str(name).to_int())

func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	
	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event.relative)
	
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _handle_mouse_look(mouse_delta: Vector2) -> void:
	camera_rotation.x -= mouse_delta.y * mouse_sensitivity
	camera_rotation.y -= mouse_delta.x * mouse_sensitivity
	
	# Clamp vertical rotation to prevent flipping
	camera_rotation.x = clamp(camera_rotation.x, -PI/2 + 0.1, PI/2 - 0.1)
	
	# Apply rotation
	rotation.y = camera_rotation.y
	camera.rotation.x = camera_rotation.x
	
	# Sync rotation to other players
	if _sync_timer > 1.0:
		_sync_rotation.rpc(camera_rotation)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_movement(delta)
		
		# Only sync if we've been active for a moment to allow other peers to join/load
		_sync_timer += delta
		if _sync_timer > 1.0:
			_sync_position.rpc(global_position, velocity)
	
	move_and_slide()
	
	
func ApplySkin(colors: Array[Color]):
	$Skin/RobotHead.find_children("*", "MeshInstance3D", true)[0].modulate = Color(1,0.5,0)

func _process_movement(delta: float) -> void:
	# Get input direction
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	
	# Calculate movement direction relative to camera
	var direction := Vector3.ZERO
	direction += transform.basis.z * input_dir.y
	direction += transform.basis.x * input_dir.x
	direction.y = 0  # Keep movement horizontal
	direction = direction.normalized()
	
	# Apply acceleration/deceleration
	if direction.length() > 0:
		target_velocity = target_velocity.lerp(direction * move_speed, acceleration * delta)
	else:
		target_velocity = target_velocity.lerp(Vector3.ZERO, friction * delta)
	
	velocity.x = target_velocity.x
	velocity.z = target_velocity.z
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta

@rpc("unreliable_ordered")
func _sync_position(pos: Vector3, vel: Vector3) -> void:
	if not is_multiplayer_authority():
		# Interpolate to the synced position
		global_position = global_position.lerp(pos, 0.5)
		velocity = vel

@rpc("unreliable_ordered")
func _sync_rotation(rot: Vector2) -> void:
	if not is_multiplayer_authority():
		camera_rotation = rot
		rotation.y = camera_rotation.y
		camera.rotation.x = camera_rotation.x
		
