extends CharacterBody3D

@export var wander_area: Vector3 = Vector3(50, 0, 50) # Size of the area to wander within
@export var speed: float = 3.0 # Speed of the NPC
@export var wait_time_range: Vector2 = Vector2(1, 5) # Range of wait times

var target_position: Vector3
var waiting: bool = false

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var wait_timer: Timer = $Timer

func _ready():
	wait_timer.connect("timeout", _on_wait_timer_timeout)
	set_random_target_position()

func _process(delta):
	if waiting:
		return

	var direction = (target_position - global_position).normalized()
	# Move the character
	global_position += direction * speed * delta
	
	# Rotate the character to face the movement direction
	set_train_rotation(direction)
	
	if global_position.distance_to(target_position) < 1:
		wait_before_next_move()

func set_random_target_position():
	var random_x = randf_range(-wander_area.x / 2, wander_area.x / 2)
	var random_z = randf_range(-wander_area.z / 2, wander_area.z / 2)
	target_position = global_position + Vector3(random_x, 0, random_z)

func set_train_rotation(direction: Vector3):
	# Skip rotation if direction is zero or nearly zero
	if direction.length_squared() < 0.01:
		return
	
	# Ensure the character faces the direction of movement
	# Use look_at to align the character's forward vector (-Z in Godot) with the direction
	var target_pos = global_position + direction
	look_at(target_pos, Vector3.UP)

func wait_before_next_move():
	waiting = true
	# Use wait_time_range for random wait time
	var wait_time = randf_range(wait_time_range.x, wait_time_range.y)
	wait_timer.start(wait_time)

func _on_wait_timer_timeout():
	waiting = false
	set_random_target_position()
