tool
extends Control


class_name ShyCanvas


signal save_request(data)
signal saved
signal transform_changed
signal offset_changed
signal scale_changed
signal area_rect_changed


export var ruler := true setget _set_ruler; func _set_ruler(new) -> void:
		ruler = new
		update()
export var scroll_bar := true setget _set_scroll_bar; func _set_scroll_bar(new):
		if scroll_bar != new:
			scroll_bar = new
			if new:
				_add_scrooll_bars()
			else:
				_remove_scroll_bar()

var transform := Transform2D.IDENTITY setget _set_offset; func _set_offset(new) -> void:
		new =_limit_transform_to_rect(new)
		transform = new
		_update_bar_pos()
		emit_signal("transform_changed", transform)
		update()
var area_rect := Rect2() setget _set_area_rect; func _set_area_rect(new) -> void:
		if new != area_rect:
			area_rect = new
			_update_bars()
			update()
			emit_signal("area_rect_changed")
var bar_h: ScrollBar
var bar_v: ScrollBar
var undo := UndoRedo.new()


# flow

func _ready() -> void:
	if scroll_bar:
		_add_scrooll_bars()
	

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		match event.button_index:
			BUTTON_WHEEL_UP:
				scale(0.909091)
			BUTTON_WHEEL_DOWN:
				scale(1.1)
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(BUTTON_MIDDLE):
			move(-event.relative)


func _unhandled_key_input(event: InputEventKey) -> void:
	if event.pressed and event.scancode == KEY_Z and event.control == true:
		if event.shift:
			undo.redo()
		else:
			undo.undo()


func _draw() -> void:
	draw_style_box(_get_background(), Rect2(Vector2.ZERO, rect_size))
	_draw_grid()
	if ruler:
		_draw_ruler()
	#draw_set_transform_matrix(transform.affine_inverse())
	#draw_rect(area_rect, Color.green, false)


# puplic

# resets the transform aka resets canvas position and scale
func reset() -> void:
	_reset()


func move(amount: Vector2) -> void:
	self.transform = transform.translated(amount)


func move_to(pos: Vector2) -> void:
	self.transform.origin = pos


func scale(amount: float) -> void:
	scale_to(transform.get_scale().x * amount)


func scale_to(scale: float) -> void:
	_scale(scale)


func offset_to_position(value, translate := true):
	if value is int or value is float:
		return value / transform.get_scale().x
	if translate:
		return transform.affine_inverse().xform(value)
	else:
		return transform.affine_inverse().basis_xform(value)


func position_to_offset(value, translate := true):
	if value is float or value is int:
		return value * transform.get_scale().x
	if translate:
		return transform.xform(value)
	else:
		return transform.basis_xform(value)

# virtual

func _update() -> void:
	pass


func _on_transform_changed(_transform: Transform2D) -> void:
	pass


# events

func _on_bar_v_changed(new) -> void:
	self.transform.origin.y = new


func _on_bar_h_changed(new) -> void:
	self.transform.origin.x = new


# private

func _update_bars() -> void:
	var offset = position_to_offset(rect_size, false) / 2
	if bar_v:
		bar_v.min_value = area_rect.position.y - offset.y
		bar_v.max_value = area_rect.end.y - offset.y
	if bar_h:
		bar_h.min_value = area_rect.position.x - offset.x
		bar_h.max_value = area_rect.end.x - offset.x
	_update_bar_pos()


func _update_bar_pos() -> void:
	if bar_v:
		bar_v.value = transform.origin.y
	if bar_h:
		bar_h.value = transform.origin.x


func _draw_grid() -> void:
	var offset: float = _get_ruler_width() if ruler else 0.0
	var from: Vector2 = position_to_offset(offset * Vector2.ONE)
	var to: Vector2 = position_to_offset(rect_size)
	var step = (_get_grid_step() / (_get_grid_substeps() + 1)) * Vector2.ONE
	var pos: Vector2 = from.snapped(step)
	draw_set_transform_matrix(transform.affine_inverse())
	while pos.x <= to.x or pos.y <= to.y:
		if pos.x >= from.x and pos.x <= to.x:
			var line_width := _get_grid_minor_line_width()
			var color := _get_grid_minor_line_color()
			if int(pos.x) % _get_grid_step() == 0:
				line_width = _get_grid_major_line_width()
				color = _get_grid_major_line_color()
			draw_line(Vector2(pos.x, from.y), Vector2(pos.x, to.y), color, position_to_offset(line_width))
		if pos.y >= from.y and pos.y <= to.y:
			var line_width := _get_grid_minor_line_width()
			var color := _get_grid_minor_line_color()
			if int(pos.y) % _get_grid_step() == 0:
				line_width = _get_grid_major_line_width()
				color = _get_grid_major_line_color()
			draw_line(Vector2(from.x, pos.y), Vector2(to.x, pos.y), color, position_to_offset(line_width))
		pos += step
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_ruler() -> void:
	var from: Vector2 = position_to_offset(Vector2.ONE * _get_ruler_width())
	var to: Vector2 = position_to_offset(rect_size)
	var step = _get_grid_step() / (_get_grid_substeps() + 1) * Vector2.ONE
	var pos: Vector2 = from.snapped(step)
	while pos.x <= to.x:
		if pos.x > from.x:
			var point = offset_to_position(pos)
			if int(pos.x) % _get_grid_step() == 0:
				draw_string(_get_ruler_font(), Vector2(point.x, _get_ruler_width()), str(int(pos.x)), _get_ruler_font_color())
			draw_line(Vector2(point.x, 0), Vector2(point.x, _get_ruler_width()), _get_ruler_line_color(), _get_ruler_line_width())
		pos.x += step.x
	draw_line(Vector2.ONE * _get_ruler_width(), Vector2(rect_size.x, _get_ruler_width()), _get_ruler_line_color(), 2.0)
	var tf = Transform2D(PI/2, Vector2.ZERO)
	draw_set_transform_matrix(tf.affine_inverse())
	while pos.y <= to.y:
		if pos.y > from.y:
			var point = offset_to_position(pos)
			if int(pos.y) % _get_grid_step() == 0:
				draw_string(_get_ruler_font(), tf.xform(Vector2(_get_ruler_width(), point.y)), str(int(pos.y)), _get_ruler_font_color())
			draw_line(tf.xform(Vector2(0, point.y)), tf.xform(Vector2(_get_ruler_width(), point.y)), _get_ruler_line_color(), _get_ruler_line_width())
		pos.y += step.y
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_line(Vector2.ONE * _get_ruler_width(), Vector2(_get_ruler_width(), rect_size.y), _get_ruler_line_color(), 2.0)


func _remove_scroll_bar() -> void:
	if is_instance_valid(bar_v):
		bar_v.queue_free()
	bar_v = null
	if is_instance_valid(bar_h):
		bar_h.queue_free()
	bar_h = null


func _limit_transform_to_rect(old: Transform2D) -> Transform2D:
	var offset = position_to_offset(rect_size / 2, false)
	old.origin = _get_nearest_point_in_rect(old.origin + offset, area_rect) - offset
	return old

func _add_scrooll_bars() -> void:
	bar_v = VScrollBar.new()
	bar_v.set_anchors_and_margins_preset(Control.PRESET_RIGHT_WIDE)
	bar_v.connect("value_changed", self, "_on_bar_v_changed")
	add_child(bar_v)
	bar_h = HScrollBar.new()
	bar_h.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
	bar_h.connect("value_changed", self, "_on_bar_h_changed")
	add_child(bar_h)
	_update_bar_pos()

# static

static func _get_nearest_point_in_rect(point: Vector2, rect: Rect2) -> Vector2:
	if rect.has_point(point):
		return point
	point.x = max(rect.position.x, min(point.x, rect.end.x))
	point.y = max(rect.position.y, min(point.y, rect.end.y))
	return point


func _reset_area() -> void:
	var rect = get_rect()
	for i in get_children():
		if i is ShyGraphNode:
			rect.expand(i.offset)
			rect.expand(i.offset + i.rect_size)
	self.area_rect = rect


func _reset() -> void:
	self.transform = Transform2D.IDENTITY
	_reset_area()
	update()


func _scale(scale_to) -> void:
	scale_to = max(_get_min_scale() / 100.0, min(scale_to, _get_max_scale() / 100.0))
	var mouse_from = position_to_offset(get_local_mouse_position())
	var new = Transform2D.IDENTITY.scaled(Vector2.ONE * scale_to)
	new.origin = transform.origin
	transform = new
	var mouse_to = position_to_offset(get_local_mouse_position())
	transform.origin += mouse_from - mouse_to
	self.transform = transform


# theme
func _get_background() -> StyleBox:
	return get_stylebox("bg", "")
	
func _get_grid_step() -> int:
	if has_constant("grid_step", ""):
		return get_constant("grid_step", "")
	return 128

func _get_grid_substeps() -> int:
	if has_constant("grid_substeps", ""):
		 return get_constant("grid_substeps", "")
	return 1

func _get_min_scale() -> int:
	if has_constant("min_scale", ""):
		return get_constant("min_scale", "")
	return 10# in procent

func _get_max_scale() -> int:
	if has_constant("max_scale", ""):
		return get_constant("max_scale", "")
	return 1000
func _get_ruler_width() -> int:
	if has_constant("ruler_widht", ""):
		 return get_constant("ruler_width", "")
	return 16

func _get_ruler_line_step() -> int:
	if has_constant("ruler_line_step", ""):
		return get_constant("ruler_line_step", "")
	return 128

func _get_ruler_font() -> Font:
	return get_font("ruler_font", "")

func _get_ruler_line_width() -> int:
	if has_constant("ruler_line_width", ""):
		return get_constant("ruler_line_width", "")
	return 1

func _get_ruler_font_color() -> Color:
	if has_color("ruler_font_color", ""):
		return get_color("ruler_font_color", "")
	return Color.white

func _get_ruler_line_color() -> Color:
	if has_color("ruler_line_color", ""):
		return get_color("ruler_line_color", "")
	return Color.white

func _get_grid_major_line_width() -> int:
	if has_constant("grid_major_line_width", ""):
		return get_constant("grid_major_line_width", "")
	return 2

func _get_grid_minor_line_width() -> int:
	if has_constant("grid_minor_line_width", ""):
		 return get_constant("grid_minor_line_width", "")
	return 1

func _get_grid_major_line_color() -> Color:
	if has_color("grid_major_line_color", ""):
		return get_color("grid_major_line_color", "")
	return Color.darkgray

func _get_grid_minor_line_color() -> Color:
	if has_color("grid_minor_line_color", ""):
		return get_color("grid_minor_line_color", "")
	return Color.gray


# theme settings
