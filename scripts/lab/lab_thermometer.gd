class_name LabThermometer
extends Area2D

var dragging: bool = false
var _offset: Vector2
var _reading: Label

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	z_index = 20
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 100)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -35)
	add_child(collision)
	_reading = Label.new()
	_reading.position = Vector2(25, -90)
	_reading.size = Vector2(180, 55)
	_reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reading.add_theme_font_size_override("font_size", 16)
	add_child(_reading)
	show_reading(null)
	input_event.connect(_on_input_event)

func show_reading(value: Variant) -> void:
	_reading.text = "Термометр\n—" if value == null else "Термометр\n%.1f °C" % float(value)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		_offset = position - get_canvas_transform().affine_inverse() * event.position
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseMotion:
		position = get_canvas_transform().affine_inverse() * event.position + _offset
		position.x = clampf(position.x, 50.0, 1100.0)
		position.y = clampf(position.y, 280.0, 470.0)
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_line(Vector2(0, -80), Vector2(0, 0), Color("d7ecf0"), 14, true)
	draw_line(Vector2(0, -68), Vector2(0, 0), Color("d98b83"), 5, true)
	draw_circle(Vector2.ZERO, 12, Color("d98b83"))
