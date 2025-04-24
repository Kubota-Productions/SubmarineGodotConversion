# Hud.gd
extends Node

@export var mouse_flight: Node = null
@export var boresight: Control = null
@export var mouse_pos: Control = null

var player_cam: Camera3D = null

func _ready():
	if mouse_flight == null:
		push_error("%s: Hud - Mouse Flight Controller not assigned!" % name)
		return

	player_cam = mouse_flight.get_node_or_null("Camera3D")
	if player_cam == null:
		push_error("%s: Hud - No camera found on assigned Mouse Flight Controller!" % name)

func _process(_delta: float) -> void:
	if mouse_flight == null or player_cam == null:
		return

	update_graphics()

func update_graphics() -> void:
	if boresight != null:
		var screen_pos = player_cam.unproject_position(mouse_flight.boresight_pos)
		boresight.visible = screen_pos.z > 1.0
		if boresight.visible:
			boresight.position = screen_pos.xy

	if mouse_pos != null:
		var screen_pos = player_cam.unproject_position(mouse_flight.mouse_aim_pos)
		mouse_pos.visible = screen_pos.z > 1.0
		if mouse_pos.visible:
			mouse_pos.position = screen_pos.xy

func set_reference_mouse_flight(controller: Node) -> void:
	mouse_flight = controller
