extends Control

@onready var main_menu: Control = $"../MainMenu"
const menu_scene = preload("res://Scenes/Main_Menu.tscn")

func _ready():
	hide()

func resume():
	if main_menu.visible == true:
		return
	show()
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")
	
func pause():
	if main_menu.visible == true:
		return
	show()
	get_tree().paused = true
	$AnimationPlayer.play("blur")
	
func tabbacktomenu():
	if Input.is_action_just_pressed("Escape") and get_tree().paused == false:
		pause()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif Input.is_action_just_pressed("Escape") and get_tree().paused == true:
		resume()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_pressed() -> void:
	resume()


func _on_back_to_menu_pressed() -> void:
	var Levelloader_enterwater = get_tree().get_root().get_node("Main/LevelLoader") as Levelloader
	Levelloader_enterwater._backtomainmenu()
	hide()


func _on_exit_pressed() -> void:
	get_tree().quit()
	
func _process(delta):
	tabbacktomenu()
