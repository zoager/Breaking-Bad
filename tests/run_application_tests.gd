extends SceneTree
const Catalog = preload("res://scripts/catalog/reaction_catalog.gd")
const Mixture = preload("res://scripts/domain/mixture_state.gd")
const Chemistry = preload("res://scripts/chemistry/reaction_engine.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file("res://data/demo_catalog.json").is_empty(), "demo catalog validates")
	var mixture := Mixture.create(0.1, 0.02, 20.0, {"hydrogen": 0.001, "chloride": 0.001, "bicarbonate": 0.001, "sodium": 0.001})
	var engine := Chemistry.new()
	var events: Dictionary = {"count": 0, "reentrant": &""}
	engine.reaction_applied.connect(func(current: MixtureState, _result: ReactionCalculation) -> void:
		events.count += 1
		events.reentrant = engine.apply(catalog, "bicarbonate_acid", current, 0).get_status()
	)
	check(engine.apply(catalog, "bicarbonate_acid", mixture, 0).get_status() == &"ok", "apply succeeds")
	near(mixture.get_released_products().carbon_dioxide, 0.001, "gas ledger")
	near(mixture.get_formed_solvent().water, 0.001, "water ledger")
	near(mixture.get_amount_mol("hydrogen"), 0, "acid consumed")
	near(mixture.get_amount_mol("bicarbonate"), 0, "bicarbonate consumed")
	near(mixture.get_amount_mol("sodium"), 0.001, "sodium spectator")
	near(mixture.get_volume_l(), 0.02, "model volume unchanged")
	check(mixture.get_revision() == 1 and events.count == 1, "one revision and one signal")
	check(events.reentrant == &"stale_state", "reentrant callback cannot double apply")
	check(engine.apply(catalog, "bicarbonate_acid", mixture, 0).get_status() == &"stale_state", "duplicate command rejected")
	check(engine.apply(catalog, "bicarbonate_acid", mixture, 1).get_status() == &"insufficient_reagents", "fresh revision without fresh reagent cannot repeat")
	check(events.count == 1, "no duplicate effect event")
	var ledger: Dictionary[String, float] = mixture.get_released_products()
	ledger.carbon_dioxide = 99
	near(mixture.get_released_products().carbon_dioxide, 0.001, "ledger copy isolated")
	var acid := Mixture.create(0.1, 0.01, 20.0, {"hydrogen": 0.001, "chloride": 0.001})
	var base := Mixture.create(0.1, 0.01, 20.0, {"bicarbonate": 0.001, "sodium": 0.001})
	check(acid.transfer_to(mixture, 0.01) == &"ok", "fresh acid transfer")
	check(base.transfer_to(mixture, 0.01) == &"ok", "fresh base transfer")
	check(engine.apply(catalog, "bicarbonate_acid", mixture, mixture.get_revision()).get_status() == &"ok", "legitimate later experiment")
	near(mixture.get_released_products().carbon_dioxide, 0.002, "cumulative gas")
	check(events.count == 2, "second genuine event")
	var before: Dictionary[String, float] = mixture.get_components()
	check(engine.apply(catalog, "unknown", mixture, mixture.get_revision()).get_status() == &"unsupported_reaction", "unknown reaction")
	check(mixture.get_components() == before and events.count == 2, "failure leaves state and events intact")
	var receiver := Mixture.create(0.1, 0.0, 20.0, {})
	check(mixture.transfer_to(receiver, 0.01) == &"ok", "post reaction transfer")
	check(receiver.get_released_products().is_empty(), "gas history is not poured as contents")
	near(mixture.get_released_products().carbon_dioxide, 0.002, "gas history retained")
	# Algebraic phase-routing fixture; not an additional gameplay reaction.
	var solid_fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/catalog_valid.json"))
	solid_fixture.species[2].phase = "s"
	check(catalog.load_json(JSON.stringify(solid_fixture)).is_empty(), "phase routing fixture")
	var solid_mixture := Mixture.create(1, 0.1, 20, {"h_plus": 0.01, "oh_minus": 0.01})
	check(engine.apply(catalog, "fixture_neutralization", solid_mixture, 0).get_status() == &"ok", "solid routing")
	near(solid_mixture.get_solids().water, 0.01, "solid retained separately")
	check(solid_mixture.get_components().get("water", 0) == 0, "solid not dissolved")
	for connection: Dictionary in engine.get_signal_connection_list("reaction_applied"):
		engine.disconnect("reaction_applied", connection.callable)
	print("Application tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func near(actual: float, expected: float, description: String) -> void:
	check(is_finite(actual) and absf(actual - expected) <= 1e-12, description)
