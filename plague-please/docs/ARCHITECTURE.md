# Plague, Please — Project Schema

A medieval-fantasy hospital sim: take in incoming patients (Papers,
Please-style judgment calls), tell the sick from the healthy from the
doppelgangers, cure the ones you admit, brew cures and order supplies to
make that possible, and survive an escalating roguelike run where wrong
calls cost you reputation - and sometimes let a monster into the hospital.

This document describes the schema that's been scaffolded so far and how
the pieces are meant to fit together. It's deliberately data-driven: new
diseases, symptoms, ingredients, recipes and patient types are added as
`.tres` resource files in the editor, not by writing new code.

## Folder layout

```
plague-please/
├── assets/            art, audio, fonts (yours - see assets/README.md)
├── data/               content as .tres resources, loaded by ContentDB
│   ├── symptoms/
│   ├── diseases/
│   ├── patients/       PatientArchetypeData
│   ├── ingredients/
│   ├── recipes/
│   └── dopplegangers/
├── dialogues/          placeholder for the writing/story pass (yours)
├── docs/                this file
├── scenes/
│   ├── main/            MainMenu.tscn
│   ├── hospital/         Hospital.tscn (hub) + IntakeRoom, TreatmentRoom,
│   │                      AlchemyLab, SupplyRoom - all walkable
│   ├── player/           Player.tscn (the walk controller)
│   ├── patients/         Patient.tscn, DoppelgangerMonster.tscn
│   ├── world/            RoomDoor.tscn (room-to-room trigger)
│   ├── system/           TransitionScreen.tscn (autoload, fade between scenes)
│   ├── minigames/        one scene per examination minigame (provided later)
│   └── ui/               HUD, IntakePanel, TreatmentPanel, BrewPanel, ShopPanel
└── scripts/
    ├── autoload/         singletons, see below
    ├── resources/         data-class definitions (SymptomData, DiseaseData, ...)
    ├── entities/          runtime nodes (Patient, DoppelgangerMonster)
    ├── player/             HospitalPlayer movement controller
    ├── world/              RoomDoor, PatientQueue, Station (+ subclasses)
    ├── minigames/          MinigameBase - the contract real minigames implement
    ├── systems/            ExaminationController, HuntManager (doppelganger hunt)
    └── ui/                 screen scripts (MainMenu, HUD, *Panel)
```

## Core loop (implemented, functional end-to-end)

`MainMenu` → **Begin Shift** → `GameManager.start_new_run()` resets
`RunManager` state, fades into `Hospital.tscn` (the hub), and starts day 1.
`RunManager` generates that day's patient queue from the content in
`ContentDB`.

**Getting around is walking, not clicking.** The hub and every room are real
`CharacterBody2D`-driven scenes: WASD/arrows move the `Player`
(`scripts/player/player.gd`), and walking into a `RoomDoor` (a placeholder
brown rectangle for now) fades to the target room via `TransitionScreen` and
drops you at that door's `target_spawn_position` on the other side. See
"Movement & room transitions" below.

**Four rooms, each doing one job.** `IntakeRoom` is where new patients
arrive one at a time, on a slow cooldown (`spawn_interval` - deliberately
sparse, this isn't meant to be a rush) - several can be queued and waiting
at once, up to `PatientQueue.slot_positions.size()` (6, spread across the
room). On open, an `IntakePanel` only shows the patient's own flavor line -
no symptoms yet. **Inspect Closely** is the actual test: it reveals the
real symptom list (and records what it just revealed into `Codex` - see
"The Codex" below), and if what turns up doesn't read like an ordinary
illness, that's the tell something's off. Then **Admit** or **Reject** (no
Quarantine anymore - every verdict either sends them on or turns them
away, nothing sits detained in the room). A patient you correctly Admit
doesn't get resolved on the spot if they're actually sick - they're sent
to `TreatmentRoom` instead, where you cure them with a brewed potion once
you're ready; that's where the reputation/gold reward actually lands. A
wrongly-Admitted doppelganger doesn't resolve quietly: it follows the same
corridor route any admitted patient would - off to `TreatmentRoom` - and
only drops its disguise once it's actually arrived there. HUD fires an
alert, and you have to find and catch it before the clock runs out *and*
before it works through the patients actually waiting to be cured there -
see "Doppelganger hunt" under "Room feature systems". It never wanders out
of `TreatmentRoom` once unmasked. `AlchemyLab` and `SupplyRoom` each have a
`Station` (cauldron / shelf) that opens a brewing/ordering panel the same
way. See "Patient flow: Intake → Treatment" and "Room feature systems"
below for the full detail.

A day ends when `GameClock` crosses `HOURS_PER_DAY` hours (see "Game clock
& Day Report" below) - `RunManager.end_current_day()` freezes a summary and
emits `EventBus.day_ended`; `GameManager` shows `DayReportScreen`, and its
Continue button starts the next day back in the merged Hospital scene.
Reputation hitting 0, suspicion hitting 100, or player HP hitting 0 ends
the run immediately instead, from wherever the player happens to be
(mid-shift or already on a Day Report) - `GameManager._on_game_over()`
transitions straight to `GameOverScreen` (reason-specific message, final
stats, Return to Main Menu). `_on_day_ended()` no-ops if the run already
ended this way, so a day boundary landing right after can't paper over the
game-over screen with a day report.

## Movement & the merged map

`scripts/player/player.gd` (`HospitalPlayer`) reads `move_up/down/left/
right` (WASD + arrows, see `project.godot`'s `[input]` section), normalizes
diagonal movement, `move_and_slide()`. Looks for a child `AnimatedSprite2D`
with `idle`/`walk` animations and drives it automatically; also owns
`interact` handling - see "Interact & modal-UI groups" below.

**One scene, not six.** Intake, Treatment, Alchemy Lab, Supply Room, and
the Morgue used to each be their own scene, connected by `RoomDoor`
teleport triggers through a central hub. They're now all regions of one
merged `scenes/hospital/Hospital.tscn`, connected by real walkable
corridors - built by a one-off generator (not hand-painted; see "Room
feature systems" below for why room content is generated rather than
authored tile-by-tile). The trigger for the merge: `CorpseMonster` needs
to chase the player across "rooms," and `DoppelgangerMonster` needs to
walk to patients wherever they are - both are much simpler and more
honest as continuous movement through one space than as
despawn-and-respawn-on-scene-swap illusions. `RoomDoor`/`room_door.gd`
still exist as a reusable component (and still handle the
`MainMenu` <-> `Hospital` <-> `DayReportScreen` transitions via
`TransitionScreen`), just unused *between* these five areas now - you
walk there.

**Layout** (same relative directions as the old hub): Intake north,
Treatment south, Alchemy Lab west, Supply Room east, the Morgue further
south past Treatment. Two corridors cross near the origin - a vertical
one (Intake↔Treatment↔Morgue) and a horizontal one (Alchemy Lab↔Supply
Room) - with **no teleport doors inside the map at all**: reaching any
area is just walking there. Each area keeps its own tinted
`TileMapLayer` (`Floor_Intake`, `Floor_Treatment`, etc., plus a neutral
`Floor_Corridors`) sharing one `TileSet`, so the old per-room color-coding
survives the merge even though it's all one node tree.

- **Building the tile layout**: the generator paints each area's wall
  ring + interior and each corridor's floor strip + border walls into a
  **global "floor always wins over wall"** rule - any cell any region
  wants painted floor stays floor even if another region's wall-ring
  candidate would otherwise land there. That's what lets a corridor punch
  a clean gap through a room's wall ring automatically (no manual
  gap-list bookkeeping - see the old per-room approach that predates
  this), and what lets the two corridors cross each other at the center
  without a wall-vs-floor conflict at the intersection.
- **Every corridor doorway is 6 tiles (96px) wide**, not the original 2
  (32px). The Player's `CircleShape2D` collision is 24px across, so a
  2-tile gap only left an ~8px dead-center window to walk straight
  through - anyone approaching from elsewhere in a much wider room would
  just run into the wall next to the gap, reading exactly like an
  invisible wall. Widened after the fact rather than at generation time -
  `Floor_Corridors` gets floor added on the extra columns/rows on each
  side, and any wall tile a room's own layer had painted on those same
  cells gets erased. If a corridor's width ever needs revisiting again,
  do the same: add floor to `Floor_Corridors` on the new cells, then erase
  (not repaint) any wall tile the affected room layers have there.
- **`patient_queue.gd`'s `zone_name`** ("IntakeRoom"/"TreatmentRoom") is
  what keys `RoomState`'s queues now - no longer inferred from
  `get_tree().current_scene.name`, since every zone lives in the same
  scene. "Room"/room-name is legacy vocabulary at this point; think
  "zone."
- **A sick-admitted patient visibly walks toward Treatment** instead of
  vanishing at Intake - `IntakePanel._on_admit_pressed()` sends them
  through `INTAKE_TO_TREATMENT_PATH`, not a single straight line: `Patient`
  has no real pathfinding, and a direct line from most Intake queue slots
  to Treatment cuts diagonally through Intake's own wall instead of
  through the doorway gap in it. The route is two legs -
  `INTAKE_CORRIDOR_GAP` (lines the patient up with that doorway first) then
  `TREATMENT_BOUND_EXIT` (straight down the corridor from there) - via
  `Patient.dismiss()`'s optional `path` param, which walks each waypoint in
  turn before the final leg. The *same* `CaseFile` (same rolled portrait -
  see `CaseFile.portrait_path`) reappears as a fresh `Patient` node waiting
  in Treatment's own queue once the original reaches the last waypoint and
  despawns. Not a single continuous walk with one persistent node (that
  would need real cross-zone pathfinding this game doesn't have) - a
  two-node handoff timed and dressed to read as one. A wrongly-admitted
  doppelganger walks this exact same route (see "Doppelganger hunt" below)
  instead of resolving on the spot.
- **Monsters no longer need "respawn on room entry" logic** - the merged
  scene persists for the whole run, so once `HuntManager`/`CorpseManager`
  spawn a monster it just keeps existing and moving through the shared
  space (real `move_and_slide()` chasing, not teleporting) until it's
  resolved. `resume_if_active()`/`on_room_entered()` still exist, but only
  matter for the `Hospital` <-> `DayReportScreen` <-> `Hospital` round
  trip now, where the whole scene genuinely does unload and reload.
  `DoppelgangerMonster` is the one exception to "moves through the shared
  space" - it's clamped every frame to `HuntManager.SPAWN_X_RANGE`/
  `SPAWN_Y_RANGE` (Treatment's interior) and only ever targets a waiting
  patient inside that same box, so it can chase around Treatment Ward but
  can never wander out through the corridor.
- Physics layers (`project.godot`'s `[layer_names]`): `1 = world`,
  `2 = player`, `3 = patients`.

## Art & assets in use

Everything below pulls from the packs already in `assets/` rather than
placeholder Godot primitives, so it's real to swap out, not to build from
scratch:

- **Player** (`scenes/player/Player.tscn`) - Tiny RPG pack's Priest
  (`Idle`/`Walk`, 6/8 frames), scaled to `1.0` - full native 100px, matching
  `rp-game`'s own Knight (which isn't scaled down at all either). Went
  through three passes (`0.36` → `0.48` → `0.8`) before landing here after
  repeated "still too small" feedback.
  **Visual scale and collision size are deliberately decoupled**: the
  `CircleShape2D` collision radius is `12`, not scaled up to match - a
  bigger hitbox would be wider than the 32px (2-tile) door gaps rooms are
  built with, physically trapping the player. A large sprite with a
  forgiving, much smaller "feet" hitbox is a common and intentional
  top-down-RPG pattern, not an oversight. If sprite scale changes again,
  collision radius doesn't need to follow it - just keep the radius
  comfortably under 16 (half the gap width) - but `PromptLabel`'s
  (Patient's talk prompt / DoppelgangerMonster's catch prompt) offsets do
  need to shift by however much the sprite's *visual* height changed.
- **Patient** (`scenes/patients/Patient.tscn`) - Minifolks Villagers +
  Villagers2 packs (`assets/MinifolksVillagers*/`), 32x32 frames at
  `scale = 1.2` (idle = row 0 cols 0-3, walk = row 1 cols 0-5 - holds for
  every character in both packs even though total sheet width varies per
  character, since the extra columns are just other animations this game
  doesn't use). Each patient picks a random look in `patient.gd:_ready()`
  from `Patient.PORTRAITS` - 18 pre-baked `SpriteFrames` resources under
  `resources/sprite_frames/` (one per character across both packs) - so
  the several people waiting in a room at once don't all look identical.
  Add another look by dropping a new Minifolks-layout PNG in and adding a
  matching entry to both `PORTRAITS` and `resources/sprite_frames/`.
- **DoppelgangerMonster** (`scenes/patients/DoppelgangerMonster.tscn`) -
  kept on the older Tiny RPG pack's Skeleton, tinted purple - the
  disguise's true form is deliberately a different art style/pack than
  the Minifolks patients, so it reads as *wrong* the instant it appears.
- **Display scale** - `project.godot`'s `[display]` matches `rp-game`'s
  approach: a tiny `384x216` virtual canvas (`window/size/viewport_*`)
  integer-upscaled (`window/stretch/scale_mode="integer"`) to a
  `1152x648` default window, plus `2d/snap/snap_2d_*_to_pixel` under
  `[rendering]` for crisp (non-blurry) pixel movement. **This means every
  screen-space UI control (HUD/panels/MainMenu) is laid out against a
  384x216 canvas, not a "normal" 1000+px-wide screen** - a control sized as
  if it had a full HD canvas to work with will dominate the screen.
  HUD/panels/MainMenu were all re-sized down (and given small
  `theme_override_font_sizes/font_size`, ~8-9, since Godot's default
  theme's 16px font is disproportionately large at this canvas size) after
  the first pass came in too big.
- **Room floors and walls** - a shared `TileSet`
  (`assets/tilesets/hospital_tileset.tres`) built from the Pixel Art Top
  Down pack: `TX Tileset Stone Ground.png` for the floor and `TX Tileset
  Wall.png` for walls (atlas coord `(3,13)`, full 16x16 collision on
  physics layer `1`/"world" - the same wall tile `rp-game`'s own village
  level uses). **The floor tile is `(12,3)`, not `(1,1)`** - `(1,1)` (what
  `rp-game` happens to use) turned out to be a completely flat, textureless
  cell on this particular sheet; tiling it looked identical to a flat
  `ColorRect`, which is exactly the "not really using the tileset" bug this
  fixed. `(12,3)` has a visible speckled texture instead. If you swap the
  floor tile again, actually crop and look at the candidate cell first (a
  quick `Image.get_region()` + upscale + save_png, viewed directly) rather
  than trusting an atlas coordinate blind - most cells on this sheet *are*
  flat/plain by design, only some have visible detail. Each room is painted
  as a filled floor rect plus a one-tile wall ring around it, with a
  door-sized gap left in the ring wherever that room's `RoomDoor` sits (see
  "Movement & room transitions" above). `Floor`'s `modulate` carries each
  room's identity color as a tint on top of the now-textured tile, so rooms
  stay tell-apart-at-a-glance. Regenerate/extend from the editor's Tile Map
  panel - it was built by a one-off script, not hand-painted, and there's
  nothing script-specific about the result.
- **UI** - `MainMenu`'s button, the panels' backgrounds/buttons, and the
  `HUD`'s background bar all use `StyleBoxTexture`s pulled from
  `assets/Free_UI_Asset_Pack/` (folders `1`, `5`, `6`, `8` specifically -
  the pack's files are numbered, not named, so those folder numbers are
  the only record of which piece is which; re-derive by opening them if
  you reorganize). `texture_margin_*` values on each `StyleBoxTexture` are
  eyeballed, not measured - nudge them in the Inspector if a corner looks
  stretched.
- **Item icons** (`assets/sprites/items/`) - 25 individually-trimmed PNGs
  cropped from `assets/25 itens.png` (a 5x5 sheet, already alpha-keyed
  around each icon in the source - the crop just tightens each cell's
  bounding box down to its actual content, +2px padding, rather than
  exporting the whole cell). `IngredientData.icon`/`PotionRecipeData.icon`
  on every ingredient/recipe `.tres` point at one each (picked by loose
  color/material association - e.g. `willowbark` → a bark-colored plank
  icon, `chill_balm` → the teal potion icon); `ShopPanel`/`BrewPanel` show
  them in each row. Only 9 of the 25 are wired up yet - the rest (weapons/
  armor/misc) are cropped and available under that same folder for future
  content that needs them, named descriptively (`sword_steel.png`,
  `helmet.png`, etc.) rather than by grid position.
- **Not yet pulled from the packs**: `RoomDoor`'s, `ReceptionDesk`'s (well,
  gone now, but `Cauldron`/`SupplyShelf` are the same story) visuals (still
  flat `ColorRect`s) - the Pixel Art pack's `TX Props with Shadow.png`/
  `TX Struct.png` have a wooden double-door and a stone archway that would
  fit well, but picking exact pixel regions out of those sheets needs the
  sprite visually open in the editor (region editor), not something to
  guess blind.

## Patient flow: Intake → Treatment

Originally three separate rooms (Waiting Room, Examination Room, Emergency
Room), consolidated into two: **arrivals happen in one place, curing
happens in another**, matching how an actual hospital separates triage
from the ward.

- **`scripts/world/patient_queue.gd`** (`PatientQueue`) - the queue manager
  behind both rooms, replacing the old one-patient-at-a-time
  `PatientSpawner`. Holds up to `slot_positions.size()` patients waiting at
  once (12, in a 4x3 grid), backed by `RoomState.get_queue(room_name)` so
  the *whole queue* - not just one patient - survives leaving and
  re-entering the room. It no longer rolls its own cases at all (either
  room) - it only ever materializes a *visible* Patient node for whatever
  RoomState already has queued. Intake's own arrivals are rolled by
  `GameClock` instead, straight into RoomState, independent of whether
  Intake Room is even loaded - see "Game clock & Day Report". Treatment's
  queue only ever grows via `IntakePanel.push()` (below). Either way,
  entering the room always resumes whatever `RoomState` remembers first,
  instantly (no walk-in) - they were already here, not just arriving.
  Treatment's `PatientQueue` also ticks each waiting patient's
  `CaseFile.death_timer` (`_tick_death_timers()`, only while Treatment is
  the loaded scene) - "the more sick he is, the quicker he'll die," sized
  by `DiseaseData.death_time_seconds()` and started the moment
  `IntakePanel` admits them. Runs out → `Patient.die()`, same path a
  doppelganger kill takes - see "Death, disposal, and what happens if you
  don't".
- **`scripts/autoload/room_state.gd`** (autoload `RoomState`) - rooms are
  separate scenes, so a scene reload used to destroy and recreate every
  waiting patient, and `PatientQueue` would just roll brand new ones on
  return. That read as "the same NPC has different symptoms every visit,"
  because it wasn't the same NPC anymore. `RoomState.get_queue(room_name)`
  returns a persistent `Array[CaseFile]` for that room (creating an empty
  one on first use); `push()`/`remove()` add/drop a case. `PatientQueue`
  removes a case the moment its patient is actually *dismissed* (resolved,
  not just "the panel was closed"). This is also the **hand-off point
  between rooms**: `IntakePanel.push("TreatmentRoom", case)` is how an
  admitted patient's `CaseFile` gets from one room to the other - a
  `Patient` *node* never moves between scenes (it can't - it's torn down
  and a new one is built from the same `CaseFile`), but the `CaseFile`
  itself is the real persistent identity, so reusing it is what makes it
  read as "the same patient" showing up in the next room.
- **`scripts/entities/patient.gd`** (`Patient`) - a small state machine
  (`WALKING_IN → WAITING → LEAVING`), added to the `"npcs"` group while
  waiting so `Player._find_nearest_waiting_patient()` can find *any* of
  several concurrently-waiting ones, not just one. `setup_waiting()` is the
  RoomState-resume entry point (straight into `WAITING`, no walk-in);
  `setup()` is the normal fresh-spawn one.
- **`scripts/ui/intake_panel.gd`** (`IntakePanel`) - shows
  `CaseFile.presented_symptoms` (or "nothing out of the ordinary"), an
  optional **Inspect Closely** (reveals a doppelganger's `tells` via
  `CaseFile.record_minigame_result(&"basic_observation", ...)` -
  deliberately a placeholder for the real examination minigames "provided
  later" per the brief, not a finished one), then:
    - **Admit** on a genuinely sick patient → `RoomState.push("TreatmentRoom",
      case)`. **No reward yet** - admitting isn't the same as curing.
    - **Admit** on a healthy patient → resolves immediately
      (`RunManager.resolve_case(case, &"admit")`), nothing to treat.
    - **Admit** on a doppelganger → resolves immediately too, but this is
      the *wrong* call - triggers `HuntManager` (see "Room feature
      systems").
    - **Reject** always resolves immediately, same as before.
- **`scripts/ui/treatment_panel.gd`** (`TreatmentPanel`) - shows the
  admitted patient's condition and, since the cure isn't just handed to the
  player (see "The Codex"), a **Try** button per potion currently in
  `InventoryManager` stock - not just the correct one, since not knowing
  which is right is the point. Picking the right one consumes it via
  `InventoryManager.consume_potion()`, calls
  `RunManager.resolve_case(case, &"admit")` (where the reputation/gold
  reward actually lands) and `Codex.record_cure_known()`. Picking a wrong
  one still consumes it - wasted, no other penalty - and shows that
  recipe's own `PotionRecipeData.side_effects_on_misuse` line as feedback,
  patient still waiting, death timer still running. Once
  `Codex.is_cure_known()` for a disease, the body text names the cure
  directly (a player who's cured something before shouldn't have to
  re-guess), though the **Try**-list mechanic doesn't change - it's just a
  hint above it now. Nothing in stock → the list says so instead of a
  disabled button. **No Reject here** - they're already admitted, not up
  for a second triage call; Close/Escape leaves them waiting until the
  player comes back with something to try (a "discharge without curing"
  escape valve doesn't exist yet - see "Not yet built").
- Both panels have a corner **X** button and Escape (`ui_cancel`) to back
  out *without* deciding anything - the patient just keeps waiting. This
  was a real bug fixed earlier in development: patient-facing panels used
  to force a decision the moment they opened, with no way out.
  `IntakePanel`/`TreatmentPanel`'s body text sits in a `ScrollContainer`
  (`horizontal_scroll_mode` off, vertical-only) rather than a bare `Label`,
  so several symptoms - or a longer hand-written description down the line
  - doesn't get clipped or blow out the panel's fixed size; same treatment
  on `BrewPanel`/`ShopPanel`'s lists.

## Interact & modal-UI groups

`Player._try_interact()` and its movement-freeze check are written against
groups, not direct references, so every room's interactable content is
independent of Player's code:

| Group | Who's in it | What it's for |
|---|---|---|
| `"modal_ui"` | Every panel (`IntakePanel`, `TreatmentPanel`, `BrewPanel`, `ShopPanel`, `CodexScreen`) | Player freezes movement while any node in this group reports `is_open() == true`. `CodexScreen` additionally pauses the whole tree (`get_tree().paused`) while open, so this is belt-and-suspenders for it specifically. |
| `"dialogue_ui"` | The patient-facing panels (`IntakePanel`, `TreatmentPanel`) | Player calls `open_with_patient(patient)` on whichever one matches the patient's own `zone_name` ("IntakeRoom"/"TreatmentRoom" - set by `PatientQueue._spawn_into_slot()`, matched against `IntakePanel.zone_name`/`TreatmentPanel.zone_name`). Both panels exist simultaneously in the merged Hospital scene now, unlike the old per-room scenes where only one was ever present - matching by zone (not "whichever's first in the group") is what stops a Treatment Ward patient from opening the Admit/Reject panel. |
| `"npcs"` | `Patient` while `WAITING` | `Player._find_nearest_waiting_patient()` - picks the *nearest* of however many are currently waiting. |
| `"doppelganger_monster"` | `DoppelgangerMonster` | `Player._try_interact()` catches it directly (`monster.catch()`), second interact priority. |
| `"corpse_monster"` | `CorpseMonster` (an undisposed corpse gone bad - see "Corpses..." below) | `Player._try_interact()` catches it directly, *highest* interact priority - it's actively chasing you, more urgent than a wandering doppelganger. |
| `"corpses"` | `Corpse` | `Player._try_interact()` calls `CorpseManager.pickup_corpse()` on the nearest one (gated by `CorpseManager.can_pickup()` - cooldown + not already carrying one). |
| `"stations"` | `Station` and its subclasses (`BrewingStation`, `SupplyStation`, `DisposalStation`) | `Player._try_interact()` calls `station.interact()` on the nearest one, which itself finds and opens its own panel (`"brew_ui"`/`"shop_ui"`) or, for `DisposalStation`, calls `CorpseManager.dispose_carried()` directly. |

Adding a new room interactable is a matter of joining the right group(s) -
Player never needs to change.

## Room feature systems

- **Alchemy Lab** (`BrewingStation` + `BrewPanel`) - `scripts/world/
  station.gd` (`Station`) is the base for any proximity-interactable piece
  of furniture; walk up to the `Cauldron` and interact to open `BrewPanel`.
  Rebuilds its recipe row list from `ContentDB.recipes` every time it
  opens, so a newly-authored recipe `.tres` shows up with no code changes.
  Each row shows the recipe's ingredient cost and current potion stock;
  **Brew** calls `InventoryManager.brew(recipe)`, which spends the
  ingredients and adds one potion - fails harmlessly (with feedback) if
  supplies are short.
- **Supply Room** (`SupplyStation` + `ShopPanel`) - ordering, not instant
  buying. Each ingredient row shows cost for a batch of
  `SupplyOrders.ORDER_BATCH_SIZE` (3) and current stock; **Order** spends
  the gold immediately (`RunManager.spend_gold()`) and queues a delivery
  that arrives after `SupplyOrders.ORDER_DELAY` (20s) via
  `scripts/autoload/supply_orders.gd` (autoload `SupplyOrders`) - ticked in
  that autoload's own `_process()`, not the room's, specifically so an
  order keeps cooking down even if the player leaves Supply Room to go do
  something else while they wait, which is the entire point of "ordering"
  as distinct from "buying." `ShopPanel` shows a live "on the way" list
  with countdown while open; `order_delivered` fires regardless of whether
  anyone's watching, adding straight to `InventoryManager`.
- **Doppelganger hunt** (`scripts/systems/doppelganger_hunt.gd`, autoload
  `HuntManager`) - the "rare random event": the payoff for the "monster
  that has to be hunted down" part of the brief.
  `IntakePanel._on_admit_pressed()` calls `HuntManager.start_hunt(case)`
  once the wrongly-**Admit**ted doppelganger's `Patient` node actually
  reaches Treatment Ward (via `Patient.gone`, after walking
  `INTAKE_TO_TREATMENT_PATH` like any other admitted patient - see
  "Movement & the merged map"), not the instant Admit is clicked. It's
  rare by construction, not by a dedicated roll - it only fires when a
  patient actually was a doppelganger (`doppelganger_chance`, currently
  0.4) *and* the player misjudges it. `EventBus.doppelganger_hunt_started`/
  `_resolved` drive a HUD alert banner (`hud.gd`). A 45-second countdown
  (`HUNT_DURATION`) runs regardless of where the player's standing (there's
  only one scene now, but the countdown is independent of it either way);
  the visible `DoppelgangerMonster` (see "Art & assets in use") spawns
  inside `SPAWN_X_RANGE`/`SPAWN_Y_RANGE` (Treatment Ward's interior) and
  **never leaves it** - it's clamped there every frame and only ever
  targets a waiting patient that's also inside that box, so it can hunt
  around Treatment but can't wander off into the corridor or another zone.
  `resume_if_active()` still exists for the one case a monster node can't
  survive - a `Hospital` <-> `DayReportScreen` round trip, which does
  genuinely unload the scene.
  `DoppelgangerMonster` owns its own predation (`doppelganger_monster.gd`):
  SEEKING picks the nearest waiting patient inside Treatment and walks to
  it; in melee range it attacks (with an animation) and, once per
  `ATTACK_COOLDOWN` (5s), actually kills them (`Patient.die()`) - gone for
  good, no cure, no reward, ever - then goes back to SEEKING. Catching it
  (walk up, interact) relieves suspicion, pays out gold/reputation, and
  records its tells into `Codex` (see "The Codex") even if it was never
  Inspected; letting the timer run out costs more suspicion than the
  original mistake did. Still intentionally simple - one monster, no
  difficulty scaling with suspicion/day.

## Death, disposal, and what happens if you don't (`CorpseManager`)

Every patient death - the doppelganger's `kill_random_patient()`, or a
disease's `death_timer` running out (see "Patient flow" below) - now
routes through `Patient.die()`, which no longer just despawns them. It
calls `CorpseManager.register_corpse(case, position)`, which spawns a
`Corpse` node (`scenes/patients/Corpse.tscn`) right there in Treatment
Ward: the dead patient's own portrait, sprite rotated 90° so it reads as
a body at a glance, not a napping patient.

- **Pick it up** - walk up, interact (gated by `CorpseManager.can_pickup()`:
  a `PICKUP_COOLDOWN` of 1s between attempts, shown live in the HUD's
  `CooldownLabel`). This removes the Corpse node and sets
  `CorpseManager.carried_case` - the single source of truth for "what am I
  carrying." There's no world node for a carried body; `hud.gd`'s
  "Carrying: <name>" box and `player.gd`'s speed debuff
  (`CARRY_SPEED_MULTIPLIER`, 0.65×) both just poll that var directly.
- **Dispose of it** - carry it to the Morgue (`scenes/hospital/Morgue.tscn`,
  reached via a `MorgueDoor` placed *inside* Treatment Ward rather than a
  gap in Treatment's own boundary wall - it's not "leaving through the
  wall," just a portal standing in a corner) and interact with the
  `DisposalStation`. Clears `carried_case` for good.
- **Leave it too long and it turns** - `CorpseManager._corpses` ticks a
  `TRANSFORM_DELAY` (45s) per corpse *globally*, regardless of scene. Miss
  it and the corpse is replaced by a `CorpseMonster` (randomly Werewolf,
  Slime, or Orc sprites - `resources/sprite_frames/monster_*.tres` - a
  different pack/style than the doppelganger's Skeleton on purpose, so it
  reads as a different kind of threat) plus a flat reputation penalty
  (`NEGLECT_REPUTATION_PENALTY`). Unlike `DoppelgangerMonster`'s aimless
  wander, `CorpseMonster` actively chases whoever's in group `"player"`
  every physics frame, and it follows across *any* room change - see
  `CorpseManager.on_room_entered()`, called by
  `TransitionScreen.change_scene()` after every scene swap (the one place
  all room transitions funnel through, unlike the doppelganger hunt's
  single-room-only `resume_if_active()` pattern). Interacting with it
  (highest interact priority - see "Interact & modal-UI groups") dispels
  it for good, no extra reward; it's damage control, not a hunt.

## Sound effects (`scripts/autoload/sfx.gd`, autoload `SFX`)

All pulled from `assets/audio/sfx/400 Sounds Pack` (only a handful of its
~400 files are actually wired up - `SFX.SOUNDS` is the full list of what's
in use). Two ways a sound gets triggered:

- **Direct calls** - `SFX.play(&"click")` etc. from the script that
  triggers it: button presses, panel open/close, `RoomDoor`, player
  footsteps (`player.gd:_update_footsteps()`, a fixed-interval timer while
  moving, not tied to animation frames).
- **Auto-wired to `EventBus`** in `SFX._ready()` - gameplay *outcomes*
  play a sound with zero changes to the system that caused them:
  `diagnosis_resolved` → a paper-stamp sound for any verdict,
  `gold_changed` → a coin sound for any gold change (spend or gain),
  `potion_brewed` → a brew-success chime, `doppelganger_hunt_started`/
  `_resolved` → the hunt alert/catch/escape sounds. This is why
  `RunManager`/`InventoryManager`/`HuntManager` don't reference `SFX` at
  all - they just do what they already did, and it happens to make sound
  now.

Streams load lazily into `SFX._cache` on first `play()`, not preloaded en
masse. Add a new sound by adding one entry to `SOUNDS` (a path, or an
`Array` of paths to pick randomly from, like `&"footstep"` does) and
either calling `SFX.play(&"your_id")` somewhere or wiring it to an
`EventBus` signal in `_ready()`.

## Autoload singletons (`scripts/autoload/`)

Registered in `project.godot` under `[autoload]`, in load order:

| Singleton | Responsibility |
|---|---|
| `EventBus` | Global signals. Systems talk through this instead of holding references to each other. |
| `ContentDB` | Loads every `.tres` under `res://data` on startup, indexed by `id`. |
| `InventoryManager` | Ingredient/potion stock, brewing, `consume_potion()` for treatment. |
| `RunManager` | Day counter, reputation/gold/suspicion, patient queue, case generation, verdict resolution. Owns `adjust_reputation()`/`add_gold()`/`spend_gold()`/`adjust_suspicion()` - every system that moves these numbers goes through these so the HUD's signals (`reputation_changed`, `gold_changed`) stay reliable. |
| `GameManager` | Top-level state machine + scene switching (menu / day / game over). |
| `TransitionScreen` | Fade-to-black wrapper around every scene swap; applies `GameManager.pending_spawn_position`. |
| `HuntManager` | The doppelganger hunt's countdown and monster spawn/catch/escape resolution - see "Room feature systems" above. |
| `RoomState` | Remembers each `PatientQueue` room's list of (unresolved) `CaseFile`s across scene reloads, and hands admitted patients off from Intake to Treatment - see "Patient flow" above. |
| `SupplyOrders` | Pending ingredient orders and their delivery countdowns - see "Room feature systems" (Supply Room) above. |
| `SFX` | Sound effects - see "Sound effects" below. |
| `CorpseManager` | Corpses, pickup/carry/dispose, and the neglect-to-monster escalation - see "Death, disposal, and what happens if you don't" above. |
| `GameClock` | The Month/Day/Hour calendar and real-time Intake arrivals - see "Game clock & Day Report" below. |
| `Codex` | What the player has personally discovered this run about diseases/cures/dopplegangers - see "The Codex" below. |

## Data-driven content (`scripts/resources/` + `data/`)

Each `scripts/resources/*.gd` is a `Resource` subclass with `class_name`,
edited as `.tres` files under `data/`. `ContentDB` loads them all
automatically - **add new content by creating a new `.tres` in the right
`data/` subfolder in the editor (right-click → New Resource), no code
changes needed.**

- **`SymptomData`** - one observable sign (visual/vitals/smell/etc), can be
  marked `is_red_herring` for misleading tells.
- **`DiseaseData`** - a real illness: its symptom set, severity, contagion,
  which `PotionRecipeData` cures it, how fast it escalates if missed.
- **`PatientArchetypeData`** - a template patients are generated from: name
  pool, portraits, possible diseases, and `doppelganger_chance`.
- **`DopplegangerProfile`** - which archetype a doppelganger hides behind
  and the subtle `tells` (`SymptomData`) that expose it.
- **`IngredientData`** - a stockable alchemy ingredient with tag-like
  `properties` (cooling, toxic, binding, ...).
- **`RecipeIngredientSlot`** / **`PotionRecipeData`** - a cure recipe: which
  ingredients + quantities, what disease it cures, brew time.
- **`CaseFile`** - not hand-authored; the *generated* runtime record for one
  patient's visit (their rolled disease or doppelganger status, symptoms
  shown, and everything discovered about them so far). This is the object
  that flows from Intake through Treatment (or straight to a verdict) - see
  "Patient flow" above.

Example content already in place end-to-end: `symptom_pale_skin` +
`symptom_shallow_breathing` → `disease_marsh_ague` → cured by
`recipe_fever_tonic` (`ingredient_willowbark` + `ingredient_marshroot`).
`archetype_villager` rolls a disease from `possible_diseases` (currently
four: `marsh_ague`, `chill_pox`, `wailing_cough`, `swamp_rot`, each with its
own cure recipe and ingredient pair - `chill_balm`, `cough_syrup`,
`rot_poultice`) or, per `doppelganger_chance`, turns out to be
`doppel_villager_mimic`, exposed by `symptom_flickering_eyes`.
Use these as templates for new content.

`RunManager.STARTING_GOLD` (40) is enough to place two `ORDER_BATCH_SIZE`
supply orders on a fresh run - the cheapest disease's full ingredient
list - so a new run isn't stuck broke before its first delivery lands.

## Minigame plugin contract (`scripts/minigames/minigame_base.gd`)

Examinations are meant to be a set of pluggable minigames, provided later.
The contract:

1. A minigame is a scene whose root script `extends MinigameBase`.
2. It sets its own `minigame_id` (e.g. `&"pulse_check"`).
3. When the player finishes it, it calls `finish(success, result)`, where
   `result` is a free-form `Dictionary` (e.g.
   `{"revealed_symptoms": [...], "score": 0.8}`).
4. `ExaminationController` (`scripts/systems/examination_controller.gd`)
   instances a minigame from its `minigame_registry` (id → `PackedScene`,
   filled in in the Inspector), calls `start(case)`, and listens for
   `finished`. Results get recorded onto the `CaseFile` automatically.

Nothing about Intake Room needs to change as new minigames are added - just
build the scene, extend `MinigameBase`, register it, and swap
`IntakePanel`'s "Inspect Closely" placeholder for a real call into
`ExaminationController`.

## The Codex (`scripts/autoload/codex.gd`, autoload `Codex`)

The player's field notes - deliberately *not* a pre-authored bestiary.
`ContentDB` knows about every `DiseaseData`/`DopplegangerProfile` from the
moment the game boots, but `Codex` starts every run (`start_new_run()`,
called from `RunManager.start_new_run()`) with nothing recorded, and only
learns what the player has actually caused to happen this run:

| Recorded when | Call | Effect |
|---|---|---|
| **Inspect Closely** on a sick patient | `IntakePanel._on_inspect_pressed()` → `Codex.record_disease_seen(disease.id)` | That disease's symptom list is now readable in the Codex. |
| Trying the *right* potion in Treatment | `TreatmentPanel._on_try_pressed()` → `Codex.record_cure_known(disease.id)` | That disease's cure recipe is now named in the Codex and in Treatment's own body text going forward - knowing the symptoms doesn't tell you the cure; a **Try** that actually works does. A wrong **Try** just wastes that potion. |
| **Inspect Closely** on a doppelganger | `IntakePanel._on_inspect_pressed()` → `Codex.record_doppelganger_seen(profile.id)` | That doppelganger's disguise/tells are now readable. |
| **Catching** a loose doppelganger | `HuntManager._resolve(true)` → `Codex.record_doppelganger_seen(profile.id)` | Same, even if it was never Inspected at Intake (a wrongly-Admitted one skips straight to the hunt). |

`scenes/ui/CodexScreen.tscn` (`codex_screen.gd`) is the reader: a
`Panel`/`VBoxContainer`/`TabContainer` styled like `DayReportScreen`, with
**Diseases** and **Dopplegangers** tabs, each rebuilt from `ContentDB`
every time it opens. An entry the player hasn't earned yet renders as
`"???"` with a one-line hint on how to learn it, rather than being hidden
outright - the point is to show *how much* is still unknown, not just
what already is. Toggled from anywhere in `Hospital.tscn` with the
`"codex"` action (`I`, see `project.godot`'s `[input]` section) and closes
on `ui_cancel` or its own Close button; opening it sets
`get_tree().paused = true` (its own `process_mode` is `PROCESS_MODE_ALWAYS`
so it keeps taking input while everything else is frozen - this cascades
to its children too, since `PROCESS_MODE_INHERIT` follows the nearest
ancestor's mode) and closing it unpauses. Won't stack open on top of
another modal panel (Intake/Treatment/Brew/Shop) - see `_other_modal_open()`.

## Roguelike run state (`RunManager`)

- `reputation` - drops hard on a wrong verdict (admit a doppelganger,
  reject a genuine patient); the run ends at 0.
- `gold` - earned on correctly-resolved patients (immediately for healthy
  ones/correct Reject calls, on cure for sick ones - see "Patient flow");
  spend it ordering ingredients in the Supply Room.
- `suspicion` - rises specifically when a doppelganger is admitted
  undetected; the run ends at 100. This is the "something is wrong and it's
  your fault" pressure valve, separate from reputation.
- Difficulty currently scales only via patient count per day
  (`_generate_day_queue`, unused now - see "Game clock & Day Report") -
  obvious next step is scaling `doppelganger_chance` / symptom ambiguity
  by day too.

## Game clock & Day Report

`GameClock` (autoload) owns the actual calendar - Month/Day/Hour - ticking
in real time regardless of scene, same "doesn't care what room you're in"
philosophy as `HuntManager`'s countdown:

- `SECONDS_PER_HOUR` (10s) real seconds per in-game hour, `HOURS_PER_DAY`
  (24) hours per day, `DAYS_PER_MONTH` (30) days per month.
  `format_clock()` → `"M1 D5 14:00"`, shown live in the HUD's corner
  (`hud.gd` polls it every frame, replacing the old static "Day N" label).
- **Intake arrivals are no longer room-scoped.** `GameClock` rolls a new
  `CaseFile` straight into `RoomState.get_queue("IntakeRoom")` every
  `PATIENT_ARRIVAL_INTERVAL` (5s, capped at `MAX_INTAKE_BACKLOG` so
  ignoring the room forever doesn't pile up unboundedly) - whether or not
  Intake Room is even loaded. `PatientQueue` (`patient_queue.gd`) no
  longer rolls its own cases at all now (for *either* room) - it only
  ever materializes a *visible* Patient node for whatever's already
  queued, exactly like it already did for Treatment.
- **Crossing a day boundary** (`HOURS_PER_DAY` hours) calls
  `RunManager.end_current_day()`: freezes the day's `day_stats` into a
  summary, advances `current_day`, resets `day_stats` for the new day,
  then fires `EventBus.day_ended`. `GameManager._on_day_ended()` sets
  `state = DAY_REPORT`, stashes the summary on
  `GameManager.last_day_number`/`last_day_summary` (read directly by
  `DayReportScreen._ready()` - same "autoload holds the handoff data"
  pattern as `pending_spawn_position`), and transitions to
  `scenes/ui/DayReportScreen.tscn`. This finally wires up the
  `EventBus.day_ended` → Day Report path that was a TODO stub before.
- **`day_stats`** (on `RunManager`, reset each day): `cured`/`died`/
  `doppel_rejected`/`doppel_admitted` counts, plus `gold_earned`/
  `gold_spent`/`gold_history` (an array of `{"hour","gold"}` snapshots,
  one per `add_gold()`/`spend_gold()` call). Incremented at the exact
  narrative moment each thing happens - `TreatmentPanel._on_try_pressed()`
  (on a correct **Try**) for `cured`, `Patient.die()` for `died` (covers *both* causes of death
  uniformly), `_apply_verdict_consequences()` for the doppelganger
  counts - not inferred after the fact from generic verdict data.
- **`DayReportScreen`** (`scenes/ui/DayReportScreen.tscn` +
  `day_report_screen.gd`) - a `TabContainer` with two tabs: "Patients"
  (the four counts as plain labels) and "Finances" (earned/spent/net
  labels plus `GoldChart`, a `Control` with a hand-rolled `_draw()` line
  chart - no plotting library - plotting `gold_history` for the day).
  Continue calls `GameManager.continue_after_day_report()`, back to the
  Hospital hub. That call is a no-op if the run already ended (see below)
  - previously it would just silently do nothing with zero feedback,
    indistinguishable from a broken button.
- **`GameOverScreen`** (`scenes/ui/GameOverScreen.tscn` +
  `game_over_screen.gd`) - reputation hitting 0, suspicion hitting 100, or
  player HP hitting 0 (`RunManager._check_game_over()` → `EventBus.
  game_over` → `GameManager._on_game_over()`) transitions here immediately,
  from wherever the player was (mid-shift in Hospital, or already looking
  at a Day Report) - `state = GAME_OVER` is set the same instant. Shows a
  reason-specific message (`GameOverScreen.REASON_TEXT`), the day reached,
  and final reputation/suspicion/gold; the only way out is Return to Main
  Menu, a fresh `RunManager.start_new_run()` - no Continue, the run is
  genuinely over.
- `TransitionScreen.change_scene()` used to silently drop a request that
  arrived while another transition was still fading - harmless normally,
  but a day boundary landing the same instant as a room-door transition
  (a real scenario now that GameClock runs independently of what the
  player's doing) would leave `state` and the visible scene out of sync
  forever. Fixed: a second request while busy is remembered
  (`_pending_target`) and fired the moment the current one finishes,
  instead of dropped.

## Not yet built (intentionally left as TODOs)

Every room now has *basic* logic (see "Room feature systems" and "Patient
flow" above) - what follows is what's still missing or still deliberately
simplified:

- Actual minigames - `scenes/minigames/`, per the `MinigameBase`/
  `ExaminationController` contract above. `IntakePanel`'s "Inspect Closely"
  is a one-button placeholder standing in for these, not a real minigame.
- The old self-contained day-queue (`patient_queue`/`call_next_patient`/
  `submit_verdict`/`start_next_day`/`_generate_day_queue` on `RunManager`)
  is dead code now that `GameClock` drives both real-time Intake arrivals
  and the actual day boundary - see "Game clock & Day Report". Left in
  place, unused, rather than ripped out.
- The Intake→Treatment "walk" is a two-node handoff (see "Movement & the
  merged map"), not one continuous path - a sick-admitted patient's
  original node walks partway into the corridor and despawns while a
  fresh, same-looking node picks up the rest of the trip into Treatment.
  Convincing at normal speed, not literally one continuous walk.
  Similarly, monsters chase via straight-line `move_and_slide()` toward
  their target, not real pathfinding - fine in this map's mostly-straight
  corridors, would need a navmesh for anything more complex.
- A "discharge without curing" option in `TreatmentRoom` - right now an
  admitted patient you can never brew a cure for waits in that queue
  forever (occupying one of its visible slots, though not blocking new
  admits - `RoomState`'s queue array isn't capped, only how many are
  simultaneously *visible* is). Not a functional blocker today given how
  few recipes exist, but worth an escape valve once more diseases do.
- Doppelganger hunt depth - currently one monster, confined to Treatment
  Ward on purpose (see "Room feature systems"), with no difficulty scaling
  with suspicion/day. `EventBus.doppelganger_unmasked` is still unused - reserved for a future
  "correctly identified via a real minigame" moment distinct from the
  hunt-trigger path (`doppelganger_hunt_started`). Only this one specific
  event is wired up so far - a generic "rare random event" framework
  (other event types, a shared scheduler) doesn't exist yet.
- Room door/prop art (`RoomDoor`, `Cauldron`, `SupplyShelf` are all flat
  `ColorRect`s) and dynamically-built shop/brew row UI (plain Godot
  buttons, no `StyleBoxTexture` skin) - see "Art & assets in use" for why
  the door/prop art specifically wasn't pulled from the tileset yet.
- Suspicion isn't shown in the HUD yet (reputation/gold/HP are).
- Save/meta-progression between runs.
- Dialogue/story integration - see `dialogues/README.md`.
