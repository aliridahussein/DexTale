# Architecture

Godot 4.7, GDScript (typed where practical), Compatibility renderer. The viewport is 480×270 and is scaled by whole numbers (×3 windowed, ×4 at 1080p fullscreen).

## Big picture

```
Autoloads (live for the whole session)
  Settings  GameState  QuestManager  DialogueManager  AudioManager  SaveManager  SceneManager  UI(scene)
        │          ▲            ▲              │                                       │
        │   flags  │   flags    │      events / lines                                  │ change_area()
        ▼          │            │              ▼                                       ▼
  ┌──────────────── current scene: an area (GameArea) ───────────────────────────────────────┐
  │ Ground/Overlay TileMapLayers · Objects (y-sorted: Player, NPCs, props) · Interactions     │
  │ (Interactable, EchoPoint) · Encounter (MistPulse) · Triggers (AreaExit, StoryTrigger)     │
  │ · Spawns (Marker2D) · Lights · Effects · Ambient (CanvasModulate) · Mist · Bounds         │
  └───────────────────────────────────────────────────────────────────────────────────────────┘
```

**Rule of thumb:** story state lives in **flags** (`GameState`). Everything else is a view of those flags:
- Objectives and the journal (`QuestManager`).
- Which dialogue branch plays (`"if"` conditions).
- Which interactions are offered (`requires` / `hidden_when`).
- How a scene looks when you re-enter it (open doors, the night lighting, the gate).

## Autoloads

| Autoload | File | Responsibility |
|---|---|---|
| `Settings` | `scripts/autoload/settings.gd` | Volumes, text speed, fullscreen (F11), screen shake, objective HUD. Saved to `user://settings.cfg`. Adds WASD and E to the `ui_*` actions. |
| `GameState` | `scripts/autoload/game_state.gd` | Flags, condition checks (`check("flag>=2")`), the current area, play time, the journal order, and **input locks** (nested, by reason). Emits `flag_changed`. |
| `QuestManager` | `scripts/autoload/quest_manager.gd` | Reads `data/quests/quests.json` and works out active, optional and completed objectives plus discoveries from flags. Emits `objective_changed` and `journal_updated`. |
| `DialogueManager` | `scripts/autoload/dialogue_manager.gd` | Runs conversations from `data/dialogue/*.json`. It emits `line_shown` and `choices_shown`, and waits for `advance()` / `choose()`. Events go to registered handlers. It also has `validate()`, used by the tests. |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Crossfaded music and ambience, a pool of 10 sound-effect voices, buses (Music / Ambience / SFX) and per-area reverb. A missing file only produces a warning. |
| `SaveManager` | `scripts/autoload/save_manager.gd` | One JSON save slot. Saves only when it is safe (no dialogue, cutscene, transition or challenge). Saves are triggered by area changes and objective changes. **V2:** writes go through a verified temp file and keep a `.bak` of the previous save (`validate()` checks every field). `block_saving(reason, owner)` ties a block to a node's lifetime. `why_not_saving()` gives the player a reason. |
| `SceneManager` | `scripts/autoload/scene_manager.gd` | Fades, `change_area(id, spawn, position)`, `goto_scene(path)`, spawn placement and flashes. |
| `UI` | `scenes/ui/ui.tscn` + `scripts/ui/ui.gd` | The HUD (objective, prompts, toasts, area titles, save note), the Echo screen effect, the dialogue box, journal, document reader, pause and settings. It also registers the global dialogue events. **V2 additions:**<br>• `caption(text, world_pos)`: a non-modal line in the world.<br>• `begin_reveal()` / `end_reveal()`: hide prompts and pause toasts while a vision shows.<br>• The reconstruction board and the ritual view. |

## Key scenes and scripts

- **Player** (`scenes/characters/player.tscn`, `scripts/player/`):
  - Movement is a `CharacterBody2D` in floating mode, using normalized input.
  - Facing and animation come from 8 `SpriteFrames` animations.
  - The interaction sensor picks the nearest available `Interactable` in front of Rowan.
  - `walk_to()` drives scripted walks; it gives up if it gets stuck.
  - `player_echo.gd` handles the F ability; `game_camera.gd` handles limits, shake and cutscene pans.
- **NPC** (`scenes/characters/npc.tscn`, `scripts/npc/npc.gd`): one scene for everyone. Configure it with `sprite_frames`, `conversation`, `facing_name`, `wander_radius`, `spectral` (ghost shader) and `present_when`.
- **Interactables** (`scripts/interactables/`):
  - `Interactable` (E) and `EchoPoint` (F) both support `requires` / `hidden_when` and start a `conversation_id`.
  - `AreaExit` is a walk-in transition with an optional lock.
  - `StoryTrigger` is a walk-in conversation, with an optional `once_flag`.
- **Areas** (`scripts/world/game_area.gd` plus one script per area):
  - The base class sets camera bounds, music, ambience and reverb, registers the area's dialogue events, and places the player at the requested spawn.
  - Subclasses implement `_area_ready()` and `area_events()`.
- **Systems** (`scripts/systems/`): `SealPuzzle` is pure logic, which keeps it unit-testable; `MistPulse` is a self-building, telegraphed hazard that you can reuse anywhere. **V2:** `ResonanceRitual` is the pure logic of the bell ritual.
- **Screens** (`scripts/ui/`): `main_menu.gd`, `prologue.gd`, and `ending.gd`, which plays the three ending sequences and builds the epilogue from `data/endings.json`. `ending.gd` exposes `phase` (sequence / title / summary / credits) so tests can check that each ending completes.
- **V2 interaction details:**
  - `Interactable.align_select` picks rows of wall targets by where Rowan stands.
  - `highlight_path` names a sprite that brightens while selected.
  - `important` makes the prompt gold.
  - `requires` accepts `"a, b, !c"`.
- **V2 screens:**
  - `reconstruction_view.gd`: the Echo Reconstruction board, driven by `data/reconstructions.json`.
  - `ritual_view.gd`: the bell ritual, which emits `marks_changed`, `note_sung` and `soured` so the tower can light the bell's marks.

## Dialogue events

A dialogue step `{"event": "name", "args": [...]}` calls a registered `Callable`. The conversation **waits** if the handler is a coroutine (it uses `await`) or returns a `Signal`.

- **Global events** (registered by `UI`): `toast`, `sfx`, `music`, `ambience`, `shake`, `flash`, `open_document`, `fade_out`, `fade_in`, `echo_effect`, plus V2's `reconstruct` and `caption_here`.
- **Area events** (returned by each area's `area_events()`):

| Area | Events |
|---|---|
| Village | `pip_face_rowan`, `pip_face_tower`, `pip_hum`, `gate_open`, `well_memory`, `well_memory_end` |
| Forge | `mara_hammer`, `mara_show_pin`, `mara_give_pin` |
| Chapel | `archive_open`, `alden_enter` |
| Mist path | `sentinel_stir`, `sentinel_challenge`, `sentinel_fade` |
| Tower | `install_pin`, `bell_resonate`, `orin_appear`, `orin_look_bell`, `show_vista`, `bell_ritual`, `ending` |

`tests/test_data.gd` fails if a conversation uses an event that has no handler.

## Flow of a typical interaction

1. The player presses **E**, and `Player._unhandled_input` calls `Interactable.interact()`.
2. That calls `DialogueManager.start(id)`, which locks input with the reason `"dialogue"`.
3. The `DialogueBox` shows each line with the typewriter effect; the player presses advance, which calls `DialogueManager.advance()`.
4. A `{"set": {...}}` step calls `GameState.set_flag()`, which emits `flag_changed`. In response:
   - `QuestManager` may emit `objective_changed`, which makes the UI show a toast.
   - `SaveManager` requests an autosave, which happens once the conversation ends.
   - Area scripts react: lighting changes, the gate opens, NPC visibility updates.

## Rendering and layering

- The `Objects` node is y-sorted. Every prop's origin is its base, which drives the sorting.
- `Effects` (z 6) holds light shafts and particles. `Mist` (z 10) is the shader fog.
- UI sits on separate CanvasLayers:
  - 5: vignette and Echo effect
  - 10: HUD
  - 12: the tower's vista
  - 15: dialogue
  - 20: menus
  - 100: fades
- Lighting uses a `CanvasModulate` per area plus `PointLight2D` lights, some with `flicker_light.gd`. The shaders are in `assets/shaders/`: mist, spectral, echo overlay and dissolve.

## Content pipeline

The art and audio are generated by Python scripts in `tools/` (requires Pillow, NumPy and SciPy). Godot ignores that folder via `.gdignore`.

1. **`tools/art/*.py`** produces the PNGs: tiles, characters, props, portraits, the font, UI art and backgrounds.
2. **`tools/build/build_resources.py`** produces the tileset (with collision and footstep "surface" data), sprite frames, prop scenes, the player and NPC scenes, and the theme.
3. **`tools/build/build_ui.py`** produces the UI scenes and screens.
4. **`tools/build/levels.py`** produces the five area scenes. ⚠️ It overwrites any editor changes to them.
5. **`tools/audio/generate_audio.py`** produces the WAVs. Music and ambience carry loop points (a `smpl` chunk) that Godot detects on import.

Once you start editing a scene in the editor, treat the editor copy as the source of truth. Use the generators only for new assets.
