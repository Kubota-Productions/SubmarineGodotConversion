class_name MouseFlightController
extends Node3D

## Components
@export var aircraft: Node3D = null
@export var mouse_aim: Node3D = null
@export var camera_rig: Node3D = null
@export var cam: Camera3D = null

## Options
@export var use_fixed: bool = true
@export var cam_smooth_speed: float = 5.0
@export var mouse_sensitivity: float = 3.0
@export var aim_distance: float = 500.0
@export var show_debug_info: bool = false
@export var position_follow_speed: float = 10.0 

## Runtime
var frozen_direction: Vector3 = Vector3.FORWARD
var is_mouse_aim_frozen: bool = false
var _debug_objects: Array[Node3D] = []

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Validate required components
	if not aircraft:
		push_error("MouseFlightController: No aircraft assigned!")
	if not mouse_aim:
		push_error("MouseFlightController: No mouse aim assigned!")
	if not camera_rig:
		push_error("MouseFlightController: No camera rig assigned!")
	if not cam:
		push_error("MouseFlightController: No camera assigned!")
	
	# Ensure we're not parented to anything to avoid inherited rotations
	if get_parent():
		var original_parent = get_parent()
		var original_transform = original_parent.global_transform
		get_parent().call_deferred("remove_child", self)
		get_tree().root.call_deferred("add_child", self)
		global_transform = original_transform

func _process(delta):
	if not use_fixed:
		update_camera_pos(delta)

	rotate_rig(delta)
	
	if show_debug_info:
		update_debug_draw()

func _physics_process(delta):
	if use_fixed:
		update_camera_pos(delta)

func _input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate the aim target using camera's axes (like Unity version)
		var mouse_delta = event.relative * mouse_sensitivity * 0.01
		mouse_aim.rotate(cam.global_transform.basis.x.normalized(), -mouse_delta.y)
		mouse_aim.rotate(cam.global_transform.basis.y.normalized(), -mouse_delta.x)
		
		# Clamp rotation to prevent flipping
		var forward = mouse_aim.global_transform.basis.z.normalized()
		if abs(forward.y) > 0.99:  # Nearly straight up/down
			var flat_forward = Vector3(forward.x, 0, forward.z).normalized()
			var target_basis = Basis.looking_at(flat_forward, Vector3.UP).orthonormalized()
			mouse_aim.global_transform.basis = target_basis

func rotate_rig(delta):
	if not mouse_aim or not camera_rig or not cam or not aircraft:
		return

	# Right mouse button to freeze/unfreeze aim direction
	if Input.is_action_just_pressed("right_click"):
		is_mouse_aim_frozen = true
		frozen_direction = mouse_aim.global_transform.basis.z.normalized()
	elif Input.is_action_just_released("right_click"):
		is_mouse_aim_frozen = false
		mouse_aim.global_transform.basis = Basis.looking_at(frozen_direction, Vector3.UP).orthonormalized()

	# Determine up vector: use camera_rig's up when nearly vertical, else aircraft's up
	var up_vec = camera_rig.global_transform.basis.y if abs(mouse_aim.global_transform.basis.z.y) > 0.9 else aircraft.global_transform.basis.y

	# Calculate target basis using mouse_aim's forward and aircraft's up vector
	var target_forward = mouse_aim.global_transform.basis.z.normalized()
	var target_basis = Basis.looking_at(target_forward, up_vec).orthonormalized()

	# Smoothly rotate camera rig towards the target basis
	camera_rig.global_transform.basis = damp(
		camera_rig.global_transform.basis.orthonormalized(),
		target_basis,
		cam_smooth_speed,
		delta
	)

func update_camera_pos(delta):
	if aircraft:
		global_transform.origin = global_transform.origin.lerp(
			aircraft.global_transform.origin,
			position_follow_speed * delta)

func damp(a: Basis, b: Basis, lambda: float, dt: float) -> Basis:
	return a.orthonormalized().slerp(b.orthonormalized(), 1 - exp(-lambda * dt))

## Debug functions
func update_debug_draw():
	clear_debug_draw()

func clear_debug_draw():
	for obj in _debug_objects:
		obj.queue_free()
	_debug_objects.clear()

func draw_sphere(pos: Vector3, color: Color, size: float):
	var mesh = SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.global_position = pos
	add_child(instance)
	_debug_objects.append(instance)

## Position getters
func get_boresight_pos() -> Vector3:
	if aircraft:
		return (aircraft.global_transform.basis.z * aim_distance) + aircraft.global_position
	else: 
		return global_transform.basis.z * aim_distance

func get_mouse_aim_pos() -> Vector3:
	var x: Vector3
	if is_mouse_aim_frozen:
		if mouse_aim:
			x = mouse_aim.global_position + (frozen_direction * aim_distance) 
		else:
			x = global_position + (global_transform.basis.z * aim_distance)
	else:
		if mouse_aim:
			x = mouse_aim.global_position + (mouse_aim.global_transform.basis.z * aim_distance)
		else:
			x = global_position + (global_transform.basis.z * aim_distance)
			
	return x
