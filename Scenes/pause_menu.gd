extends Control

func _ready():
	$AnimationPlayer.play_backwards("RESET")
	get_tree().paused = false

func resume():
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")
	
func pause():
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
	get_tree().change_scene_to_file("res://Scenes/Main_Menu.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
	
func _process(delta):
	tabbacktomenu()
