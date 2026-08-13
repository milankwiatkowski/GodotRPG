extends Node
class_name ExaminationController
## Drop this into the Examination Room scene. It drives which minigame(s)
## run for the current case and lets a minigame scene plug in without the
## room needing to know anything about it beyond MinigameBase's contract.

## Maps minigame_id -> minigame scene. Populate in the Inspector as
## minigames are built (drag each minigame's .tscn in).
@export var minigame_registry: Dictionary = {} # StringName -> PackedScene

## Container node the active minigame gets instanced into.
@export var minigame_slot: Control

func run_minigame(minigame_id: StringName, case: CaseFile) -> void:
	if not minigame_registry.has(minigame_id):
		push_error("ExaminationController: no minigame registered for id '%s'" % minigame_id)
		return
	for child in minigame_slot.get_children():
		child.queue_free()
	var instance: MinigameBase = minigame_registry[minigame_id].instantiate()
	minigame_slot.add_child(instance)
	instance.finished.connect(_on_minigame_finished.bind(instance), CONNECT_ONE_SHOT)
	instance.start(case)

func _on_minigame_finished(_success: bool, _result: Dictionary, instance: MinigameBase) -> void:
	instance.queue_free()
