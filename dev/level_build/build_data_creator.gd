@tool
@icon("res://addons/plenticons/icons/64x-hidpi/objects/chest-yellow.png")
extends Node3D



@export_group('Configuration')
@export var excecute_creation: bool = false:
	set = create_instance
@export var object_name: String
@export var object_obj: Mesh

@export_group('Export')
@export var execute_save: bool = false:
	set = save_instance

@export var object_mesh: MeshInstance3D
@export var object_col: CollisionShape3D

const path = "res://dev/"



func create_instance(real: bool) -> void:
	for i in get_children():
		i.queue_free()
	object_mesh = MeshInstance3D.new()
	add_child(object_mesh)
	object_mesh.owner = self

	if object_name and object_obj:
		var new_mesh = object_obj.duplicate() as Mesh
		object_mesh.mesh = new_mesh
		object_mesh.name = object_name
		var new_shape = object_mesh.mesh.create_convex_shape(true,true)
		object_col = CollisionShape3D.new()
		add_child(object_col)
		object_col.owner = self
		object_col.shape = new_shape
		object_col.shape = new_shape
		object_mesh.name = 'Mesh'
		object_col.name = 'Collision'
		object_obj = new_mesh


func save_instance(real: bool) -> void:
	var new_build = BuildComponentData.new()
	new_build.name = object_name
	new_build.build_mesh = object_mesh.mesh
	new_build.mesh_position_offset = object_mesh.position
	new_build.build_collision = object_col.shape
	new_build.collision_position_offset = object_col.position
	ResourceSaver.save(new_build,path + object_name +'.tres')
