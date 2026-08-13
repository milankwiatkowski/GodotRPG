extends Node2D
class_name Station
## Base for a proximity-interactable piece of furniture (cauldron, supply
## shelf, ...). Player._try_interact() finds the nearest one in range and
## calls interact() on it - override that in a subclass. Unlike Patient/
## RoomDoor, a Station has no collision of its own; it's just a position
## and a prompt.

@export var interact_range: float = 32.0

func _ready() -> void:
	add_to_group("stations")

## Override in subclasses.
func interact() -> void:
	pass
