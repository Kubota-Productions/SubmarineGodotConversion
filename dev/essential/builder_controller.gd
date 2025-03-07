class_name BuilderControl
extends CharacterBody3D

@export var inventory: Array[LevelBuildInventory]
@export var target_parent: Node3D
@export var set_free: bool = true
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_rotation: Node3D = $CameraPivot/CameraRotation
@onready var builder_point: BuilderPoint = $CameraPivot/CameraRotation/FarmBuilder
@onready var camera_3d: Camera3D = $CameraPivot/CameraRotation/Camera3D

var mouse_input: Vector2
var speed: float = 50.0

const builder_inventory: String = 'res://sanctum/builder/inventories/'

@export var mouse_sens: float = 0.05
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	builder_point.build_data.clear()
	for i in inventory:
		set_inventory(i)
	if target_parent:
		builder_point.target_parent = target_parent

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x) * mouse_sens)
		camera_rotation.rotate_x(deg_to_rad(-event.relative.y) * mouse_sens)
		camera_rotation.rotation.x = clamp(camera_rotation.rotation.x,deg_to_rad(-89),deg_to_rad(89))

		mouse_input = event.relative

	if Input.is_action_just_pressed('Sprint'):
		speed = 125.0
	elif Input.is_action_just_released('Sprint'):
		speed = 50.0

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var vertical_direction:= 0.0

	if Input.is_action_pressed('Jump'):
		vertical_direction = speed
	elif Input.is_action_pressed('Slam'):
		vertical_direction = -speed
	velocity.x = lerp(velocity.x,direction.x * speed,5*delta)
	velocity.y = lerp(velocity.y,vertical_direction,5*delta)
	velocity.z = lerp(velocity.z,direction.z * speed,5*delta)

	move_and_slide()

func grab_inventory() -> void:
	var dir = DirAccess.open(builder_inventory)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".remap"):
				file_name = file_name.replace(".remap", "")
			if file_name.ends_with(".import"):
				file_name = file_name.replace(".import", "")
			var resource_packet = load(builder_inventory+file_name)
			if resource_packet is LevelBuildInventory:
				set_inventory(resource_packet)
			file_name = dir.get_next()
	builder_point._ready()


func set_inventory(new_inventory: LevelBuildInventory) -> void:
	for i in new_inventory.build_data:
		builder_point.build_data.append(i)
