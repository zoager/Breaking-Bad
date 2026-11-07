extends SceneTree

const Catalog = preload("res://scripts/catalog/reaction_catalog.gd")
const Mixture = preload("res://scripts/domain/mixture_state.gd")
const Calculator = preload("res://scripts/chemistry/reaction_calculator.gd")
const REACTION_ID: String = "fixture_neutralization"
const TOLERANCE: float = 1.0e-12 # Relative tolerance, not a chemical threshold.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file("res://tests/fixtures/catalog_valid.json").is_empty(), "fixture loaded")
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/catalog_valid.json"))
	input.species.append({"id": "chloride", "name_uk": "Тестовий Cl-", "atoms": {"Cl": 1}, "charge": -1, "phase": "aq"})
	check(catalog.load_json(JSON.stringify(input)).is_empty(), "spectator fixture loaded")
	var mixture := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 0.01, "oh_minus": 0.02, "chloride": 0.01})
	var before: Dictionary[String, float] = mixture.get_components()
	var calculation := Calculator.calculate(catalog, REACTION_ID, mixture)
	check(calculation.get_status() == &"ok", "reaction allowed")
	var result: Dictionary = calculation.snapshot()
	near(result.extent_mol, 0.01, "extent")
	check(result.limiting_species == ["h_plus"], "limiting reagent")
	near(result.consumed_mol.h_plus, 0.01, "acid consumed")
	near(result.consumed_mol.oh_minus, 0.01, "base consumed")
	near(result.produced_mol.water, 0.01, "water produced")
	near(result.remaining_dissolved_mol.oh_minus, 0.01, "excess base remains")
	near(result.remaining_dissolved_mol.chloride, 0.01, "spectator preserved")
	check(result.product_phases.water == "l", "product phase explicit")
	check(mixture.get_components() == before and mixture.get_revision() == 0, "calculation never commits mixture")
	result.produced_mol.water = 99.0
	near(calculation.snapshot().produced_mol.water, 0.01, "result isolated")
	check(Calculator.calculate(catalog, REACTION_ID, mixture).snapshot() == calculation.snapshot(), "repeat evaluation deterministic")
	var equal := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 0.01, "oh_minus": 0.01})
	check(Calculator.calculate(catalog, REACTION_ID, equal).snapshot().limiting_species == ["h_plus", "oh_minus"], "tied reagents sorted")
	check(Calculator.calculate(catalog, "missing", equal).get_status() == &"unsupported_reaction", "unsupported differs from impossible chemistry")
	check(Calculator.calculate(null, REACTION_ID, equal).get_status() == &"invalid_input", "null catalog")
	check(Calculator.calculate(catalog, REACTION_ID, null).get_status() == &"invalid_input", "null mixture")
	var empty := Mixture.create(1.0, 0.0, 20.0, {})
	check(Calculator.calculate(catalog, REACTION_ID, empty).get_status() == &"empty_mixture", "empty mixture")
	for has_zero: bool in [false, true]:
		var amounts: Dictionary[String, float] = {"h_plus": 0.01}
		if has_zero:
			amounts["oh_minus"] = 0.0
		var missing := Mixture.create(1.0, 0.1, 20.0, amounts)
		check(Calculator.calculate(catalog, REACTION_ID, missing).get_status() == &"insufficient_reagents", "missing/zero reagent")
	for temperature: float in [9.0, 31.0]:
		var cold := Mixture.create(1.0, 0.1, temperature, {"h_plus": 0.01, "oh_minus": 0.01})
		check(Calculator.calculate(catalog, REACTION_ID, cold).get_status() == &"conditions_not_met", "temperature condition")
	for temperature: float in [10.0, 30.0]:
		var boundary := Mixture.create(1.0, 0.1, temperature, {"h_plus": 0.01, "oh_minus": 0.01})
		check(Calculator.calculate(catalog, REACTION_ID, boundary).get_status() == &"ok", "inclusive temperature boundary")
	var dilute := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 0.00001, "oh_minus": 0.01})
	check(Calculator.calculate(catalog, REACTION_ID, dilute).get_status() == &"conditions_not_met", "concentration threshold")
	var boundary := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 0.0001, "oh_minus": 0.01})
	check(Calculator.calculate(catalog, REACTION_ID, boundary).get_status() == &"ok", "exact concentration threshold")
	var unknown := Mixture.create(1.0, 0.1, 20.0, {"unknown": 1.0})
	check(Calculator.calculate(catalog, REACTION_ID, unknown).get_status() == &"unknown_species", "unknown mixture component")
	var unsupported := Mixture.create(1.0, 0.1, 20.0, {"water": 0.01})
	check(Calculator.calculate(catalog, REACTION_ID, unsupported).get_status() == &"unsupported_phase", "non aqueous input")
	# Scaling the entire equation must not change consumed/produced amounts.
	input.reactions[0].reactants = {"h_plus": 2, "oh_minus": 2}
	input.reactions[0].products = {"water": 2}
	check(catalog.load_json(JSON.stringify(input)).is_empty(), "scaled balanced equation")
	var scaled: Dictionary = Calculator.calculate(catalog, REACTION_ID, mixture).snapshot()
	near(scaled.extent_mol, 0.005, "scaled extent")
	near(scaled.produced_mol.water, 0.01, "coefficient scaling preserves yield")
	# Remove test-only concentration requirement to test genuinely tiny amounts.
	input.reactions[0].conditions.min_concentration_mol_l = {}
	check(catalog.load_json(JSON.stringify(input)).is_empty(), "tiny amount fixture")
	var tiny := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 1e-20, "oh_minus": 2e-20})
	var tiny_result: Dictionary = Calculator.calculate(catalog, REACTION_ID, tiny).snapshot()
	check(tiny_result.status == &"ok", "no arbitrary minimum moles")
	near(tiny_result.produced_mol.water, 1e-20, "tiny yield")
	# Verify elemental and charge conservation for excess and scaled coefficients.
	for element: String in ["H", "O", "Cl", "charge"]:
		near(total(catalog, before, element), total(catalog, scaled.remaining_dissolved_mol, element) + total(catalog, scaled.produced_mol, element), "conservation: " + element)
	var huge := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 1.7e308, "oh_minus": 1.7e308})
	input.reactions[0].conditions.min_concentration_mol_l = {"h_plus": 0.001}
	check(catalog.load_json(JSON.stringify(input)).is_empty(), "finite concentration fixture")
	check(Calculator.calculate(catalog, REACTION_ID, huge).get_status() == &"numeric_error", "overflowing concentration rejected")
	# A 2:1 fixture distinguishes reagent amounts from stoichiometric ratios.
	input.species.append({"id": "carbonate", "name_uk": "Тестовий CO3", "atoms": {"C": 1, "O": 3}, "charge": -2, "phase": "aq"})
	input.species.append({"id": "co2", "name_uk": "Тестовий CO2", "atoms": {"C": 1, "O": 2}, "charge": 0, "phase": "g"})
	input.reactions[0].reactants = {"h_plus": 2, "carbonate": 1}
	input.reactions[0].products = {"water": 1, "co2": 1}
	input.reactions[0].conditions.min_concentration_mol_l = {}
	check(catalog.load_json(JSON.stringify(input)).is_empty(), "2:1 balanced fixture")
	var acid_limited := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 0.015, "carbonate": 0.01})
	var gas_result: Dictionary = Calculator.calculate(catalog, REACTION_ID, acid_limited).snapshot()
	check(gas_result.status == &"ok" and gas_result.limiting_species == ["h_plus"], "2:1 acid limited despite greater amount")
	near(gas_result.extent_mol, 0.0075, "2:1 extent")
	near(gas_result.consumed_mol.h_plus, 0.015, "2:1 acid consumption")
	near(gas_result.produced_mol.co2, 0.0075, "gas yield")
	near(gas_result.remaining_dissolved_mol.carbonate, 0.0025, "carbonate excess")
	check(gas_result.product_phases.co2 == "g", "gas phase retained")
	var carbonate_limited := Mixture.create(1.0, 0.1, 20.0, {"h_plus": 0.03, "carbonate": 0.01})
	var other_result: Dictionary = Calculator.calculate(catalog, REACTION_ID, carbonate_limited).snapshot()
	check(other_result.limiting_species == ["carbonate"], "2:1 carbonate limited")
	near(other_result.remaining_dissolved_mol.h_plus, 0.01, "2:1 acid excess")
	for element: String in ["H", "O", "C", "charge"]:
		var actual: float = total(catalog, gas_result.remaining_dissolved_mol, element) + total(catalog, gas_result.produced_mol, element)
		# Absolute roundoff check for a zero total net charge is intentional.
		check(absf(actual - total(catalog, acid_limited.get_components(), element)) < 1e-12, "2:1 conservation: " + element)
	print("Reaction tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func total(catalog: ReactionCatalog, amounts: Dictionary, element: String) -> float:
	var sum: float = 0.0
	for id: String in amounts:
		var species: Dictionary = catalog.species_snapshot(id)
		var count: float = float(species.charge) if element == "charge" else float(species.atoms.get(element, 0))
		sum += float(amounts[id]) * count
	return sum

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func near(actual: float, expected: float, description: String) -> void:
	check(is_finite(actual) and absf(actual - expected) <= TOLERANCE * maxf(absf(expected), 1e-300), description)
