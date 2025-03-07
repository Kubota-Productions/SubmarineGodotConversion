class_name BuilderPoint
extends RayCast3D


@export var free_place: bool = true
@export var build_data: Array[BuildComponentData]
@export var current_build_data: BuildComponentData

var target_parent: Node3D
var build_component: BuildComponent

var position_point: Vector3
var target_rot: float = 0.0
var target_scale: float = 1.0

var max_scale: float = 15.0
var tween_rot : Tween

var apply_alignment: bool = false
var can_place: bool = true
var scaling: bool = false
var can_transform: bool = true

@onready var slot_container: GridContainer = $VBoxContainer/MarginContainer/Panel/ScrollContainer/SlotContainer

const BUILD_COMPONENT = preload("res://dev/essential/components/build_component.tscn")
const BUILD_SLOT = preload("res://dev/essential/components/build_slot.tscn")

func _ready() -> void:
	if owner:
		await owner.ready
	build_component = BUILD_COMPONENT.instantiate()
	build_component.top_level = true
	add_child(build_component)
	build_component.global_rotation = Vector3.ZERO
	if current_build_data:
		build_component.set_data(current_build_data)
	if free_place:
		build_component.set_free_place()
		max_scale = 20.0


	for data in build_data:
		var build_slot = BUILD_SLOT.instantiate()
		build_slot.build_data = data
		slot_container.add_child(build_slot)

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('Primary') and can_place:
		if is_colliding() and build_component:
			can_place = false
			if target_parent:
				build_component.place_down(target_parent)
			else:
				build_component.place_down(get_collider())
			build_component = null

			build_component = BUILD_COMPONENT.instantiate()
			build_component.top_level = true
			add_child(build_component)
			if current_build_data:
				build_component.set_data(current_build_data)
			build_component.global_rotation = Vector3.ZERO
			build_component.build_mesh.rotation.y = target_rot
			build_component.scale = Vector3.ONE * target_scale
			build_component.set_free_place()
			await get_tree().create_timer(0.15).timeout
			can_place = true

	if Input.is_action_just_pressed('MiddleToggle'):
		scaling = !scaling

	if Input.is_action_just_pressed('Secondary'):
		if is_colliding():
			if get_collider().has_meta('BuildComponent'):
				var build: Node3D = get_collider().get_meta('BuildComponent')
				build.queue_free()

	if build_component and can_transform:
		if Input.is_action_just_pressed('SwapUp'):
			if scaling:
				target_scale += 0.1
				target_scale = clamp(target_scale,1.0,max_scale)
				rotate_build()
			else:
				target_rot += deg_to_rad(15.0)
				rotate_build()
		elif Input.is_action_just_pressed('SwapDown'):
			if scaling:
				target_scale -= 0.1
				target_scale = clamp(target_scale,1.0,max_scale)
				rotate_build()
			else:
				target_rot -= deg_to_rad(15.0)
				rotate_build()

		if Input.is_action_just_pressed('Special'):
			apply_alignment = not apply_alignment
			if not apply_alignment:
				build_component.global_rotation.x = 0.0
				build_component.global_rotation.z = 0.0

func _process(delta: float) -> void:
	if build_component:
		if is_colliding():
			position_point = lerp(position_point,get_collision_point(),20.0 * delta)
			build_component.global_position.x = position_point.x
			build_component.global_position.y = position_point.y
			build_component.global_position.z = position_point.z
			if apply_alignment:
				var transform_target = align_with_y(build_component.transform, get_collision_normal()) * transform
				build_component.transform = lerp(build_component.transform,transform_target,7.0 * delta)
				build_component.scale = Vector3.ONE * target_scale
			build_component.visible = true
		else:
			build_component.visible = false

func rotate_build() -> void:
	if tween_rot:
		tween_rot.kill()
	tween_rot = create_tween().set_parallel()
	tween_rot.tween_property(build_component.build_mesh,'rotation',Vector3(0,target_rot,0),0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween_rot.tween_property(build_component,'scale',Vector3.ONE * target_scale,0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform


func _on_panel_inventory_opened(is_open: bool) -> void:
	can_transform = not is_open


func _on_panel_new_build_data(new_build_data: BuildComponentData) -> void:
	if build_component:
		current_build_data = new_build_data
		build_component.set_data(current_build_data)
