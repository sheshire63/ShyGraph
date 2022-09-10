tool
extends Control

class_name BitMapButton


signal changed(data)

export var names_x: PoolStringArray = [] setget _set_names_x
export var names_y: PoolStringArray = [] setget _set_names_y
export var label_size_x := 64
export var label_size_y := 64
export var selected_color := Color.white
export var unselected_color := Color.transparent

var matrix := [] setget _set_matrix

var _set_matrix_at_ready := false

func _ready() -> void:
	if _set_matrix_at_ready:
		_set_matrix(matrix)


func _draw() -> void:
	var rect = _get_button_rect()
	var size = _get_segment_size()
	for i in names_y.size():
		draw_string(get_font("font"), Vector2(16, i * size.y + size.y / 2 + rect.position.y), names_y[i], Color.white, label_size_y * .75)
	for grid_x in names_x.size():
		for grid_y in names_y.size():
			if grid_y in matrix[grid_x]:
				draw_rect(Rect2(Vector2(grid_x, grid_y) * size + rect.position + Vector2.ONE, size - 2 * Vector2.ONE), selected_color)
			else:
				draw_rect(Rect2(Vector2(grid_x, grid_y) * size + rect.position + Vector2.ONE, size - 2 * Vector2.ONE), unselected_color)
	draw_set_transform(Vector2(rect_size.x, 0), PI/2, Vector2.ONE)
	for i in names_x.size():
		draw_string(get_font("font"), Vector2(16, i * size.x + size.x / 2 + 4), names_x[i], Color.white, label_size_x * .75)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var rect = _get_button_rect()
		var pos = (event.get_position() - rect.position) / _get_segment_size()
		pos = pos.floor()
		if pos.x >= 0 and pos.y >= 0:
			if pos.y in matrix[pos.x]:
				matrix[pos.x].erase(pos.y)
			else:
				matrix[pos.x].append(pos.y)
			emit_signal("changed", matrix)
			update()


func _get_button_rect() -> Rect2:
	var rect = Rect2(Vector2(label_size_x, label_size_y), Vector2.ZERO)
	rect.end = rect_size
	return rect


func _get_segment_size() -> Vector2:
	return _get_button_rect().size / Vector2(names_x.size(), names_y.size())


func _set_names_x(value: PoolStringArray) -> void:
	value.invert()
	names_x = value
	setup()


func _set_names_y(value: PoolStringArray) -> void:
	names_y = value
	setup()


func setup() -> void:
	if !is_inside_tree():
		_set_matrix_at_ready = true
		return

	if matrix.size() > names_x.size():
		matrix.resize(names_x.size())
	while matrix.size() < names_x.size():
		matrix.append([])

	rect_min_size = Vector2(
			label_size_x + (names_x.size() * 16.0),
			label_size_y + (names_y.size() * 16.0))
	rect_size = Vector2.ZERO
	update()
	_set_matrix_at_ready = false


func _set_matrix(value) -> void:
	matrix = value
	setup()
