class_name CatalogReaction
extends RefCounted

var _definition: Dictionary

## Construct only from a completely validated catalog definition.
func _init(definition: Dictionary) -> void:
	_definition = definition.duplicate(true)

func snapshot() -> Dictionary:
	return _definition.duplicate(true)
