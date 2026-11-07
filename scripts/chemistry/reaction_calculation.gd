class_name ReactionCalculation
extends RefCounted
## Read-only by convention; public access returns deep copies.

var _status: StringName
var _details: Dictionary

func _init(status: StringName, details: Dictionary = {}) -> void:
	_status = status
	_details = details.duplicate(true)

func get_status() -> StringName:
	return _status

func snapshot() -> Dictionary:
	var result: Dictionary = _details.duplicate(true)
	result["status"] = _status
	return result
