extends Node3D

@onready var animation_player = $AnimationPlayer
var particles: GPUParticles3D 
var is_playing = false

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space key
		if is_playing:
			particles.emitting = false
			animation_player.stop()
		else:
			particles.emitting = !particles.emitting
			animation_player.play("Cube_001Action")
		is_playing = !is_playing  # Toggle state
		
		
