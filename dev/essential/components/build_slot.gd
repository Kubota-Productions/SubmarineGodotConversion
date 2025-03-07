class_name BuildComponentSlot
extends TextureRect

@export var build_data: BuildComponentData

var swap_tween: Tween

func _ready() -> void:
	if owner:
		await owner.ready
	pivot_offset.x += size.x/2
	pivot_offset.y += size.y/2
	if build_data:
		texture = build_data.icon
	self_modulate = Color(0.2618, 0.2667, 0.3324, 1.0)
func get_farm_data() -> BuildComponentData:
	return build_data

func swap_out() -> void:
	if swap_tween:
		swap_tween.kill()
	swap_tween = create_tween().set_parallel()
	swap_tween.tween_property(self,'self_modulate',Color(0.2618, 0.2667, 0.3324, 1.0),0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	swap_tween.tween_property(self,'scale',Vector2.ONE * 0.95,0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	swap_tween.tween_property(self,'scale',Vector2.ONE,0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.15)

func swap_in() -> void:
	if swap_tween:
		swap_tween.kill()
	swap_tween = create_tween().set_parallel()
	swap_tween.tween_property(self,'self_modulate',Color(0.9029, 0.3561, 1.0, 1.0),0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	swap_tween.tween_property(self,'scale',Vector2.ONE * 1.1,0.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	swap_tween.tween_property(self,'scale',Vector2.ONE,0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.1)
