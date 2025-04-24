class_name MouseFlightController extends Node3D

@export var aircraft: Node3D = null
@export var mouse_aim: Node3D 
@export var camera_rig: Node3D = null
@export var cam: Camera3D = null

@export var use_fixed: bool = true
@export var cam_smooth_speed: float = 5.0
@export var mouse_sensitivity: float = 3.0
@export var aim_distance: float = 500.0
@export var show_debug_info: bool = false
var mouse_x_global := 0.0
var mouse_y_global := 0.0

var frozen_direction: Vector3 = Vector3.FORWARD
var is_mouse_aim_frozen: bool = false

func _ready():
		# Capture the mouse so it is hidden and relative mouse motion is used
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
	if not aircraft:
		push_error("MouseFlightController: No aircraft assigned!")
	if not mouse_aim:
		push_error("MouseFlightController: No mouse aim assigned!")
	if not camera_rig:
		push_error("MouseFlightController: No camera rig assigned!")
	if not cam:
		push_error("MouseFlightController: No camera assigned!")
	
	# The rig should not be parented to anything to avoid unintended rotations
	#get_parent().remove_child(self)
	#get_tree().root.add_child(self)

func _process(delta):
	if not use_fixed:
		update_camera_pos()
	rotate_rig(delta)

func _physics_process(delta):
	if use_fixed:
		update_camera_pos()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_x = event.relative.x * mouse_sensitivity
		var mouse_y = -event.relative.y * mouse_sensitivity
		mouse_x_global = mouse_x
		mouse_y_global = mouse_y

func rotate_rig(delta):
	if not mouse_aim or not cam or not camera_rig:
		return

	# Right mouse button to freeze/unfreeze aim direction
	if Input.is_action_just_pressed("right_click"):
		is_mouse_aim_frozen = true
		frozen_direction = mouse_aim.global_transform.basis.z
	elif Input.is_action_just_released("right_click"):
		is_mouse_aim_frozen = false
		mouse_aim.look_at(mouse_aim.global_transform.origin + frozen_direction, Vector3.UP)

	# Get mouse movement
	var mouse_x = mouse_x_global
	var mouse_y = mouse_y_global

	mouse_aim.rotate_object_local(Vector3.RIGHT, deg_to_rad(mouse_y))
	mouse_aim.rotate_object_local(Vector3.UP, deg_to_rad(mouse_x))

	# Determine up vector based on pitch angle
	var up_vec = camera_rig.global_transform.basis.y if abs(mouse_aim.global_transform.basis.z.y) > 0.9 else Vector3.UP

	# Smoothly rotate camera rig towards mouse aim, using the computed aim position
	var target_rotation = camera_rig.global_transform.looking_at(MouseAimPos(), up_vec)
	camera_rig.global_transform.basis = damp(camera_rig.global_transform.basis, target_rotation.basis, cam_smooth_speed, delta)

func get_frozen_mouse_aim_pos() -> Vector3:
	if mouse_aim:
		return mouse_aim.global_transform.origin + frozen_direction * aim_distance
	return global_transform.origin + (global_transform.basis.z * aim_distance)

func update_camera_pos():
	if aircraft:
		global_transform.origin = aircraft.global_transform.origin

# Frame-rate independent damping function
func damp(a: Basis, b: Basis, lambda: float, dt: float) -> Basis:
	a = a.orthonormalized()
	b = b.orthonormalized()
	return a.slerp(b, 1 - exp(-lambda * dt))

func _draw():
	if show_debug_info:
		if aircraft:
			draw_sphere(BoresightPos(), Color.WHITE)
		if mouse_aim:
			draw_sphere(MouseAimPos(), Color.RED)
			draw_ray(mouse_aim.global_transform.origin, mouse_aim.global_transform.origin + mouse_aim.global_transform.basis.z * 50, Color.BLUE)
			draw_ray(mouse_aim.global_transform.origin, mouse_aim.global_transform.origin + mouse_aim.global_transform.basis.y * 50, Color.GREEN)
			draw_ray(mouse_aim.global_transform.origin, mouse_aim.global_transform.origin + mouse_aim.global_transform.basis.x * 50, Color.RED)

# Helper debug draw functions
func draw_sphere(pos: Vector3, color: Color):
	var debug_sphere = ImmediateMesh.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	debug_sphere.surface_set_material(0, mat)
	var instance = MeshInstance3D.new()
	instance.mesh = debug_sphere
	instance.global_transform.origin = pos
	add_child(instance)

func draw_ray(from: Vector3, to: Vector3, color: Color):
	var line = ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(from)
	line.surface_add_vertex(to)
	line.surface_end()
	var instance = MeshInstance3D.new()
	instance.mesh = line
	add_child(instance)

func BoresightPos() -> Vector3:
	return (aircraft.global_transform.basis.z * aim_distance) + aircraft.global_transform.origin if aircraft else global_transform.basis.z * aim_distance

func MouseAimPos() -> Vector3:
	return get_frozen_mouse_aim_pos() if is_mouse_aim_frozen else mouse_aim.global_transform.origin + mouse_aim.global_transform.basis.z * aim_distance
