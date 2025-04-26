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
	# fuck this why ! 
	#if not use_fixed :
		#update_camera_pos()

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
		if abs(forward.y) > 0.98:  # Nearly straight up/down
			var flat_forward = Vector3(forward.x, 0, forward.z).normalized()
			mouse_aim.global_transform.basis = Basis.looking_at(flat_forward, Vector3.UP).orthonormalized()

func rotate_rig(delta):
	if not mouse_aim or not camera_rig:
		return

	# Right mouse button to freeze/unfreeze aim direction
	if Input.is_action_just_pressed("right_click"):
		is_mouse_aim_frozen = true
		frozen_direction = mouse_aim.global_transform.basis.z.normalized()
	elif Input.is_action_just_released("right_click"):
		is_mouse_aim_frozen = false
		mouse_aim.global_transform.basis = Basis.looking_at(frozen_direction, Vector3.UP).orthonormalized()

	# Determine up vector based on pitch angle (like Unity version)
	var up_vec = aircraft.global_transform.basis.y if abs(mouse_aim.global_transform.basis.z.y) > 0.9 else Vector3.UP

	# Smoothly rotate camera rig towards mouse aim
	var target_basis = Basis.looking_at(mouse_aim.global_transform.basis.z.normalized(), up_vec).orthonormalized()
	camera_rig.global_transform.basis = damp(
		camera_rig.global_transform.basis.orthonormalized(),
		target_basis,
		cam_smooth_speed,
		delta
	)

func update_camera_pos(delta):
	if aircraft:
		global_transform.origin = lerp(global_transform.origin , aircraft.global_transform.origin,delta)

func damp(a: Basis, b: Basis, lambda: float, dt: float) -> Basis:
	return a.orthonormalized().slerp(b.orthonormalized(), 1 - exp(-lambda * dt))

## Debug functions
func update_debug_draw():
	clear_debug_draw()
	
	if aircraft:
		draw_sphere(get_boresight_pos(), Color.WHITE, 0.5)
	
	if mouse_aim:
		draw_sphere(get_mouse_aim_pos(), Color.RED, 0.5)
		draw_ray(mouse_aim.global_position, mouse_aim.global_position + mouse_aim.global_transform.basis.z * 5, Color.BLUE)
		draw_ray(mouse_aim.global_position, mouse_aim.global_position + mouse_aim.global_transform.basis.y * 5, Color.GREEN)
		draw_ray(mouse_aim.global_position, mouse_aim.global_position + mouse_aim.global_transform.basis.x * 5, Color.RED)

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

func draw_ray(from: Vector3, to: Vector3, color: Color):
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	add_child(instance)
	_debug_objects.append(instance)

## Position getters
func get_boresight_pos() -> Vector3:
	return (aircraft.global_transform.basis.z * aim_distance) + aircraft.global_position if aircraft else global_transform.basis.z * aim_distance

func get_mouse_aim_pos() -> Vector3:
	if is_mouse_aim_frozen:
		var x =mouse_aim.global_position + (frozen_direction * aim_distance) if mouse_aim else global_position + (global_transform.basis.z * aim_distance)
		return  x
	else:
		var x =  mouse_aim.global_position + (mouse_aim.global_transform.basis.z * aim_distance) if mouse_aim else global_position + (global_transform.basis.z * aim_distance)
		return x
