extends SceneTree

const Mixture = preload("res://scripts/domain/mixture_state.gd")
const NUMERIC_TOLERANCE: float = 1.0e-12 # Absolute tolerance for small test fixtures.
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var source := make_mixture(1.0, 0.1, 20.0, {"sodium": 0.01, "chloride": 0.01})
	var target := make_mixture(1.0, 0.1, 40.0, {"other": 0.02})
	check(source.transfer_to(target, 0.05) == &"ok", "valid transfer")
	near(source.get_volume_l() + target.get_volume_l(), 0.2, "volume conservation")
	for species_id: String in ["sodium", "chloride"]:
		near(source.get_amount_mol(species_id) + target.get_amount_mol(species_id), 0.01, "component conservation")
	near(target.get_amount_mol("other"), 0.02, "existing component preserved")
	near(float(target.get_concentration_mol_l("sodium")), 0.005 / 0.15, "dilution")
	near(target.get_temperature_c(), 100.0 / 3.0, "weighted temperature")
	check(source.get_revision() == 1 and target.get_revision() == 1, "versions advance")
	var snapshot: Dictionary[String, float] = source.get_components()
	snapshot["sodium"] = 99.0
	near(source.get_amount_mol("sodium"), 0.005, "snapshot is not mutable state")
	var source_before: Dictionary[String, float] = source.get_components()
	var target_before: Dictionary[String, float] = target.get_components()
	check(source.transfer_to(target, 0.2) == &"insufficient_volume", "insufficient source rejected")
	check(source.transfer_to(source, 0.01) == &"invalid_target", "self transfer rejected")
	check(source.transfer_to(null, 0.01) == &"invalid_target", "null target rejected")
	for invalid_volume: float in [-0.1, 0.0, INF, NAN]:
		check(source.transfer_to(target, invalid_volume) == &"invalid_volume", "invalid transfer rejected")
	check(source.get_components() == source_before and target.get_components() == target_before, "failed transfers preserve components")
	check(source.get_revision() == 1 and target.get_revision() == 1, "failed transfers preserve versions")
	var full := make_mixture(0.1, 0.1, 20.0, {})
	check(source.transfer_to(full, 0.01) == &"capacity_exceeded", "overflow rejected")
	near(full.get_volume_l(), 0.1, "overflow preserves target")
	near(source.get_volume_l(), 0.05, "overflow preserves source")
	var empty := make_mixture(0.05, 0.0, 99.0, {})
	check(empty.get_concentration_mol_l("sodium") == null, "empty concentration undefined")
	check(source.transfer_to(empty, source.get_volume_l()) == &"ok", "full drain and exact capacity")
	near(source.get_amount_mol("sodium"), 0.0, "full drain leaves no component")
	near(empty.get_temperature_c(), 20.0, "empty vessel temperature does not affect liquid")
	check(source.transfer_to(empty, 0.01) == &"insufficient_volume", "empty source rejected")
	check(Mixture.create(1.0, 0.0, 20.0, {"x": 1.0}) == null, "solute without volume rejected")
	check(Mixture.create(1.0, 0.1, 20.0, {"x": -1.0}) == null, "negative amount rejected")
	check(Mixture.create(1.0, 0.1, 20.0, {"x": NAN}) == null, "nonfinite amount rejected")
	check(Mixture.create(1.0, 2.0, 20.0, {}) == null, "initial overflow rejected")
	check(Mixture.create(0.0, 0.0, 20.0, {}) == null, "zero capacity rejected")
	check(Mixture.create(1.0, 0.1, INF, {}) == null, "nonfinite temperature rejected")
	var extreme_source := make_mixture(1.0, 0.1, 20.0, {"x": 1.7e308})
	var extreme_target := make_mixture(1.0, 0.1, 20.0, {"x": 1.7e308})
	check(extreme_source.transfer_to(extreme_target, 0.1) == &"invalid_result", "numeric overflow rejected")
	near(extreme_source.get_volume_l(), 0.1, "overflow transaction atomic")
	print("Mixture tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func make_mixture(capacity: float, volume: float, temperature: float,
		components: Dictionary[String, float]) -> MixtureState:
	return Mixture.create(capacity, volume, temperature, components)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func near(actual: float, expected: float, description: String) -> void:
	check(is_finite(actual) and absf(actual - expected) <= NUMERIC_TOLERANCE, description)
