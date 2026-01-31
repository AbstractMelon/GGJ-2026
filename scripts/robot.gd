extends CharacterBody3D
class_name Robot

@export var move_speed := 5.0
@export var acceleration := 10.0
@export var friction := 8.0

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var target_velocity := Vector3.ZERO
var is_mask_removed := false

@onready var skin := $Skin

func _ready() -> void:
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
	ApplyPartColor($Skin/RobotHead, colors[0] )
	ApplyPartColor($Skin/RobotArms, colors[1] )
	ApplyPartColor($Skin/RobotBody, colors[2])
	ApplyPartColor($Skin/RobotBottom, colors[3] )

func remove_mask() -> void:
	if is_mask_removed:
		return
	is_mask_removed = true
	animation_player.play("mask-remove")
	
	# Wait 2 seconds then hide the mask
	await get_tree().create_timer(1.0).timeout
	$Skin/Mask.visible = false
