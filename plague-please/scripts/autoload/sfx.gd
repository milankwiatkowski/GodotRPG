extends Node
## Autoload (SFX): one-stop shop for sound effects, all pulled from
## assets/audio/sfx/400 Sounds Pack. Two ways in:
##  - `SFX.play(&"click")` etc. for direct UI feedback (button presses,
##    panel open/close, footsteps, doors) - called straight from the
##    scripts that trigger those.
##  - Auto-wired to EventBus in _ready() for gameplay outcomes (verdicts,
##    brewing, the doppelganger hunt, gold changes) so RunManager/
##    HuntManager/InventoryManager don't need to know SFX exists at all.
##
## Streams are loaded once into `_cache` on first use, not preloaded en
## masse - most of the 400-sound pack is never touched by this game.

const BASE := "res://assets/audio/sfx/400 Sounds Pack/"

## StringName id -> file path (or Array of paths to pick one at random from).
const SOUNDS := {
	&"click": BASE + "UI/select_1.wav",
	&"cancel": BASE + "UI/cancel.wav",
	&"open_dialogue": BASE + "UI/pop_2.wav",
	&"open_station": BASE + "UI/pop_1.wav",
	&"coin": BASE + "Items/coin_collect.wav",
	&"order_placed": BASE + "Items/coins_gather_quick.wav",
	&"brew_success": BASE + "UI/synth_confirmation.wav",
	&"fail": BASE + "UI/synth_error.wav",
	&"verdict": BASE + "Materials/paper_sort.wav",
	&"lock": BASE + "Environment/lock_lock.wav",
	&"door": BASE + "Environment/door_open.wav",
	&"alert": BASE + "UI/synth_warning.wav",
	&"catch": BASE + "Weapons/harsh_thud.wav",
	&"kill": BASE + "Combat and Gore/crunch_splat.wav",
	&"pickup": BASE + "Combat and Gore/squelching_1.wav",
	&"dispose": BASE + "Environment/door_close.wav",
	&"transform": BASE + "Other/ghost_long.wav",
	&"footstep": [
		BASE + "Footsteps/foley_footstep_concrete_1.wav",
		BASE + "Footsteps/foley_footstep_concrete_2.wav",
		BASE + "Footsteps/foley_footstep_concrete_3.wav",
		BASE + "Footsteps/foley_footstep_concrete_4.wav",
	],
}

var _cache: Dictionary = {} # path (String) -> AudioStream

func _ready() -> void:
	EventBus.diagnosis_resolved.connect(func(_case, _correct): play(&"verdict"))
	EventBus.gold_changed.connect(func(_new_value): play(&"coin"))
	EventBus.potion_brewed.connect(func(_recipe): play(&"brew_success"))
	EventBus.doppelganger_hunt_started.connect(func(_case): play(&"alert"))
	EventBus.doppelganger_hunt_resolved.connect(func(_case, success): play(&"catch" if success else &"fail"))

## Plays a sound by id (see SOUNDS above). Silently does nothing for an
## unknown id rather than erroring - SFX is feedback, never load-bearing.
func play(id: StringName, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(id):
		return
	var entry: Variant = SOUNDS[id]
	var path: String = entry[randi() % entry.size()] if entry is Array else entry
	var stream := _load_cached(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "Master"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _load_cached(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
