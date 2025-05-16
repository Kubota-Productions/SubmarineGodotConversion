extends Node3D

# Boid parameters
@export var boid_scene: PackedScene
@export var boid_count: int = 20
@export var spawn_radius: float = 10.0
@export var max_speed: float = 10.0
@export var max_force: float = 0.5
@export var perception_radius: float = 5.0
@export var separation_radius: float = 2.0
@export var alignment_weight: float = 1.0
@export var cohesion_weight: float = 1.0
@export var separation_weight: float = 1.5
@export var boundary_weight: float = 2.0
@export var boundary_size: Vector3 = Vector3(20, 20, 20)
@onready var submarine: SubmarineController = $"../submarine"
@export var avoidance_radius: float = 10
@export var avoidance_weight: float = 2.0

# Boid array
var boids: Array = []

func _ready() -> void:
	# Check if boid_scene is assigned
	if not boid_scene:
		push_error("Boid scene not assigned! Please assign a PackedScene in the Inspector.")
		return
	
	# Spawn boids
	for i in range(boid_count):
		var boid = boid_scene.instantiate()
		if not boid is CharacterBody3D:
			push_error("Boid scene root must be a CharacterBody3D node!")
			boid.queue_free()
			continue
		
		boid.name = "Boid_" + str(i)
		
		# Set random initial position
		var random_pos = Vector3(
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius),
			randf_range(-spawn_radius, spawn_radius)
		)
		boid.global_position = random_pos
		
		# Set random initial velocity
		boid.velocity = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		).normalized() * max_speed
		
		add_child(boid)
		boids.append(boid)

func _physics_process(delta: float) -> void:
	# Update each boid
	for boid in boids:update_boid(boid, delta)

func update_boid(boid: CharacterBody3D, delta: float) -> void:
	# Calculate steering forces
	var steering: Vector3 = Vector3.ZERO
	steering += alignment(boid) * alignment_weight
	steering += cohesion(boid) * cohesion_weight
	steering += separation(boid) * separation_weight
	steering += stay_in_bounds(boid) * boundary_weight
	steering += avoid_obstacle(boid) * avoidance_weight
	
	# Apply steering to velocity
	boid.velocity += steering
	boid.velocity = boid.velocity.limit_length(max_speed)
	
	# Update rotation to face movement direction
	if boid.velocity.length() > 0:
		var target_rotation = atan2(boid.velocity.x, boid.velocity.z)
		boid.rotation.y = lerp_angle(boid.rotation.y, target_rotation, 0.1)
	
	# Move the boid
	boid.move_and_slide()

func alignment(boid: CharacterBody3D) -> Vector3:
	var avg_velocity: Vector3 = Vector3.ZERO
	var neighbor_count: int = 0
	
	for other_boid in boids:
		if other_boid != boid and boid.global_position.distance_to(other_boid.global_position) < perception_radius:
			avg_velocity += other_boid.velocity
			neighbor_count += 1
	
	if neighbor_count > 0:
		avg_velocity /= neighbor_count
		avg_velocity = avg_velocity.normalized() * max_speed
		return (avg_velocity - boid.velocity).limit_length(max_force)
	return Vector3.ZERO

func cohesion(boid: CharacterBody3D) -> Vector3:
	var avg_position: Vector3 = Vector3.ZERO
	var neighbor_count: int = 0
	
	for other_boid in boids:
		if other_boid != boid and boid.global_position.distance_to(other_boid.global_position) < perception_radius:
			avg_position += other_boid.global_position
			neighbor_count += 1
	
	if neighbor_count > 0:
		avg_position /= neighbor_count
		var desired = (avg_position - boid.global_position).normalized() * max_speed
		return (desired - boid.velocity).limit_length(max_force)
	return Vector3.ZERO

func separation(boid: CharacterBody3D) -> Vector3:
	var steering: Vector3 = Vector3.ZERO
	var neighbor_count: int = 0
	
	for other_boid in boids:
		var distance = boid.global_position.distance_to(other_boid.global_position)
		if other_boid != boid and distance < separation_radius:
			var diff = boid.global_position - other_boid.global_position
			steering += diff.normalized() / max(distance, 0.1)
			neighbor_count += 1
	
	if neighbor_count > 0:
		steering /= neighbor_count
		steering = steering.normalized() * max_speed
		return (steering - boid.velocity).limit_length(max_force)
	return Vector3.ZERO

func stay_in_bounds(boid: CharacterBody3D) -> Vector3:
	var steering: Vector3 = Vector3.ZERO
	var center: Vector3 = Vector3.ZERO
	var margin: float = 2.0
	
	if boid.global_position.x > center.x + boundary_size.x / 2 - margin:
		steering.x -= max_force
	elif boid.global_position.x < center.x - boundary_size.x / 2 + margin:
		steering.x += max_force
	
	if boid.global_position.y > center.y + boundary_size.y / 2 - margin:
		steering.y -= max_force
	elif boid.global_position.y < center.y - boundary_size.y / 2 + margin:
		steering.y += max_force
	
	if boid.global_position.z > center.z + boundary_size.z / 2 - margin:
		steering.z -= max_force
	elif boid.global_position.z < center.z - boundary_size.z / 2 + margin:
		steering.z += max_force
	
	return steering

func avoid_obstacle(boid: CharacterBody3D) -> Vector3:
	if not submarine or not submarine is Node3D:
		return Vector3.ZERO
	
	var to_submarine = submarine.global_position - boid.global_position
	var distance = to_submarine.length()
	
	if distance > avoidance_radius or distance < 0.1:
		return Vector3.ZERO
	
	# Use raycast to confirm submarine is in line of sight
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		boid.global_position,
		submarine.global_position
	)
	query.exclude = [boid.get_rid()] # Exclude the boid itself
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == submarine:
		var steering = -to_submarine.normalized() * max_speed
		return (steering - boid.velocity).limit_length(max_force)
	
	return Vector3.ZERO
