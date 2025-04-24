class_name SubmarineController
extends RigidBody3D

## Components
@export var controller: MouseFlightController = null
# Add this at the top with other class variables
var debug_lines: Array[MeshInstance3D] = []
## Physics
@export var thrust: float = 10.0 ## Normal forward thrust
@export var vertical_thrust: float = 10.0 ## Up/down thrust
@export var horizontal_thrust: float = 10.0 ## Left/right thrust
@export var max_thrust: float = 30.0 ## Boost thrust
@export var turn_torque: Vector3 = Vector3(90.0, 25.0, 45.0) ## Pitch, Yaw, Roll torque
@export var force_mult: float = 1.0 ## Force multiplier (reduced from 10.0)

## Autopilot
@export var sensitivity: float = 0.1 ## Autopilot sensitivity
@export var aggressive_turn_angle: float = 1.0 ## Angle for aggressive turns

## Runtime
var pitch: float = 0.0
var yaw: float = 0.0
var roll: float = 0.0
var engine_toggle: bool = false ## Start with engine on like Unity version
var current_thrust: float = 0.0
var move_direction: Vector3 = Vector3.ZERO

func _ready():
	if controller == null:
		push_error("SubmarineController: Missing reference to MouseFlightController!")

func _process(delta):
	# Get movement input (matches Unity axis conventions)
	var vertical_movement = Input.get_axis("Backward", "Forward")
	var horizontal_movement = Input.get_axis("Right", "Left")
	
	# Engine control
	if Input.is_action_just_pressed("toggle_thrust"):
		engine_toggle = !engine_toggle
	
	# Thrust control
	if engine_toggle:
		if Input.is_action_pressed("speed_boost"):
			change_speed(max_thrust, delta)
		else:
			change_speed(thrust, delta)
	else:
		change_speed(0.0, delta)
	
	# Reset autopilot values
	yaw = 0.0
	pitch = 0.0
	roll = 0.0
	
	if controller:
		run_autopilot(controller.get_mouse_aim_pos())
	
	# Apply manual controls if pressed
	if Input.is_action_pressed("manual_roll"):
		roll = horizontal_movement
	
	# Calculate movement direction
	move_direction = (Vector3.UP * vertical_thrust * vertical_movement * force_mult) + \
					(Vector3.RIGHT * horizontal_thrust * horizontal_movement * force_mult)

func change_speed(speed: float, delta: float):
	# Smoothly change thrust using lerp like Unity version
	current_thrust = lerp(current_thrust, speed, delta * 5)
	if is_zero_approx(current_thrust):
		current_thrust = 0.0

func run_autopilot(fly_target: Vector3):
	return
	# Convert target to local space (matches Unity's InverseTransformPoint)
	var local_fly_target = global_transform.basis.inverse() * (fly_target - global_position).normalized() * sensitivity
	var angle_off_target = rad_to_deg(acos(Vector3.FORWARD.dot((fly_target - global_position).normalized())))
	
	# Calculate yaw and pitch to face target
	yaw = clamp(local_fly_target.x, -1.0, 1.0)
	pitch = -clamp(local_fly_target.y, -1.0, 1.0)
	
	# Calculate roll (mix between aggressive and level flight)
	var aggressive_roll = clamp(local_fly_target.x, -1.0, 1.0)
	var wings_level_roll = transform.basis.x.y
	var wings_level_influence = inverse_lerp(0.0, aggressive_turn_angle, angle_off_target)
	
	roll = lerp(wings_level_roll, aggressive_roll, wings_level_influence)

func _physics_process(delta):
		# ... (rest of your physics code)
	_draw_debug()
	# Apply forces (matches Unity's ForceMode.Force)
	apply_central_force(transform.basis * Vector3.FORWARD * current_thrust * force_mult)
	apply_central_force(move_direction)
	
	# Apply torque (without delta multiplication for more responsive turning)
	apply_torque(transform.basis * Vector3(
		turn_torque.x * pitch,
		turn_torque.y * yaw,
		-turn_torque.z * roll
	) * force_mult)

# Add this function
func _draw_debug():
	print(self)
	# Clear old debug lines
	for line in debug_lines:
		line.queue_free()
	debug_lines.clear()
	
	# Create new debug lines
	if controller:
		_create_debug_line(global_position, global_position + global_transform.basis.z, Color.RED)
		_create_debug_line(global_position, controller.get_mouse_aim_pos(), Color.GREEN)
		_create_debug_line(controller.global_position, controller.get_mouse_aim_pos(), Color.BLUE)

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
	add_child(mesh_instance)
	debug_lines.append(mesh_instance)
