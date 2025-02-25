extends RigidBody3D

@export var thrust: float = 100.0
@export var vertical_thrust: float = 100.0
@export var horizontal_thrust: float = 100.0
@export var max_thrust: float = 69.0
@export var turn_torque: Vector3 = Vector3(90.0, 25.0, 45.0)
@export var force_mult: float = 1000.0
@export var sensitivity: float = 5.0
@export var aggressive_turn_angle: float = 10.0

var pitch: float = 0.0
var yaw: float = 0.0
var roll: float = 0.0
var engine_toggle: bool = true
var previous_speed: float = 0.0
var speed_interpolator: float = 0.0
var current_thrust: float = 0.0
var move_direction: Vector3

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

func _process(delta):
	var vertical_movement = Input.get_axis("move_down", "move_up")
	var horizontal_movement = Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("toggle_thrust"):
		engine_toggle = not engine_toggle

	if engine_toggle:
		change_speed(0, delta)
	elif Input.is_action_pressed("speed_boost"):
		change_speed(max_thrust, delta)
	else:
		change_speed(thrust, delta)

	var auto_yaw = 0.0
	var auto_pitch = 0.0
	var auto_roll = 0.0

	run_autopilot(auto_yaw, auto_pitch, auto_roll)

	yaw = auto_yaw
	pitch = auto_pitch
	roll = auto_roll if not Input.is_action_pressed("manual_roll") else horizontal_movement

func change_speed(speed: float, delta: float):
	if previous_speed != speed:
		previous_speed = speed
		speed_interpolator = 0.0

	current_thrust = lerp(current_thrust, speed, (speed_interpolator + delta) * 5)

func run_autopilot(out_yaw: float, out_pitch: float, out_roll: float):
	var fly_target = Vector3.ZERO  # Replace with actual target logic
	var local_fly_target = global_transform.basis.inverse() * (fly_target - global_position).normalized() * sensitivity
	var angle_off_target = rad_to_deg(acos(Vector3.FORWARD.dot((fly_target - global_position).normalized())))

	out_yaw = clamp(local_fly_target.x, -1.0, 1.0)
	out_pitch = -clamp(local_fly_target.y, -1.0, 1.0)

	var aggressive_roll = clamp(local_fly_target.x, -1.0, 1.0)
	var wings_level_roll = transform.basis.x.y
	var wings_level_influence = clamp(angle_off_target / aggressive_turn_angle, 0.0, 1.0)

	out_roll = lerp(wings_level_roll, aggressive_roll, wings_level_influence)

func _physics_process(delta):
	move_direction = (Vector3.UP * vertical_thrust * force_mult) + (Vector3.RIGHT * horizontal_thrust * force_mult)
	
	apply_central_force((Vector3.FORWARD * current_thrust * force_mult + move_direction) * delta)
	apply_torque(Vector3(turn_torque.x * pitch, turn_torque.y * yaw, -turn_torque.z * roll) * force_mult)
