extends Marker3D

var yaw := 0.0  # To store the player's yaw (left-right rotation)
var pitch := 0.0  # To store the camera's pitch (up-down rotation)
var mouse_sens_y = 0.01
var mouse_sens_x = 0.01
var pitch_min := -1  # Minimum pitch (look directly up)
var pitch_max := 1  # Maximum pitch (look directly down)

func _unhandled_input(event: InputEvent) -> void:
	# Capture mouse movement input for looking around
	if event is InputEventMouseMotion:
		# Calculate yaw and pitch changes based on mouse movement
		yaw -= event.relative.x * mouse_sens_x  # Rotate the player left/right
		pitch -= event.relative.y * mouse_sens_y  # Rotate the camera up/down

		# Clamp the pitch to the specified range
		pitch = clamp(pitch, pitch_min, pitch_max)
		
func _physics_process(delta: float) -> void:
	# Update the rotation based on the clamped pitch and yaw values
	rotation.x = pitch
	rotation.y = yaw
