extends Node3D
class_name NPCBrain

@export var nav_region: NavigationRegion3D = null
@export var player: Node3D = null  # Changed to Node3D for compatibility
@export var npc_scene: PackedScene = null  # Scene to instantiate NPCs
@export var num_npcs: int = 5  # Number of NPCs to spawn
@export var min_spawn_separation: float = 2.0  # Minimum distance between NPCs

# Configuration variables
var wander_area: Vector3 = Vector3(50, 0, 50)
var speed: float = 1.5
var run_away_speed: float = 6.0
var wait_time_range: Vector2 = Vector2(1, 5)
var player_detection_radius: float = 5
var flee_distance: float = 6.0
var obstacle_avoidance_distance: float = 3.0
var speed_variation: float = 0.2
var personality_cohesion: float = 1.0
var personality_separation: float = 1.0
var flee_update_interval: float = 1.0
var target_update_interval: float = 2.0
var wait_probability: float = 0.001
var max_angle_change: float = deg_to_rad(30)
var max_slope_angle: float = deg_to_rad(60)
var stuck_threshold: float = 0.1
var stuck_time_threshold: float = 1.0
var jump_probability: float = 0.01

# References
var npcs: Array = []  # Array of NPC instances
var npc_states: Dictionary = {}  # Per-NPC state

func _ready():
	# Wait for proper initialization
	await get_tree().process_frame
	await get_tree().physics_frame
	
	if not nav_region or not player or not npc_scene:
		push_error("NPCBrain: nav_region, player, or npc_scene not set")
		return
	
	# Connect the nav mesh changed signal
	if nav_region.navigation_mesh_changed.connect(_on_nav_map_changed) != OK:
		push_warning("Failed to connect navigation_mesh_changed signal")
	
	# Wait for physics to be ready
	await get_tree().physics_frame
	
	spawn_npcs()
	
	# Register existing NPCs
	for child in get_tree().get_nodes_in_group("npcs"):
		if child is CharacterBody3D and child.has_method("set_brain") and not npcs.has(child):
			register_npc(child)

func spawn_npcs():
	if not nav_region:
		push_error("NavigationRegion3D not set")
		return
	
	var map = nav_region.get_navigation_map()
	if map == RID():
		push_error("Navigation map not ready")
		return
	
	var bounds = AABB(Vector3(-wander_area.x/2, 0, -wander_area.z/2), wander_area)
	
	for i in range(num_npcs):
		var spawn_pos = Vector3.ZERO
		var attempts = 0
		var max_attempts = 50
		
		while attempts < max_attempts:
			# Wait a frame if we've tried multiple times
			if attempts > 0:
				await get_tree().physics_frame
				
			# Random position within bounds
			var random_pos = Vector3(
				randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
				0,
				randf_range(bounds.position.z, bounds.position.z + bounds.size.z)
			)
			
			# Snap to navmesh
			spawn_pos = NavigationServer3D.map_get_closest_point(map, random_pos)
			
			# Validate spawn position (this is now async)
			if await is_valid_spawn_position(spawn_pos):
				break
				
			spawn_pos = Vector3.ZERO
			attempts += 1
		
		if spawn_pos == Vector3.ZERO:
			push_warning("Failed to find valid spawn position for NPC %d after %d attempts" % [i, max_attempts])
			continue
		
		# Instantiate NPC
		var npc = npc_scene.instantiate()
		if not npc is CharacterBody3D:
			push_error("NPC scene must be a CharacterBody3D")
			npc.queue_free()
			continue
		
		# Add to scene first
		add_child(npc)
		# Wait for the node to be properly added to the scene tree
		await get_tree().process_frame
		
		npc.global_position = spawn_pos
		npc.add_to_group("npcs")
		register_npc(npc)
		npc.name = "NPC_%d" % i


func is_valid_spawn_position(pos: Vector3) -> bool:
	# Wait for physics to be ready
	await get_tree().physics_frame
	
	var world = get_world_3d()
	if world == null:
		push_warning("World3D is null")
		return false
		
	var space = world.direct_space_state
	if space == null:
		push_warning("DirectSpaceState is null")
		return false

	var valid_surface = false
	for offset in [Vector3.ZERO, Vector3(0.2, 0, 0), Vector3(-0.2, 0, 0), Vector3(0, 0, 0.2), Vector3(0, 0, -0.2)]:
		var from = pos + Vector3.UP * 0.5 + offset
		var to = pos + Vector3.DOWN * 1.0 + offset
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 0xFFFFFFFF
		
		# Try the raycast with error handling
		var result
		for attempt in 3:  # Try up to 3 times
			result = space.intersect_ray(query)
			if result != null:
				break
			await get_tree().physics_frame  # Wait if first attempt fails
			
		if result:
			var normal = result.normal
			var slope_angle = acos(normal.dot(Vector3.UP))
			if slope_angle <= max_slope_angle:
				valid_surface = true
				break
				
	return valid_surface

func register_npc(npc: CharacterBody3D):
	if not npcs.has(npc):
		npcs.append(npc)
		npc.set_brain(self)
		npc_states[npc] = {
			"waiting": false,
			"fleeing": false,
			"current_speed": speed * (1.0 + randf_range(-speed_variation, speed_variation)),
			"current_cohesion_weight": personality_cohesion,
			"current_alignment_weight": 1.0,
			"current_separation_weight": personality_separation,
			"smoothed_velocity": Vector3.ZERO,
			"flee_timer": 0.0,
			"target_update_timer": 0.0,
			"stuck_timer": 0.0,
			"last_position": npc.global_position,
			"wander_direction": Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(),
			"wait_timer": 0.0,
			"target_position": Vector3.ZERO,
			"is_jumping": false,
			"current_animation_state": "Idle"
		}
		set_random_target_position(npc)

func _physics_process(delta: float):
	if not player or npcs.is_empty():
		return

	for npc in npcs:
		var state = npc_states[npc]
		var distance_to_player = npc.global_position.distance_to(player.global_position)

		# Stuck detection
		var current_stuck_threshold = stuck_time_threshold if not state.fleeing else stuck_time_threshold * 0.5
		if not state.waiting and npc.global_position.distance_to(state.last_position) < stuck_threshold:
			state.stuck_timer += delta
			if state.stuck_timer > current_stuck_threshold:
				if state.fleeing:
					set_flee_target(npc)
				else:
					set_random_target_position(npc)
				state.stuck_timer = 0.0
				state.target_update_timer = 0.0
		else:
			state.stuck_timer = 0.0
		state.last_position = npc.global_position

		# Flee or wander logic
		if distance_to_player < player_detection_radius:
			if not state.fleeing:
				state.fleeing = true
				state.waiting = false
				state.flee_timer = 0.0
				set_flee_target(npc)
				state.target_update_timer = 0.0
				npc.play_animation("Run")
		else:
			if state.fleeing:
				state.fleeing = false
				set_random_target_position(npc)
				state.target_update_timer = 0.0

		if not state.fleeing:
			if randf() < wait_probability and not state.waiting:
				state.waiting = true
				state.wait_timer = randf_range(wait_time_range.x, wait_time_range.y)
				npc.play_animation("Idle")
			if state.waiting:
				state.wait_timer -= delta
				if state.wait_timer <= 0:
					state.waiting = false
					set_random_target_position(npc)
				npc.apply_velocity(Vector3.ZERO)
				if not state.is_jumping and randf() < jump_probability:
					npc.play_animation("Jump")
					state.is_jumping = true
			else:
				state.target_update_timer += delta
				if should_update_target(npc):
					set_boid_target(npc)
					state.target_update_timer = 0.0
				move_toward_path(npc, state.current_speed, delta)
		else:
			state.flee_timer += delta
			state.target_update_timer += delta
			if should_update_target(npc):
				set_flee_target(npc)
				state.target_update_timer = 0.0
				state.flee_timer = 0.0
			if not npc.nav_agent.is_navigation_finished():
				var next_pos = npc.nav_agent.get_next_path_position()
				var direction_to_next = (next_pos - npc.global_position).normalized()
				var direction_to_player = (player.global_position - npc.global_position).normalized()
				if direction_to_next.dot(direction_to_player) > 0.3:
					set_flee_target(npc)
					state.target_update_timer = 0.0
					state.flee_timer = 0.0
				else:
					move_toward_path(npc, run_away_speed, delta)
			else:
				move_toward_path(npc, run_away_speed, delta)

		# Update animation based on movement
		if not state.waiting and not state.fleeing and npc.velocity.length() > 0.1 and not state.is_jumping:
			npc.play_animation("Walk")

func should_update_target(npc: CharacterBody3D) -> bool:
	var state = npc_states[npc]
	if npc.nav_agent.is_navigation_finished() or not npc.nav_agent.is_target_reachable():
		return true
	if npc.nav_agent.distance_to_target() < 1.5:
		return true
	var interval = flee_update_interval if state.fleeing else target_update_interval
	return state.target_update_timer >= interval

func get_wander_vector(state: Dictionary) -> Vector3:
	var angle_change = randf_range(-max_angle_change, max_angle_change) * get_physics_process_delta_time()
	state.wander_direction = state.wander_direction.rotated(Vector3.UP, angle_change).normalized()
	return state.wander_direction

func get_cohesion_vector(npc: CharacterBody3D, bodies: Array) -> Vector3:
	if bodies.is_empty():
		return Vector3.ZERO
	var center = Vector3.ZERO
	for body in bodies:
		center += body.global_position
	center /= bodies.size()
	return (center - npc.global_position).normalized()

func get_alignment_vector(bodies: Array) -> Vector3:
	if bodies.is_empty():
		return Vector3.ZERO
	var average_velocity = Vector3.ZERO
	for body in bodies:
		average_velocity += body.velocity
	average_velocity /= bodies.size()
	return average_velocity.normalized()

func get_obstacle_avoidance_vector(npc: CharacterBody3D) -> Vector3:
	var avoidance = Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var directions = [
		Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT,
		Vector3.FORWARD + Vector3.RIGHT, Vector3.FORWARD + Vector3.LEFT
	]
	for dir in directions:
		var query = PhysicsRayQueryParameters3D.create(
			npc.global_position,
			npc.global_position + dir.normalized() * obstacle_avoidance_distance
		)
		query.collision_mask = 0xFFFFFFFF
		var result = space.intersect_ray(query)
		if result:
			var avoid_dir = (npc.global_position - result.position).normalized()
			avoidance += avoid_dir
	return avoidance.normalized() if avoidance.length_squared() > 0 else Vector3.ZERO

func get_nearby_character_bodies(npc: CharacterBody3D) -> Array:
	return []
	var bodies = []
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	if not space:
		return bodies
	
	var shape = SphereShape3D.new()
	shape.radius = 5.0  # Fixed radius value
	
	# No need to await here - shape creation is immediate
	# Just ensure radius is valid
	if shape.radius <= 0:
		shape.radius = 5.0
	
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), npc.global_position)
	query.collision_mask = 0xFFFFFFFF
	query.exclude = [npc]
	
	var results = space.intersect_shape(query)
	
	for result in results:
		var collider = result.collider
		if collider is CharacterBody3D and npcs.has(collider):
			bodies.append(collider)
	
	return bodies
	
	for result in results:
		var collider = result.collider
		if collider is CharacterBody3D and npcs.has(collider):
			bodies.append(collider)
	
	# Free the shape to prevent memory leaks
	shape.free()
	
	return bodies

func adjust_boid_weights(npc: CharacterBody3D, bodies: Array) -> Dictionary:
	var state = npc_states[npc]
	var dynamic_cohesion = state.current_cohesion_weight
	var dynamic_separation = state.current_separation_weight
	var dynamic_alignment = state.current_alignment_weight

	var close_count = 0
	for body in bodies:
		if npc.global_position.distance_to(body.global_position) < 2.0:
			close_count += 1
	if close_count > 2:
		dynamic_separation *= 1.5
		dynamic_cohesion *= 0.5

	state.current_cohesion_weight = lerp(state.current_cohesion_weight, dynamic_cohesion, 0.1)
	state.current_separation_weight = lerp(state.current_separation_weight, dynamic_separation, 0.1)
	state.current_alignment_weight = lerp(state.current_alignment_weight, dynamic_alignment, 0.1)

	return {
		"cohesion": state.current_cohesion_weight,
		"alignment": state.current_alignment_weight,
		"separation": state.current_separation_weight
	}

func set_boid_target(npc: CharacterBody3D) -> void:
	var state = npc_states[npc]
	var nearby_bodies = get_nearby_character_bodies(npc)
	var dynamic_weights = adjust_boid_weights(npc, nearby_bodies)
	var cohesion = get_cohesion_vector(npc, nearby_bodies) * dynamic_weights.cohesion
	var alignment = get_alignment_vector(nearby_bodies) * dynamic_weights.alignment
	var wander = get_wander_vector(state)
	var avoidance = get_obstacle_avoidance_vector(npc)

	var direction = (wander + avoidance * 2.0).normalized()

	if direction.length_squared() > 0.01:
		var map = nav_region.get_navigation_map()
		var target = npc.global_position + direction * 5.0
		var closest_point = NavigationServer3D.map_get_closest_point(map, target)
		npc.nav_agent.set_target_position(closest_point)
		state.target_position = closest_point
	else:
		npc.nav_agent.set_target_position(npc.global_position)
		state.target_position = npc.global_position
	


func set_flee_target(npc: CharacterBody3D) -> void:
	var state = npc_states[npc]
	var flee_direction = (npc.global_position - player.global_position).normalized()
	flee_direction.y = 0
	var map = nav_region.get_navigation_map()
	var distances = [flee_distance, flee_distance * 1.5, flee_distance * 0.5]
	
	for dist in distances:
		var flee_target = npc.global_position + flee_direction * dist
		var closest_point = NavigationServer3D.map_get_closest_point(map, flee_target)
		if is_valid_flee_target(npc, closest_point, flee_target, flee_direction):
			npc.nav_agent.set_target_position(closest_point)
			if npc.nav_agent.is_target_reachable():
				state.target_position = closest_point
				return

		for i in range(24):
			var angle = deg_to_rad(i * 15.0)
			var alt_direction = flee_direction.rotated(Vector3.UP, angle).normalized()
			var alt_target = npc.global_position + alt_direction * dist
			var alt_closest = NavigationServer3D.map_get_closest_point(map, alt_target)
			if is_valid_flee_target(npc, alt_closest, alt_target, flee_direction):
				npc.nav_agent.set_target_position(alt_closest)
				if npc.nav_agent.is_target_reachable():
					state.target_position = alt_closest
					return


			var alt_direction_opposite = flee_direction.rotated(Vector3.UP, -angle).normalized()
			var alt_target_opposite = npc.global_position + alt_direction_opposite * dist
			var alt_closest_opposite = NavigationServer3D.map_get_closest_point(map, alt_target_opposite)
			if is_valid_flee_target(npc, alt_closest_opposite, alt_target_opposite, flee_direction):
				npc.nav_agent.set_target_position(alt_closest_opposite)
				if npc.nav_agent.is_target_reachable():
					state.target_position = alt_closest_opposite

	# Fallback: random direction
	for i in range(10):
		var random_angle = randf_range(0, TAU)
		var random_direction = Vector3(cos(random_angle), 0, sin(random_angle)).normalized()
		var random_target = npc.global_position + random_direction * flee_distance
		var random_closest = NavigationServer3D.map_get_closest_point(map, random_target)
		if is_valid_flee_target(npc, random_closest, random_target, flee_direction):
			npc.nav_agent.set_target_position(random_closest)
			if npc.nav_agent.is_target_reachable():
				state.target_position = random_closest
				return


	# Last resort: nearest valid navmesh point
	var safe_point = NavigationServer3D.map_get_closest_point(map, npc.global_position)
	if safe_point.distance_to(npc.global_position) > 0.1 and safe_point.distance_to(player.global_position) > npc.global_position.distance_to(player.global_position):
		npc.nav_agent.set_target_position(safe_point)
		if npc.nav_agent.is_target_reachable():
			state.target_position = safe_point
			return
	else:
		npc.nav_agent.set_target_position(npc.global_position)
		state.target_position = npc.global_position

func is_valid_flee_target(npc: CharacterBody3D, closest_point: Vector3, target: Vector3, flee_direction: Vector3) -> bool:
	if closest_point.distance_to(target) > 1.0 or closest_point.distance_to(npc.global_position) < 0.5:
		return false
	
	var current_distance_to_player = npc.global_position.distance_to(player.global_position)
	var target_distance_to_player = closest_point.distance_to(player.global_position)
	if target_distance_to_player < current_distance_to_player:
		return false
	
	var direction_to_closest = (closest_point - npc.global_position).normalized()
	var direction_to_player = (player.global_position - npc.global_position).normalized()
	if direction_to_closest.dot(direction_to_player) > 0.0:
		return false
	
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var valid_surface = false
	for offset in [Vector3.ZERO, Vector3(0.2, 0, 0), Vector3(-0.2, 0, 0), Vector3(0, 0, 0.2), Vector3(0, 0, -0.2)]:
		var query = PhysicsRayQueryParameters3D.create(closest_point + Vector3.UP * 0.5 + offset, closest_point + Vector3.DOWN * 1.0 + offset)
		query.collision_mask = 0xFFFFFFFF
		var result = space.intersect_ray(query)
		if result:
			var normal = result.normal
			var slope_angle = acos(normal.dot(Vector3.UP))
			if slope_angle <= max_slope_angle:
				valid_surface = true
				break
	return valid_surface

func move_toward_path(npc: CharacterBody3D, move_speed: float, delta: float) -> void:
	var state = npc_states[npc]
	if npc.nav_agent.is_navigation_finished() or npc.nav_agent.get_current_navigation_path().size() == 0:
		if not state.fleeing:
			state.waiting = true
			state.wait_timer = randf_range(wait_time_range.x, wait_time_range.y)
			npc.play_animation("Idle")
		npc.apply_velocity(Vector3.ZERO)
		return

	var next_pos = npc.nav_agent.get_next_path_position()
	var desired_velocity = (next_pos - npc.global_position).normalized() * move_speed
	
	if npc.is_on_floor():
		var floor_normal = npc.get_floor_normal()
		var slope_angle = acos(floor_normal.dot(Vector3.UP))
		if slope_angle > deg_to_rad(30):
			var boost = 2.0 if state.fleeing else 1.5
			desired_velocity *= boost
			desired_velocity.y += 3.0 if state.fleeing else 2.0

	desired_velocity.y = npc.velocity.y
	state.smoothed_velocity = state.smoothed_velocity.lerp(desired_velocity, 5.0 * delta)
	npc.apply_velocity(Vector3(state.smoothed_velocity.x, npc.velocity.y, state.smoothed_velocity.z))
	npc.update_rotation_target(npc.global_position + state.smoothed_velocity)

func set_random_target_position(npc: CharacterBody3D) -> void:
	var state = npc_states[npc]
	if state.fleeing:
		return
	
	if not nav_region:
		push_error("NavigationRegion3D not set")
		return
	
	var map = nav_region.get_navigation_map()
	if map == RID():
		push_error("Navigation map not ready")
		return
	
	var random_x = randf_range(-wander_area.x / 2, wander_area.x / 2)
	var random_z = randf_range(-wander_area.z / 2, wander_area.z / 2)
	var target = npc.global_position + Vector3(random_x, 0, random_z)
	var closest_point = NavigationServer3D.map_get_closest_point(map, target)
	
	if closest_point == Vector3.ZERO:
		push_warning("Failed to find valid target position for NPC %s" % npc.name)
		return
	
	npc.nav_agent.set_target_position(closest_point)
	state.target_position = closest_point

	
	# Add this new method to handle nav mesh changes
func _on_nav_map_changed():
	# When the navigation mesh changes, we might want to update NPC paths
	for npc in npcs:
		var state = npc_states[npc]
		if state.fleeing:
			set_flee_target(npc)
		else:
			set_random_target_position(npc)
