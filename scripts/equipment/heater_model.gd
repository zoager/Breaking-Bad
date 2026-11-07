class_name HeaterModel
extends RefCounted
## Deliberately pedagogical rates, NOT substance properties or heater wattage.
const AMBIENT_C: float = 20.0
const MAXIMUM_C: float = 60.0 # Supported demonstration range, not a boiling point.
const HEATING_C_PER_SECOND: float = 4.0
const COOLING_C_PER_SECOND: float = 1.0

func advance(mixture: MixtureState, power: float, seconds: float, in_contact: bool) -> StringName:
	if mixture == null or not is_finite(seconds) or seconds <= 0.0:
		return &"invalid_input"
	if not is_finite(power) or power < 0.0 or power > 1.0:
		return &"invalid_power"
	if mixture.get_volume_l() <= 0.0:
		return &"empty_vessel"
	var current: float = mixture.get_temperature_c()
	if not is_finite(current) or current < AMBIENT_C or current > MAXIMUM_C:
		return &"unsupported_temperature"
	var target: float
	if in_contact and power > 0.0:
		var rate: float = HEATING_C_PER_SECOND * power
		# Bound time before multiplication, so even very large finite delta is safe.
		var applied_time: float = minf(seconds, (MAXIMUM_C - current) / rate)
		target = minf(MAXIMUM_C, current + rate * applied_time)
	else:
		var applied_time: float = minf(seconds, (current - AMBIENT_C) / COOLING_C_PER_SECOND)
		target = maxf(AMBIENT_C, current - COOLING_C_PER_SECOND * applied_time)
	return mixture.set_temperature_c(target, mixture.get_revision())
