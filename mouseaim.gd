extends Node3D
#var mouse_sensitivity = 0.1
#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#var mouse_x = event.relative.x * mouse_sensitivity
		#var mouse_y = -event.relative.y * mouse_sensitivity
		#global_rotation.x += mouse_y
		#global_rotation.y += mouse_x
