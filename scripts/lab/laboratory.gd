extends Node2D

const Vessel = preload("res://scripts/lab/lab_vessel.gd")
const Mixture = preload("res://scripts/domain/mixture_state.gd")
const Catalog = preload("res://scripts/catalog/reaction_catalog.gd")
const ChemistryEngine = preload("res://scripts/chemistry/reaction_engine.gd")
const Heater = preload("res://scripts/equipment/heater_model.gd")
const Thermometer = preload("res://scripts/lab/lab_thermometer.gd")
const CATALOG_PATH: String = "res://data/demo_catalog.json"
const HEATER_SEAT: Vector2 = Vector2(680, 470)
const HEATER_CONTACT_HALF_WIDTH: float = 50.0
const HEATER_CONTACT_VERTICAL_TOLERANCE: float = 12.0
const REACTION_ID: String = "bicarbonate_acid"
var _catalog := Catalog.new()
var _engine := ChemistryEngine.new()
var _vessels: Array[LabVessel] = []
var _receiver: LabVessel
var _zone: Area2D
var _portion: SpinBox
var _status: Label
var _product_info: Label
var _heater := Heater.new()
var _water: LabVessel
var _heater_zone: Area2D
var _probe: LabThermometer
var _power: SpinBox
var _heater_switch: CheckButton
var _heater_info: Label

func _ready() -> void:
	get_viewport().physics_object_picking = true
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	_build_interface()
	_build_heating_interface()
	var errors: PackedStringArray = _catalog.load_file(CATALOG_PATH)
	if not errors.is_empty():
		_status.text = "Не вдалося завантажити каталог. " + "; ".join(errors)
		push_error(_status.text)
		return
	_engine.reaction_applied.connect(_on_reaction_applied)
	_reset()

func _build_interface() -> void:
	_zone = Area2D.new()
	_zone.position = Vector2(980, 395)
	_zone.collision_layer = 2
	_zone.collision_mask = 1
	_zone.input_pickable = false
	var zone_shape := RectangleShape2D.new()
	zone_shape.size = Vector2(260, 200)
	var collision := CollisionShape2D.new()
	collision.shape = zone_shape
	_zone.add_child(collision)
	add_child(_zone)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label(layer, "ЛАБОРАТОРІЯ / ПЕРШИЙ ДОСЛІД", Vector2(40, 25), Vector2(1000, 45), 29)
	_label(layer, "Перетягни розчин над приймальною склянкою та відпусти — переллється обрана порція.", Vector2(40, 85), Vector2(1200, 35), 20)
	_label(layer, "Склянка має стояти в позначеній робочій зоні. Додай по 10 мл обох розчинів.", Vector2(40, 120), Vector2(1200, 35), 18)
	_label(layer, "Порція, мл:", Vector2(40, 175), Vector2(150, 40), 20)
	_portion = SpinBox.new()
	_portion.position = Vector2(195, 170)
	_portion.size = Vector2(130, 45)
	_portion.min_value = 1
	_portion.max_value = 50
	_portion.step = 1
	_portion.value = 10
	layer.add_child(_portion)
	var reset := Button.new()
	reset.text = "Почати заново"
	reset.position = Vector2(1010, 170)
	reset.size = Vector2(220, 45)
	reset.pressed.connect(_reset)
	layer.add_child(reset)
	_label(layer, "РОБОЧА ЗОНА", Vector2(855, 260), Vector2(260, 35), 18)
	_product_info = _label(layer, "CO₂ вийшло: 0 ммоль", Vector2(820, 565), Vector2(410, 35), 20)
	_status = _label(layer, "", Vector2(40, 635), Vector2(1200, 40), 17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(layer, "Навчальне спрощення: повна стехіометрична реакція при 20 °C; без кінетики та зміни об’єму. Відтінки — умовне маркування.", Vector2(40, 685), Vector2(1200, 25), 14)

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _reset() -> void:
	if _catalog.get_reaction_ids().is_empty():
		return
	for vessel: LabVessel in _vessels:
		vessel.queue_free()
	_vessels.clear()
	_spawn("NaHCO₃ · 0,10 моль/л", Vector2(180, 470), Color("e8be74"), Mixture.create(0.2, 0.1, 20.0, {"sodium": 0.01, "bicarbonate": 0.01}))
	_spawn("HCl · 0,10 моль/л", Vector2(420, 470), Color("b39be8"), Mixture.create(0.2, 0.1, 20.0, {"hydrogen": 0.01, "chloride": 0.01}))
	_receiver = _spawn("Приймальна склянка", Vector2(980, 470), Color("82d6b0"), Mixture.create(0.1, 0.0, 20.0, {}))
	_water = _spawn("Вода · нагрівання", Vector2(680, 470), Color("e5a17b"), Mixture.create(0.1, 0.05, 20.0, {}))
	_water.show_temperature = false
	_water.refresh()
	_heater_switch.button_pressed = false
	_power.value = 50
	_probe.position = Vector2(790, 320)
	_probe.dragging = false
	_status.text = "Почни з будь-якого розчину. Кожне відпускання над приймальною склянкою переливає одну порцію."
	_product_info.text = "CO₂ вийшло: 0 ммоль"

func _spawn(title: String, pos: Vector2, color: Color, mixture: MixtureState) -> LabVessel:
	var vessel := Vessel.new()
	vessel.title = title
	vessel.position = pos
	vessel.accent = color
	vessel.mixture = mixture
	vessel.dropped.connect(_on_drop)
	_vessels.append(vessel)
	add_child(vessel)
	return vessel

func _on_drop(vessel: LabVessel) -> void:
	# Wait for Area2D overlap information to catch up with the dragged transform.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(vessel) or not _vessels.has(vessel):
		return
	if vessel == _water:
		_status.text = "Воду можна нагрівати на помаранчевій платформі. Помісти термометр у склянку."
		return
	if vessel == _receiver:
		_status.text = "Приймальна склянка встановлена." if _zone.overlaps_area(vessel) else "Поверни приймальну склянку в робочу зону."
		return
	if not _receiver.overlaps_area(vessel):
		_status.text = "Посуд переміщено. Для переливання піднеси розчин над приймальною склянкою."
		return
	vessel.position = vessel.drag_origin
	if not _zone.overlaps_area(_receiver):
		_status.text = "Спочатку встанови приймальну склянку в робочу зону."
		return
	pour(vessel, _portion.value / 1000.0)

## UI adapter: the domain, not the animation, owns transferred amounts.
func pour(source: LabVessel, volume_l: float) -> StringName:
	var status: StringName = source.mixture.transfer_to(_receiver.mixture, volume_l)
	if status != &"ok":
		_status.text = "Недостатньо розчину в джерелі." if status == &"insufficient_volume" else "Переливання відхилено: перевір об’єм і вільну місткість."
		return status
	_status.text = "Перелито %.0f мл. Додай другий компонент і спостерігай." % (volume_l * 1000.0)
	var result: ReactionCalculation = _engine.apply(_catalog, REACTION_ID, _receiver.mixture, _receiver.mixture.get_revision())
	if result.get_status() not in [&"ok", &"insufficient_reagents"]:
		_status.text = "Переливання виконано; реакцію не застосовано: " + str(result.get_status())
	for vessel: LabVessel in _vessels:
		vessel.refresh()
	return &"ok"

func _on_reaction_applied(mixture: MixtureState, _result: ReactionCalculation) -> void:
	if mixture != _receiver.mixture:
		return
	if "gas_bubbles" in _catalog.reaction_snapshot(REACTION_ID).visual_events:
		_receiver.show_bubbles()
	var released: Dictionary[String, float] = mixture.get_released_products()
	_product_info.text = "CO₂ вийшло: %.3f ммоль" % (float(released.get("carbon_dioxide", 0.0)) * 1000.0)
	_status.text = "Спостерігаємо виділення CO₂. Газ виходить із відкритої склянки."

func _draw() -> void:
	draw_rect(Rect2(0, 235, 1280, 365), Color("172d37"))
	draw_rect(Rect2(35, 485, 1210, 12), Color("6d8991"))
	draw_rect(Rect2(35, 497, 1210, 90), Color("293d49"))
	draw_rect(Rect2(850, 295, 260, 190), Color(0.3, 0.8, 0.65, 0.08))
	draw_rect(Rect2(850, 295, 260, 190), Color("82d6b0"), false, 2)
	draw_rect(Rect2(600, 475, 160, 12), Color("e5a17b"))

func _build_heating_interface() -> void:
	_heater_zone = Area2D.new()
	_heater_zone.position = Vector2(680, 405)
	_heater_zone.collision_layer = 8
	_heater_zone.collision_mask = 1
	_heater_zone.input_pickable = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(150, 160)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	_heater_zone.add_child(collision)
	add_child(_heater_zone)
	_probe = Thermometer.new()
	add_child(_probe)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label(layer, "Нагрівач, %:", Vector2(360, 175), Vector2(175, 40), 20)
	_power = SpinBox.new()
	_power.position = Vector2(535, 170)
	_power.size = Vector2(125, 45)
	_power.min_value = 0
	_power.max_value = 100
	_power.step = 10
	_power.value = 50
	layer.add_child(_power)
	_heater_switch = CheckButton.new()
	_heater_switch.text = "Нагрівання"
	_heater_switch.position = Vector2(705, 170)
	_heater_switch.size = Vector2(245, 45)
	layer.add_child(_heater_switch)
	_heater_info = _label(layer, "", Vector2(40, 565), Vector2(750, 55), 17)
	_heater_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(layer, "НАГРІВАЧ: ЛИШЕ ВОДА", Vector2(545, 270), Vector2(275, 30), 15)

func _physics_process(delta: float) -> void:
	advance_heating(delta)

## Dedicated water exercise: no unsupported temperature-dependent chemistry implied.
func advance_heating(seconds: float) -> void:
	if not is_instance_valid(_water):
		return
	var offset: Vector2 = _water.position - HEATER_SEAT
	var seated: bool = absf(offset.x) <= HEATER_CONTACT_HALF_WIDTH and absf(offset.y) <= HEATER_CONTACT_VERTICAL_TOLERANCE
	var in_contact: bool = _heater_zone.overlaps_area(_water) and seated and not _water.dragging
	var power: float = _power.value / 100.0 if _heater_switch.button_pressed else 0.0
	var status: StringName = _heater.advance(_water.mixture, power, seconds, in_contact)
	if status != &"ok":
		_heater_info.text = "Нагрівання недоступне: " + str(status)
		return
	_water.refresh()
	var measuring: bool = _probe.overlaps_area(_water) and _water.contains_liquid_point(_probe.global_position) and not _probe.dragging and not _water.dragging
	_probe.show_reading(_water.mixture.get_temperature_c() if measuring else null)
	var action: String = "Нагрівання води" if in_contact and power > 0.0 else "Нагрівач вимкнений або немає контакту"
	_heater_info.text = action + ". Термометр перетягни у воду.\nІгрова модель: 4 °C/с при 100 %; охолодження 1 °C/с; межа 60 °C."
