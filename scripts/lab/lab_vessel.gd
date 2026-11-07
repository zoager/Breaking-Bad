class_name LabVessel
extends Area2D

signal dropped(vessel: LabVessel)
var mixture: MixtureState
var title: String = ""
var accent: Color = Color.WHITE
var dragging: bool = false
var show_temperature: bool = true
var drag_origin: Vector2
var _offset: Vector2
var _bubble_time: float = 0.0
var _elapsed: float = 0.0
var _info: Label

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(116, 150)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, -65)
	add_child(collision)
	_info = Label.new()
	_info.position = Vector2(-125, 20)
	_info.size = Vector2(250, 90)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.add_theme_font_size_override("font_size", 17)
	add_child(_info)
	input_event.connect(_on_input_event)
	refresh()

func refresh() -> void:
	if _info == null or mixture == null:
		return
	_info.text = "%s\n%.0f / %.0f мл" % [title, mixture.get_volume_l() * 1000.0, mixture.get_capacity_l() * 1000.0]
	if show_temperature:
		_info.text += " · %.0f °C" % mixture.get_temperature_c()
	queue_redraw()

func show_bubbles() -> void:
	_bubble_time = 3.0 # Presentation duration, unrelated to reaction kinetics.

func _on_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_origin = position
		_offset = position - get_canvas_transform().affine_inverse() * event.position
		z_index = 10
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseMotion:
		position = get_canvas_transform().affine_inverse() * event.position + _offset
		position.x = clampf(position.x, 100.0, 1180.0)
		position.y = clampf(position.y, 280.0, 490.0)
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		z_index = 0
		dropped.emit(self)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_elapsed += delta
	if _bubble_time > 0.0:
		_bubble_time = maxf(0.0, _bubble_time - delta)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-59, -142, 118, 148), Color(0.8, 0.9, 0.95, 0.07))
	if mixture != null:
		var height: float = 125.0 * mixture.get_volume_l() / mixture.get_capacity_l()
		draw_rect(Rect2(-50, -height, 100, height), Color(0.48, 0.83, 0.89, 0.6))
	draw_line(Vector2(-55, -140), Vector2(-55, 0), Color("c8e1ea"), 5, true)
	draw_line(Vector2(-55, 0), Vector2(55, 0), Color("c8e1ea"), 5, true)
	draw_line(Vector2(55, 0), Vector2(55, -140), Color("c8e1ea"), 5, true)
	draw_line(Vector2(-65, -140), Vector2(65, -140), accent, 6, true)
	for tick: int in range(1, 5):
		draw_line(Vector2(33, -25 * tick), Vector2(48, -25 * tick), Color("c8e1ea"), 2)
	if _bubble_time > 0.0:
		for index: int in range(8):
			var rise: float = fmod(_elapsed * 45.0 + index * 16.0, 120.0)
			draw_circle(Vector2(-35 + index * 10, -10.0 - rise), 3.0 + index % 3, Color("edfaff"), false, 2.0, true)

## Thermometer bulb must be inside the displayed liquid, not merely near the vessel.
func contains_liquid_point(global_point: Vector2) -> bool:
	if mixture == null or mixture.get_volume_l() <= 0.0:
		return false
	var local_point: Vector2 = to_local(global_point)
	var height: float = 125.0 * mixture.get_volume_l() / mixture.get_capacity_l()
	return absf(local_point.x) < 50.0 and local_point.y <= 0.0 and local_point.y >= -height
