class_name SubmarineController
extends RigidBody3D

##levelloading
@onready var test_scene: PackedScene = preload("res://Scenes/test_scene.tscn")
@onready var level_loader: Levelloader = get_tree().root.get_node("Main").get_node("LevelLoader")

var fuel_empty_triggered := false

## Components
@export var controller: MouseFlightController = null
@export var sub_particles: GPUParticles3D = null
@export var submarinemodel: Node3D = null

## Physics
@export var thrust: float = -10  # Matched Unity's thrust = 100f
@export var vertical_thrust: float = -10 # Matched Unity's verticalThrust = 100f
@export var horizontal_thrust: float = -10  # Matched Unity's horizontalThrust = 100f
@export var max_thrust: float = -20  # Matched Unity's maxthrust = 69f
@export var turn_torque: Vector3 = Vector3(90.0, 25.0, 45.0)  # Matched Unity's turnTorque
@export var force_mult: float = 1000.0  # Matched Unity's forceMult = 1000 * 100

## Autopilot
@export var sensitivity: float = 5.0  # Matched Unity's sensitivity = 5f
@export var aggressive_turn_angle: float = 10.0  # Matched Unity's aggressiveTurnAngle = 10f

## Fuel System
@export var max_fuel: float = 100.0
@export var fuel: float = 100.0
@export var fuel_depletion_rate: float = 5.0  # Units per second when moving
@onready var fuelbar: ProgressBar = $Hud/Fuelbar

## Runtime
var pitch: float = 0.0
var yaw: float = 0.0
var roll: float = 0.0
var engine_toggle: bool = true  # Matched Unity's engineToggle = true (thrust off)
var current_thrust: float = 0.0
var move_direction: Vector3 = Vector3.ZERO
var previous_speed: float = 0.0  # Added to match Unity's previousSpeed
var speed_i: float = 0.0  # Added to match Unity's speedI

func _ready():
	submarinemodel.particles = sub_particles
	
	angular_damp = 2.0  # Increased to mimic Unity's Rigidbody angular drag
	if controller == null:
		push_error("SubmarineController: Missing reference to MouseFlightController!")

func _process(delta):
	var vertical_movement = Input.get_axis("ui_down", "ui_up")
	var horizontal_movement = Input.get_axis("ui_right", "ui_left")
	if is_instance_valid(fuelbar):
		fuelbar.max_value = max_fuel
		fuelbar.value = fuel

	if Input.is_action_just_pressed("toggle_thrust"):
		engine_toggle = !engine_toggle

	if engine_toggle or fuel <= 0.0:
		change_speed(0.0, delta)
	else:
		if Input.is_action_pressed("speed_boost"):
			change_speed(max_thrust, delta)
		else:
			change_speed(thrust, delta)

		# Deplete fuel if thrust or movement input is active
		if abs(current_thrust) > 0.01 or vertical_movement != 0 or horizontal_movement != 0:
			fuel = max(fuel - fuel_depletion_rate * delta, 0.0)

	if controller:
		run_autopilot(controller.get_mouse_aim_pos(), delta)

	if Input.is_action_pressed("manual_roll"):
		roll = horizontal_movement

	move_direction = (global_transform.basis.y * vertical_thrust * vertical_movement * force_mult) + \
					 (global_transform.basis.x * horizontal_thrust * horizontal_movement * force_mult)
					
	# Trigger scene change when fuel is depleted
	if fuel <= 0.0 and not fuel_empty_triggered:
		fuel_empty_triggered = true
		level_loader._loadlevel("res://Scenes/test_scene.tscn")

func change_speed(speed: float, delta: float):
	if previous_speed != speed:
		previous_speed = speed
		speed_i = 0.0
	current_thrust = lerp(current_thrust, speed, (speed_i + delta) * 5)
	speed_i += delta
	if is_zero_approx(current_thrust):
		current_thrust = 0.0

func run_autopilot(fly_target: Vector3, delta: float):
	var local_fly_target = global_transform.basis.inverse() * (fly_target - global_position).normalized() * sensitivity
	
	var angle_off_target = rad_to_deg(acos(global_transform.basis.z.normalized().dot((fly_target - global_position).normalized())))
	
	yaw = clamp(local_fly_target.x, -1.0, 1.0)
	pitch = -clamp(local_fly_target.y, -1.0, 1.0)

	var aggressive_roll = clamp(local_fly_target.x, -1.0, 1.0)
	var wings_level_roll = global_transform.basis.x.y
	var wings_level_influence = inverse_lerp(0.0, aggressive_turn_angle, angle_off_target)
	roll = lerp(wings_level_roll, aggressive_roll, wings_level_influence)

func _physics_process(delta):
	apply_central_force(global_transform.basis * Vector3.FORWARD * current_thrust * force_mult)
	apply_central_force(move_direction)

	var torque = Vector3(
		turn_torque.x * clamp(pitch, -1, 1),
		turn_torque.y * clamp(yaw, -1, 1),
		-turn_torque.z * clamp(roll, -1, 1)
	) * force_mult * delta

	apply_torque(global_transform.basis * torque)

	_draw_debug()

# Debug visualization (unchanged)
func _draw_debug():
	for line in debug_lines:
		line.queue_free()
	debug_lines.clear()
	
	#if controller:
		#_create_debug_line(global_position, global_position + global_transform.basis.z * -5, Color.BLUE)
		#_create_debug_line(global_position, global_position + global_transform.basis.y * 5, Color.GREEN)
		#_create_debug_line(global_position, global_position + global_transform.basis.x * 5, Color.RED)
		#_create_debug_line(global_position, global_position + global_transform.basis.x * -5, Color.RED)

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
