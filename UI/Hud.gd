# Hud.gd
extends Control

@export var mouse_flight: Node = null
@export var lerp: TextureRect = null
@export var mouse_pos: TextureRect = null
@export var player_cam: Camera3D = null

func _ready():
	if mouse_flight == null:
		push_error("%s: Hud - Mouse Flight Controller not assigned!" % name)
		return

	player_cam = mouse_flight.get_node_or_null("Camera3D")
	if player_cam != null:
		push_error("%s: Hud - No camera found on assigned Mouse Flight Controller!" % name)

func _physics_process(delta: float) -> void:
	lerp.global_position = get_global_mouse_position() - lerp.size /2 #+
