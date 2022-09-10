tool
extends PopupDialog

signal submited(name, add_script)

onready var c_add_script := $VBoxContainer/AddScript
onready var c_name := $VBoxContainer/Control/Name


func submit(_text:= "") -> void:
	emit_signal("submited", c_name.text, c_add_script.pressed)
	hide()


func _on_AddNodeDialog_about_to_show() -> void:
	c_name.grab_focus()
	c_name.select_all()
	rect_size = rect_min_size