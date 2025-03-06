extends Node3D
@export var global_transform_basis = global_transform.basis

func _physics_process(delta: float) -> void:
	global_transform_basis = global_transform.basis
