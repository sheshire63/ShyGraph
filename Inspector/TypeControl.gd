tool
extends Panel

signal changed


onready var c_box := $Box

onready var c_name := $Box/Name
onready var c_color := $Box/Color
onready var c_size_x := $Box/Size/X
onready var c_size_y := $Box/Size/Y
onready var c_multiple := $Box/Multiple
onready var c_same_side := $Box/SameSide
onready var c_connect_to := $Box/Connect2

onready var c_show := $Show


var type : Dictionary setget _set_type
func _set_type(new):
	type = new
	if !is_inside_tree() or !new:
		return
	c_name.text = new.name
	c_color.color = new.color
	c_size_x.value = new.size.x
	c_size_y.value = new.size.y
	c_multiple.pressed = new.multiple
	c_same_side.pressed = new.same_side
	_setup_connect_to()


var edit : ShyGraphEdit setget _set_edit
func _set_edit(new):
	edit = new
	if !is_inside_tree() or !new:
		return


func _ready() -> void:
	_set_edit(edit)
	_set_type(type)
	_setup_connect_to()
	rect_min_size.y = c_show.rect_size.y


func _on_Name_text_changed(new_text:String) -> void:
	type.name = new_text
	_update()


func _on_Color_color_changed(color:Color) -> void:
	type.color = color
	_update()


func _on_X_value_changed(value:float) -> void:
	type.size.x = value
	_update()
	

func _on_Y_value_changed(value:float) -> void:
	type.size.y = value
	_update()


func _on_Multiple_toggled(button_pressed:bool) -> void:
	type.multiple = button_pressed
	_update()


func _on_SameSide_toggled(button_pressed:bool) -> void:
	type.same_side = button_pressed
	_update()


func _setup_connect_to() -> void:
	if !edit:
		return
	for i in c_connect_to.get_children():
		c_connect_to.remove_child(i)
		i.queue_free()
	for i in edit.types.size():
		var control = CheckBox.new()
		control.text = str(edit.types[i].name)
		control.pressed = i in type.connections
		control.connect("toggled", self, "_on_connect_to_toggled", [i])
		c_connect_to.add_child(control)


#func _update_size() -> void:
#	rect_min_size = Vector2.RIGHT * 74 + c_box.rect_size
#	rect_size = Vector2.ZERO


func _update() -> void:
	emit_signal("changed")


func _on_Show_toggled(button_pressed: bool) -> void:
	c_box.visible = button_pressed
	if button_pressed:
		rect_min_size.y = c_show.rect_size.y + c_box.rect_size.y
	else:
		rect_min_size.y = c_show.rect_size.y

func set_label(label: String) -> void:
	c_show.text = type.name


func _on_connect_to_toggled(pressed: bool, id: int) -> void:
	if pressed:
		if not id in type.connections:
			type.connections.append(id)
	else:
		if id in type.connections:
			type.connections.erase(id)	
	_update()


