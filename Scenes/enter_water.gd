extends Area3D

@onready var Dev_scene: PackedScene = preload("res://Scenes/Devscene.tscn")

func _on_body_entered(body: Node3D) -> void:
	#get_tree().change_scene_to_file("res://Scenes/Devscene.tscn")
	var Levelloader_enterwater = get_tree().get_root().get_node("Main/LevelLoader") as Levelloader
	Levelloader_enterwater._loadlevel("res://Scenes/Devscene.tscn")
	print("Entered by:", body.name)
	get_tree().get_root().print_tree_pretty()
