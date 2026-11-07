class_name CatalogSpecies
extends RefCounted

var _id: String
var _name_uk: String
var _atoms: Dictionary[String, int] = {}
var _charge: int
var _phase: String

func _init(id: String, name_uk: String, atoms: Dictionary[String, int], charge: int, phase: String) -> void:
	_id = id
	_name_uk = name_uk
	_atoms = atoms.duplicate()
	_charge = charge
	_phase = phase

func snapshot() -> Dictionary:
	return {"id": _id, "name_uk": _name_uk, "atoms": _atoms.duplicate(), "charge": _charge, "phase": _phase}
