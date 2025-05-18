extends CharacterBody3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
@export var animation_player_path: NodePath
var animation_player: AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var brain: NPCBrain 

func set_brain(new_brain: NPCBrain):
	brain = new_brain

func _ready():
	if animation_player_path:
		animation_player = get_node(animation_player_path)
		play_animation("Idle")
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0

func apply_velocity(new_velocity: Vector3):
	velocity.x = new_velocity.x
	velocity.z = new_velocity.z

func update_rotation_target(target_pos: Vector3):
	if (target_pos - global_position).length_squared() > 0.01:
		look_at(target_pos, Vector3.UP)

func play_animation(animation_name: String):
	if animation_player and animation_player.has_animation(animation_name):
		if animation_player.current_animation != animation_name:
			animation_player.play(animation_name)
			if animation_name == "Jump" and not animation_player.animation_finished.is_connected(_on_jump_animation_finished):
				animation_player.animation_finished.connect(_on_jump_animation_finished)

func _on_jump_animation_finished(anim_name: String):
	if anim_name == "Jump" and brain and brain.npc_states.has(self):
		brain.npc_states[self].is_jumping = false
		if brain.npc_states[self].waiting:
			play_animation("Idle")

func _physics_process(delta: float):
	if not brain or not brain.npc_states.has(self):
		return

	# Apply gravity
	if not is_on_floor() and not brain.npc_states[self].is_jumping:
		velocity.y -= gravity * delta

	var was_on_floor = is_on_floor()
	move_and_slide()
	
	# Floor snapping
	if was_on_floor and not is_on_floor() and velocity.y <= 0:
		var snap = Vector3.DOWN * 0.2
		var snap_result = move_and_collide(snap, true)
		if snap_result:
			global_position = snap_result.get_position()
