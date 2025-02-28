extends RigidBody3D

@export var camera : Node3D 
@export var camera_target : Node3D
@export var speed : float = 50
@export var rotation_node : Node3D
@export var turn_speed = 0.1
@export var upside_down_threshold = 0.02  # Threshold for detecting if the object is upside down

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gravity_scale = 0  # Disable gravity for this example

func _physics_process(delta: float) -> void:
	# Smoothly rotate towards the target rotation based on the input from rotation_node
	global_rotation.x = lerp_angle(global_rotation.x, rotation_node.global_rotation.x, turn_speed)
	global_rotation.y = lerp_angle(global_rotation.y, rotation_node.global_rotation.y, turn_speed)
	global_rotation.z = lerp_angle(global_rotation.z, rotation_node.global_rotation.z, turn_speed)
	
	# Handle forward movement
	if Input.is_action_pressed("forward"):
		var direction := (camera_target.global_position - camera.global_position).normalized()
		apply_central_force(direction * speed)
	
	# Handle turning left and right
	if Input.is_action_pressed("left"):
		rotate_y(0.02)
	if Input.is_action_pressed("right"):
		rotate_y(-0.02)
	
