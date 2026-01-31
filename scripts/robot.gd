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
const ACCESSORIES = [
	preload("res://assets/parts/accessories/Bowtie.fbx"),
	preload("res://assets/parts/accessories/Crown.fbx"),
	preload("res://assets/parts/accessories/FancyHat.fbx"),
	preload("res://assets/parts/accessories/Tie.fbx"),
	preload("res://assets/parts/accessories/TopHat.fbx"),
]

func _ready() -> void:
	add_to_group("robot")
	# Use instance ID as random seed to ensure different robots get different parts
	seed(get_instance_id())
	RandomizeParts()
	ApplySkin(GenerateColorPallete())

func _physics_process(_delta: float) -> void:
	
	move_and_slide()

func RandomizeParts() -> void:
	# Store transforms
	var head_transform = $RobotModel/Skin/RobotHead.transform
	var arms_transform = $RobotModel/Skin/RobotArms.transform
	var body_transform = $RobotModel/Skin/RobotBody.transform
	var bottom_transform = $RobotModel/Skin/RobotBottom.transform
	var accessory_transform = $RobotModel/Skin/Accessory.transform
	
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
	
	var old_accessory = $RobotModel/Skin/Accessory
	$RobotModel/Skin.remove_child(old_accessory)
	old_accessory.free()
	
	# Instantiate random parts
	var new_head = HEADS.pick_random().instantiate()
	new_head.name = "RobotHead"
	new_head.transform = head_transform
	$RobotModel/Skin.add_child(new_head)
	
	var new_arms = ARMS.pick_random().instantiate()
	new_arms.name = "RobotArms"
	new_arms.transform = arms_transform
	$RobotModel/Skin.add_child(new_arms)
	
	var new_body = BODIES.pick_random().instantiate()
	new_body.name = "RobotBody"
	new_body.transform = body_transform
	$RobotModel/Skin.add_child(new_body)
	
	var new_bottom = BOTTOMS.pick_random().instantiate()
	new_bottom.name = "RobotBottom"
	new_bottom.transform = bottom_transform
	$RobotModel/Skin.add_child(new_bottom)
	
	var new_accessory = ACCESSORIES.pick_random().instantiate()
	new_accessory.name = "Accessory"
	new_accessory.transform = accessory_transform
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
