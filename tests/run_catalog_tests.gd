extends SceneTree

const Catalog = preload("res://scripts/catalog/reaction_catalog.gd")
const FIXTURE: String = "res://tests/fixtures/catalog_valid.json"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	var catalog := Catalog.new()
	check(catalog.load_file(FIXTURE).is_empty(), "valid file loads")
	check(catalog.get_reaction_ids() == ["fixture_neutralization"], "reaction indexed")
	check(catalog.species_snapshot("h_plus").charge == 1, "typed species converted")
	var snapshot: Dictionary = catalog.species_snapshot("water")
	snapshot.atoms.H = 77
	check(catalog.species_snapshot("water").atoms.H == 2, "species snapshot isolated")
	var reaction: Dictionary = catalog.reaction_snapshot("fixture_neutralization")
	reaction.conditions.temperature_c[0] = 1000
	check(catalog.reaction_snapshot("fixture_neutralization").conditions.temperature_c[0] == 10, "reaction snapshot deeply isolated")
	check(catalog.species_snapshot("unknown").is_empty(), "missing id explicit")
	check(not catalog.load_file("res://tests/fixtures/does_not_exist.json").is_empty(), "missing file rejected")
	for text: String in ["{", "null", "[]", "true", "{}"]:
		reject(catalog, text, "malformed or incomplete root")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	var changed: Dictionary = fixture.duplicate(true)
	changed.schema_version = 2
	reject(catalog, JSON.stringify(changed), "unsupported schema")
	changed = fixture.duplicate(true)
	changed.units.volume = "mL"
	reject(catalog, JSON.stringify(changed), "wrong canonical unit")
	changed = fixture.duplicate(true)
	changed.species.append(changed.species[0].duplicate(true))
	reject(catalog, JSON.stringify(changed), "duplicate species id")
	changed = fixture.duplicate(true)
	changed.reactions.append(changed.reactions[0].duplicate(true))
	reject(catalog, JSON.stringify(changed), "duplicate reaction id")
	for bad_atoms: Variant in [{}, {"Xx": 1}, {"H": 0}, {"H": 1.5}, {"H": true}, {"H": "1"}, {"H": 10001}, []]:
		changed = fixture.duplicate(true)
		changed.species[0].atoms = bad_atoms
		reject(catalog, JSON.stringify(changed), "bad atomic composition")
	for charge: Variant in [true, "1", 0.5, 10001]:
		changed = fixture.duplicate(true)
		changed.species[0].charge = charge
		reject(catalog, JSON.stringify(changed), "bad charge")
	changed = fixture.duplicate(true)
	changed.species[0].phase = "plasma"
	reject(catalog, JSON.stringify(changed), "unknown phase")
	for coefficient: Variant in [0, -1, 0.5, true, "1", 10001]:
		changed = fixture.duplicate(true)
		changed.reactions[0].reactants.h_plus = coefficient
		reject(catalog, JSON.stringify(changed), "invalid coefficient")
	changed = fixture.duplicate(true)
	changed.reactions[0].reactants.unknown = 1
	reject(catalog, JSON.stringify(changed), "dangling reactant reference")
	changed = fixture.duplicate(true)
	changed.reactions[0].products.water = 2
	reject(catalog, JSON.stringify(changed), "atom imbalance")
	changed = fixture.duplicate(true)
	changed.species[0].charge = 0
	reject(catalog, JSON.stringify(changed), "charge imbalance with balanced atoms")
	changed = fixture.duplicate(true)
	changed.reactions[0].products.h_plus = 1
	reject(catalog, JSON.stringify(changed), "implicit catalyst rejected")
	for field: String in ["reactants", "products", "sources", "conditions", "simplifications"]:
		changed = fixture.duplicate(true)
		changed.reactions[0].erase(field)
		reject(catalog, JSON.stringify(changed), "missing required reaction field")
	changed = fixture.duplicate(true)
	changed.reactions[0].conditions.temperature_c = [40, 20]
	reject(catalog, JSON.stringify(changed), "reversed temperature interval")
	changed = fixture.duplicate(true)
	changed.reactions[0].conditions.temperature_c = [true, 20]
	reject(catalog, JSON.stringify(changed), "boolean temperature")
	changed = fixture.duplicate(true)
	changed.reactions[0].conditions.temperature_c = [10]
	reject(catalog, JSON.stringify(changed), "incomplete interval")
	for limits: Variant in [{"unknown": 0.1}, {"water": 0.1}, {"h_plus": -1}, {"h_plus": true}, []]:
		changed = fixture.duplicate(true)
		changed.reactions[0].conditions.min_concentration_mol_l = limits
		reject(catalog, JSON.stringify(changed), "invalid concentration constraint")
	changed = fixture.duplicate(true)
	changed.reactions[0].conditions.catalyst = "unknown"
	reject(catalog, JSON.stringify(changed), "unsupported condition not silently ignored")
	changed = fixture.duplicate(true)
	changed.reactions[0].visual_events = ["explosion"]
	reject(catalog, JSON.stringify(changed), "unimplemented dangerous effect rejected")
	changed = fixture.duplicate(true)
	changed.reactions[0].sources = []
	reject(catalog, JSON.stringify(changed), "source required")
	changed = fixture.duplicate(true)
	changed.reactions[0].simplifications = []
	reject(catalog, JSON.stringify(changed), "simplification required")
	var errors: PackedStringArray = catalog.load_json(JSON.stringify(changed), "bad_fixture.json")
	check(not errors.is_empty() and errors[0].contains("bad_fixture.json.reactions[0]"), "diagnostic identifies file and entry")
	var nonfinite: String = FileAccess.get_file_as_string(FIXTURE).replace('"h_plus": 0.001', '"h_plus": 1e999')
	reject(catalog, nonfinite, "nonfinite concentration")
	# A valid reload replaces, rather than appends to, the previous catalog.
	changed = fixture.duplicate(true)
	changed.reactions[0].id = "replacement"
	check(catalog.load_json(JSON.stringify(changed)).is_empty(), "valid reload succeeds")
	check(catalog.get_reaction_ids() == ["replacement"], "old entries removed on valid reload")
	print("Catalog tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func reject(catalog: ReactionCatalog, text: String, description: String) -> void:
	check(not catalog.load_json(text).is_empty(), description)
	check(catalog.get_reaction_ids() == ["fixture_neutralization"], "failed reload preserves catalog: " + description)

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
