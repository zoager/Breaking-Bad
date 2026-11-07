class_name MixtureState
extends RefCounted
## Owns dissolved contents, retained solids and cumulative product ledgers.
## Underscored state is owned here; callers use copies and validated operations.

var _volume_l: float = 0.0
var _capacity_l: float = 0.0
var _temperature_c: float = 0.0
var _moles: Dictionary[String, float] = {}
var _revision: int = 0
var _solids: Dictionary[String, float] = {}
var _released: Dictionary[String, float] = {}
var _formed_solvent: Dictionary[String, float] = {}

static func create(capacity_l: float, volume_l: float, temperature_c: float,
		components: Dictionary[String, float]) -> MixtureState:
	if not is_finite(capacity_l) or capacity_l <= 0.0:
		return null
	if not is_finite(volume_l) or volume_l < 0.0 or volume_l > capacity_l:
		return null
	if not is_finite(temperature_c):
		return null
	for species_id: String in components:
		var amount: float = components[species_id]
		if species_id.is_empty() or not is_finite(amount) or amount < 0.0:
			return null
		if volume_l == 0.0 and amount > 0.0:
			return null
	var mixture := MixtureState.new()
	mixture._capacity_l = capacity_l
	mixture._volume_l = volume_l
	mixture._temperature_c = temperature_c
	mixture._moles = components.duplicate()
	return mixture

func get_volume_l() -> float:
	return _volume_l

func get_capacity_l() -> float:
	return _capacity_l

func get_temperature_c() -> float:
	return _temperature_c

func get_revision() -> int:
	return _revision

func get_components() -> Dictionary[String, float]:
	return _moles.duplicate()

func get_amount_mol(species_id: String) -> float:
	return _moles.get(species_id, 0.0)

## Null means undefined concentration in an empty vessel, not zero molarity.
func get_concentration_mol_l(species_id: String) -> Variant:
	if _volume_l == 0.0:
		return null
	return get_amount_mol(species_id) / _volume_l

## Returns an explicit rejection code; a rejected operation changes neither vessel.
func transfer_to(target: MixtureState, volume_l: float) -> StringName:
	if target == null or target == self:
		return &"invalid_target"
	if not is_finite(volume_l) or volume_l <= 0.0:
		return &"invalid_volume"
	if volume_l > _volume_l:
		return &"insufficient_volume"
	var new_target_volume: float = target._volume_l + volume_l
	if not is_finite(new_target_volume) or new_target_volume > target._capacity_l:
		return &"capacity_exceeded"
	var fraction: float = volume_l / _volume_l
	var source_components: Dictionary[String, float] = _moles.duplicate()
	var target_components: Dictionary[String, float] = target._moles.duplicate()
	for species_id: String in _moles:
		var moved: float = _moles[species_id] * fraction
		var remaining: float = _moles[species_id] - moved
		var combined: float = target.get_amount_mol(species_id) + moved
		if not is_finite(combined) or remaining < 0.0:
			return &"invalid_result"
		source_components[species_id] = remaining
		target_components[species_id] = combined
	# Equal density and specific heat, additive volumes, no heat losses/reaction heat.
	# Weighted terms avoid overflowing an intermediate temperature * volume product.
	var temperature: float = _temperature_c
	if target._volume_l > 0.0:
		var weight: float = volume_l / new_target_volume
		temperature = target._temperature_c * (1.0 - weight) + _temperature_c * weight
	if not is_finite(temperature):
		return &"invalid_result"
	# Commit only after all validation; no signals/callbacks inside the transaction.
	_moles = source_components
	_volume_l -= volume_l
	_revision += 1
	target._moles = target_components
	target._volume_l = new_target_volume
	target._temperature_c = temperature
	target._revision += 1
	return &"ok"

func get_solids() -> Dictionary[String, float]:
	return _solids.duplicate()

func get_released_products() -> Dictionary[String, float]:
	return _released.duplicate()

func get_formed_solvent() -> Dictionary[String, float]:
	return _formed_solvent.duplicate()

## Internal transaction boundary used by ReactionEngine; callers must not edit fields.
func _commit_reaction(expected_revision: int, dissolved: Dictionary[String, float],
		solids: Dictionary[String, float], released: Dictionary[String, float],
		formed_solvent: Dictionary[String, float]) -> StringName:
	if expected_revision != _revision:
		return &"stale_state"
	for amounts: Dictionary in [dissolved, solids, released, formed_solvent]:
		for id: String in amounts:
			if id.is_empty() or not is_finite(amounts[id]) or amounts[id] < 0.0:
				return &"numeric_error"
	_moles = dissolved.duplicate()
	_solids = solids.duplicate()
	_released = released.duplicate()
	_formed_solvent = formed_solvent.duplicate()
	_revision += 1
	return &"ok"

## Temperature operations also invalidate pending reaction commands.
func set_temperature_c(temperature_c: float, expected_revision: int) -> StringName:
	if expected_revision != _revision:
		return &"stale_state"
	if not is_finite(temperature_c):
		return &"invalid_temperature"
	if temperature_c != _temperature_c:
		_temperature_c = temperature_c
		_revision += 1
	return &"ok"
