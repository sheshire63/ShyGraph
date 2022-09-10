tool 
extends ShyCanvas


class_name ShyGraphEdit


enum line_types {line, bezier}
const SIDES = {
		ShyGraphNode.SIDE.LEFT: Vector2.LEFT,
		ShyGraphNode.SIDE.RIGHT: Vector2.RIGHT,
		ShyGraphNode.SIDE.TOP: Vector2.UP,
		ShyGraphNode.SIDE.BOTTOM: Vector2.DOWN,
		}
# const break_line_key := "shy_graph_break_lines"


signal connected (from, to)
signal disconnected (from, to)
signal nodes_loaded
signal cleared
signal node_added (node)#not called on load
signal node_removed (node) #not called on clear
signal nodes_moved (nodes)
signal node_selected (node)
signal node_deselected (node)



export(String, DIR) var node_folder := ""
var types := [] setget _set_types; func _set_types(new) -> void:
		for i in new.size():
			new[i].merge(new_type())
		types = new
		update()
		_update_nodes()
export(line_types) var line_type := line_types.line

var node_menu := PopupMenu.new()
var nodes := {}
var connections := []
var selected_nodes := []

var _create_connection_from := {}
var _hover_slot := {}
var _break_from: Vector2
var _select_from : Vector2
var _copy_data: Dictionary
var _node_menu_from_empty := PopupMenu.new()


func _get_property_list() -> Array:
	var list := [
		{
			"name": "Types",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY,
		},
		{
			"name": "types",
			"type": TYPE_ARRAY,
			"usage": PROPERTY_USAGE_DEFAULT,
			"hint_string": "Types",
		},
	]
	return list


func _ready() -> void:
	if !owner or (Engine.editor_hint and owner.get_parent() is Viewport):
		return
	node_menu.connect("id_pressed", self, "_on_node_menu_id_pressed")
	add_child(node_menu)
	_node_menu_from_empty.connect("id_pressed", self, "_node_menu_from_empty_id_pressed")
	_node_menu_from_empty.connect("popup_hide", self, "_node_menu_from_empty_closed")
	add_child(_node_menu_from_empty)
	_load_nodes()
	connect("transform_changed", self, "_on_transform_changed")
	undo.connect("version_changed", self, "_on_undo_v_change")
	update()


func _process(delta: float) -> void:
	if (_create_connection_from and !_node_menu_from_empty.visible) or _break_from or _select_from:
		update()


func _unhandled_key_input(event: InputEventKey) -> void:
	if event.is_pressed():
		match event.scancode:
			KEY_C:
				if event.control:
					copy()
			KEY_V:
				if event.control:
					paste()
			KEY_D:
				if event.control:
					duplicate_selected()
			KEY_CONTROL:
				_break_from = Vector2.ZERO
				update()
			KEY_DELETE:
				delete_selected()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			match event.button_index:
				BUTTON_LEFT:
					if _create_connection_from:
						_connect_to_empty()
					if Input.is_key_pressed(KEY_CONTROL):
						_break_from = position_to_offset(get_local_mouse_position())
					else:
						_start_select_drag()
					update()
				BUTTON_RIGHT:
					if _create_connection_from:
						_create_connection_from = {}
					else:
						node_menu.popup(Rect2(event.global_position, node_menu.rect_size))
		else:
			if event.button_index == BUTTON_LEFT:
				if _break_from:
					_break_connections()
				elif _select_from:
					_end_select_drag()


func _draw() -> void:
	var tf = transform.affine_inverse()
	draw_set_transform(tf.origin, tf.get_rotation(), tf.get_scale())
	_draw_connections()
	_draw_create_connection()
	if _break_from:
		draw_line(_break_from, position_to_offset(get_local_mouse_position()), _get_break_line_color(), _get_break_line_width())
	if _select_from:
		draw_rect(Rect2(_select_from, position_to_offset(get_local_mouse_position()) - _select_from), _get_selection_fill_color())
		draw_rect(Rect2(_select_from, position_to_offset(get_local_mouse_position()) - _select_from),
				_get_selection_stroke_color(), false, _get_selection_stroke_width())



# puplic

func clear() -> void:
	_clear()
	emit_signal("cleared")


func deselect_all() -> void:
	undo.create_action("deselect_all")
	undo.add_do_method(self, "_deselect_multiple", selected_nodes.duplicate())
	undo.add_undo_method(self, "_select_multiple", selected_nodes.duplicate())
	undo.commit_action()


func select_multiple(nodes: Array) -> void:
	undo.create_action("select_mutiple")
	if !Input.is_key_pressed(KEY_CONTROL):
		undo.add_do_method(self, "_deselect_multiple", selected_nodes.duplicate())
		undo.add_undo_method(self, "_select_multiple", selected_nodes.duplicate())
	undo.add_do_method(self, "_select_multiple", nodes.duplicate())
	undo.add_undo_method(self, "_deselect_multiple", nodes.duplicate())
	undo.commit_action()


func deselect(node) -> void:
	undo.create_action("deselect")
	undo.add_do_method(self, "_deselect", node)
	undo.add_undo_method(self, "_select", node)
	undo.commit_action()


func select(node: ShyGraphNode) -> void:
	undo.create_action("select")
	undo.add_do_method(self, "_select", node)
	undo.add_undo_method(self, "_deselect", node)
	undo.commit_action()


func init_drag(slot: Dictionary) -> void:
	if _create_connection_from:
		_end_drag(slot)
	else:
		_start_drag(slot)


func save_data() -> Dictionary:
	var data = {"nodes": {}, "connections": connections}
	for child in get_children():
		if child is ShyGraphNode:
			data.nodes[child.name] = child.save_data()
	emit_signal("saved", data)
	return data


func load_data(data: Dictionary) -> void:
	clear()
	if data:
		connections = data.connections
		for i in data.nodes:
			var node_data = data.nodes[i]
			if node_data.type in nodes:
				var node = _create_node_instance(nodes[node_data.type])
				add_child(node, true)
				node.load_data(node_data)
				node.name = i
			else:
				printerr("node type not found: %s"%(node_data.type))
		

func add_connection(from: Dictionary, to: Dictionary) -> void:
	if !_is_connection_allowed(from, to):
		return
	undo.create_action("add_connection")
	var conn = {"from": from, "to": to}
	undo.add_do_method(self, "_add_connection", conn)
	undo.add_undo_method(self, "_remove_connection", conn)
	undo.commit_action()
	emit_signal("connected", from, to)


func remove_connection(from: Dictionary, to: Dictionary) -> void:
	undo.create_action("remove_connection")
	undo.add_do_method(self, "_remove_connection", {"from": from, "to": to})
	undo.add_undo_method(self, "_add_connection", {"from": from, "to": to})
	undo.commit_action()
	emit_signal("disconnected", from, to)


func get_type_color(type: int) -> Color:
	if type < 0 or type >= types.size():
		printerr("Invalid type: " + str(type))
		return Color.white
	return types[type].color


func get_type_size(type: int) -> Vector2:
	if type < 0 or type >= types.size():
		printerr("Invalid type: " + str(type))
		return Vector2.ONE
	return types[type].size


func new_type(label := "Type", color := Color.white, size := Vector2(8, 8), multiple:= true, same_side := false,connections := []) -> Dictionary:
	return {
		"name": label,
		"color": color,
		"size": size,
		"multiple": multiple,
		"same_side": same_side,
		"connections": connections,
		}


func add_node_at_center(node: ShyGraphNode) -> void:
	add_child(node, true)
	node.offset = position_to_offset(rect_size/2)


#get slot from node
func get_slot(node_name:String, slot: int) -> Dictionary:
	var node: ShyGraphNode = get_node(node_name)
	if node:
		return node.get_slot(slot)
	return {}


func delete_selected() -> void:
	undo.create_action("delete_selected")
	for i in selected_nodes:
		undo.add_undo_reference(i)
	undo.add_do_method(self, "_delete_multiple", selected_nodes.duplicate())
	undo.add_undo_method(self, "_restore_nodes", selected_nodes.duplicate())
	undo.add_undo_property(self, "connections", connections.duplicate())
	undo.add_do_method(self, "_deselect_multiple", selected_nodes.duplicate())
	undo.add_undo_method(self, "_select_multiple", selected_nodes.duplicate())
	undo.commit_action()


func duplicate_selected() -> void:
	_paste_nodes(_copy_selected())


func copy() -> void:
	_copy_data = _copy_selected()


func paste() -> void:
	_paste_nodes(_copy_data)


func add_type(type := {}) -> void:
	if !type:
		type = new_type()
	types.append(type)


func add_node_type(node: ShyGraphNode) -> void:
	if not node.nme in nodes:
		node_menu.add_item(node.name)
	nodes[node.name] = node


# events

func _on_node_menu_id_pressed(id:int) -> void:
	var node =_create_node_instance(nodes.values()[id])
	node.type = nodes.keys()[id]

	undo.create_action("add_node")
	undo.add_do_reference(node)
	undo.add_do_method(self, "add_child", node, true)
	undo.add_do_property(node, "offset", position_to_offset(get_local_mouse_position()))
	undo.add_undo_method(self, "remove_child", node)
	undo.commit_action()

	emit_signal("node_added", node)


func _on_undo_v_change() -> void:
	update()



# node events

func _on_node_moved(amount: Vector2, node: ShyGraphNode) -> void:
	var rect = _include_node_in_rect(node, area_rect)
	for i in selected_nodes:
		if i == node:
			continue
		i.offset += amount
		rect = _include_node_in_rect(i, rect)
	update()
	emit_signal("nodes_moved", selected_nodes)
	self.area_rect = rect


func _on_node_moved_to(to: Vector2, from: Vector2, node: ShyGraphNode) -> void:
	undo.create_action("node_moved")
	for i in selected_nodes:
		undo.add_do_property(node, "offset", node.offset)
		undo.add_undo_property(node, "offset", node.offset - (to-from))
	undo.commit_action()
	update()


func _on_node_request_select(node: ShyGraphNode) -> void:
	undo.create_action("node_selected")
	if !Input.is_key_pressed(KEY_CONTROL):
		undo.add_do_method(self, "_deselect_multiple", selected_nodes.duplicate())
		undo.add_undo_method(self, "_select_multiple", selected_nodes.duplicate())
	undo.add_do_method(node, "select")
	undo.add_undo_method(node, "deselect")
	undo.commit_action()


func _on_node_selected(node: ShyGraphNode) -> void:
	selected_nodes.append(node)
	emit_signal("node_selected", node)


func _on_node_deselected(node: ShyGraphNode) -> void:
	selected_nodes.erase(node)
	emit_signal("node_deselected", node)


func _on_node_delete(node) -> void:
	undo.create_action("delete_node")
	undo.add_undo_reference(node)
	undo.add_do_method(self, "_delete_node", (node))
	undo.add_undo_method(self, "add_child", node)
	undo.commit_action()
	emit_signal("node_removed", node)


func _on_node_offset_changed(_offset, node) -> void:
	self.area_rect = _include_node_in_rect(node, area_rect)


func _on_node_renamed(old: String, new: String) -> void:
	for i in connections:
		if i.from.node == old:
			i.from.node = new
		if i.to.node == old:
			i.to.node == new



# private

func _create_line(connection: Dictionary) -> Dictionary:
	var from: Dictionary = connection.from
	var to: Dictionary = connection.to
	if !has_node(from.node) or (to and !has_node(to.node)):
		print(to)
		printerr("node not found: %s"%(from.node if has_node(from.node) else to.node))
		_remove_connection({"from": connection.from, "to": connection.to})
		return {"line": [], "colors": []}
	var from_node = get_node(from.node)
	var from_pos = from_node.get_slot_offset(from.slot)
	var from_slot = get_slot(from.node, from.slot)
	var from_color = get_type_color(from_slot.type)
	var from_side = SIDES[from_slot.side]

	var to_pos: Vector2
	var to_color := Color.white
	var to_side := Vector2.ZERO
	if to:
		var to_node = get_node(to.node)
		var to_slot = get_slot(to.node, to.slot)
		to_pos = to_node.get_slot_offset(to.slot)
		to_color = get_type_color(to_slot.type)
		to_side = SIDES[to_slot.side]
	else:
		to_pos = position_to_offset(get_local_mouse_position())

	var line : PoolVector2Array = []
	var colors : PoolColorArray = []
	match line_type:
		line_types.line:
			line = [from_pos, to_pos]
			colors = [from_color, to_color]

		line_types.bezier:
			var curve = Curve2D.new()
			var weight = get_constant("bezier_len_pos", "GraphEdit")
			curve.add_point(from_pos, from_side * weight, from_side * weight)
			curve.add_point(to_pos, to_side * weight, to_side * weight)
			line = curve.get_baked_points()
			var gradient = Gradient.new()
			gradient.colors = [from_color, to_color]
			for i in line.size():
				colors.append(gradient.interpolate(1.0 / line.size() * i))
	return {"line": line, "colors": colors}


func _draw_connections() -> void:
	for i in connections:
		var line_data = _create_line(i)
		draw_polyline_colors(line_data.line, line_data.colors, _get_line_width())


func _draw_create_connection() -> void:
	if _create_connection_from:# todo add check
		if !_hover_slot or _is_connection_allowed(_create_connection_from, _hover_slot):
			var line_data = _create_line({
				"from": _create_connection_from,
				"to": _hover_slot,
				})
			draw_polyline_colors(line_data.line, line_data.colors)


func _load_nodes() -> void:
	node_menu.clear()
	nodes = {}
	
	if node_folder:
		var dir := Directory.new()
		if dir.open(node_folder):
			dir.list_dir_begin()
			var file = dir.get_next()
			while file != "":
				if not file.begins_with("_") and file.get_extension() in [".tscn", ".scn"]:
					var node = load(node_folder + "/" + file)
					var node_name = file.get_basename()
					nodes[node_name] = node
					node_menu.add_item(node_name)
			dir.list_dir_end()
	for node in get_children():
		if node is ShyGraphNode:
			node_menu.add_item(node.name)
			nodes[node.name] = node
			remove_child(node)
	emit_signal("nodes_loaded")


func _start_drag(from: Dictionary) -> void:
	_create_connection_from = from


func _end_drag(to := {}) -> void:
	if _create_connection_from:
		if to:
			add_connection(_create_connection_from, to)
	_create_connection_from = {}
	update()


func _create_node_instance(node) -> ShyGraphNode:
	if node is Node:
		node = node.duplicate(4)
	elif node is PackedScene:
		node = node.instance()
	elif node is Script:
		node = node.new()
	
	if not node is ShyGraphNode:
		printerr("node is not a ShyGraphNode")
		node = ShyGraphNode.new()
	node.rect_scale = Vector2.ONE / transform.get_scale()
	node.connect("moved", self, "_on_node_moved", [node])
	node.connect("offset_changed", self, "_on_node_offset_changed", [node])
	node.connect("moved_to", self, "_on_node_moved_to", [node])
	node.connect("selected", self, "_on_node_selected", [node])
	node.connect("deselected", self, "_on_node_deselected", [node])
	node.connect("request_delete", self, "_on_node_delete", [node])
	node.connect("_request_select", self, "_on_node_request_select")
	node.connect("rename", self, "_on_node_renamed")
	return node


func _break_connections() -> void:
	var list = []
	for connection in connections:
		var line = _create_line(connection).line
		for i in line.size() - 1:
			if Geometry.segment_intersects_segment_2d(_break_from, position_to_offset(get_local_mouse_position()), line[i], line[i + 1]):
				list.append(connection)
				break
	if list:
		undo.create_action("break_connections")
		for i in list:
			undo.add_do_method(self, "_remove_connection", i)
			undo.add_undo_method(self, "_add_connection", i)
		undo.commit_action()
	_break_from = Vector2.ZERO
	update()


func _start_select_drag() -> void:
	_select_from = position_to_offset(get_local_mouse_position())


func _end_select_drag() -> void:
	var rect = Rect2(_select_from, Vector2.ZERO)
	rect.end = position_to_offset(get_local_mouse_position())
	var nodes := []
	for i in get_children():
		if i is ShyGraphNode:
			if rect.abs().intersects(Rect2(i.offset, i.rect_size)):
				nodes.append(i)
	select_multiple(nodes)
	_select_from = Vector2.ZERO
	update()


func _is_connection_allowed(from: Dictionary, to: Dictionary) -> bool:
	if from.hash() == to.hash():#prevent connection to self
		return false
	var from_slot = get_node(from.node).get_slot(from.slot)
	var to_slot = get_node(to.node).get_slot(to.slot)
	var conns = types[from_slot.type].connections
	if from_slot.side == to_slot.side:
		if !types[from_slot.type].same_side or !types[to_slot.type].same_side:
			return false
	if to_slot.type in conns:
		return true
	conns = types[to_slot.type].connections
	if from_slot.type in conns:
		return true
	return false


func _disconnect_slot(node: String, slot: int) -> void:
	for connection in connections:
		if connection.from.node == node and connection.from.slot == slot:
			_remove_connection(connection)
		elif connection.to.node == node and connection.to.slot == slot:
			_remove_connection(connection)
		else:
			continue
		emit_signal("disconnected", connection.from, connection.to)


func _clear() -> void:
	connections = []
	_create_connection_from = {}
	selected_nodes = []
	for i in get_children():
		if i is ShyGraphNode:
			i.queue_free()
	_reset()


func _select_multiple(nodes: Array) -> void:
	for i in nodes:
		_select(i)


func _deselect_multiple(nodes: Array) -> void:
	for i in nodes:
		_deselect(i)


func _select(node: ShyGraphNode) -> void:
	node.select()


func _deselect(node: ShyGraphNode) -> void:
	node.deselect()


func _add_connection(connection: Dictionary) -> void:
	var from_node: ShyGraphNode = get_node(connection.from.node)
	var from_slot = from_node.get_slot(connection.from.slot)
	var to_node: ShyGraphNode = get_node(connection.to.node)
	var to_slot = to_node.get_slot(connection.to.slot)
	if !types[from_slot.type].multiple:
		_disconnect_slot(connection.from.node, connection.from.slot)
	if !types[to_slot.type].multiple:
		_disconnect_slot(connection.to.node, connection.to.slot)
	connections.append(connection)
	update()


func _remove_connection(connection: Dictionary) -> void:
	for i in connections:
		if i.hash() == connection.hash():
			connections.erase(i)
	update()


func _delete_multiple(nodes: Array) -> void:
	for i in nodes:
		_delete_node(i)


func _delete_node(node: ShyGraphNode) -> void:
	var to_remove = []
	for i in connections:
		if i.from.node == node.name or i.to.node == node.name:
			to_remove.append(i)
	for i in to_remove:
		_remove_connection(i)
		emit_signal("disconnected", i.from, i.to)

	_deselect(node)
	remove_child(node)


func _restore_nodes(nodes: Array) -> void:
	for i in nodes:
		_restore_node(i)


func _restore_node(node: ShyGraphNode) -> void:
	#func that adds the node and sets it up
	add_child(node)


func _convert_and_add_connections(conns: Array, ref: Dictionary) -> void:
	for i in conns:
		var new = i.duplicate(true)
		if new.from.node in ref:
			new.from.node = ref[new.from.node].name
		if new.to.node in ref:
			new.to.node = ref[new.to.node].name
		_add_connection(new)


func _copy_selected() -> Dictionary:
	var data = {"nodes": {}, "connections": []}
	for i in selected_nodes:
		data.nodes[i.name] = i.save_data()
	for conn in connections:
		if conn.from in data.nodes and conn.to in data.nodes:
			data.connections.append(conn)
	return data


func _paste_nodes(data) -> void:
	if !data:
		return
	var node_data := {}
	var node_ref := {}
	var conns := []
	for i in data.nodes:
		var node = _create_node_instance(nodes[data.nodes[i].type])
		node_data[node] = data.nodes[i]
		node_ref[i] = node
	if !node_ref:
		return
	for conn in connections:
		if conn.from.node in node_ref.keys() and conn.to.node in node_ref.keys():
			conns.append(conn)
	
	undo.create_action("paste")
	for i in node_ref:
		var node = node_ref[i]
		undo.add_do_reference(node)
		undo.add_do_method(self, "add_child", node, true)
		undo.add_do_method(node, "load_data", node_data[node])
		undo.add_undo_method(self, "remove_child", node)
	undo.add_do_method(self, "_convert_and_add_connections", conns, node_ref)
	undo.add_undo_property(self, "connections", connections.duplicate())
	undo.add_do_method(self, "_translate_nodes", node_ref.values(), Vector2.ONE * 64)
	undo.add_do_method(self, "_deselect_multiple", selected_nodes.duplicate())
	undo.add_do_method(self, "_select_multiple", node_ref.values())
	undo.add_undo_method(self, "_deselect_multiple", node_ref.values())
	undo.add_undo_method(self, "_select_multiple", selected_nodes.duplicate())
	undo.commit_action()


func _translate_nodes(nodes: Array, offset: Vector2) -> void:
	for i in nodes:
		i.offset += offset

var _connect_to_empty_data := {}
func _connect_to_empty() -> void:
	var _nodes := {}
	var conns := []
	for i in nodes:
		for j in nodes[i].slots.size():
			var to := {"node": i, "slot": j}
			if _is_connection_allowed(_create_connection_from, to):
				_nodes[i] = nodes[i]
				conns.append(to)
				break
	if !_nodes:
		_create_connection_from = {}
		update()
		return
	_connect_to_empty_data = {
			"nodes": _nodes,
			"conns": conns,
	}
	_node_menu_from_empty.clear()
	for i in _nodes:
		_node_menu_from_empty.add_item(i)
	_node_menu_from_empty.popup(Rect2(get_global_mouse_position(), _node_menu_from_empty.rect_size))

	#check for each node in nodes if it has a valid slot
		#if true add to a popupmenu


func _node_menu_from_empty_id_pressed(id: int) -> void:
	#todo fix its connects to itself
	#	and nodes created via this work like intended
	#		we cant use the node name because the from node may have that name
	undo.create_action("add_node")
	var conn = {
			"from": _create_connection_from,
			"to": {
				"node": "",
				"slot": _connect_to_empty_data.conns[id].slot,
				},
			}
	var new = _create_node_instance(_connect_to_empty_data.nodes.values()[id])
	new.type = _connect_to_empty_data.nodes.keys()[id]
	new.offset = position_to_offset(get_local_mouse_position())
	undo.add_do_reference(new)
	undo.add_do_method(self, "add_child", new)
	undo.add_undo_method(self, "remove_child", new)
	undo.add_do_method(self, "_convert_and_add_connections", [conn], {"": new})
	undo.add_undo_property(self, "connections", connections.duplicate())
	undo.commit_action()


func _node_menu_from_empty_closed() -> void:
	_create_connection_from = {}
	update()


func _include_node_in_rect(node:ShyGraphNode, rect: Rect2) -> Rect2:
	rect = rect.expand(node.offset)
	rect = rect.expand(node.offset + node.rect_size)
	return rect


#theme
func _get_break_line_color() -> Color:
	if has_color("break_line_color", ""):
		return get_color("break_line_color", "")
	return Color.red

func _get_line_width() -> int:
	if has_constant("line_width", ""):
		return get_constant("line_width", "")
	return 5

func _get_break_line_width() -> int:
	if has_constant("break_line_width", ""):
		return get_constant("break_line_width", "")
	return 1

func _get_selection_fill_color() -> Color:
	if has_color("selection_fill_color", ""):
		return get_color("selection_fill_color", "")
	return Color(0.5, 0.5, 0.5, 0.5)

func _get_selection_stroke_color() -> Color:
	if has_color("selection_stroke_color", ""):
		return get_color("selection_stroke_color", "")
	return Color.gray

func _get_selection_stroke_width() -> int:
	if has_constant("selection_stroke_width", ""):
		return get_constant("selection_stroke_width", "")
	return 1


func _update_nodes() -> void:
	for i in get_children():
		if i is ShyGraphNode:
			i.update()
			i.update_slots()