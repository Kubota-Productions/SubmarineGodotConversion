extends Control

@export var mouse_flight: Node = null
@export var boresight: Control = null
@export var mouse_pos: Control = null
@export var player_cam: Camera3D = null

func _ready():
	# Ensure HUD spans the entire viewport
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	if mouse_flight == null:
		push_error("%s: Hud - Mouse Flight Controller not assigned!" % name)
		return
	if player_cam == null:
		push_error("%s: Hud - No camera found!" % name)
		return
	print("Camera transform: ", player_cam.global_transform)

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
	update_graphics(mouse_flight)

func update_graphics(controller: Node) -> void:
	if not (controller and controller.has_method("get_boresight_pos") and controller.has_method("get_mouse_aim_pos")):
		return
	
	if boresight:
		var boresight_world_pos: Vector3 = controller.get_boresight_pos()
		var boresight_screen_pos: Vector2 = player_cam.unproject_position(boresight_world_pos)
		boresight.position = boresight_screen_pos - boresight.size / 2  # Center the node
	
	if mouse_pos:
		var mouse_aim_world_pos: Vector3 = controller.get_mouse_aim_pos()
		var mouse_pos_screen_pos: Vector2 = player_cam.unproject_position(mouse_aim_world_pos)
		mouse_pos.position = mouse_pos_screen_pos - mouse_pos.size / 2  # Center the node

func set_reference_mouse_flight(controller: Node) -> void:
	mouse_flight = controller
	player_cam = _find_camera_in_node(mouse_flight) if mouse_flight != null else null
