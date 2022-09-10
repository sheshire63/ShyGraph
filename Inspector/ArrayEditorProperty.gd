tool
extends EditorProperty


var object
var path
var sub_control
var value_property
var object_property
var label_property

var box := VBoxContainer.new()
var control := SpinBox.new()
var updating := false

var value

func _init(_object, _path, _sub_control, _value_property, _object_property) -> void:
	object = _object
	path = _path
	sub_control = _sub_control
	value_property = _value_property
	object_property = _object_property
	#label_property = _label_property


func _ready() -> void:
	label = "Count"
	add_child(control)
	add_focusable(control)
	add_child(box)
	set_bottom_editor(box)
	value = get_edited_object()[get_edited_property()]
	control.connect("value_changed", self, "_on_value_changed")
	setup()


func _on_value_changed(new: float) -> void:
	if updating:
		return
	value.resize(new)
	emit_changed(get_edited_property(), value)


func update_property() -> void:
	updating = true
	var new = get_edited_object()[get_edited_property()]
	value = new
	setup()
	updating = false


func setup() -> void:
	clear()
	control.value = value.size()
	for i in value:
		var c = sub_control.instance()
		c[value_property] = i
		c[object_property] = object
		box.add_child(c)
		c.set_label(str(value.find(i)))
		c.connect("changed", self, "_on_changed")


func clear() -> void:
	for i in box.get_children():
		box.remove_child(i)
		i.queue_free()


func _on_changed() -> void:
	emit_changed(get_edited_property(), value, "", true)


# func get_tooltip_text() -> String:
# 	return ""

