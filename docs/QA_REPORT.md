# QA report

**Build:** v0.1 prototype · Godot 4.7.2 stable · Windows 11, RTX 4070 SUPER (OpenGL 3.3 Compatibility).
**Date:** 2026-11-22.

## Summary

| Check | Result |
|---|---|
| Automated test suite (headless, 22 tests) | **22 passed, 0 failed**, about 28 s |
| Visual tour: windowed run through every area and ending, 33 screenshots | **0 engine or script errors** |
| Asset import (144+ files) | No import errors |
| Windows export | Preset valid, but **not built**: export templates aren't installed |
| Human playtest | **Not done yet** (see the checklist below) |
| Listening test of the audio | **Not done**: audio was checked only by spectrogram and level analysis |

## Automated tests

Run them with:

```powershell
& "C:\Users\user\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
```

Script and engine errors raised during a test count as failures (a `Logger` hooks the engine's error output).

| Suite | Tests | What is checked |
|---|---|---|
| `test_data` | 7 | Dialogue structure (labels, gotos, speakers, conditions, events with handlers). Every flag used anywhere is documented in `data/flags.json`. Objectives and journal entries are well formed. Documents, images and portraits exist. All three endings have a title, lines and an epilogue. All 64 conversations are referenced. All 40 sound effects exist, and all music and ambience loops are detected as looping. |
| `test_state` | 5 | Condition parsing (`!`, `>=`, `==`, lists). Nested input locks. Objectives advance correctly from flags. Journal entries appear in discovery order with no duplicates. Saves round-trip (flags, numbers, area, journal, position), corrupt or wrong-version saves are rejected, and deleting works. |
| `test_puzzle` | 3 | The Three Seals: a wrong order resets on the third press, repeated presses are ignored, Moon → Flame → Crown solves it, and presses after solving are ignored. The mist pulse always warns before it bursts, hits exactly once per burst, and has a slow (mercy) mode. |
| `test_scenes` | 4 | Every area has its required nodes and tiles. Every exit leads to a real spawn in a real area. Every NPC, interactable, echo point and trigger uses an existing conversation. All UI scenes instantiate. |
| `test_playthrough` | 3 | **End-to-end, on the real scenes at 6× speed** (details below). |

The end-to-end playthrough tests cover the following.

- **`test_full_story_to_the_chorus_ending`** goes from the arrival cutscene to the Chorus ending.
  - Village: Pip (kind choice), the well echo (journal entry), Tobin and Elsie, petting the cat three times.
  - Forge: walking in through the door trigger, Mara, inspecting the pin, Echo on the pin, receiving the pin and the promise, the pin vanishing from the bench.
  - Chapel: Alden, the inscription echo, a wrong seal order (resets) then the right one (the door opens and stops blocking), the full ledger (read to the last page), Alden's scene with an accusation, the key, the optional song objective appearing, and the ledger echo.
  - Village at night: night lighting, Pip's song, the gate opening and no longer blocking, walking through it.
  - Mist path: the Sentinel blocks you; listening, its story, one wrong answer, then the right answer; the Sentinel disappears.
  - Saving mid-story works and contains the progress.
  - Tower: installing the pin, Orin's echo, all three optional questions, then choosing Chorus. The ending scene loads, and the epilogue reflects the lullaby, the well and the peaceful Sentinel. No dialogue event was missing a handler.
- **`test_endure_route_and_no_softlock`** covers the mist challenge.
  - The challenge starts, and saving is blocked during it.
  - A pulse hit pushes Rowan back to the start of the field.
  - Walking south cancels; talking again and choosing "Not yet" still blocks without trapping you.
  - Retrying works. Three hits switch on mercy (slower pulses). Reaching the far side passes as "endured", and saving is allowed again.
- **`test_other_endings_play`** checks that Keeper and Promise can be chosen and load the ending scene, and that Chorus is *not* offered without the song.

## Visual tour (windowed)

`godot --path . res://tests/tour.tscn` drives the real game: title, prologue, the arrival cutscene, dialogue and choices, the Echo effect, the journal, each area, the seals, the archive, the ledger, night in the village, Pip's song, the gate, the Sentinel and mist pulses, the tower with Orin and the vista, and all three endings with their epilogues.

Screenshots are saved to `docs/screenshots/`. Add `-- --only=story` or `-- --only=endings` to run half of it.

## Bugs found and fixed during QA

| # | Problem | Found by | Fix |
|---|---|---|---|
| 1 | `Interactable.priority` clashed with Area2D's built-in `priority`, so the interactable scripts failed to compile | scene smoke test | renamed to `focus_priority` |
| 2 | The test runner reported false passes: suites without `setup()` never got the runner, and script errors weren't counted | reading test output | always inject the runner; count errors with a `Logger` |
| 3 | `ending.gd` didn't parse (untyped dictionary lookup) | scene smoke test | explicit type |
| 4 | **Gameplay bug:** choosing "I won't turn back" right after walking up to the Sentinel cancelled the challenge immediately, because Rowan stood south of the cancel line | end-to-end test | the challenge now fades briefly and places Rowan at the start of the field |
| 5 | Chapel and forge floors read as brick walls | screenshots | new low-contrast floor slabs |
| 6 | The forest edge above the village looked like repeating wallpaper | screenshots | canopy variants plus individual trees |
| 7 | The journal's parchment stretched into blotches | screenshots | larger texture, tiled instead of stretched |
| 8 | Toast and objective panels didn't shrink after long text | screenshots | `reset_size()` before showing |
| 9 | Mist-pulse warning bands were harsh rectangles | screenshots | soft gradient bands |
| 10 | Ending narration was hard to read over the village | screenshots | dark band behind the text |
| 11 | The distant tower was barely visible; the "sunset" looked like night | screenshots | brighter sky halo behind the tower; warmer, brighter sunset and stronger sun rays |
| 12 | The ending tour seemed to "stop" | tour log | not a game bug: `goto_scene` deliberately ignores requests during a fade, and the first run was killed by my own timeout |

## Known limitations and open risks

- **No human has played it.** Automated tests prove the game can be completed and every branch is wired. They can't judge feel: movement speed (74 px/s), text speed, prompt placement, the difficulty of the mist challenge, or pacing.
- **Audio hasn't been listened to.** Levels were normalized (music RMS around −19 dB, ambience around −28 dB) and checked by spectrogram, but the mix and the musical quality are unverified.
- No `.exe` yet. Install the templates via *Editor → Manage Export Templates → Download and Install*, then *Project → Export → Windows Desktop*.
- Gamepad bindings exist (D-pad or left stick, A to interact, X for Echo, Y for journal, Start to pause) but are untested.
- The console prints one informational warning: "Camera2D overridden to physics process mode" (because physics interpolation is on).
- The area scenes come from `tools/build/levels.py`. Re-running it overwrites any editor changes to them.

## Estimated play time

This is estimated from the content, not measured with a person:
- **About 10 to 13 minutes** on the critical path for a quick reader.
- **About 15 to 20 minutes** for a first-time player who reads everything and finds the optional echoes, Pip's song and the Chorus ending.

## Manual playtest checklist (new player)

1. **Title:** Continue is disabled with no save. Settings sliders change volume live. F11 toggles fullscreen. Credits open and close.
2. **New Game:** twelve tolls with twelve marks, then two lines and the letter. Esc skips.
3. **Arrival:** the camera looks at the tower, then at Pip; Rowan walks up and Pip starts talking. Try every choice on a replay.
4. **Movement:** WASD and arrow keys; diagonals aren't faster; no sliding; you can walk behind trees and roofs but not through buildings.
5. **Prompts:** "[E] …" appears near things. "[F] Listen" appears near the well and nearby echoes.
6. **Echo:** press F anywhere: the effect plays and a "quiet" line appears. At the well, the names and the whisper appear.
7. **Journal (J):** shows the current objective, details and discoveries; scroll with W/S; close with J or Esc.
8. **Forge:** Mara shows the pin; inspect it; listen to it; talk to Mara again and receive the pin. The village turns to dusk.
9. **Chapel:** read the inscription (faded), listen to it (clear), get the seals wrong (they reset), then right (the door opens). Read all five ledger pages; Alden arrives; you get the key.
10. **Optional:** talk to Pip after the ledger to unlock the Gathering Song.
11. **Gate:** opens with the key. The tower road is beyond.
12. **Sentinel:** try both routes on two playthroughs. Get hit by the mist; walk back south (the challenge cancels); try again; after three hits it slows down.
13. **Tower:** read Orin's notes on the desk; listen at the bell; set the pin; talk to Orin; choose an ending. Each ending looks different and the epilogue reflects your choices.
14. **Save and load:** quit to the title mid-game (Esc → Return to Title), then Continue. You should be back in the same area with your progress. Pause → Save Game works except during dialogue or the mist challenge.
15. **Pause** works everywhere in gameplay, and dialogue doesn't advance while paused.
