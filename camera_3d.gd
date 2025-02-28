class_name FollowCamera
extends Camera3D


@export var follow_target : Node3D
@export var look_at_target : Node3D
@export_range(0,1) var camera_looseness = 0.5


func _process(delta: float) -> void:
	#var PlayerCameraOffset = (global_position - sub.global_position) 
	#
	#global_position = (global_position - (PlayerCameraOffset * camera_looseness)) 
	global_position = lerp(global_position, follow_target.global_position, camera_looseness)
	if global_position != look_at_target.global_position:
		look_at(look_at_target.global_position)
		#look_at(Vector3.ZERO)
	
