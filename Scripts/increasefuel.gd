class_name FuelPickup
extends Area3D

var fuel_amount: float = 1000
var respawn_time: float = 30.0  
var rotation_speed: float = 50.0  
var max_fuel_increase: float = 50.0  

var emission_oscillation_speed: float = 1
var emission_min_strength: float = 0.6
var emission_max_strength: float = 1.5
var _original_emission_color: Color = Color(1, 1, 1, 1)
var _time: float = 0.0

var _active: bool = true
var _mesh_instance: MeshInstance3D

func _ready():
	_mesh_instance = get_node_or_null("MeshInstance3D")
	
	if _mesh_instance and _mesh_instance.mesh:
		var material = _mesh_instance.get_active_material(0)
		if material is StandardMaterial3D and material.emission_enabled:
			_original_emission_color = material.emission
	
func _process(delta):
	if _active and _mesh_instance:
		_mesh_instance.rotate_y(deg_to_rad(rotation_speed * delta))
		
	_time += delta
	var emission_strength = _calculate_emission_strength()
	_update_emission(emission_strength)

func _calculate_emission_strength() -> float:
	# Calculate oscillation using sine wave
	var t = _time * emission_oscillation_speed * TAU  # TAU = 2*PI
	var oscillation = (sin(t) + 1) / 2  # Convert from [-1,1] to [0,1]
	return lerp(emission_min_strength, emission_max_strength, oscillation)

func _update_emission(strength: float):
	if not _mesh_instance or not _mesh_instance.mesh:
		return
	
	var material = _mesh_instance.get_active_material(0)
	if material is StandardMaterial3D and material.emission_enabled:
		# Multiply the original color by the strength while preserving alpha
		material.emission = Color(
			_original_emission_color.r * strength,
			_original_emission_color.g * strength,
			_original_emission_color.b * strength,
			_original_emission_color.a
		)

func _on_body_entered(body: Node):
	if not _active:
		return
		
	if body is SubmarineController:
		var submarine: SubmarineController = body
		
		submarine.max_fuel += max_fuel_increase
		
		submarine.fuel = min(submarine.fuel + fuel_amount, submarine.max_fuel)

		_active = false
		if _mesh_instance:
			_mesh_instance.visible = false
		
		get_tree().create_timer(respawn_time).timeout.connect(_respawn_pickup)

func _respawn_pickup():
	_active = true
	if _mesh_instance:
		_mesh_instance.visible = true
