tool
extends EditorPlugin


const node_folder_setting := "ShyGraph/node_folder_path"

var slot_inspector := SlotInspectorPlugin.new()
var type_inspector := TypeInspectorPlugin.new()


var object
var new_node_button: Button
var load_nodes_button: Button
var save_nodes_button: Button

var _add_node_dialog: Popup


func _enter_tree() -> void:
	add_inspector_plugin(slot_inspector)
	add_inspector_plugin(type_inspector)
	add_buttons()


func _exit_tree() -> void:
	remove_buttons()
	_add_node_dialog.queue_free()
	remove_inspector_plugin(slot_inspector)
	remove_inspector_plugin(type_inspector)


func remove_buttons() -> void:
	for i in [new_node_button, load_nodes_button, save_nodes_button]:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, i)
		i.queue_free()


func handles(object: Object) -> bool:
	return object is ShyGraphEdit


func edit(_object: Object) -> void:
	object = _object


func make_visible(visible: bool) -> void:
	for i in [new_node_button, load_nodes_button, save_nodes_button]:
		i.visible = visible


func add_buttons() -> void:
	var base_control = get_editor_interface().get_base_control()
	_create_add_node_dialog()
	base_control.add_child(_add_node_dialog)


	new_node_button = Button.new()
	new_node_button.icon = base_control.get_icon("Add", "EditorIcons")
	new_node_button.connect("pressed", _add_node_dialog, "popup_centered", [_add_node_dialog.rect_size])
	new_node_button.hint_tooltip = "Add new Node"
	new_node_button.visible = false
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, new_node_button)

	load_nodes_button = Button.new()
	load_nodes_button.icon = base_control.get_icon("Load", "EditorIcons")
	load_nodes_button.hint_tooltip = "Load Nodes from Node Folder"
	load_nodes_button.connect("pressed", self, "laod_nodes_from_folder")
	load_nodes_button.visible = false
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, load_nodes_button)

	save_nodes_button = Button.new()
	save_nodes_button.icon = base_control.get_icon("Save", "EditorIcons")
	save_nodes_button.hint_tooltip = "Save Nodes to Node Folder"
	save_nodes_button.connect("pressed", self, "save_nodes_to_folder")
	save_nodes_button.visible = false
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU,save_nodes_button)


func laod_nodes_from_folder() -> void:#todo add undo?
	var dir = Directory.new()
	var node_folder = object.node_folder
	if node_folder and dir.dir_exists(node_folder):
		if dir.open(node_folder) == OK:
			dir.list_dir_begin()
			var file_path = dir.get_next()
			while file_path != "":
				if not file_path.get_extension() in ["tscn", "scn"]:
					file_path = dir.get_next()
					continue
				var new = load(node_folder + "/" + file_path).instance(3)
				if new and new is ShyGraphNode:
					if object.has_node(new.name):
						var old: Node = object.get_node(new.name)
						object.remove_child(old)
						old.queue_free()
					object.add_node_at_center(new)

					new.owner = object.owner
				file_path = dir.get_next()
			dir.list_dir_end()
		else:
			printerr("Failed to open Node Folder")


func save_nodes_to_folder() -> void:
	var node_folder = object.node_folder
	if !node_folder:
		printerr("No Node Folder defined")
		return
	for node in object.get_children():
		if node is ShyGraphNode:
			var node_scene = PackedScene.new()
			var result = node_scene.pack(node)
			if result == OK:
				ResourceSaver.save(node_folder + "/" + node.name + ".tscn", node_scene)
			else:
				printerr("failed to save node: %s"%[str(result)])


func create_new_nodetype(name: String, add_script: bool) -> void:# todo add undo
	var new = ShyGraphNode.new()
	new.name = name
	object.add_node_at_center(new)
	new.owner = object.owner
	if add_script:
		var node_folder = object.node_folder
		if node_folder:
			var script: Script
			if object.custom_node_template:
				script = object.custom_node_template
			else:
				script = load("res://addons/ShyGraph/Inspector/NodeTemplate.gd")
			var path = node_folder + "/" + new.name + ".gd"
			script.resource_path = path
			ResourceSaver.save(path, script)
			new.script = script
		else:
			printerr("No Node Folder defined")


func _create_add_node_dialog() -> void:
	_add_node_dialog = load("res://addons/ShyGraph/Inspector/AddNodeDialog.tscn").instance()
	_add_node_dialog.connect("submited", self, "create_new_nodetype")


