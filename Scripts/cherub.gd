extends CharacterBody3D

@export var wander_area: Vector3 = Vector3(50, 0, 50)
@export var speed: float = 3.0
@export var run_away_speed: float = 6.0
@export var wait_time_range: Vector2 = Vector2(1, 5)
@export var player_detection_radius: float = 10.0
@export var flee_distance: float = 10.0
@export var boid_detection_radius: float = 5.0 : set = _set_boid_detection_radius
@export var cohesion_weight: float = 1.0
@export var alignment_weight: float = 1.0
@export var separation_weight: float = 1.5
@export var separation_distance: float = 2.0
@export var boid_target_distance: float = 5.0
@export var obstacle_avoidance_distance: float = 3.0
@export var speed_variation: float = 0.2  # ±20% speed variation
@export var personality_cohesion: float = 1.0  # Multiplier for cohesion weight
@export var personality_separation: float = 1.0  # Multiplier for separation weight
@export var flee_update_interval: float = 0.5  # Time between flee target updates

var target_position: Vector3
var waiting: bool = false
var fleeing: bool = false
var current_speed: float
var current_cohesion_weight: float
var current_alignment_weight: float
var current_separation_weight: float
var smoothed_velocity: Vector3 = Vector3.ZERO
var flee_timer: float = 0.0

@onready var wait_timer: Timer = $Timer
@onready var player: Node3D = $"../BuilderController"
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var nav_region: NavigationRegion3D = $"../Environment/NavigationRegion3D"

func _ready():
	wait_timer.timeout.connect(_on_wait_timer_timeout)
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	set_random_target_position()
	_validate_boid_detection_radius()
	# Apply personality and speed variation
	current_speed = speed * (1.0 + randf_range(-speed_variation, speed_variation))
	current_cohesion_weight = cohesion_weight * personality_cohesion
	current_alignment_weight = alignment_weight
	current_separation_weight = separation_weight * personality_separation

func _set_boid_detection_radius(value: float) -> void:
	if value <= 0:
		push_warning("boid_detection_radius must be greater than 0. Setting to default value 5.0.")
		boid_detection_radius = 5.0
	else:
		boid_detection_radius = value

func _validate_boid_detection_radius() -> void:
	if boid_detection_radius <= 0:
		push_warning("boid_detection_radius is invalid (<= 0). Setting to default value 5.0.")
		boid_detection_radius = 5.0

func _physics_process(delta: float) -> void:
	if not player:
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player < player_detection_radius:
		if not fleeing:
			fleeing = true
			waiting = false
			flee_timer = 0.0
			set_flee_target()
	else:
		if fleeing:
			fleeing = false
			set_random_target_position()

	if waiting and not fleeing:
		self.velocity = Vector3.ZERO
	else:
		var move_speed = run_away_speed if fleeing else current_speed
		if not fleeing:
			set_boid_target()
		else:
			flee_timer += delta
			if flee_timer >= flee_update_interval:
				flee_timer = 0.0
				set_flee_target()
		move_toward_path(move_speed, delta)

	move_and_slide()

func set_flee_target() -> void:
	var flee_direction = (global_position - player.global_position).normalized()
	flee_direction.y = 0
	var flee_target = global_position + flee_direction * flee_distance
	var map = nav_region.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map, flee_target)

	if closest_point.distance_to(flee_target) < 1.0 and closest_point.distance_to(global_position) > 0.5:
		nav_agent.set_target_position(closest_point)
		return

	# Try more angles for a valid flee target
	for i in range(16):  # Increased from 8 to 16 for finer granularity
		var angle = deg_to_rad(i * 22.5)  # 360 / 16 = 22.5 degrees
		var alt_direction = flee_direction.rotated(Vector3.UP, angle).normalized()
		var alt_target = global_position + alt_direction * flee_distance
		var alt_closest = NavigationServer3D.map_get_closest_point(map, alt_target)
		if alt_closest.distance_to(alt_target) < 1.0 and alt_closest.distance_to(global_position) > 0.5:
			nav_agent.set_target_position(alt_closest)
			return

	# Fallback: move in a random navmesh-validated direction
	var random_x = randf_range(-flee_distance, flee_distance)
	var random_z = randf_range(-flee_distance, flee_distance)
	var fallback_target = global_position + Vector3(random_x, 0, random_z)
	var fallback_closest = NavigationServer3D.map_get_closest_point(map, fallback_target)
	if fallback_closest.distance_to(global_position) > 0.5:
		nav_agent.set_target_position(fallback_closest)
	else:
		nav_agent.set_target_position(global_position)  # Last resort: stay in place

func set_boid_target() -> void:
	var nearby_bodies = get_nearby_character_bodies()
	var dynamic_weights = adjust_boid_weights(nearby_bodies)
	var cohesion = get_cohesion_vector(nearby_bodies) * dynamic_weights.cohesion
	var alignment = get_alignment_vector(nearby_bodies) * dynamic_weights.alignment
	var separation = get_separation_vector(nearby_bodies) * dynamic_weights.separation
	var wander = get_wander_vector()
	var avoidance = get_obstacle_avoidance_vector()

	var direction = (
		cohesion +
		alignment +
		separation +
		wander +
		avoidance * 2.0  # Stronger weight for avoidance
	).normalized()

	if direction.length_squared() > 0.01:
		var target = global_position + direction * boid_target_distance
		var map = nav_region.get_navigation_map()
		var closest_point = NavigationServer3D.map_get_closest_point(map, target)
		nav_agent.set_target_position(closest_point)
	else:
		nav_agent.set_target_position(global_position)

func adjust_boid_weights(bodies: Array) -> Dictionary:
	var dynamic_cohesion = current_cohesion_weight
	var dynamic_separation = current_separation_weight
	var dynamic_alignment = current_alignment_weight

	# Increase separation if too many NPCs are too close
	var close_count = 0
	for body in bodies:
		if global_position.distance_to(body.global_position) < separation_distance * 0.5:
			close_count += 1
	if close_count > 2:
		dynamic_separation *= 1.5
		dynamic_cohesion *= 0.5  # Reduce cohesion to avoid clumping

	# Smooth weight transitions (lerp toward target weights)
	current_cohesion_weight = lerp(current_cohesion_weight, dynamic_cohesion, 0.1)
	current_separation_weight = lerp(current_separation_weight, dynamic_separation, 0.1)
	current_alignment_weight = lerp(current_alignment_weight, dynamic_alignment, 0.1)

	return {
		"cohesion": current_cohesion_weight,
		"alignment": current_alignment_weight,
		"separation": current_separation_weight
	}

func get_nearby_character_bodies() -> Array:
	var bodies = []
	if boid_detection_radius <= 0.5:
		return bodies

	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = boid_detection_radius
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position)
	query.collision_mask = 0xFFFFFFFF  # Adjust collision mask if needed

	var results = space.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider is CharacterBody3D and collider != self:
			bodies.append(collider)
	return bodies
	

func get_obstacle_avoidance_vector() -> Vector3:
	var avoidance = Vector3.ZERO
	var space = get_world_3d().direct_space_state
	var directions = [
		Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT,
		Vector3.FORWARD + Vector3.RIGHT, Vector3.FORWARD + Vector3.LEFT
	]
	for dir in directions:
		var query = PhysicsRayQueryParameters3D.create(
			global_position,
			global_position + dir.normalized() * obstacle_avoidance_distance
		)
		query.collision_mask = 0xFFFFFFFF  # Adjust mask for obstacles
		var result = space.intersect_ray(query)
		if result:
			var avoid_dir = (global_position - result.position).normalized()
			avoidance += avoid_dir
	return avoidance.normalized() if avoidance.length_squared() > 0 else Vector3.ZERO

func get_cohesion_vector(bodies: Array) -> Vector3:
	if bodies.is_empty():
		return Vector3.ZERO
	var center = Vector3.ZERO
	for body in bodies:
		center += body.global_position
	center /= bodies.size()
	return (center - global_position).normalized()

func get_alignment_vector(bodies: Array) -> Vector3:
	if bodies.is_empty():
		return Vector3.ZERO
	var average_velocity = Vector3.ZERO
	for body in bodies:
		average_velocity += body.velocity
	average_velocity /= bodies.size()
	return average_velocity.normalized()

func get_separation_vector(bodies: Array) -> Vector3:
	var separation = Vector3.ZERO
	for body in bodies:
		var distance = global_position.distance_to(body.global_position)
		if distance < separation_distance and distance > 0:
			var push = (global_position - body.global_position).normalized()
			separation += push / max(distance, 0.1)
	return separation.normalized() if separation.length_squared() > 0 else Vector3.ZERO

func get_wander_vector() -> Vector3:
	if randf() < 0.1:  # Occasionally update wander target
		set_random_target_position()
	if nav_agent.is_navigation_finished():
		return Vector3.ZERO
	var next_pos = nav_agent.get_next_path_position()
	return (next_pos - global_position).normalized()

func move_toward_path(move_speed: float, delta: float) -> void:
	if nav_agent.is_navigation_finished() or nav_agent.get_current_navigation_path().size() == 0:
		if not fleeing:
			wait_before_next_move()
		self.velocity = Vector3.ZERO
		return

	var next_pos = nav_agent.get_next_path_position()
	var desired_velocity = (next_pos - global_position).normalized() * move_speed
	desired_velocity.y = 0
	# Smooth velocity changes
	smoothed_velocity = smoothed_velocity.lerp(desired_velocity, 5.0 * delta)
	self.velocity = smoothed_velocity
	set_train_rotation(smoothed_velocity)

func set_random_target_position() -> void:
	if fleeing:
		return
	var random_x = randf_range(-wander_area.x / 2, wander_area.x / 2)
	var random_z = randf_range(-wander_area.z / 2, wander_area.z / 2)
	var target = global_position + Vector3(random_x, 0, random_z)
	var map = nav_region.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map, target)
	nav_agent.set_target_position(closest_point)

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
