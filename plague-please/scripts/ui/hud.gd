extends CanvasLayer
## Reusable Clock/Reputation/Gold overlay. Instance res://scenes/ui/HUD.tscn
## into any room scene (hub or otherwise) - it reads RunManager/GameClock
## directly and stays live via EventBus + polling, so it needs no wiring
## beyond that.
##
## Also owns:
##  - The doppelganger-hunt alert banner + top-right countdown
##    (HuntManager.time_left). Alert started -> a standing warning that
##    doesn't go away on its own (it's actionable - go catch the thing).
##    Resolved -> a brief result message that clears itself after a few
##    seconds. Since HUD is instanced fresh in every room, _ready() also
##    checks HuntManager.is_active() so switching rooms mid-hunt doesn't
##    silently drop the warning or the countdown.
##  - The "Carrying: <name>" box and pickup-cooldown indicator, both
##    reading CorpseManager directly every frame - no signals needed,
##    it's cheap enough to just poll.

@onready var clock_label: Label = $Background/Margin/HBox/DayLabel
@onready var reputation_label: Label = $Background/Margin/HBox/ReputationLabel
@onready var gold_label: Label = $Background/Margin/HBox/GoldLabel
@onready var hp_label: Label = $HPPanel/HPLabel
@onready var alert_panel: Panel = $AlertPanel
@onready var alert_label: Label = $AlertPanel/AlertLabel
@onready var alert_timer: Timer = $AlertTimer
@onready var hunt_timer_panel: Panel = $HuntTimerPanel
@onready var hunt_timer_label: Label = $HuntTimerPanel/HuntTimerLabel
@onready var carry_panel: Panel = $CarryPanel
@onready var carry_portrait: TextureRect = $CarryPanel/CarryHBox/CarryPortrait
@onready var carry_label: Label = $CarryPanel/CarryHBox/CarryLabel
@onready var cooldown_label: Label = $CooldownLabel

func _ready() -> void:
	layer = 10 # above room content, below TransitionScreen's fade (layer 100)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.doppelganger_hunt_started.connect(_on_hunt_started)
	EventBus.doppelganger_hunt_resolved.connect(_on_hunt_resolved)
	alert_timer.timeout.connect(func(): alert_panel.visible = false)
	_refresh()
	if HuntManager.is_active():
		_show_alert("A patient wasn't human! It's loose in Treatment Ward, killing patients - go catch it!")

func _process(_delta: float) -> void:
	clock_label.text = GameClock.format_clock()
	_update_hunt_timer()
	_update_carry_box()
	_update_cooldown_label()

func _on_reputation_changed(new_value: int, _delta: int) -> void:
	reputation_label.text = "Rep %d" % new_value

func _on_gold_changed(new_value: int) -> void:
	gold_label.text = "Gold %d" % new_value

func _on_player_hp_changed(new_value: int, _delta: int) -> void:
	hp_label.text = "HP %d/%d" % [new_value, RunManager.PLAYER_MAX_HP]

func _on_hunt_started(_case: CaseFile) -> void:
	alert_timer.stop()
	_show_alert("A patient wasn't human! It's loose in Treatment Ward, killing patients - go catch it!")

func _on_hunt_resolved(_case: CaseFile, success: bool) -> void:
	var msg := "Caught it! The doppelganger is dealt with." if success else "It got away. Suspicion is rising..."
	_show_alert(msg)
	alert_timer.start()

func _show_alert(text: String) -> void:
	alert_label.text = text
	alert_panel.visible = true

func _update_hunt_timer() -> void:
	if not HuntManager.is_active():
		hunt_timer_panel.visible = false
		return
	hunt_timer_panel.visible = true
	var t: int = maxi(0, ceili(HuntManager.time_left))
	hunt_timer_label.text = "%d:%02d" % [t / 60, t % 60]

func _update_carry_box() -> void:
	var case: CaseFile = CorpseManager.carried_case
	if case == null:
		carry_panel.visible = false
		return
	carry_panel.visible = true
	carry_label.text = "Carrying: %s" % case.patient_name
	if case.portrait_path != "":
		var frames: SpriteFrames = load(case.portrait_path)
		if frames and frames.has_animation(&"idle"):
			carry_portrait.texture = frames.get_frame_texture(&"idle", 0)

func _update_cooldown_label() -> void:
	var remaining := CorpseManager.pickup_cooldown_remaining()
	if remaining <= 0.0:
		cooldown_label.visible = false
		return
	cooldown_label.visible = true
	cooldown_label.text = "Pickup ready in %.1fs" % remaining

func _refresh() -> void:
	clock_label.text = GameClock.format_clock()
	reputation_label.text = "Rep %d" % RunManager.reputation
	gold_label.text = "Gold %d" % RunManager.gold
	hp_label.text = "HP %d/%d" % [RunManager.player_hp, RunManager.PLAYER_MAX_HP]
