extends Node3D

@onready var animation_player = $AnimationPlayer

var is_playing = false

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		if is_playing:
			animation_player.stop()
		else:
			animation_player.play("Cube_001Action")
		is_playing = !is_playing  # Toggle state
