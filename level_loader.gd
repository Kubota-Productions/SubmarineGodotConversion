extends Node
class_name Levelloader

static var level : Node
@export var Levelattachment: Node3D = null
@onready var main_menu: Control = $"../MainMenu"
@onready var submarinecamerarig: MouseFlightController = $Submarinecamerarig

func _loadlevel(scenepath):
	var scene = load(scenepath)
	var node = scene.instantiate()
	level = node
	for child in Levelattachment.get_children():
		remove_child(child)
		child.queue_free()
	Levelattachment.add_child(node)
	
func _backtomainmenu():
	for child in Levelattachment.get_children():
		remove_child(child)
		child.queue_free()
	main_menu.show()
