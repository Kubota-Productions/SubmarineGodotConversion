@tool
class_name BuildComponent
extends Node3D

@export var build_data: BuildComponentData

@onready var build_mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: StaticBody3D = $MeshInstance3D/StaticBody3D
@onready var collision_shape: CollisionShape3D = $MeshInstance3D/StaticBody3D/CollisionShape3D

var can_place: bool = true

@export var placed_down: bool = false

func _enter_tree() -> void:
	if Engine.is_editor_hint() and placed_down:
		set_data(build_data)
		apply_placement()
		$BuildFog.visible = false

func _ready() -> void:
	if placed_down:
		set_data(build_data)
		apply_placement()
	if Engine.is_editor_hint(): return
	if owner:
		await owner.ready
	collision.set_meta('BuildComponent',self)
	if build_data and not placed_down:
		set_data(build_data)



func place_down(farm_parent: Node3D, apply_juice: bool = true):
	reparent(farm_parent)
	apply_placement()
	if apply_juice:
		play_place_effects()


func apply_placement() -> void:
	collision.process_mode = Node.PROCESS_MODE_INHERIT
	build_mesh.material_override = null
	build_mesh.set_layer_mask_value(1,true)
	build_mesh.set_layer_mask_value(4,false)
	placed_down = true
	build_mesh.material_override = null

func play_place_effects() -> void:
	build_mesh.scale = Vector3.ONE * 0.05
	var position_mesh = build_mesh.position
	build_mesh.position = Vector3.ZERO
	var tween = create_tween().set_parallel()
	tween.tween_property(build_mesh,'scale',Vector3.ONE * 1.15,0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(build_mesh,'position',position_mesh * 1.15,0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(build_mesh,'scale',Vector3.ONE,0.3).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.3)
	tween.tween_property(build_mesh,'position',position_mesh,0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.4)
	$BuildFog/AnimationPlayer.play('fog')
	$AudioStreamPlayer3D.play()


func set_data(new_decor_data: BuildComponentData) -> void:
	if is_instance_valid(build_mesh):
		build_data = new_decor_data
		build_mesh.mesh = build_data.build_mesh
		collision_shape.shape = build_data.build_collision
		build_mesh.position = Vector3.ZERO + build_data.mesh_position_offset
		collision_shape.position = Vector3.ZERO + build_data.collision_position_offset

func set_free_place():
	can_place = true
