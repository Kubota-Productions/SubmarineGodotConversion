class_name SubmarineController
extends RigidBody3D

@export_category("Control Variables")
@export var curve : Curve ## Unused for now
@export var thrust : float = 0.10 ## default "engine on" speed
@export var max_thrust : float  = 0.30 ## The "boost speed"
@export var turn_torque: Vector3 = Vector3(90.0, 25.0, 45.0) 
@export var force_mult: float = 1000.0 
@export var sensitivity: float = 5.0 
@export var aggressive_turn_angle: float = 10.0 
@export var controller: MouseFlightController ## Camera Rig Node

var pitch: float = 0.0 
var yaw: float = 0.0 
var roll: float = 0.0 
var engine_toggle: bool = false 
var previous_speed: float = 0.0 
var current_thrust: float = 0.0 
var move_direction: Vector3 = Vector3.ZERO

func _process(delta):
	## Get input for movement
	var vertical_movement = Input.get_axis("Backward", "Forward") ## Now controls vertical movement
	var horizontal_movement = Input.get_axis("Right", "Left")
	
	## Engine toggle
	if Input.is_action_just_pressed("toggle_thrust"):
		engine_toggle = !engine_toggle 
		if not engine_toggle:
			current_thrust = 0.0  ## Ensure thrust is reset when toggling off
	
	## Adjust speed based on engine state
	if engine_toggle:
		if Input.is_action_pressed("speed_boost"):
			change_speed(max_thrust, delta)
		else:
			change_speed(thrust, delta)
	else:
		current_thrust = 0.0

	## Auto-turn behavior
	var auto_yaw = 0.0
	var auto_pitch = 0.0
	var auto_roll = 0.0

	if controller:
		run_autopilot(controller.MouseAimPos(), auto_yaw, auto_pitch, auto_roll)

	yaw = auto_yaw
	pitch = auto_pitch
	roll = auto_roll if not Input.is_action_pressed("manual_roll") else horizontal_movement
	
	## Ensure submarine moves in all directions properly only when input is given
	move_direction = Vector3.ZERO
	if horizontal_movement != 0.0 or vertical_movement != 0.0:
		move_direction = (transform.basis * Vector3(horizontal_movement, vertical_movement, 0)).normalized() * force_mult
	if engine_toggle:
		move_direction += transform.basis.z * current_thrust * force_mult

func change_speed(speed: float, delta: float):
	if !is_equal_approx(previous_speed, speed):
		previous_speed = speed

	current_thrust = lerp(current_thrust, speed, (delta) * 5)
	if is_zero_approx(current_thrust):
		current_thrust = 0.0

func run_autopilot(fly_target: Vector3, out_yaw: float, out_pitch: float, out_roll: float):
	var local_fly_target = global_transform.basis.inverse() * (fly_target - global_position).normalized() * sensitivity
	var angle_off_target = rad_to_deg(acos(Vector3.FORWARD.dot((fly_target - global_position).normalized())))

	out_yaw = clamp(local_fly_target.x, -1.0, 1.0)
	out_pitch = -clamp(local_fly_target.y, -1.0, 1.0)

	var aggressive_roll = clamp(local_fly_target.x, -1.0, 1.0)
	var wings_level_roll = transform.basis.x.y
	var wings_level_influence = clamp(angle_off_target / aggressive_turn_angle, 0.0, 1.0)

	out_roll = lerp(wings_level_roll, aggressive_roll, wings_level_influence)

func _physics_process(delta):
	## Apply movement forces based on thrust
	apply_central_force(move_direction)
	apply_torque(Vector3(turn_torque.x * pitch, turn_torque.y * yaw, -turn_torque.z * roll) * force_mult)
	
	print("current pos = " + str(position))
	print("vel = " + str(linear_velocity))
