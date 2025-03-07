@icon("res://addons/plenticons/icons/64x-hidpi/2d/square-yellow.png")
@tool
class_name LevelBuildSaver
extends Node

@export var target_parent: Node3D
@export_group('Creation')
@export_subgroup('Save')
@export var save_build_name: String = 'save'
@export_dir var save_build_folder: String = "res://builder/saves/"
@export var excecute_save: bool = false:
	set = save_instances

@export_subgroup('Load')
@export var load_build: LevelBuildData

@export var excecute_load: bool = false:
	set = load_instanced

@export var execute_convert_mesh: bool = false:
	set = convert_to_meshes

@export var execute_decor_clear: bool = false:
	set = decor_clear

@export_storage var current_build: LevelBuildData

@export_group('Inventory')
@export var inventory_name: String
@export_dir var inventory_path: String = "res://builder/basic/"
@export_dir var inventory_save_path: String = "res://builder/inventories/"

@export var execute_inventory: bool = false:
	set = get_directories


const BUILD_COMPONENT = preload("res://dev/essential/components/build_component.tscn")

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('DebugWorld'):
		save_instances(true)
	if Input.is_action_just_pressed('DebugFarm'):
		load_instanced(true)

func get_directories(_real: bool) -> void:
	var inventory = LevelBuildInventory.new()

	var dir = DirAccess.open(inventory_path + "/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".remap"):
				file_name = file_name.replace(".remap", "")
			if file_name.ends_with(".import"):
				file_name = file_name.replace(".import", "")
			var resource_packet = load(inventory_path+file_name)
			if resource_packet is BuildComponentData:
				inventory.build_data.append(resource_packet)
			file_name = dir.get_next()
	ResourceSaver.save(inventory,inventory_save_path + '/Inv' + inventory_name + ".tres")

func save_instances(real: bool) -> void:
	var level_build = LevelBuildData.new()
	var instances = get_tree().get_nodes_in_group('BuildComponent')
	for instance in instances:
		if instance is BuildComponent:
			if instance.placed_down:
				var build_instance = BuildInstance.new()
				build_instance.build_data = instance.build_data
				build_instance.build_position = instance.position
				build_instance.build_rotation = instance.rotation
				build_instance.build_scale = instance.scale
				build_instance.build_mesh_rotation = instance.build_mesh.rotation
				level_build.build_instances.append(build_instance)
	current_build = level_build
	ResourceSaver.save(current_build,save_build_folder + save_build_name + '.tres')
	load_build = load(save_build_folder + save_build_name + '.tres')

func load_instanced(real: bool):
	current_build = load_build
	var instances = get_tree().get_nodes_in_group('BuildComponent')
	for instance in instances:
		if instance is BuildComponent:
			if instance.placed_down:
				instance.queue_free()

	for build in current_build.build_instances:
		var new_build = BUILD_COMPONENT.instantiate() as BuildComponent
		self.add_child(new_build,true)
		new_build.set_owner(self)
		new_build.position = build.build_position
		new_build.rotation = build.build_rotation
		new_build.scale = build.build_scale
		new_build.build_mesh.rotation = build.build_mesh_rotation
		new_build.set_data(build.build_data)
		new_build.apply_placement()
		new_build.reparent(target_parent)
		var node_name = build.build_data.name.replace(' ','')
		new_build.name = node_name

func convert_to_meshes(real: bool) -> void:
	var decor_meshes = get_tree().get_nodes_in_group("BuildComponent")
	for decor in decor_meshes:
		if decor is BuildComponent:
			var new_mesh = MeshInstance3D.new()
			add_child(new_mesh)
			new_mesh.set_owner(self)
			new_mesh.global_transform = decor.global_transform
			new_mesh.mesh = decor.build_mesh.mesh
			new_mesh.rotation += decor.build_mesh.rotation
			if target_parent:
				new_mesh.reparent(target_parent)
				new_mesh.name = decor.name


func decor_clear(real: bool):
	get_tree().call_group('BuildComponent','queue_free')
