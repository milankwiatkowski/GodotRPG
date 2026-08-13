extends CanvasLayer
## Autoload (scene-based, so it can own a ColorRect/Label - see project.godot's
## [autoload] entry). A quick fade-to-black wrapped around every scene swap
## (menu -> hospital, room -> room) so change_scene_to_file()'s hitch reads
## as a deliberate beat instead of a jarring cut. Pattern lifted from the
## rp-game project's TransitionScreen/LevelTransition.
##
## Callers go through change_scene() rather than calling
## get_tree().change_scene_to_file() directly, both for the fade and so
## GameManager.pending_spawn_position (set by RoomDoor) gets applied once
## the new scene is actually in the tree. Also the one place every room
## transition funnels through, which makes it the natural hook for
## CorpseManager.on_room_entered() - a chasing revenant needs to follow
## the player into *any* room, not just one specific one, so it can't use
## the "one room's own script calls resume_if_active() on _ready()"
## pattern HuntManager's doppelganger uses.

const FADE_TIME := 0.15
const HOLD_TIME := 0.08

@onready var fade_rect: ColorRect = $FadeRect
@onready var loading_label: Label = $LoadingLabel

var _busy: bool = false
## If change_scene() is called again while already mid-transition (e.g. a
## day boundary lands the same instant a room door fires - see
## GameManager._on_day_ended()), the request used to be silently dropped,
## leaving state and the visible scene out of sync. Now it's remembered
## and fired the moment the current transition finishes instead - only
## the most recent request wins if several stack up.
var _pending_target: String = ""


func _ready() -> void:
	layer = 100 # above any in-game UI
	fade_rect.modulate.a = 0.0
	loading_label.modulate.a = 0.0


func change_scene(target_scene_path: String) -> void:
	if _busy:
		_pending_target = target_scene_path
		return
	_busy = true
	await _fade(0.0, 1.0)
	get_tree().change_scene_to_file(target_scene_path)
	await get_tree().process_frame
	_apply_pending_spawn()
	CorpseManager.on_room_entered()
	await get_tree().create_timer(HOLD_TIME).timeout
	await _fade(1.0, 0.0)
	_busy = false
	if _pending_target != "":
		var next := _pending_target
		_pending_target = ""
		change_scene(next)


func is_busy() -> bool:
	return _busy


## RoomDoor sets GameManager.pending_spawn_position before the swap so the
## player lands near the door they used rather than wherever the destination
## scene's Player node happens to be parked in the editor.
func _apply_pending_spawn() -> void:
	if GameManager.pending_spawn_position == Vector2.INF:
		return
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		players[0].global_position = GameManager.pending_spawn_position
	GameManager.pending_spawn_position = Vector2.INF


func _fade(from_a: float, to_a: float) -> void:
	var t := 0.0
	while t < FADE_TIME:
		t += get_process_delta_time()
		var f: float = clampf(t / FADE_TIME, 0.0, 1.0)
		var a: float = lerpf(from_a, to_a, f)
		fade_rect.modulate.a = a
		loading_label.modulate.a = a
		await get_tree().process_frame
	fade_rect.modulate.a = to_a
	loading_label.modulate.a = to_a
