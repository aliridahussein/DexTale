# The Thirteenth Bell

*Every night the bell saves the village. Every night, someone forgets why.*

A short medieval dark-fantasy mystery made in **Godot 4.7.2** (GDScript, Compatibility renderer). Rowan comes home to Dawnmere the night its bell falls silent and learns what the bell has been taking. The game has:
- seven areas;
- an Echo ability for hearing the past;
- a seal puzzle;
- a guardian with two ways past it;
- a broken drawbridge guarded by something that notices light;
- three endings.

A first play takes about 15 to 25 minutes. That is an estimate; there have been no timed playtests yet.

**This is Prototype V2.2** (branch `feature/watchmans-crossing`, built on V2's `prototype-v2`). It adds **the Watchman's Crossing** between the Sentinel and the tower:
- an inventory, and a drawbridge to repair with tools found in the guard's watchhouse;
- a winch to work at safe tension;
- a short stealth crossing past the Watchman's Shadow, using light and cover;
- an optional mystery that can put the Shadow to rest.

See [docs/V2_2_CHANGELOG.md](docs/V2_2_CHANGELOG.md) and [docs/WATCHMANS_CROSSING_DESIGN.md](docs/WATCHMANS_CROSSING_DESIGN.md).

V2 fixed the defects from the independent QA audit and added the well mystery and the bell ritual ([docs/V2_RELEASE_NOTES.md](docs/V2_RELEASE_NOTES.md)). V1 is tagged `v1-baseline`.

![The village square at sunset](docs/screenshots/07_village_sunset.png)

## Run it

1. Godot is at `C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\`.
2. Open the editor, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** to play from the title screen. To test one area, open it in `scenes/world/` and press **F6**.

Run the tests (75 tests in 11 suites, about 10 minutes; add `-- --suite=test_crossing` for one suite, or `--test=sneaking` for matching tests):

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
```

Run the visual tour, which plays through the whole game in a window, checks that every ending completes, and saves screenshots to `docs/screenshots/v2/`. The crossing's section saves to `docs/screenshots/v2_2/`. Add `-- --only=story`, `v2`, `crossing` or `endings` to run one section.

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path . res://tests/tour.tscn
```

Export templates for 4.7.2 are installed on this machine. *Project → Export* has two presets: *Windows Desktop* and *Web* (single-threaded, for any static host). [docs/V2_RELEASE_NOTES.md](docs/V2_RELEASE_NOTES.md) has the command-line builds and how to test the web build locally.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrow keys | D-pad / left stick |
| Interact | E | A |
| Listen to the Echo | F | X |
| Journal | J | Y |
| Inventory (V2.2) | I | Back / View |
| Lantern shutter (V2.2) | L | LB |
| Advance dialogue | Enter / Space / E | A |
| Pause | Esc | Start |
| Fullscreen | F11 | |

Inside the journal: W/S scrolls and A/D switches pages. On the reconstruction board: W/S chooses an answer and E decides. In the bell ritual: W/S sings higher or lower and E sings the circled note.

V2.2 screens:
- **Inventory:** arrows/WASD choose, E selects and does an action (Inspect, Hold, Combine, Shutter). The mouse works too.
- **Winch:** hold A/D to slacken or tighten (or hold the on-screen labels), E releases the weight.

Esc steps back from any of them. Gamepad bindings are untested.

## Folder structure

```
project.godot            settings, input map, autoloads
scenes/world/            seven areas (village, forge, chapel, mist_path, crossing, watchhouse, bell_tower)
scenes/characters/       player.tscn, npc.tscn (one NPC scene for everyone)
scenes/interactables/    drop-in Interactable / EchoPoint / AreaExit / StoryTrigger
scenes/props/            82 props (each with sprite, collision, optional light)
scenes/ui/, scenes/main/ HUD, dialogue box, journal, menus, prologue, ending
scripts/autoload/        GameState, QuestManager, DialogueManager, SaveManager, ...
scripts/world/           game_area.gd (base) + one script per area
scripts/systems/         seal_puzzle.gd, mist_pulse.gd, resonance_ritual.gd (V2), winch_puzzle.gd (V2.2)
data/                    ALL story content as JSON (dialogue, quests, documents, endings, flags,
                         reconstructions, items)
assets/                  generated art, font, shaders, audio
tests/                   test runner, 11 suites, shared driver, V1 save fixtures, visual tour
tools/                   Python generators for art, scenes and audio (ignored by Godot)
docs/                    GAME_DESIGN, ARCHITECTURE, QA_REPORT, NEXT_STEPS, screenshots
```

For how the pieces fit together, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## How to…

**Add dialogue.** Edit `data/dialogue/*.json`. A conversation is a list of steps:

```json
"baker": [
	{"if": "met_baker", "goto": "again"},
	["baker", "Bread's fresh. Memories, less so."],
	{"choice": [
		{"text": "I'll take a loaf.", "set": {"bought_bread": true}, "goto": "buy"},
		{"text": "Just looking.", "goto": "bye"}
	]},
	{"label": "buy"}, ["baker", "Two coins."], {"end": true},
	{"label": "bye"}, {"set": {"met_baker": true}},
	{"label": "again"}, ["baker", "Back again?"]
]
```

- **Steps:** a line `[speaker, text]`, `choice`, `label`, `goto`, `set`, `event`, `wait`, `run`, `end`.
- **Any step** can carry an `"if"` condition.
- **Line text** supports BBCode (`[wave]`, `[color]`) and `{p}` for a short pause.
- **Speakers** live in `data/speakers.json`.
- **New flags** go in `data/flags.json`, or the tests fail (that catches typos).

**Add an NPC.** Instance `scenes/characters/npc.tscn` under an area's `Objects` node and set its exports:
- `sprite_frames`: a `SpriteFrames` with `idle_*` / `walk_*` animations.
- `conversation`, `facing_name`, and optionally `wander_radius`.
- `spectral`, for a ghost.
- `present_when`, so it only appears while a condition holds.

**Add an interaction.** Instance `scenes/interactables/interactable.tscn`, or `echo_point.tscn` for an F-reveal, under `Interactions`, then set:
- `conversation_id` and `prompt`.
- `requires` / `hidden_when` conditions.

For custom behaviour, connect to its `interacted` signal in the area script.

**Add an area.**
1. Duplicate an area scene; keep the node layout described in `scripts/world/game_area.gd`.
2. Set `area_id`, `display_name`, `music`, `ambience` and `bounds`.
3. Register the scene in `GameState.AREAS`.
4. Add `Spawns/<name>` markers.
5. Connect areas with `AreaExit` nodes (`target_area` + `target_spawn`).

**Add a quest step.** Add an objective to `data/quests/quests.json` with `start` and `done` conditions. Add journal entries under `discoveries` with a `when` condition. Nothing else is needed: progress is derived from flags.

**Add an Echo Reconstruction** (a clue board like the one at the well).
1. Add an entry to `data/reconstructions.json`: clues with `when` conditions, and answers where every wrong answer names the clue that rules it out.
2. Open the board from dialogue with `{"event": "reconstruct", "args": ["<id>"]}`.

The steps and design rules are in [docs/V2_GAMEPLAY_DESIGN.md](docs/V2_GAMEPLAY_DESIGN.md).

**Add an ending.**
1. Add it to `data/endings.json` (title, lines, epilogue lines).
2. Add a choice that sets `ending_selected` and fires the `ending` event (see `orin_decide` in `data/dialogue/tower.json`).
3. Add its visual sequence to `scripts/ui/ending.gd` and `scripts/world/bell_tower.gd`.

**Change art or audio.** Replace a PNG or WAV with the same name and size. To regenerate everything (needs Python 3 with Pillow, NumPy and SciPy), run:

```powershell
cd tools\art; python tiles.py; python characters.py; python props.py; python ui_art.py
cd ..\build; python build_resources.py; python build_ui.py; python levels.py
cd ..\audio; python generate_audio.py
```

⚠️ `levels.py` rewrites the seven area scenes, so skip it once you've edited areas in the editor.

## Status (Prototype V2.2)

- **Working and tested:**
  - The Watchman's Crossing, played through on both routes past the Sentinel: the repair and the winch, sneaking past the Shadow, being caught and recovering, and the optional Last Promise.
  - The inventory.
  - Old saves.
  - Leaving mid-scene.
  - The tests cover all of it: 75 automated tests, a windowed tour of 35 screenshots, and a web build played in a browser.
- **Not yet done:**
  - No human playtest of the crossing yet ([docs/V2_2_PLAYTEST_GUIDE.md](docs/V2_2_PLAYTEST_GUIDE.md)).
  - The tuning values are first-pass.
  - Browser frame rate and smoothness are unverified.
  - Gamepad is untested.
  - Details: [docs/WATCHMANS_CROSSING_QA.md](docs/WATCHMANS_CROSSING_QA.md).

| V2.2 document | For |
|---|---|
| [docs/V2_2_CHANGELOG.md](docs/V2_2_CHANGELOG.md) | Features, source changes, integration decisions, compatibility |
| [docs/WATCHMANS_CROSSING_DESIGN.md](docs/WATCHMANS_CROSSING_DESIGN.md) | The encounter: places, bridge, winch, lantern, Shadow, the Last Promise |
| [docs/INVENTORY_SYSTEM.md](docs/INVENTORY_SYSTEM.md) | Items, use, combinations, persistence, adding items |
| [docs/WATCHMANS_CROSSING_QA.md](docs/WATCHMANS_CROSSING_QA.md) | Test cases, actual results, known issues, what is unverified |
| [docs/V2_2_PLAYTEST_GUIDE.md](docs/V2_2_PLAYTEST_GUIDE.md) | Running a playtest of the crossing with 3–5 new players |

### Prototype V2 (unchanged by V2.2)

- **Working and tested:**
  - The complete game from the title screen to all three endings.
  - The V2 mystery and the bell ritual.
  - Crash-safe saves that still load V1 saves.
  - 48 automated tests pass, including every ending through its card, epilogue and Return to Title.
  - The windowed tour runs with no errors.
  - The web build was played in a browser through a new game, saving and Continue, The Keeper, and the ritual into The Chorus.
- **Not yet done:**
  - No human playtest yet.
  - Nobody has listened to the audio.
  - Gamepad is untested.
  - Browser frame rate and fullscreen are unverified.

| Document | For |
|---|---|
| [docs/V2_RELEASE_NOTES.md](docs/V2_RELEASE_NOTES.md) | What's new, how to run and build, known limitations |
| [docs/V2_CHANGELOG.md](docs/V2_CHANGELOG.md) | Every change, with the audit's issue IDs |
| [docs/V2_QA_REPORT.md](docs/V2_QA_REPORT.md) | Test cases, results, evidence, what is still untested |
| [docs/V2_GAMEPLAY_DESIGN.md](docs/V2_GAMEPLAY_DESIGN.md) | Echo Reconstruction and the ritual, and how to reuse them |
| [docs/V2_PLAYTEST_GUIDE.md](docs/V2_PLAYTEST_GUIDE.md) | Running a playtest with 3–5 new players |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md) | How the code fits together; the road ahead (from V1) |
