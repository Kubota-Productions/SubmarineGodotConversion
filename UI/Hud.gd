# Hud.gd
extends Control

@export var mouse_flight: Node = null
@export var boresight: Control = null
@export var mouse_pos: Control = null
@export var player_cam: Camera3D = null

func _ready():
	if mouse_flight == null:
		push_error("%s: Hud - Mouse Flight Controller not assigned!" % name)
		return

	if player_cam == null:
		push_error("%s: Hud - No camera found!" % name)

func _find_camera_in_node(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var found = _find_camera_in_node(child)
		if found:
			return found
	return null

func _process(_delta: float) -> void:
	if mouse_flight == null or player_cam == null:
		return
	# Call update_graphics with the mouse_flight controller
	update_graphics(mouse_flight)

func update_graphics(controller: Node) -> void:
	if not (controller and controller.has_method("get_boresight_pos") and controller.has_method("get_mouse_aim_pos")):
		return
	
	if boresight:
		print("Boresight %s" % controller.get_boresight_pos())
		var boresight_world_pos: Vector3 = controller.get_boresight_pos()
		#var boresight_world_pos: Vector3 = controller.get_mouse_aim_pos()
		var boresight_screen_pos: Vector2 = player_cam.unproject_position(boresight_world_pos)
		boresight.position = boresight_screen_pos
		
	
	if mouse_pos:
		var mouse_aim_world_pos: Vector3 = controller.get_mouse_aim_pos()
		var mouse_pos_screen_pos: Vector2 = player_cam.unproject_position(mouse_aim_world_pos)
		mouse_pos.position = mouse_pos_screen_pos
		

func set_reference_mouse_flight(controller: Node) -> void:
	mouse_flight = controller
	player_cam = _find_camera_in_node(mouse_flight) if mouse_flight != null else null
