class_name ReactionEngine
extends RefCounted

signal reaction_applied(mixture: MixtureState, result: ReactionCalculation)
const Calculator = preload("res://scripts/chemistry/reaction_calculator.gd")
const Result = preload("res://scripts/chemistry/reaction_calculation.gd")

## Accept a command, never an externally mutable/fabricated calculation result.
## Re-evaluate against current catalog and mixture, then commit once before notifying.
func apply(catalog: ReactionCatalog, reaction_id: String, mixture: MixtureState,
		expected_revision: int) -> ReactionCalculation:
	if mixture == null:
		return Result.new(&"invalid_input")
	if expected_revision != mixture.get_revision():
		return Result.new(&"stale_state")
	var result: ReactionCalculation = Calculator.calculate(catalog, reaction_id, mixture)
	if result.get_status() != &"ok":
		return result
	var data: Dictionary = result.snapshot()
	var dissolved: Dictionary[String, float] = {}
	dissolved.assign(data.remaining_dissolved_mol)
	var solids: Dictionary[String, float] = mixture.get_solids()
	var released: Dictionary[String, float] = mixture.get_released_products()
	var solvent: Dictionary[String, float] = mixture.get_formed_solvent()
	for id: String in data.produced_mol:
		var phase: String = data.product_phases[id]
		var destination: Dictionary[String, float]
		match phase:
			"aq": destination = dissolved
			"s": destination = solids
			"g": destination = released
			"l":
				# Only water is supported as a liquid solvent product in this version.
				var species: Dictionary = catalog.species_snapshot(id)
				if species.atoms != {"H": 2, "O": 1} or species.charge != 0:
					return Result.new(&"unsupported_phase")
				destination = solvent
			_: return Result.new(&"unsupported_phase")
		var combined: float = float(destination.get(id, 0.0)) + float(data.produced_mol[id])
		if not is_finite(combined):
			return Result.new(&"numeric_error")
		destination[id] = combined
	var status: StringName = mixture._commit_reaction(expected_revision, dissolved, solids, released, solvent)
	if status != &"ok":
		return Result.new(status)
	reaction_applied.emit(mixture, result)
	return result
