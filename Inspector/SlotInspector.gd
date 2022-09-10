tool
extends EditorInspectorPlugin

class_name SlotInspectorPlugin


# const InspectorControl = preload("res://addons/ShyGraph/SlotInspector.tscn")
const ArrayEditorProperty = preload("res://addons/ShyGraph/Inspector/ArrayEditorProperty.gd")
const SlotControl = preload("res://addons/ShyGraph/Inspector/SlotControl.tscn")


func can_handle(object: Object) -> bool:
	return object is ShyGraphNode


func parse_property(object: Object, type: int, path: String, hint: int, hint_text: String, usage: int) -> bool:
	if path == "slots":
		var control = ArrayEditorProperty.new(object, path, SlotControl, "slot", "node")
		add_property_editor(path, control)
		return true
	return false