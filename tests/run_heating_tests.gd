extends SceneTree
const Heater = preload("res://scripts/equipment/heater_model.gd")
const Mixture = preload("res://scripts/domain/mixture_state.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var heater := Heater.new()
	var water := Mixture.create(0.1, 0.05, 20.0, {})
	check(heater.advance(water, 0.5, 5.0, true) == &"ok", "heat accepted")
	near(water.get_temperature_c(), 30, "half power: 2C per second")
	check(water.get_revision() == 1, "temperature invalidates state revision")
	check(water.set_temperature_c(40, 0) == &"stale_state", "stale temperature command")
	check(water.set_temperature_c(INF, 1) == &"invalid_temperature", "infinite temperature rejected")
	check(water.set_temperature_c(NAN, 1) == &"invalid_temperature", "NaN temperature rejected")
	near(water.get_temperature_c(), 30, "invalid temperature keeps state")
	var revision: int = water.get_revision()
	for power: float in [-0.1, 1.1, INF, NAN]:
		check(heater.advance(water, power, 1, true) == &"invalid_power", "invalid power")
	for seconds: float in [-1, 0, INF, NAN]:
		check(heater.advance(water, 1, seconds, true) == &"invalid_input", "invalid duration")
	check(water.get_revision() == revision, "invalid heating never changes revision")
	check(heater.advance(null, 1, 1, true) == &"invalid_input", "null mixture")
	var empty := Mixture.create(0.1, 0, 20, {})
	check(heater.advance(empty, 1, 1, true) == &"empty_vessel", "empty vessel")
	check(empty.get_revision() == 0, "empty vessel unmodified")
	heater.advance(water, 1, 1, false)
	near(water.get_temperature_c(), 29, "no contact cools instead of heating")
	heater.advance(water, 0, 2, true)
	near(water.get_temperature_c(), 27, "off cools")
	heater.advance(water, 0, 1e308, false)
	near(water.get_temperature_c(), 20, "cooling clamped at ambient")
	revision = water.get_revision()
	heater.advance(water, 0, 1, false)
	check(water.get_revision() == revision, "equilibrium is not a mutation")
	heater.advance(water, 1, 1e308, true)
	near(water.get_temperature_c(), 60, "large finite duration capped safely")
	revision = water.get_revision()
	heater.advance(water, 1, 1, true)
	check(water.get_revision() == revision, "cap is not repeated mutation")
	var cold := Mixture.create(0.1, 0.05, 19, {})
	check(heater.advance(cold, 1, 1, true) == &"unsupported_temperature", "outside demonstration range")
	var bulk := Mixture.create(0.1, 0.05, 20, {})
	var stepped := Mixture.create(0.1, 0.05, 20, {})
	heater.advance(bulk, 0.5, 5, true)
	for index: int in range(50):
		heater.advance(stepped, 0.5, 0.1, true)
	near(stepped.get_temperature_c(), bulk.get_temperature_c(), "frame independent heating")
	var solution := Mixture.create(0.1, 0.05, 20, {"sodium": 0.001})
	var components: Dictionary[String, float] = solution.get_components()
	heater.advance(solution, 1, 2, true)
	check(solution.get_components() == components, "heat never consumes components")
	near(solution.get_volume_l(), 0.05, "heat never evaporates volume in supported model")
	print("Heating tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func near(actual: float, expected: float, description: String) -> void:
	check(is_finite(actual) and absf(actual - expected) <= 1e-10, description)
