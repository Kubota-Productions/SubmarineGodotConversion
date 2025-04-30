extends Node

@export var title_structs: Array[Dictionary]  # Holds depth and text
@export var fog_gradient: GradientTexture1D

@export var ingame: bool = false

@export var depth_info: Label
@export var depth_info1: Label
@export var title_change: Label

@export var score_counter_submarine: Label
@export var score_counter_player: Label

@export var submarine: Node3D
@export var sub_hud: Control
@export var sub_camera_rig: Node3D
@export var player: Node3D
@export var player_spawnpoint: Node3D
@export var sub_controller: Node

@export var switching_distance: float = 25.0

var depths: float = 0.0
var depthp: float = 0.0

var submarine_ref: Node3D
var in_submarine: bool = true

var points: int = 0

func _ready() -> void:
	submarine_ref = submarine

func _process(delta: float) -> void:
	if ingame:
		in_game()

func in_game() -> void:
	score_counter_player.text = "Score: " + str(points)
	score_counter_submarine.text = "Score: " + str(points)

	depths = abs(submarine.global_transform.origin.y)
	depth_info.text = "Depth: " + str(int(depths))

	depthp = abs(player.global_transform.origin.y)
	depth_info1.text = "Depth: " + str(int(depthp))

	if Input.is_action_just_pressed("switch"):
		switch()

	var y: float = depths if in_submarine else depthp
	var normalized_y: float = clamp(y / 10000.0, 0.0, 1.0)

	# Apply fog color based on depth
	var target_color: Color = fog_gradient.gradient.sample(normalized_y)
	var world_env: WorldEnvironment = get_node("/root/WorldEnvironment")
	if world_env:
		world_env.environment.fog_color = target_color

	# Update title based on depth
	for title in title_structs:
		if y >= title["depth"]:
			title_change.text = title["text"]

func switch() -> void:
	var distance: float = submarine.global_transform.origin.distance_to(player.global_transform.origin)
	
	if distance < switching_distance:
		in_submarine = !in_submarine
		sub_hud.visible = in_submarine
		sub_camera_rig.visible = in_submarine
		player.visible = !in_submarine

		if !in_submarine:
			player.global_transform.origin = player_spawnpoint.global_transform.origin

		sub_controller.set_process(in_submarine)

# Scene switching methods
func load_into_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/WalkingDevScene.tscn")

func load_into_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Devscene.tscn")
