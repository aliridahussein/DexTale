# Prototype V2.2: changelog (the Watchman's Crossing)

V2.2 adds one new encounter between the Hollow Sentinel and the bell tower. The road ends at a ravine with a raised, broken drawbridge and a guard's empty watchhouse. Across it, once the bridge is down, something walks the old guard's round.

The point of V2.2 is for the player to *do* things:
- find tools and combine them;
- repair a mechanism and work it;
- cross under mild pressure, fail fairly and try again;
- optionally, discover that the frightening figure is a forgotten person keeping an old promise.

The story, the other areas, the art direction, the controls and all three endings are unchanged.

- **Branch:** `feature/watchmans-crossing`, cut from `prototype-v2` at `068fa1c` (V2 milestone 3).
- **Not committed, pushed or deployed.** The public website and the repository's `web/` folder are untouched.

## Features

**The Watchman's Crossing and the watchhouse:**
- two new areas, generated with the existing tools in the existing style;
- the Mistbound Path's north road now leads there, from either way past the Sentinel;
- the bridge leads on to the tower, and the tower's stairs lead back down.

**Inventory** (I):
- a reusable, data-driven inventory (`data/items.json`) built as a view over story flags, so it can't drift out of sync and needs no new save fields;
- Inspect, Hold (to use on something in the world), Combine (in either order) and Shutter;
- refusals that explain themselves and never lose an item;
- keyboard and mouse support;
- the existing Iron Tuning Pin and Iron Key (and V2's Tobin's lantern) appear in it automatically.

**New items:**

| Item | Where | Notes |
|---|---|---|
| Old Lantern | Watchhouse | Taken lit, never needs fuel; **L** opens and closes the shutter. |
| Strong Rope, Iron Hook | Watchhouse | Combine into the **Hooked Line**. |
| Watchman's Token | Watchhouse | Optional. |

**The bridge** (three states that only move forward):
- **The clues:** the broken chain, a winch that refuses to drop an unrepaired bridge, the guard's logbook ("When the lower chain fails, secure it before releasing the weight. The bridge must never fall freely."), and the winch's Echo (hook first, then the wheel).
- **The repair:** the Hooked Line thrown down to catch the chain.
- **The winch:** a tension gauge with loose, SAFE and tight zones, told apart by pattern and text as well as colour. Resistance grows as the chain tightens. A wrong release fails harmlessly and says why. Logic is in `WinchPuzzle`, deterministic and unit-tested.
- **The lowering:** a camera pan, the counterweight, the span folding down, a thud, dust and shake, then the reveal.

**The Watchman's Shadow** (stealth):
- **States:** a state machine (PATROL, SUSPICIOUS, INVESTIGATE, RETURN, RESOLVED, plus DORMANT and QUIET), on a fixed round.
- **Sight** needs range (120 px with the lantern open, 44 px closed), a ±62° cone and a clear line against world collision, so the stone supports hide Rowan.
- **Warning:** awareness rises and decays. A "?" warning, an amber-tinted cone and a sound come well before capture.
- **Rotten planks:** two half-planks creak and bring it to look, from its own bank. The lantern reveals them.
- **Capture:** sends Rowan back to the bridge head and keeps everything. Hints follow repeated catches.

**The Last Promise** (optional):
- **The clues:** the token, two Echoes (the chair, the post) and the tally marks.
- **The deduction:** "What was the Watchman waiting for?" on the existing Echo Reconstruction board, with retryable wrong answers.
- **The ending of the thread:** placing the token at the post puts the Shadow to rest ("He no longer remembers her face. But he remembers that he waited.").
- **Echoes elsewhere:** Orin acknowledges it, and every ending's epilogue remembers it.

**Journal:**
- new objective: "Find a way across the old crossing.";
- two optional objectives;
- eight new journal entries.

**Sounds:** creak, chain rattle, winch click, the Shadow's alert, the bridge's thud (generated; existing sounds unchanged).

## Source changes

**New scripts:**

| File | Role |
|---|---|
| `scripts/autoload/inventory.gd` | `Inventory` autoload |
| `scripts/interactables/item_pickup.gd`, `item_target.gd` | Things to take, things to use items on |
| `scripts/systems/winch_puzzle.gd` | Pure winch logic |
| `scripts/ui/inventory_view.gd`, `winch_view.gd` | The two new screens |
| `scripts/world/crossing.gd`, `watchhouse.gd`, `watchman_shadow.gd` | The areas and the Shadow |

**New data and scenes:**
- **Data:**
  - `data/items.json`;
  - `data/dialogue/crossing.json`;
  - new entries in `documents.json` (the logbook), `reconstructions.json` (`watchman_promise`), `speakers.json` (child, Edrin), `quests.json`, `endings.json`, `flags.json`;
  - an Orin branch in `dialogue/tower.json`.
- **Scenes and art:** `crossing.tscn`, `watchhouse.tscn`, `inventory_view.tscn` and `winch_view.tscn`, plus props, tiles, the Shadow's sprite sheet, item icons and sounds. All generated.

**Changed:**

| File | Change |
|---|---|
| `project.godot` | `Inventory` autoload; `inventory` (I, Back) and `lantern` (L, LB) actions |
| `scripts/autoload/game_state.gd` | Two new areas registered |
| `scripts/player/player.gd` | The lantern (light, carried sprite, L). `teleport()` ends a scripted walk properly. A walk's last step lands exactly on its target. |
| `scripts/ui/ui.gd` | Inventory and winch screens; "Received" toasts for pickups; the Holding and Lantern chips; captions lift above prompts |
| `scripts/interactables/interactable.gd` | `prompt_text()`, so prompts can name the held item |
| `scripts/world/bell_tower.gd` | Marks the crossing done on arrival (older saves) |
| `scripts/ui/main_menu.gd` | Save names for the new areas |
| `tools/art/*.py`, `tools/audio/generate_audio.py`, `tools/build/*.py` | New content, always appended after existing entries, so every existing generated file stays byte-identical |
| `tools/build/levels.py` | The two new areas. The Mistbound Path's road north. The tower's exit now leads to the crossing, and its stairwell is opened. |
| Tests | Two new suites (`test_inventory`, `test_crossing`); the playthroughs now cross; data checks for items; `--test=` filter; the tour's crossing section |

## Integration decisions

- **Inventory as a view over flags.** No second list. Ownership is a condition (`"found_rope, !made_hooked_line"`). Pickups set a `found_flag` that is never cleared, which makes duplicates impossible.
- **The existing items join the inventory as they are.** The pin's and key's flags are unchanged. The pin leaves the inventory only when it is installed in the bell, so it can never be lost before the tower.
- **Reuse before adding:**
  - the deduction uses V2's Reconstruction board;
  - clues use the Echo system;
  - captions use V2's non-modal `UI.caption()`;
  - capture uses V2's owner-bound save blocks.
- **The ravine is a collision body on a different layer from the Shadow's sight**, so Rowan can't cross it but the Shadow can see over it.
- **Every scene releases what it holds.** If the area is freed mid-scene (title, load, restart), its input locks are released, and save blocks end with their owner.
- **Determinism for tests.** `WinchPuzzle` is pure. The Shadow has `start_at(i)` for exact positions. No randomness drives either.

## Compatibility

- **Saves:** same format (`version: 1`) with V2's crash-safe write. No new fields: the crossing's state is flags.
- **V1 and V2 saves in the tower:** the tower marks the crossing as done on arrival, so the objective resumes at "Confront the truth of the bell". Going back down finds the bridge lowered and the Shadow quiet.
- **V2 saves on the Mistbound Path past the Sentinel:** they continue into the crossing.
- **Exports:**
  - **Web:** `builds/web_v2_2/`, single-threaded preset. Played in a browser (see the QA report).
  - **Windows:** `builds/windows_v2_2/`. Exports and boots.

  Both are local only (`builds/` is git-ignored).
- **The public website** (`web/` and the Vercel deployment) is unchanged.

## Bugs fixed

Defects found while testing V2.2 are listed in `WATCHMANS_CROSSING_QA.md` §3 (V22-01 to V22-11). The most important was that the bell tower's way down had been walled in since V1.

## Tests

- **Automated:** 75 tests in 11 suites, all passing (was 48 in V2):
  - 12 inventory tests;
  - 14 crossing tests;
  - a data check for items;
  - both playthroughs extended through the crossing.
- **Visual tour:** a crossing section with 35 screenshots (`docs/screenshots/v2_2/`).
- **Results and what is unverified:** `WATCHMANS_CROSSING_QA.md`.
