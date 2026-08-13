extends Area2D
## Walking into this swaps to another room scene, fading through
## TransitionScreen rather than a hard cut. Pattern (Area2D trigger + a
## PackedScene path + a fade autoload) carried over from the rp-game
## project's LevelTransition/TransitionScreen.
##
## No class_name - keeps this a plain tool-ish script like the equivalent
## in rp-game, since it only ever references an autoload.

@export var target_scene_path: String = ""

## Where the player should end up in the destination room. Vector2.INF (the
## default) means "don't override - leave the destination scene's Player
## node wherever it's placed in the editor." Set a real value once a room
## has more than one door and arriving at the wrong one would look wrong.
@export var target_spawn_position: Vector2 = Vector2.INF

## Shown on the placeholder door's label (e.g. "Alchemy Lab") until real
## room art/signage replaces it. Purely cosmetic - has no effect on where
## this door leads.
@export var door_label: String = "":
	set(value):
		door_label = value
		if is_inside_tree():
			_apply_label()

var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_label()


func _apply_label() -> void:
	var label: Label = get_node_or_null("Label")
	if label:
		label.text = door_label


func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	if target_scene_path == "":
		push_warning("RoomDoor at %s has no target_scene_path set." % global_position)
		return
	_triggered = true
	SFX.play(&"door")
	GameManager.pending_spawn_position = target_spawn_position
	TransitionScreen.change_scene(target_scene_path)
