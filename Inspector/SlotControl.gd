tool
extends Control

signal changed

onready var c_active := $Box/Active
onready var c_type := $Box/Type
onready var c_side := $Box/Side
onready var c_allign := $Box/Allign
onready var c_offset_x := $Box/Offset/OffsetX
onready var c_offset_y := $Box/Offset/OffsetY
onready var c_anchor := $Box/Anchor/AnchorPath
onready var c_size_x := $Box/Size/SizeX
onready var c_size_y := $Box/Size/SizeY

onready var c_show := $Show
onready var c_box := $Box

var slot : Dictionary setget _set_slot
func _set_slot(new):
	slot = new
	if !is_inside_tree():
		return
	c_active.pressed = slot.active
	c_type.selected = slot.type
	c_side.selected = slot.side
	c_allign.selected = slot.allign
	c_offset_x.value = slot.offset.x
	c_offset_y.value = slot.offset.y
	c_anchor.text = slot.anchor
	c_size_x.value = slot.size.x
	c_size_y.value = slot.size.y

var node : ShyGraphNode setget _set_node
func _set_node(new):
	node = new
	if !is_inside_tree():
		return


func _ready() -> void:	
	var editor: ShyGraphEdit = node.get_parent()
	if editor:
		for i in editor.types:
			c_type.add_item(i.name)
	for i in node.ALLIGN:
		c_allign.add_item(i)
	for i in node.SIDE:
		c_side.add_item(i)
	# c_anchor.add_item("None")
	# for i in node.get_children():
	# 	if ! i is SlotButton:
	# 		c_anchor.add_item(i.name)
	_set_slot(slot)
	c_active.connect("toggled", self, "_on_active_toggled")
	c_type.connect("item_selected", self, "_on_type_item_selected")
	c_side.connect("item_selected", self, "_on_side_item_selected")
	c_allign.connect("item_selected", self, "_on_allign_item_selected")
	c_offset_x.connect("value_changed", self, "_on_offset_x_value_changed")
	c_offset_y.connect("value_changed", self, "_on_offset_y_value_changed")
	c_anchor.connect("text_changed", self, "_on_AnchorChild_text_changed")
	c_size_x.connect("value_changed", self, "_on_size_x_value_changed")
	c_size_y.connect("value_changed", self, "_on_size_y_value_changed")
	rect_min_size.y = c_show.rect_size.y


func _on_active_toggled(button_pressed: bool) -> void:
	slot.active = button_pressed
	updata_slot()


func _on_type_item_selected(index: int) -> void:
	slot.type = index
	updata_slot()


func _on_side_item_selected(index: int) -> void:
	slot.side = index
	updata_slot()


func _on_allign_item_selected(index: int) -> void:
	slot.allign = index
	updata_slot()


func _on_offset_x_value_changed(value: float) -> void:
	slot.offset.x = value
	updata_slot()


func _on_offset_y_value_changed(value: float) -> void:
	slot.offset.y = value
	updata_slot()


func _on_size_x_value_changed(value: float) -> void:
	slot.size.x = value
	updata_slot()


func _on_size_y_value_changed(value: float) -> void:
	slot.size.y = value
	updata_slot()


func _on_AnchorChild_text_changed(new_text:String) -> void:
	slot.anchor = new_text
	updata_slot()


func updata_slot() -> void:
	emit_signal("changed")


func _on_Show_toggled(button_pressed: bool) -> void:
	c_box.visible = button_pressed
	if button_pressed:
		rect_min_size.y = c_show.rect_size.y + c_box.rect_size.y
	else:
		rect_min_size.y = c_show.rect_size.y


func set_label(label: String) -> void:
	c_show.text = "Slot %s" %[label]
