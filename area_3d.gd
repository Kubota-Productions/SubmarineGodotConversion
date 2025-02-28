extends Area3D

var collected = false


func _on_body_entered(body: Node3D) -> void:
	collected = true
	print("Collected!")
