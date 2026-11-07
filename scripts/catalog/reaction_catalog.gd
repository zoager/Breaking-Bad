class_name ReactionCatalog
extends RefCounted
## Validation is structural and algebraic, NOT scientific verification of a source.

const Species = preload("res://scripts/catalog/catalog_species.gd")
const Reaction = preload("res://scripts/catalog/catalog_reaction.gd")
const SCHEMA_VERSION: int = 1
# Defensive input limits; not physical constants. Keep integer balance sums bounded.
const MAX_ENTRIES: int = 4096
const MAX_COUNT: int = 10000
const ELEMENTS: PackedStringArray = ["H", "He", "Li", "Be", "B", "C", "N", "O", "F", "Ne", "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar", "K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr", "Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I", "Xe", "Cs", "Ba", "La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn", "Fr", "Ra", "Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", "Nh", "Fl", "Mc", "Lv", "Ts", "Og"]

var _species: Dictionary[String, CatalogSpecies] = {}
var _reactions: Dictionary[String, CatalogReaction] = {}

func species_snapshot(id: String) -> Dictionary:
	return _species[id].snapshot() if _species.has(id) else {}

func reaction_snapshot(id: String) -> Dictionary:
	return _reactions[id].snapshot() if _reactions.has(id) else {}

func get_reaction_ids() -> Array[String]:
	return _reactions.keys()

func load_file(path: String) -> PackedStringArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray(["%s: cannot open file (error %d)" % [path, FileAccess.get_open_error()]])
	return load_json(file.get_as_text(), path)

## Failed reloads retain the previous valid catalog. No partially accepted entries.
func load_json(text: String, origin: String = "catalog") -> PackedStringArray:
	var json := JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return PackedStringArray(["%s:%d: %s" % [origin, json.get_error_line(), json.get_error_message()]])
	var errors: PackedStringArray = []
	if not _fields(json.data, ["schema_version", "units", "species", "reactions"], origin, errors):
		return errors
	var root: Dictionary = json.data
	if not _integer(root.schema_version, 1, 1):
		errors.append(origin + ".schema_version: unsupported version")
	if root.units != {"amount": "mol", "volume": "L", "temperature": "C"}:
		errors.append(origin + ".units: expected mol, L, C")
	if not _entries(root.species) or not _entries(root.reactions):
		errors.append(origin + ": species and reactions must be nonempty bounded arrays")
	if not errors.is_empty():
		return errors
	var new_species: Dictionary[String, CatalogSpecies] = {}
	for index: int in range(root.species.size()):
		_validate_species(root.species[index], "%s.species[%d]" % [origin, index], new_species, errors)
	# References and balances need a completely valid species table.
	if not errors.is_empty():
		return errors
	var new_reactions: Dictionary[String, CatalogReaction] = {}
	for index: int in range(root.reactions.size()):
		_validate_reaction(root.reactions[index], "%s.reactions[%d]" % [origin, index], new_species, new_reactions, errors)
	if errors.is_empty():
		_species = new_species
		_reactions = new_reactions
	return errors

static func _fields(value: Variant, required: Array[String], path: String, errors: PackedStringArray) -> bool:
	if not value is Dictionary:
		errors.append(path + ": expected object")
		return false
	var valid: bool = true
	for field: String in required:
		if not value.has(field):
			errors.append(path + "." + field + ": required")
			valid = false
	for field: Variant in value:
		if not field is String or not required.has(field):
			errors.append(path + ": unknown field " + str(field))
			valid = false
	return valid

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	# JSON numbers arrive as floats; bools and numeric strings must not pass.
	if not (value is float or value is int):
		return false
	return is_finite(float(value)) and value >= minimum and value <= maximum and floor(float(value)) == value

static func _entries(value: Variant) -> bool:
	return value is Array and not value.is_empty() and value.size() <= MAX_ENTRIES

static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _strings(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not _text(entry):
			return false
	return true

static func _validate_species(value: Variant, path: String, entries: Dictionary[String, CatalogSpecies], errors: PackedStringArray) -> void:
	if not _fields(value, ["id", "name_uk", "atoms", "charge", "phase"], path, errors):
		return
	if not _text(value.id) or not _text(value.name_uk):
		errors.append(path + ": id and name_uk must be nonempty strings")
		return
	if entries.has(value.id):
		errors.append(path + ".id: duplicate " + value.id)
		return
	if not _integer(value.charge, -MAX_COUNT, MAX_COUNT) or not value.phase in ["aq", "s", "l", "g"]:
		errors.append(path + ": invalid charge or phase")
		return
	if not value.atoms is Dictionary or value.atoms.is_empty() or value.atoms.size() > ELEMENTS.size():
		errors.append(path + ".atoms: expected nonempty element counts")
		return
	var atoms: Dictionary[String, int] = {}
	for element: Variant in value.atoms:
		if not element in ELEMENTS or not _integer(value.atoms[element], 1, MAX_COUNT):
			errors.append(path + ".atoms: invalid element/count " + str(element))
			return
		atoms[element] = int(value.atoms[element])
	entries[value.id] = Species.new(value.id, value.name_uk, atoms, int(value.charge), value.phase)

static func _side(value: Variant, path: String, species: Dictionary[String, CatalogSpecies], errors: PackedStringArray) -> bool:
	if not value is Dictionary or value.is_empty() or value.size() > MAX_ENTRIES:
		errors.append(path + ": expected nonempty stoichiometry object")
		return false
	var valid: bool = true
	for id: Variant in value:
		if not id is String or not species.has(id):
			errors.append(path + ": unknown species " + str(id))
			valid = false
		elif not _integer(value[id], 1, MAX_COUNT):
			errors.append(path + "." + id + ": coefficient must be a positive bounded integer")
			valid = false
	return valid

static func _balance(side: Dictionary, species: Dictionary[String, CatalogSpecies]) -> Dictionary:
	var result: Dictionary = {"charge": 0}
	for id: String in side:
		var definition: Dictionary = species[id].snapshot()
		var coefficient: int = int(side[id])
		result.charge += int(definition.charge) * coefficient
		for element: String in definition.atoms:
			result[element] = int(result.get(element, 0)) + int(definition.atoms[element]) * coefficient
	return result

static func _conditions(value: Variant, path: String, species: Dictionary[String, CatalogSpecies], errors: PackedStringArray) -> void:
	if not _fields(value, ["temperature_c", "min_concentration_mol_l"], path, errors):
		return
	if not value.temperature_c is Array or value.temperature_c.size() != 2:
		errors.append(path + ".temperature_c: expected [min, max]")
		return
	for temperature: Variant in value.temperature_c:
		if not (temperature is float or temperature is int) or not is_finite(float(temperature)):
			errors.append(path + ".temperature_c: finite numbers required")
			return
	if value.temperature_c[0] > value.temperature_c[1]:
		errors.append(path + ".temperature_c: reversed interval")
	if not value.min_concentration_mol_l is Dictionary:
		errors.append(path + ".min_concentration_mol_l: expected object")
		return
	for id: Variant in value.min_concentration_mol_l:
		var minimum: Variant = value.min_concentration_mol_l[id]
		if not species.has(id) or species[id].snapshot().phase != "aq":
			errors.append(path + ".min_concentration_mol_l: unknown or nonaqueous species " + str(id))
		elif not (minimum is float or minimum is int) or not is_finite(float(minimum)) or minimum < 0.0:
			errors.append(path + ".min_concentration_mol_l: invalid minimum for " + str(id))

static func _validate_reaction(value: Variant, path: String, species: Dictionary[String, CatalogSpecies], entries: Dictionary[String, CatalogReaction], errors: PackedStringArray) -> void:
	if not _fields(value, ["id", "reactants", "products", "sources", "simplifications", "conditions", "visual_events"], path, errors):
		return
	var error_count: int = errors.size()
	if not _text(value.id):
		errors.append(path + ".id: nonempty string required")
		return
	if entries.has(value.id):
		errors.append(path + ".id: duplicate " + value.id)
	if not _strings(value.sources) or value.sources.is_empty():
		errors.append(path + ".sources: nonempty source list required")
	if not _strings(value.simplifications) or value.simplifications.is_empty():
		errors.append(path + ".simplifications: explicit model limitations required")
	if not _strings(value.visual_events):
		errors.append(path + ".visual_events: expected string list")
	else:
		for event: String in value.visual_events:
			if not event in ["gas_bubbles", "precipitate"]:
				errors.append(path + ".visual_events: unsupported event " + event)
	_conditions(value.conditions, path + ".conditions", species, errors)
	var valid_left: bool = _side(value.reactants, path + ".reactants", species, errors)
	var valid_right: bool = _side(value.products, path + ".products", species, errors)
	if valid_left and valid_right:
		for id: String in value.reactants:
			if value.products.has(id):
				errors.append(path + ": unchanged species/catalysts require a future explicit model")
		var left: Dictionary = _balance(value.reactants, species)
		var right: Dictionary = _balance(value.products, species)
		if left != right:
			errors.append(path + ": atom or charge balance mismatch")
	if errors.size() == error_count:
		entries[value.id] = Reaction.new(value)
