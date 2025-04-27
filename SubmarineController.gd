class_name SubmarineController
extends RigidBody3D

## Components
@export var controller: MouseFlightController = null

## Physics
@export var thrust: float = -20.0
@export var vertical_thrust: float = 10.0
@export var horizontal_thrust: float = 10.0
@export var max_thrust: float = -60.0
@export var turn_torque: Vector3 = Vector3(90.0, 25.0, 45.0)
@export var force_mult: float = 1.0

## Autopilot
@export var sensitivity: float = 0.1
@export var aggressive_turn_angle: float = 10.0  # Increased from 1.0 to match Unity

## Runtime
var pitch: float = 0.0
var yaw: float = 0.0
var roll: float = 0.0
var engine_toggle: bool = false
var current_thrust: float = 0.0
var move_direction: Vector3 = Vector3.ZERO

func _ready():
	angular_damp = 0.5  # Helps stabilize rotation
	if controller == null:
		push_error("SubmarineController: Missing reference to MouseFlightController!")

func _process(delta):
	var vertical_movement = Input.get_axis("Backward", "Forward")
	var horizontal_movement = Input.get_axis("Right", "Left")
	
	if Input.is_action_just_pressed("toggle_thrust"):
		engine_toggle = !engine_toggle
	
	if engine_toggle:
		if Input.is_action_pressed("speed_boost"):
			change_speed(max_thrust, delta)
		else:
			change_speed(thrust, delta)
	else:
		change_speed(0.0, delta)
	

	if controller:
		run_autopilot(controller.get_mouse_aim_pos(), delta)
	
	if Input.is_action_pressed("manual_roll"):
		roll = horizontal_movement
	
	move_direction = (Vector3.DOWN * vertical_thrust * vertical_movement * force_mult) + \
					(Vector3.RIGHT * horizontal_thrust * horizontal_movement * force_mult)

func change_speed(speed: float, delta: float):
	current_thrust = lerp(current_thrust, speed, delta * 5)
	if is_zero_approx(current_thrust):
		current_thrust = 0.0

func run_autopilot(fly_target, delta):
	var to_target = (fly_target - global_transform.origin).normalized()
	var local_fly_target = global_transform.basis.inverse() * to_target * sensitivity
	
	var angle_off_target = rad_to_deg(acos(Vector3.FORWARD.dot(to_target)))
	
	# Calculate yaw and pitch (negate for correct direction)
	yaw = clamp(local_fly_target.x, -1.0, 1.0)
	pitch = -clamp(local_fly_target.y, -1.0, 1.0)
	
	# Auto-leveling roll calculation (matches Unity version)
	var aggressive_roll = clamp(local_fly_target.x, -1.0, 1.0)
	var wings_level_roll = global_transform.basis.y.x  # Equivalent to transform.right.y in Unity
	var wings_level_influence = inverse_lerp(0.0, aggressive_turn_angle, angle_off_target)
	roll = lerp(wings_level_roll, aggressive_roll, wings_level_influence)

func _physics_process(delta):
	# Apply forces
	apply_central_force(global_transform.basis * Vector3.FORWARD * current_thrust * force_mult)
	apply_central_force(move_direction)
	
	# Stabilized torque (scaled by delta, clamped, and with adjusted roll sign)
	var torque = Vector3(
		turn_torque.x * clamp(pitch, -1, 1),
		turn_torque.y * clamp(yaw, -1, 1),
		turn_torque.z * clamp(roll, -1, 1)  # Removed negative sign to test
	) * force_mult * delta  # Critical: Multiply by delta
	
	apply_torque(global_transform.basis * torque)
	
	_draw_debug()

func _draw_debug():
	# Debug visualization
	for line in debug_lines:
		line.queue_free()
	debug_lines.clear()
	
	if controller:
		#print("MFC %s" % controller.get_mouse_aim_pos())
		# Line to target (white)
		_create_debug_line(global_position, controller.get_mouse_aim_pos(), Color.WHITE)
		# Forward vector (blue)
		_create_debug_line(global_position, global_position + global_transform.basis.z * -5, Color.BLUE)
		# Up vector (green)
		_create_debug_line(global_position, global_position + global_transform.basis.y * 5, Color.GREEN)
		# Right vector (red)
		_create_debug_line(global_position, global_position + global_transform.basis.x * 5, Color.RED)
		_create_debug_line(global_position, global_position + global_transform.basis.x * -5, Color.RED)

var debug_lines: Array[MeshInstance3D] = []

func _create_debug_line(from: Vector3, to: Vector3, color: Color):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(from)
	immediate_mesh.surface_add_vertex(to)
	immediate_mesh.surface_end()
	
	mesh_instance.mesh = immediate_mesh
	get_tree().root.add_child(mesh_instance)
	debug_lines.append(mesh_instance)
