@tool
class_name BuildComponentData
extends Resource

@export_group('Info')
@export var icon: Texture2D = preload("res://icon.svg")
@export var name: String = ''
@export var color: Color = Color(255,255,255,1.0)
@export_multiline var description: String = ''

@export_group('Placement')
@export var build_mesh: Mesh
@export var mesh_position_offset: Vector3
@export var build_collision: Shape3D
@export var collision_position_offset: Vector3
