class_name SubmarineController
extends RigidBody3D

@export_category("Control Variables")
@export var curve : Curve ## Unused for now
@export var thrust : float = 0.10 ## default "engine on" speed
@export var max_thrust : float  = 0.30 ## The "boost speed"
@export_range(-100.0, 100.0) var y_axis_thrust : float = 0.0 ## Thrust along the vertical axis, locally relative to the sub
@export_range(-100.0, 100.0) var x_axis_thrust : float = 0.0 ## Thrust along the left-right axis, locally relative to the sub
@export var turn_torque: Vector3 = Vector3(90.0, 25.0, 45.0) ## Don't understand yet
@export var force_mult: float = 1000.0 ## Don't understand yet
@export var sensitivity: float = 5.0 ## Don't understand yet
@export var aggressive_turn_angle: float = 10.0	## Maybe means maximum turn angle, unsure
@export var controller: MouseFlightController ## Camera Rig Node

var pitch: float = 0.0 ## Rotation around the x-axis
var yaw: float = 0.0 ## Rotation around the y-axis
var roll: float = 0.0 ## Rotation around the z-axis
var engine_toggle: bool = false ## The engine being on or off
var previous_speed: float = 0.0 ## necessary for acceleration and deceleration math
var current_thrust: float = 0.0 ## Don't understand yet
var move_direction: Vector3 ## May be unintuitive.

#func _ready():
	#Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)		## Disables the mouse from exiting the viewport
	## TODO https://docs.godotengine.org/en/4.3/classes/class_input.html#enum-input-mousemode
	## may want to change the input of the mouse to MOUSE_MODE_CAPTURED, but the way to collect mouse
	## movement changes to InputEventMouseMotion.relative   // I would just implement this myself 
	## but I'm not there yet, hence: TODO

func _process(delta):
	## captures the input for y axis and x axis movement RELATIVE TO THE SUB'S ROTATION
	var vertical_movement = Input.get_axis("Backward", "Forward")
	var horizontal_movement = Input.get_axis("Left", "Right")
	
	## captures the input for engaging and disengaging the engine
	if Input.is_action_just_pressed("toggle_thrust"):
		engine_toggle = not engine_toggle # taggles to the opposite state
	
	## if the engine is ON...
	if engine_toggle:
		## change target speed to standard thrust value
		change_speed(thrust, delta)
		## if the speed boost is activated...
		if Input.is_action_pressed("speed_boost"):
			## change target speed to max_thrust value
			change_speed(max_thrust, delta)
	else:
		change_speed(0.0, delta)
	
	var auto_yaw = 0.0
	var auto_pitch = 0.0
	var auto_roll = 0.0

	if controller: 
		run_autopilot(controller.MouseAimPos(), auto_yaw, auto_pitch, auto_roll)

	yaw = auto_yaw
	pitch = auto_pitch
	roll = auto_roll if not Input.is_action_pressed("manual_roll") else horizontal_movement
	


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
	move_direction = (Vector3.UP * y_axis_thrust * force_mult) + (Vector3.RIGHT * x_axis_thrust * force_mult)
	

	apply_central_force((Vector3.FORWARD * current_thrust * force_mult + move_direction) * 1)
	apply_torque(Vector3(turn_torque.x * pitch, turn_torque.y * yaw, -turn_torque.z * roll) * force_mult)
	print("current pos = " + str(position))
	print("vel = " + str(linear_velocity))
