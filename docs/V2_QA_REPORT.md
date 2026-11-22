# Prototype V2: QA report

**Date:** 23 Nov 2026
**Build:** branch `prototype-v2`. The V1 baseline is tag `v1-baseline` (`cf4698d`); the Codex audit itself ran on `29073ce`.
**Engine:** Godot 4.7.2 stable (`ed1daf0bf`), Compatibility renderer.
**Machine:** Windows 11 Pro.

> Everything below was run by the developer tooling (scripts, a windowed bot and a scripted browser session). **No human playtest has been done**, so nothing here measures fun, clarity or difficulty for real players. That is the job of `V2_PLAYTEST_GUIDE.md`.

## 1. How V2 was tested

| Level | What | Result |
|---|---|---|
| Static checks | `tests/test_data.gd`: dialogue structure, every flag registered, events have handlers, quests, documents, speakers, endings, audio files and loops | 7 / 7 pass |
| Headless automated | 48 tests in 9 suites on the real scenes, driven through the same input actions and interactables a player uses, at 6× speed | **48 / 48 pass** (≈ 90 s) |
| Mutation check | V1's Keeper wait and V1's save blocking put back temporarily | The new tests **fail** as they should (Keeper, Sentinel save repro), so they detect the audit's bugs |
| Windowed scripted tour | `tests/tour.tscn` plays every area, the V2 features and all three endings in a real window, takes 47 screenshots, and fails on any engine/script error or failed check | 0 errors, 0 failed checks (final run on the finished code; see §5) |
| Interactive browser session | Web export in the Claude in-app browser (Chromium), played with real keyboard and mouse events | See §4 |
| Export boot | V2 Windows `.exe`, headless boot | Boots to title, no script errors |

The automated suites:
- `test_data` (7)
- `test_state` (5)
- `test_puzzle` (3)
- `test_scenes` (4)
- `test_save` (7, **new**)
- `test_ui` (7, **new**)
- `test_endings` (5, **new**)
- `test_v2` (7, **new**)
- `test_playthrough` (3, extended)

## 2. Audit findings: status in V2

| ID | Status | Evidence |
|---|---|---|
| QA-01 Keeper stalls | **Fixed, verified** | `test_endings.test_keeper_completes` (card visible → epilogue → keyboard scroll → Return to Title → main menu); tour checks; browser session reached "THE KEEPER", the epilogue and the title menu. Mutation check: fails with V1's line. |
| QA-02 Saving blocked after title/Continue | **Fixed, verified** | `test_save.test_title_during_mist_trial_releases_saving` follows the audit's exact steps through the pause menu's own handler. Autosave and manual save both work after Continue. Fails with V1's code (shows "Saving is paused during the mist trial"). Also tested: retreat, area change, New Game, load. |
| QA-03 Epilogue clipped | **Fixed, verified** | `test_endings`: longest possible epilogue for each ending; W/S, Page Up/Down and wheel; the button stays on screen. Tour screenshots `21–23_*_epilogue_end`. Browser: keyboard scroll reached the last paragraph. |
| QA-04 Seal targeting | **Fixed, verified** | `test_ui.test_seal_selection_follows_where_rowan_stands` (3 seals × 4 facings, highlight, no flicker); playthrough presses seals through the real E input. Tour `08`. |
| QA-05 Journal overflow | **Fixed, verified** | `test_ui.test_journal_pages_scroll_independently` covers early and end game, W/S, A/D and J. Tour `12–14`; the journal also opened in the browser. |
| QA-06 Little player action | **Addressed, not validated** | Reconstruction and ritual added (see `V2_GAMEPLAY_DESIGN.md`). Whether this raises engagement needs real players. |
| QA-07 Forge pin, fog, hazards | **Improved, visually checked** | `test_ui.test_readability_cues` and `test_mist_pulse_warning_is_distinct`. Tour `05`, `06`, `15–17`. Judged on screenshots only; no outside eyes yet. |
| QA-08 Save resilience | **Fixed, verified** | `test_save`: backup, damaged-file recovery, interrupted write, 8 kinds of invalid data refused, two genuine V1 saves continue and re-save. Browser: IndexedDB holds `savegame.json` and `.bak`, with no temp file left. No real disk failure or power loss was induced. |
| QA-09 Subtitle at night | **Fixed, verified** | `test_ui.test_village_subtitle_follows_the_light`, tour `11`. |
| QA-10 Camera2D warning | **Fixed, verified** | Launching the village headless printed 0 Camera2D warnings (V1: 1 per launch, as in the audit log). |
| QA-11 UI over Echo visions | **Fixed, verified** | `test_ui.test_echo_vision_holds_prompts_and_toasts`, plus `test_leaving_mid_vision_releases_the_ui` for a regression found by the tour. Tour `03`, `07`, `10`, `36`. |

## 3. Test cases (V2 features)

| TC | Case | How | Result |
|---|---|---|---|
| TC-01 | All three endings reach card, epilogue and title | `test_endings` ×5, tour, browser (Keeper) | Pass |
| TC-02 | The Sentinel save block is released on win, retreat, title, area change, New Game and load | `test_save` ×3 | Pass |
| TC-03 | Title → Continue → autosave and manual save | `test_save` | Pass |
| TC-04 | Save validation and backup; V1 saves | `test_save` ×4 | Pass |
| TC-05 | Seal selection, all facings | `test_ui` | Pass |
| TC-06 | Journal overflow, both pages | `test_ui` | Pass |
| TC-07 | Reconstruction: clues → board → 2 wrong answers (feedback, crossed off) → right → memory → journal | `test_v2` | Pass |
| TC-08 | Reconstruction needs its clues; Esc steps back; reopening later works | `test_v2` | Pass |
| TC-09 | Tobin: tell → lantern (brighter light on the path); spare → its own epilogue | `test_v2` ×2 | Pass |
| TC-10 | Save/load keeps reconstruction state | `test_v2` | Pass |
| TC-11 | Ritual logic: sequence, phrase reset, hints, the 13th must be sung | `test_v2.test_ritual_logic` | Pass |
| TC-12 | Ritual in the tower by keyboard: correct notes light the bell's marks; a wrong note restarts the phrase; stray E is ignored; Esc returns to the choice with no flags; retry and complete → The Chorus | `test_v2` | Pass |
| TC-13 | The Keeper and The Unbroken Promise never require the ritual or the song | `test_v2`, `test_playthrough` | Pass |
| TC-14 | The main story works without the optional mystery | `test_playthrough.test_full_story_to_the_chorus_ending` (skips it, performs the ritual) | Pass |
| TC-15 | Endure route: no softlock, mercy, retreat | `test_playthrough` | Pass |
| TC-16 | Every dialogue reference, flag, event and quest condition is valid | `test_data` | Pass |

## 4. Browser test (web export)

The `Web` preset (single-threaded) was exported to `builds/web_v2/`, served from `127.0.0.1:8061`, and played in the Claude desktop app's in-app browser (Chromium) with keyboard and mouse events. A copy of the page with an audio level probe (`probe.html`) measured the sound output.

| Check | Result |
|---|---|
| WebGL rendering | **Pass.** WebGL 2.0, Compatibility renderer, title renders. |
| Loading | **Pass.** Loads from a local server. Download sizes: `index.wasm` 39.5 MB, `index.pck` 6.8 MB. Load time over a real network not measured. |
| Canvas and keyboard focus | **Pass.** After one click the canvas has focus; Enter, Esc, WASD, arrows, E, F and J all worked. |
| Interaction controls | **Pass.** Dialogue advance, choices, Echo (F), journal (J), pause menu navigation, Save, final choice, ritual (W/S/E). |
| Audio activation | **Pass (level measured, not listened).** Silent until the first click, then title music at RMS ≈ 0.07; ritual notes peaked at ≈ 0.39. |
| Browser save persistence | **Pass.** Autosave and manual save write `savegame.json` and `savegame.json.bak` to IndexedDB (no `.tmp` left). After a page reload the title offers Continue with the right location, and Continue loads it. |
| Scaling | **Pass.** At 1280×720 the canvas filled the viewport (adaptive canvas, integer-scaled game). |
| Fullscreen (F11) | **Not verified.** In the embedded browser the game's request was refused. The console said: "requestFullscreen… API can only be initiated by a user gesture". The automated key press didn't count as one. In real browsers F11 is normally taken by the browser's own fullscreen. Check by hand, and consider a fullscreen button on the hosting page. |
| Scene transitions | **Pass.** Title → prologue → village; title → tower; tower → ending → title. |
| Ending animations | **Pass for The Keeper** (dissolve, narration, title card, epilogue, keyboard scroll, Return to Title). **Pass for the ritual → The Chorus** (ending start observed). The Unbroken Promise was not played in the browser. |
| Reload and Continue | **Pass.** |
| Missing resources | **Pass.** No load errors in the console. |
| Console errors | **Pass.** None during the whole session. |
| Mouse wheel on the epilogue | **Not confirmed in the browser.** One wheel gesture showed no change in a throttled background page. The headless test covers the wheel. |
| Frame rate | **Not measured.** The browser pane was hidden, so the page ran throttled (≈ 1.5 fps); timing in that state isn't meaningful. |

**Method note:** to reach the tower quickly, a tower save was written into the page's IndexedDB (`/userfs`, the same format the game writes). This is the same synthetic-checkpoint approach the audit used.

**Found by this session:** an Enter press meant for Orin's last line landed on the ritual and counted as a wrong note. Fixed: E/Enter now only counts on the circled 13th note, and a test was added.

**Developer browser checklist** (repeat in real Chrome, Firefox and Safari, on a laptop with integrated graphics):
- [ ] Page loads; title appears.
- [ ] Click → music starts.
- [ ] F11 or the browser's fullscreen.
- [ ] New Game; Esc skips the prologue.
- [ ] Walk, E, F, J; the journal scrolls (W/S, A/D).
- [ ] Esc → Save Game → reload → Continue.
- [ ] Reach each ending; scroll the epilogue with the wheel; Return to Title.
- [ ] The ritual with W/S/E; Esc steps back.
- [ ] Rough frame rate (the browser's FPS meter) in the village at night and on the Mistbound Path.
- [ ] Console has no red errors.

## 5. Visual evidence

`docs/screenshots/v2/` holds 47 screenshots from the final windowed tour, taken at 2× (960×540). The original V1 screenshots stay in `docs/screenshots/` for before/after comparison.
- **01–24:** the story with the V1 fixes, and all three endings (title card, top and bottom of the epilogue, back at title).
- **30–46:** the V2 features: lamp echo, board, wrong answer, solved, memory, Tobin, journal entry, lantern on the path, three-option choice, ritual start, five notes, a soured note, the last note circled, complete.

The tour driver checks the composition it can check: the board, ritual, cards and epilogues are visible and the selection is right. The images themselves were reviewed by eye. That review fixed:
- clues overflowing the board
- a faint young-Tobin ghost
- missing lines between the ritual's notes
- a toast over the memory scene

## 6. Outstanding issues and untested areas

| Item | Severity | Notes |
|---|---|---|
| No human playtest | Blocks any score claim | Run `V2_PLAYTEST_GUIDE.md` with 3–5 new players. |
| Audio not listened to | Medium | The new sounds and every V1 track were checked by measurement only. |
| Gamepad untested | Low | Bindings exist (d-pad, A/X/Y/Start). Board and ritual use the same actions. |
| Browser fullscreen, frame rate, wheel unverified | Low–Medium | See §4. Test on real browsers and low-end hardware. |
| Windows `.exe` not played through | Low | Boots cleanly; the same scenes pass the headless and windowed tests. |
| Abrupt `--quit-after` exits log leaked audio streams | Cosmetic (dev only) | Normal Quit releases audio first; this already happened in V1 and is unrelated to V2. |
| Board and ritual difficulty | Unknown | Designed to be fair and short; only players can say if they're too easy or unclear. |

**Play time (estimate, not measured):**
- Critical path: as in V1, about 10–13 minutes.
- The optional mystery adds about 1–2 minutes.
- The ritual takes about 20–60 seconds.
