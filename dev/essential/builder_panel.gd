extends Panel

signal new_build_data(build_data: BuildComponentData)
signal inventory_opened(is_open: bool)

const BUILD_SLOT = preload("res://dev/essential/components/build_slot.tscn")
@onready var slot_container: GridContainer = $ScrollContainer/SlotContainer
@onready var label: Label = $"../../MarginContainer2/Label"
@onready var v_box_container: VBoxContainer = $"../.."

var slot_index: int = 0
var current_slot: BuildComponentSlot
var can_swap: bool = true

var available: bool = false

func _ready() -> void:
	if owner:
		await owner.ready
	swap_index(0)
	v_box_container.modulate = Color(1.0, 1.0, 1.0, 0.0)
	inventory_opened.emit(available)

func _input(event: InputEvent) -> void:
	if can_swap and available:
		if Input.is_action_just_pressed('SwapUp'):
			swap_index(1)
		elif Input.is_action_just_pressed('SwapDown'):
			swap_index(-1)
	if Input.is_action_just_pressed('OpenInventory'):
		available = true
	elif Input.is_action_just_released('OpenInventory'):
		available = false

	if available:
		v_box_container.modulate = Color('white')
	else:
		v_box_container.modulate = Color(1.0, 1.0, 1.0, 0.0)
	inventory_opened.emit(available)

func swap_index(swap_count: int) -> void:
	can_swap = false
	slot_index += swap_count

	if slot_index < 0:
		slot_index = slot_container.get_child_count()-1
	if slot_index > slot_container.get_child_count()-1:
		slot_index = 0


	var slot_pick : BuildComponentSlot

	if slot_container.get_child_count() > 0:
		slot_pick = slot_container.get_child(slot_index)


	if slot_pick is BuildComponentSlot:
		if current_slot:
			current_slot.swap_out()
		current_slot = slot_pick
		current_slot.swap_in()
		label.text = current_slot.build_data.name
		new_build_data.emit(current_slot.build_data)
	await get_tree().create_timer(0.025).timeout
	can_swap = true

func tween_position() -> void:
	pass
