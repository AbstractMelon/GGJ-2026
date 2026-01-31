extends CharacterBody3D
class_name Robot

@export var move_speed := 5.0
@export var acceleration := 10.0
@export var friction := 8.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $RobotModel/AnimationPlayer

var target_velocity := Vector3.ZERO
var is_mask_removed := false

@onready var skin := $RobotModel/Skin

func _ready() -> void:
	add_to_group("robot")
	ApplySkin(GenerateColorPallete())

func _physics_process(_delta: float) -> void:
	
	move_and_slide()
	
	
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
	ApplyPartColor($RobotModel/Skin/RobotHead, colors[0] )
	ApplyPartColor($RobotModel/Skin/RobotArms, colors[1] )
	ApplyPartColor($RobotModel/Skin/RobotBody, colors[2])
	ApplyPartColor($RobotModel/Skin/RobotBottom, colors[3] )

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
