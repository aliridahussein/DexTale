# The Watchman's Crossing (V2.2): QA report

> Everything below was run by developer tooling: automated tests, a windowed bot, and a scripted browser session on a local web build. **No human playtest has been done.** Nothing here measures whether the crossing is fun, clear or fairly tuned for real players. That is the job of `V2_2_PLAYTEST_GUIDE.md`.

Branch `feature/watchmans-crossing`, based on `prototype-v2` (V2 milestone 3, `068fa1c`). Godot 4.7.2, Windows 11.

## 1. What was run

| Method | What it covers | Result |
|---|---|---|
| Headless automated suite (`tests/test_runner.tscn`) | 75 tests in 11 suites. They drive the real scenes through the same interactables, exits, Echo, dialogue and input actions a player uses. | **75 passed, 0 failed**, no engine or script errors (final run, after all fixes). |
| Windowed visual tour (`tests/tour.tscn -- --only=crossing`) | The whole crossing in a real window, with 7 checks along the way. | **0 engine/script errors, 0 failed checks.** 35 screenshots in `docs/screenshots/v2_2/`, reviewed by eye. |
| Interactive browser session | The `Web` export in the Claude desktop app's in-app browser (Chromium), with keyboard events on the game canvas and real mouse clicks. | See §5. |
| Windows export | `Windows Desktop` preset → `builds/windows_v2_2/`, then a headless boot to the title for 900 frames. | Exports; boots with no script errors. |

## 2. Test cases and actual results

These follow the brief's QA list. "Test" names are methods in `tests/`; "tour NN" is a screenshot in `docs/screenshots/v2_2/`.

### Inventory

| Case | Evidence | Result |
|---|---|---|
| Inventory opens and closes | `test_inventory.test_inventory_screen_by_keyboard_without_moving_rowan`: I opens it and pauses the game; I and Esc close it. Browser: opened with I. | Pass |
| Controls don't leak into movement | Same test: arrows, E, Esc and I pressed through the real input path, then Rowan's position is unchanged. Browser: keys during the bridge scene were ignored. | Pass |
| Items can be collected | `test_pickups_happen_once_and_stay_taken`; `complete_crossing()` in both playthroughs takes the lantern, rope, hook and token; tour 06. | Pass |
| Items can't be collected twice | Same test: a second press does nothing, `give()` refuses, and the pickup stays gone after leaving and returning. | Pass |
| Items can be inspected | Browser: Inspect on the key shows its text. `test_the_last_promise`: inspecting the token opens its board. | Pass |
| Valid combinations work | `test_combining_in_either_order` (both orders); the keyboard flow test; both playthroughs. | Pass |
| Invalid combinations fail safely | `test_wrong_combinations_explain_and_keep_both`: 6 pairs, each with a reason; nothing lost; the pin is kept. | Pass |
| Items can be used on world objects | `test_hold_an_item_and_use_it_on_the_world`; `test_pressing_e_with_nothing_held_uses_the_obvious_item`; the token on the post. | Pass |
| Inventory survives scenes and save/load | `test_inventory_survives_save_and_load`; the pickups test (area changes); browser (Continue). | Pass |
| The existing key and tuning pin still work | `test_existing_items_follow_their_flags`; `test_v1_saves_have_the_right_inventory`. In the full playthrough, the pin is still carried after the crossing and goes into the bell. | Pass |

### Bridge

| Case | Evidence | Result |
|---|---|---|
| Bridge starts raised | `test_crossing.test_bridge_starts_raised_and_the_winch_waits_for_the_chain` (and Rowan's body can't move into the ravine). | Pass |
| Winch is unusable at first | Same test: the winch only explains; calling its event directly is refused too. | Pass |
| Repair needs the right item | `test_hold_an_item_and_use_it_on_the_world`: the held pin is refused with its own line. Looking at the chain with no line changes nothing. | Pass |
| Wrong items don't break progress | Same test: the pin is kept in hand and the chain is untouched. | Pass |
| Tension puzzle works | `test_winch_tension_fails_safely_then_lowers_the_bridge`; `test_winch_logic_is_deterministic` (zones, edges, resistance, creep, no change after release). Browser: keyboard hold, and release by both mouse and E. | Pass |
| Invalid tension doesn't softlock | Releasing too loose and too tight both fail, say why and stay adjustable; Esc steps back and the winch can be retried. | Pass |
| A safe release lowers the bridge | Same test; tour 16–18; browser. | Pass |
| Lowered-bridge collision updates | `test_move` with Rowan's real body, before and after; every leg of the sneak route is checked for walls; both playthroughs walk across. Browser: walked onto the deck, and the ravine edges still block. | Pass |
| Bridge state survives save/load | `test_the_bridge_stays_down` (watchhouse, save/load, leaving the area). Browser: manual save, reload, Continue, still down. | Pass |
| Bridge stays down after a failed sneak | `test_capture_returns_to_the_bridge_head_and_keeps_everything`; `test_area_change_mid_capture_and_mid_lowering_leaves_no_locks` (its state is saved before the animation). | Pass |

### Stealth

| Case | Evidence | Result |
|---|---|---|
| Shadow patrols predictably | Fixed round, speed and pauses. `start_at(i)` gives the tests exact positions, and the warning test follows a full patrol cycle. | Pass |
| The lantern changes detection | `test_shadow_sight_lantern_and_pillars`: the same spot is seen at 93 px with the lantern open and missed with it closed. Also the near radius, the area behind it, and outside the cone. | Pass |
| No detection through solid cover | Same test: a stone support between them blocks sight; stepping out of its shadow is seen. | Pass |
| Suspicion gives clear feedback | `test_warning_investigation_and_return`: "?" before anything else, with awareness below 1. Tour 21–22: "?" and an amber cone. | Pass |
| Investigation works | Same test: it walks to where it last saw Rowan. `test_a_creaking_plank_draws_the_shadow_to_the_bridge_head`: a creak brings it to the bridge head, never over the ravine. | Pass |
| It returns to patrol | Both tests: RETURN → PATROL, calm again. | Pass |
| Rowan can cross undetected | `test_sneaking_across_reaches_the_tower` (shutter closed, around the planks, real movement); the endure-route playthrough; tour 26. | Pass |
| Being caught resets to a safe checkpoint | `test_capture_returns_to_the_bridge_head_and_keeps_everything`: back at the bridge head, the Shadow back on its round. | Pass |
| Inventory survives capture | Same test: the item list is identical. | Pass |
| Repeated failures are recoverable | Same test: three catches, and the hints after the 2nd and 3rd ("stone pillars…", "shutter closed (L)…"). | Pass |
| Returning to the title leaves no broken state | `test_title_mid_capture_leaves_no_locks`; `test_area_change_mid_capture_and_mid_lowering_leaves_no_locks` (no input lock or save block survives; Continue works). | Pass |

### The optional investigation

| Case | Evidence | Result |
|---|---|---|
| Token can be collected | The peaceful `complete_crossing()` (full playthrough); tour 06. | Pass |
| Echo clues trigger | `test_the_last_promise`: the post and chair Echoes, and the tally. | Pass |
| The deduction works | Same test: with only the token, the board asks for more and can be put away; with all three clues it can be answered. | Pass |
| Wrong answers can be retried | Same test: two answers ruled out with their reasons, then the right one. | Pass |
| Peaceful resolution ends the threat | Same test: RESOLVED; standing right in front of it for 3 s is safe; the post is done with. | Pass |
| Resolution survives reloading | Same test: save, reset, Continue, still RESOLVED. | Pass |
| Skipping it doesn't block progress | `test_sneaking_across_reaches_the_tower`; the endure-route playthrough reaches the tower without the token. | Pass |
| Orin and the epilogue react | Full playthrough: Orin's new hub line (`told_orin_watchman`), and the Chorus epilogue line. `test_the_last_promise`: the watchman line in all three endings' epilogues, and none without it. | Pass |
| Still possible after crossing (added) | `test_the_promise_can_be_kept_after_crossing`. | Pass |

### Regressions

| Case | Evidence | Result |
|---|---|---|
| Sentinel, peaceful route | `test_playthrough.test_full_story_to_the_chorus_ending` (from New Game). | Pass |
| Sentinel, endure route | `test_endure_route_and_no_softlock`, now continuing over the crossing by stealth. | Pass |
| Both routes enter the crossing | Both playthroughs step onto the Mistbound Path's north exit; the objective becomes "Find a way across the old crossing." | Pass |
| Bell Tower entry | Both playthroughs, plus the sneaking test. The tower's stairs now also lead back down (see V22-01). | Pass |
| The Keeper | `test_endings.test_keeper_completes`; `test_other_endings_play`. | Pass |
| The Unbroken Promise | `test_endings.test_promise_completes`; `test_other_endings_play`. | Pass |
| The Chorus | `test_endings.test_chorus_completes`; the full playthrough, including the ritual. | Pass |
| Journal | `test_ui.test_journal_pages_scroll_independently`; the new objectives in `test_state.test_objectives_follow_flags`. | Pass |
| Echo | `test_ui` vision tests, `test_v2`, and the new Echoes in the crossing tests. | Pass |
| Save/load | All V2 `test_save` cases (crash-safe writes, `.bak`, invalid data refused, two genuine V1 saves), plus the new cases above. | Pass |
| Return to Title | `test_save.test_title_during_mist_trial_releases_saving`; `test_title_mid_capture_leaves_no_locks`. | Pass |
| Browser export | §5. | Pass for the functional checks; some items unverified |
| Old saves | V1 saves in the tower: objective "truth" (`test_save`). Going back down finds the bridge lowered and the Shadow quiet (`test_old_saves_come_down_to_a_lowered_bridge`). A V2 save on the Mistbound Path continues into the crossing (browser). | Pass |

## 3. Defects found and fixed during V2.2 testing

| ID | Severity | What was wrong | Fix | Verified by |
|---|---|---|---|---|
| V22-01 | High (since V1) | The bell tower's way down was unreachable. Its stairwell row was solid wall, so the exit there could never be touched. With the crossing, this would have stranded old tower saves upstairs and locked the optional thread after crossing. | Opened the stairwell tiles in `levels.py`. Only the tower's tile row changed; every other scene is byte-identical. | `test_sneaking_across_reaches_the_tower`, `test_old_saves_come_down_to_a_lowered_bridge`, tour 33–35. |
| V22-02 | Medium (tests); latent in the game | A scripted walk could overshoot its target when a physics step was larger than the 1.5 px arrival window, and bounce forever. This happened at the tests' 6× speed (7.4 px steps); at normal speed a step is about 1.2 px. | A step that would overshoot lands exactly on the target. | The walk-based tests (they hung before the fix). |
| V22-03 | Medium | `teleport()` cancelled a scripted walk without emitting `arrived`, so anything waiting on that walk waited forever. Being caught mid-walk would have done this. | `teleport()` ends the walk properly. | `walk_path()` now returns early instead of hanging. |
| V22-04 | Medium | A refusal caption at a target covered the target's own prompt ("Not yet…" over "E Use Watchman's Token"), and both became unreadable. | Captions lift above any prompt they would overlap, rechecked every frame. | Overlap check in `test_the_last_promise`; tour 27. |
| V22-05 | Low | When investigating, the Shadow walked straight out over the ravine. | Investigation targets are clamped to its own bank. | `test_a_creaking_plank_draws_the_shadow_to_the_bridge_head`. |
| V22-06 | Low | The pin, key and Tobin's lantern would have shown a second "Received" toast on top of their scenes' own. | Inventory toasts are only for pickups. | `test_story_items_do_not_toast_twice`. |
| V22-07 | Low | A wrong item used on the world fell back to "Those don't go together.", which reads oddly there. | The item's own line, or "That won't help here." | `test_hold_an_item_and_use_it_on_the_world`. |
| V22-08 | Low | The Shadow's "?" was small for the main warning sign. | Pixel-doubled "?" and "!". | Tour 22 (visual). |
| V22-09 | Low | The bridge-lowering scene didn't lock input, and the crossing's own scene locks weren't released if the area was freed mid-scene. | A "bridge" lock; all crossing locks are released on exit. | `test_area_change_mid_capture_and_mid_lowering_leaves_no_locks`. |
| V22-10 | Low | The optional "give him back what he waited for" objective hid itself after crossing, although the action still worked. | It now stays until done. | `test_the_promise_can_be_kept_after_crossing`. |
| V22-11 | Low | The Shadow's visuals still ticked while it was at peace. | `_process` runs only while it is hostile. | Code; all stealth tests. |

Found and fixed earlier in development (before the tests above existed):
- the vision cone was hidden under the ground layer;
- the rotten-plank marks showed over the open ravine;
- the HUD's carry bar overlapped the winch panel;
- a parse error from an untyped `round()`;
- the tour's own winch script over-tightened (the game correctly refused).

## 4. Visual review

All 35 tour screenshots in `docs/screenshots/v2_2/` were looked at:

| Shots | What they show |
|---|---|
| 01–05 | Arrival, the raised bridge, the chain's prompt, the winch's Echo, the watchhouse |
| 06–10 | The items taken, the chair's memory, the inventory and combining |
| 11–18 | Holding the line, the repair, the winch states (including a refused release), the bridge lowering, the Shadow revealed |
| 19–21 | The cone with the shutter open and closed, a creak |
| 22–26 | The "?" warning, a capture, the bridge head after it, the hint, sneaking |
| 27–32 | The early "Not yet", the post's memory, the board, a wrong answer, the Shadow at peace, the far bank |
| 33–35 | The tower, its open stairwell, back down at the crossing |

The new art uses the existing palette, outlines and lighting. Nothing looked placeholder.

## 5. Browser test (web export)

**Method:**
- The `Web` preset was exported to `builds/web_v2_2/`, served from `127.0.0.1:8062`, and played in the Claude desktop app's in-app browser (Chromium).
- Input: keyboard events sent to the game canvas (held keys used real keydown and keyup pairs) and real mouse clicks.
- To reach the crossing quickly, checkpoint saves were written into the page's IndexedDB (`/userfs`) in the format the game itself writes. This was checked against the game's own autosave. V2 used the same synthetic-checkpoint approach.
- The public website and the repository's `web/` folder were **not** touched.

**Important limitation:** the in-app browser pane was hidden for the whole session. The page therefore rendered no frames on its own (`requestAnimationFrame`: 0 frames in 3 s), and the game advanced only when the tool captured a screenshot. So functional results are meaningful, but anything about timing or performance is **unverified**.

| Brief check | Result |
|---|---|
| Keyboard focus | **Pass.** After one click on the canvas, keys reached the game: Enter on the title, then E, I, L, Esc and W/A/S/D. |
| Input conflicts | **Pass (functional).** I, L, E and Esc did nothing in the browser itself. Keys pressed during the bridge-lowering scene were ignored by the game, as intended. |
| Lantern performance | **Unverified.** L toggles the shutter, the HUD and Rowan's light (Pass, functional), but no frame rate could be measured. |
| Fog rendering | **Pass.** The Mistbound Path's fog and the crossing's mist render correctly in the Compatibility renderer. |
| Shadow movement | **Partly verified.** The Shadow appears when the bridge lowers and moves along its round between frames. Smoothness is unverified. |
| Inventory UI scaling | **Pass.** At the 800×450 canvas the inventory is crisp and readable, with slots and icons aligned. |
| Browser save behaviour | **Pass.** It also survived the app restarting the local server.<ul><li>Entering the crossing autosaved `savegame.json` and kept the previous save as `.bak`.</li><li>A manual save from the pause menu says "Game saved."; no `.tmp` is left.</li><li>Saving mid-scene is refused with "You can't save during a conversation."</li><li>After a page reload, the title offers Continue ("Saved: The Watchman's Crossing · 12 min"), and Continue restored the lowered bridge.</li></ul> |
| Mouse interaction | **Pass.** Inventory slot and action clicks, the winch's release click, and the pause menu's buttons. |
| Scene transitions | **Pass.** Title → Mistbound Path (Continue), and walking north from the Mistbound Path into the crossing (with its arrival line). |
| Animation smoothness | **Unverified** (no frames while the pane was hidden). |
| The stealth run in the browser | **Not run.** Steering through forced frames was too coarse to sneak or be caught deliberately. The headless tests and the windowed tour cover it. |

To finish the browser checks, play `builds/web_v2_2/` with the browser **visible**: in real Chrome, Firefox and Safari, on a laptop with integrated graphics. Use the browser's FPS meter at the crossing with the lantern open and the Shadow patrolling.

## 6. Known issues and limitations

| Issue | Severity | Notes |
|---|---|---|
| No human playtest | — | `V2_2_PLAYTEST_GUIDE.md`. The tuning values (sight ranges, cone, awareness, safe band) are first-pass. |
| Browser frame rate and smoothness unverified | Medium | See §5. |
| The area title can overlap prompts for its first few seconds | Cosmetic | This happens when Rowan arrives right beside something interactable (tour 11; the winch checkpoint in the browser). It is behaviour from before V2.2; the crossing just makes it more visible. |
| Winch tension isn't kept if Rowan steps away | By design | The counterweight settles back and the winch restarts slack. It takes seconds, and it never softlocks. |
| Orin's line about the watchman is only in his first conversation | Minor | It is offered when the pin goes in, and that conversation leads straight to the ending choice. But a player can step back from the bell ritual, leave the tower by its stairs and only then resolve the watchman. Orin's later conversation doesn't mention it. The epilogue reflects the resolution either way. |
| Exit-time "leaked" audio streams | Dev only | Godot reports the music and ambience streams as leaked when the test runner or a `--quit-after` run exits. V2-only suites show the same, so this predates V2.2 and isn't caused by it. |
| Gamepad bindings untested | Low | I = Back/View, L = LB. Same status as V2. |
| One engine message during the debugging hang | Info | While a test was stuck in the V22-02 loop, Godot printed "BUG: Unreferenced static string to 0: Physics2DConstraintSolveIslands". It hasn't appeared in any run since the fix, including the final 75-test run. |

## 7. Re-running

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
```

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn -- --suite=test_crossing --test=sneaking
```

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --path . res://tests/tour.tscn -- --only=crossing
```
