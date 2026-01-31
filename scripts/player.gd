extends Robot
class_name Player

enum Role { NONE, HACKER, DETECTIVE }

@export var mouse_sensitivity := 0.002

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var interaction_prompt: Label = $HUD/InteractionPrompt
@onready var role_label: Label = $HUD/RoleLabel

var camera_rotation := Vector2.ZERO
var _sync_timer := 0.0
var _e_was_pressed := false
var player_role: Role = Role.NONE

func _ready() -> void:
	super._ready()
	# Set up authority - only the owning player controls this character
	if is_multiplayer_authority():
		camera.current = true
		# Small delay for mouse capture to work reliably
		get_tree().create_timer(0.1).timeout.connect(func():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		skin.visible = false
		interaction_prompt.visible = false
		interaction_ray.add_exception(self)
		_update_role_ui()
	else:
		# Disable camera for non-local players
		skin.visible = true
		camera.current = false
		$HUD.visible = false
	ApplySkin(GenerateColorPallete())

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
		_handle_interaction()
		
		# Only sync if we've been active for a moment to allow other peers to join/load
		_sync_timer += delta
		if _sync_timer > 1.0:
			_sync_position.rpc(global_position, velocity)
	
	move_and_slide()

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
		

func _handle_interaction() -> void:
	var e_now = Input.is_key_pressed(KEY_E)

	# Hide prompt by default
	interaction_prompt.visible = false

	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider is Robot and collider != self:
			# Hacker can hack non-hacked robots
			if player_role == Role.HACKER and not collider.is_hacked:
				interaction_prompt.text = "Press E to hack"
				interaction_prompt.visible = true
				if e_now and not _e_was_pressed:
					_request_hack.rpc_id(1, str(collider.get_path()))
			# Detective can unmask people
			elif player_role == Role.DETECTIVE and not collider.is_mask_removed:
				interaction_prompt.text = "Press E to unmask"
				interaction_prompt.visible = true
				if e_now and not _e_was_pressed:
					_request_unmask.rpc_id(1, str(collider.get_path()))

	_e_was_pressed = e_now

@rpc("any_peer", "call_local", "reliable")
func set_role(role: Role) -> void:
	# Only allow server to set roles
	if not multiplayer.is_server():
		var sender_id = multiplayer.get_remote_sender_id()
		if sender_id != 1:
			return
	
	player_role = role
	if is_multiplayer_authority():
		_update_role_ui()

func _update_role_ui() -> void:
	if not role_label:
		return
	
	match player_role:
		Role.HACKER:
			role_label.text = "You are the HACKER"
			role_label.modulate = Color.RED
		Role.DETECTIVE:
			role_label.text = "You are the DETECTIVE"
			role_label.modulate = Color.CYAN
		_:
			role_label.text = ""
	
	role_label.visible = player_role != Role.NONE
