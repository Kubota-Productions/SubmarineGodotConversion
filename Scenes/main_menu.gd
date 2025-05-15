extends Control

@onready var test_scene: PackedScene = preload("res://Scenes/test_scene.tscn")
@onready var level_loader: Levelloader = $"../LevelLoader"

func _on_start_pressed() -> void:
	level_loader._loadlevel("res://Scenes/test_scene.tscn")
	hide()
	


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	get_tree().quit()
