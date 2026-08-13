extends Node
## Autoload: owns the roguelike run/day-cycle state - current day, reputation,
## gold, suspicion - plus the running tally of what happened this in-game
## day (day_stats), reset each time GameClock crosses a day boundary. This
## is the "Papers, Please" clock: each day ends, consequences land (and
## now, an actual Day Report screen - see GameManager._on_day_ended()),
## the next day gets harder.
##
## The old self-contained day-queue (patient_queue/call_next_patient/
## submit_verdict/start_next_day/_generate_day_queue) is superseded by
## GameClock now driving both real-time patient arrivals and the day
## boundary itself - see game_clock.gd. Left in place, unused, rather than
## ripped out; nothing currently calls it.

## Enough to place two ORDER_BATCH_SIZE (3-unit) supply orders right away -
## the two ingredients the starter recipe needs - so a new run isn't stuck
## unable to afford a single cure before its first delivery.
const STARTING_GOLD := 40
const PLAYER_MAX_HP := 100

var current_day: int = 1
var reputation: int = 100
var gold: int = STARTING_GOLD
var suspicion: int = 0 # rises when dopplegangers slip through undetected
var player_hp: int = PLAYER_MAX_HP # damaged by CorpseMonster while it's got you cornered

var patient_queue: Array[CaseFile] = []
var current_case: CaseFile

## Running tally since the last day boundary - see _reset_day_stats() and
## GameManager.last_day_summary (a frozen copy handed off at the moment
## the day actually ends, for DayReportScreen to read).
## gold_history: Array of {"hour": int, "gold": int} snapshots, one per
## add_gold()/spend_gold() call - the data DayReportScreen's chart plots.
## Initialized to a valid empty shape here (not via _reset_day_stats(),
## which touches GameClock.hour - avoid any cross-autoload reference
## during var-initialization, before every autoload is guaranteed built)
## and properly reset once start_new_run() actually runs.
var day_stats: Dictionary = {
	"cured": 0, "died": 0, "doppel_rejected": 0, "doppel_admitted": 0,
	"gold_earned": 0, "gold_spent": 0, "gold_history": [],
}


func start_new_run() -> void:
	current_day = 1
	reputation = 100
	gold = STARTING_GOLD
	suspicion = 0
	player_hp = PLAYER_MAX_HP
	patient_queue.clear()
	current_case = null
	GameClock.reset()
	Codex.start_new_run()
	_reset_day_stats()

func _reset_day_stats() -> void:
	day_stats = {
		"cured": 0,
		"died": 0,
		"doppel_rejected": 0,
		"doppel_admitted": 0,
		"gold_earned": 0,
		"gold_spent": 0,
		"gold_history": [{"hour": GameClock.hour, "gold": gold}],
	}

## Called by GameClock when a day boundary (HOURS_PER_DAY hours) is
## crossed. Freezes this day's stats into a summary, advances the day
## counter, resets day_stats for the new day, then fires
## EventBus.day_ended - GameManager shows the Day Report screen from
## there (see GameManager._on_day_ended()).
func end_current_day() -> void:
	var summary := day_stats.duplicate(true)
	var finished_day := current_day
	current_day += 1
	_reset_day_stats()
	EventBus.day_ended.emit(finished_day, summary)
	_check_game_over()

func start_next_day() -> void:
	current_day += 1
	patient_queue = _generate_day_queue(current_day)
	EventBus.day_started.emit(current_day)

func call_next_patient() -> CaseFile:
	if patient_queue.is_empty():
		return null
	current_case = patient_queue.pop_front()
	EventBus.patient_called.emit(current_case)
	return current_case

## verdict is one of &"admit", &"reject". Resolves whichever
## case call_next_patient() handed out, then advances the day's queue.
func submit_verdict(verdict: StringName) -> void:
	if current_case == null:
		return
	resolve_case(current_case, verdict)
	current_case = null

## verdict is one of &"admit", &"reject". Resolves a verdict
## against any CaseFile, not just current_case/patient_queue - so
## free-roaming sources (IntakePanel, TreatmentPanel) can call this
## directly without going through the day-queue flow. Returns whether the
## verdict was correct. A wrong "admit" on a doppelganger does NOT start
## HuntManager here - reputation/suspicion consequences land immediately
## (see _apply_verdict_consequences()), but the hunt itself only starts
## once IntakePanel's patient has actually walked out of the room (see
## Patient.gone / IntakePanel._on_admit_pressed()) - "alerted after it
## leaves," not the instant you click Admit.
func resolve_case(case: CaseFile, verdict: StringName) -> bool:
	if case == null:
		return false
	var correct := _is_verdict_correct(case, verdict)
	EventBus.diagnosis_submitted.emit(case, verdict)
	_apply_verdict_consequences(case, verdict, correct)
	EventBus.diagnosis_resolved.emit(case, correct)
	return correct

func _generate_day_queue(day_number: int) -> Array[CaseFile]:
	var queue: Array[CaseFile] = []
	var patient_count: int = 3 + day_number # TODO: tune the difficulty curve
	for i in patient_count:
		queue.append(generate_case())
	return queue

## Rolls one fresh CaseFile from whatever content ContentDB currently has
## loaded - may come back sick, healthy, or a doppelganger. Used by
## GameClock for real-time Intake arrivals, and by anything else that
## wants an on-demand case.
func generate_case() -> CaseFile:
	var case := CaseFile.new()
	var archetype := ContentDB.random_archetype()
	case.archetype = archetype
	if archetype == null:
		return case
	case.patient_name = _roll_name(archetype)
	if randf() < archetype.doppelganger_chance:
		_make_doppelganger(case, archetype)
	else:
		_make_sick_or_healthy(case, archetype)
	return case

func _roll_name(archetype: PatientArchetypeData) -> String:
	if archetype.name_pool.size() > 0:
		return archetype.name_pool[randi() % archetype.name_pool.size()]
	return "Unknown"

func _make_doppelganger(case: CaseFile, archetype: PatientArchetypeData) -> void:
	case.is_doppelganger = true
	for profile in ContentDB.dopplegangers.values():
		if profile.disguise_archetype == archetype:
			case.doppelganger_profile = profile
			break
	# Doppelganger tells are deliberately NOT in presented_symptoms - they
	# only surface through a closer look (see Examination Room), matching
	# the point of wearing a disguise in the first place.

func _make_sick_or_healthy(case: CaseFile, archetype: PatientArchetypeData) -> void:
	if archetype.possible_diseases.size() > 0:
		case.true_disease = archetype.possible_diseases[randi() % archetype.possible_diseases.size()]
	# Everything visible without an examination minigame: today that's just
	# the disease's full symptom list (nothing hidden yet). Once minigames
	# exist, trim this down and let them reveal the rest via
	# CaseFile.record_minigame_result().
	if case.true_disease:
		case.presented_symptoms = case.true_disease.symptoms.duplicate()

func _is_verdict_correct(case: CaseFile, verdict: StringName) -> bool:
	if case.is_doppelganger:
		return verdict == &"reject"
	return verdict == &"admit"

func _apply_verdict_consequences(case: CaseFile, verdict: StringName, correct: bool) -> void:
	if correct:
		adjust_reputation(2)
		add_gold(5)
		if case.is_doppelganger:
			day_stats["doppel_rejected"] += 1
	else:
		adjust_reputation(-10)
		if case.is_doppelganger and verdict == &"admit":
			day_stats["doppel_admitted"] += 1
		# Doppelganger's hunt itself is NOT started here - see the doc
		# comment on resolve_case() above. IntakePanel triggers it once
		# the patient's walked out.

## Shared mutators so every system (verdicts, emergency treatment, the
## doppelganger hunt, the shop) changes reputation/gold/suspicion the same
## way and the HUD stays in sync via one signal each, instead of every
## caller poking the raw vars and remembering to emit itself. add_gold()/
## spend_gold() also feed day_stats' running earned/spent totals and
## gold_history - the data DayReportScreen's Finances tab reads.
func adjust_reputation(delta: int) -> void:
	reputation += delta
	EventBus.reputation_changed.emit(reputation, delta)
	_check_game_over()

func add_gold(amount: int) -> void:
	gold += amount
	day_stats["gold_earned"] += amount
	day_stats["gold_history"].append({"hour": GameClock.hour, "gold": gold})
	EventBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	day_stats["gold_spent"] += amount
	day_stats["gold_history"].append({"hour": GameClock.hour, "gold": gold})
	EventBus.gold_changed.emit(gold)
	return true

func adjust_suspicion(delta: int) -> void:
	suspicion = maxi(0, suspicion + delta)
	_check_game_over()

## CorpseMonster deals damage while it's got you in melee range and isn't
## being fought off - see corpse_monster.gd.
func damage_player(amount: int) -> void:
	player_hp = maxi(0, player_hp - amount)
	EventBus.player_hp_changed.emit(player_hp, -amount)
	_check_game_over()

func heal_player(amount: int) -> void:
	player_hp = mini(PLAYER_MAX_HP, player_hp + amount)
	EventBus.player_hp_changed.emit(player_hp, amount)

func _check_game_over() -> void:
	if reputation <= 0:
		EventBus.game_over.emit("reputation")
	elif suspicion >= 100:
		EventBus.game_over.emit("suspicion")
	elif player_hp <= 0:
		EventBus.game_over.emit("hp")
