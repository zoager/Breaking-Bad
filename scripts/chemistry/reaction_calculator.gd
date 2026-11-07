class_name ReactionCalculator
extends RefCounted
## Pure evaluation of ONE explicitly selected catalog reaction; never mutates inputs.

const Result = preload("res://scripts/chemistry/reaction_calculation.gd")
# Dimensionless relative tolerance for floating rounding and reporting tied limiters.
# This is not a minimum amount of reagent or a chemical threshold.
const RELATIVE_TOLERANCE: float = 1.0e-12

static func calculate(catalog: ReactionCatalog, reaction_id: String, mixture: MixtureState) -> ReactionCalculation:
	if catalog == null or mixture == null:
		return Result.new(&"invalid_input")
	var definition: Dictionary = catalog.reaction_snapshot(reaction_id)
	if definition.is_empty():
		return Result.new(&"unsupported_reaction", {"reaction_id": reaction_id})
	var volume: float = mixture.get_volume_l()
	var temperature: float = mixture.get_temperature_c()
	if not is_finite(volume) or volume < 0.0 or not is_finite(temperature):
		return Result.new(&"invalid_input")
	if volume == 0.0:
		return Result.new(&"empty_mixture")
	var components: Dictionary[String, float] = mixture.get_components()
	for id: String in components:
		var species: Dictionary = catalog.species_snapshot(id)
		if species.is_empty():
			return Result.new(&"unknown_species", {"species_id": id})
		if species.phase != "aq":
			return Result.new(&"unsupported_phase", {"species_id": id})
		if not is_finite(components[id]) or components[id] < 0.0:
			return Result.new(&"invalid_input")
	var interval: Array = definition.conditions.temperature_c
	if temperature < float(interval[0]) or temperature > float(interval[1]):
		return Result.new(&"conditions_not_met", {"condition": "temperature_c"})
	for id: String in definition.conditions.min_concentration_mol_l:
		var concentration: float = mixture.get_amount_mol(id) / volume
		if not is_finite(concentration):
			return Result.new(&"numeric_error")
		if concentration < float(definition.conditions.min_concentration_mol_l[id]):
			return Result.new(&"conditions_not_met", {"condition": "min_concentration_mol_l", "species_id": id})
	var extent: float = INF
	var ratios: Dictionary[String, float] = {}
	for id: String in definition.reactants:
		if catalog.species_snapshot(id).phase != "aq":
			return Result.new(&"unsupported_phase", {"species_id": id})
		var amount: float = mixture.get_amount_mol(id)
		if amount <= 0.0:
			return Result.new(&"insufficient_reagents", {"species_id": id})
		var ratio: float = amount / float(definition.reactants[id])
		if not is_finite(ratio) or ratio <= 0.0:
			return Result.new(&"numeric_error")
		ratios[id] = ratio
		extent = minf(extent, ratio)
	var consumed: Dictionary[String, float] = {}
	var produced: Dictionary[String, float] = {}
	var phases: Dictionary[String, String] = {}
	var remaining: Dictionary[String, float] = components.duplicate()
	var limiting: Array[String] = []
	for id: String in definition.reactants:
		if absf(ratios[id] - extent) <= RELATIVE_TOLERANCE * extent:
			limiting.append(id)
		var amount: float = extent * float(definition.reactants[id])
		var available: float = components[id]
		if not is_finite(amount) or amount <= 0.0:
			return Result.new(&"numeric_error")
		if amount > available:
			if amount - available > RELATIVE_TOLERANCE * available:
				return Result.new(&"numeric_error")
			# Correct only a roundoff overshoot, never consume unavailable material.
			amount = available
		consumed[id] = amount
		remaining[id] = available - amount
	for id: String in definition.products:
		var amount: float = extent * float(definition.products[id])
		if not is_finite(amount) or amount <= 0.0:
			return Result.new(&"numeric_error")
		produced[id] = amount
		phases[id] = catalog.species_snapshot(id).phase
	limiting.sort()
	return Result.new(&"ok", {
		"reaction_id": reaction_id,
		"mixture_revision": mixture.get_revision(),
		"extent_mol": extent,
		"limiting_species": limiting,
		"consumed_mol": consumed,
		"produced_mol": produced,
		"product_phases": phases,
		"remaining_dissolved_mol": remaining,
	})
