tool
extends EditorInspectorPlugin

class_name TypeInspectorPlugin


const ArrayEditorProperty = preload("res://addons/ShyGraph/Inspector/ArrayEditorProperty.gd")
const TypeControl = preload("res://addons/ShyGraph/Inspector/TypeControl.tscn")


func can_handle(object: Object) -> bool:
	return object is ShyGraphEdit


func parse_property(object: Object, type: int, path: String, hint: int, hint_text: String, usage: int) -> bool:
	if path == "types":
		var control = ArrayEditorProperty.new(object, path, TypeControl, "type", "edit")
		add_property_editor(path, control)
		return true
	return false
