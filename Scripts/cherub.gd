extends CharacterBody3D

@export var wander_area: Vector3 = Vector3(50, 0, 50)
@export var speed: float = 3.0
@export var run_away_speed: float = 6.0
@export var wait_time_range: Vector2 = Vector2(1, 5)
@export var player_detection_radius: float = 10.0

var target_position: Vector3
var waiting: bool = false
var fleeing: bool = false

@onready var wait_timer: Timer = $Timer
@onready var player: BuilderControl = $"../BuilderController"
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	wait_timer.timeout.connect(_on_wait_timer_timeout)
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	set_random_target_position()

func _physics_process(delta: float) -> void:
	if not player:
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player < player_detection_radius:
		run_away_from_player()
	else:
		if fleeing:
			fleeing = false
			set_random_target_position()

		if waiting:
			self.velocity = Vector3.ZERO
		else:
			move_toward_path(speed)

	move_and_slide()

func run_away_from_player() -> void:
	fleeing = true
	waiting = false
	var flee_direction = (global_position - player.global_position).normalized()
	flee_direction.y = 0
	var flee_target = global_position + flee_direction * 10.0  # Run 10 units away
	nav_agent.set_target_position(flee_target)

func move_toward_path(move_speed: float) -> void:
	if nav_agent.is_navigation_finished():
		if not fleeing:
			wait_before_next_move()
		self.velocity = Vector3.ZERO
		return

	var next_pos = nav_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	direction.y = 0
	self.velocity = direction * move_speed
	set_train_rotation(direction)

func set_random_target_position() -> void:
	var random_x = randf_range(-wander_area.x / 2, wander_area.x / 2)
	var random_z = randf_range(-wander_area.z / 2, wander_area.z / 2)
	var target = global_position + Vector3(random_x, 0, random_z)
	nav_agent.set_target_position(target)

func set_train_rotation(direction: Vector3) -> void:
	if direction.length_squared() < 0.01:
		return
	var target_pos = global_position + direction
	look_at(target_pos, Vector3.UP)

func wait_before_next_move() -> void:
	waiting = true
	var wait_time = randf_range(wait_time_range.x, wait_time_range.y)
	wait_timer.start(wait_time)

func _on_wait_timer_timeout() -> void:
	waiting = false
	set_random_target_position()
