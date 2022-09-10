tool
extends Control

class_name SlotButton


var edit
var node
var slot_index: int# todo

var slot := {} setget _set_slot
func _set_slot(new) -> void:
	slot = new
	update_position()


func _init(pos := 0) -> void:
	slot_index = pos


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	node = get_parent()
	edit = node.get_parent()
	update_position()
	connect("mouse_exited", self, "_on_mouse_exited")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		var slot_data = {
			"slot": slot_index,
			"node": node.name,
		}
		if event.is_pressed():
			edit.init_drag(slot_data)
	if event is InputEventMouseMotion:
		edit._hover_slot = {
			"slot": slot_index,
			"node": node.name,
		}


func _on_mouse_exited() -> void:
	edit._hover_slot = {}


func _draw() -> void:
	if slot and slot.active:
		var size = edit.get_type_size(slot.type)
		_draw_ellipse(size, size, edit.get_type_color(slot.type))
	

func _draw_ellipse(offset: Vector2, size: Vector2, color: Color) -> void:
	var points = []
	for i in range(0, 360, 10):
		var angle = i * PI / 180
		points.append(Vector2(
			offset.x + size.x * cos(angle),
			offset.y + size.y * sin(angle)
		))
	draw_colored_polygon(points, color)


func update_position() -> void:
	if !is_inside_tree() or !slot:
		return
	var size = edit.get_type_size(slot.type)
	rect_size = size * 2
	rect_scale = slot.size
	rect_position = node._get_slot_offset(slot) - size
	update()
