extends Node
## Autoload: keeps each patient-queue room's list of CaseFiles alive across
## scene reloads. Rooms are separate scenes, so walking through a door and
## back destroys and recreates everything in the room you left - without
## this, PatientQueue would just roll brand new patients on every return,
## which read as "the same NPC has different symptoms every visit."
## PatientQueue checks in here on _ready() to resume the same queue (same
## CaseFiles, same order) instead of losing it, and calls remove() the
## moment a patient is actually dismissed (not just "the panel was closed").
##
## Also the hand-off point between rooms: IntakeRoom pushes an admitted,
## genuinely-sick patient's case onto "TreatmentRoom"'s queue rather than
## resolving it immediately - see scripts/ui/intake_panel.gd. A Patient
## *node* never moves between scenes (it can't - it's just torn down and a
## new one is built from the same CaseFile), but the CaseFile itself is the
## real persistent identity, so reusing it is what makes it "the same
## patient" showing up in the next room.

var _queue_by_room: Dictionary = {} # String (room name) -> Array[CaseFile]

## Always returns the same Array instance for a given room, so callers can
## push()/erase() into what get_queue() returns directly if they want to.
func get_queue(room_name: String) -> Array:
	if not _queue_by_room.has(room_name):
		_queue_by_room[room_name] = []
	return _queue_by_room[room_name]

func push(room_name: String, case: CaseFile) -> void:
	get_queue(room_name).append(case)

func remove(room_name: String, case: CaseFile) -> void:
	get_queue(room_name).erase(case)
