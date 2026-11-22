# Next steps: from prototype to a year-long project

## First week

1. **Play it yourselves, separately, without help.** Use the checklist in `QA_REPORT.md`. Write down every spot where you were confused, bored or lost. That list is worth more than any feature.
2. **Listen to the audio.** Swap any track you dislike: drop a WAV with the same name into `assets/audio/...`. Godot picks it up, and the loop-point detection works for WAVs that carry `smpl` loop data. Otherwise set *Loop Mode* in the Import dock.
3. **Install the export templates and build an `.exe`.** Give it to two friends.
4. **Decide the level workflow.** Either keep generating areas with `tools/build/levels.py`, or (recommended) switch to editing areas in the Godot editor and keep the generator only for new areas.

## Turning the slice into a game

| Area | Prototype today | Suggested direction |
|---|---|---|
| Art | Generated placeholder pixel art | Keep the sizes: 16 px tiles, 16×24 characters, 32×32 portraits. Redraw in Aseprite, a few assets at a time; files drop in by name. Add expression portraits (a `"portrait"` override per line). |
| Writing | JSON with a validator | Keep JSON, or move to a dialogue add-on if you outgrow it. Add a `"voice"` field per line for recorded VO. |
| Voice | None | Record key lines; add an optional `AudioStreamPlayer` in `DialogueBox` keyed by line id. |
| Systems | Interactables, Echo, flags, quests, save | Next: save slots, key remapping, localization (Godot `TranslationServer` + CSV), an inventory only if the design needs one, and a world map. |
| Encounters | One reusable `MistPulse` hazard | Build a small library of telegraphed hazards (sweeping beams, rising tides) on the same pattern: warn, then danger, then rest. |
| QA | 22 automated tests + a visual tour | Run the tests in CI on every push (Godot runs headless on Linux runners). Add one end-to-end test per new chapter. |

## A division of work for two developers

- **Developer A (DevOps / systems)** owns:
  - CI: GitHub Actions running the headless tests and export builds.
  - Save versioning and migrations, settings and input remapping.
  - The asset pipeline (`tools/`), performance profiling, and release packaging.
  - The "engine" scripts in `scripts/autoload/` and `scripts/systems/`.
- **Developer B (software / acting / storytelling)** owns:
  - Narrative design, everything in `data/dialogue/`, documents and endings.
  - Cutscene choreography (area `area_events()`), character voice and VO recording.
  - Playtest sessions, and the area scripts in `scripts/world/`.
- **Shared:** level layout, art direction, and weekly playtests (each person plays the other's latest work).

## Git without scene conflicts

- `.godot/` is ignored. **Commit the `.import` and `.uid` files.** They keep resource identity stable across machines.
- Godot scenes are text, but merging them is unpleasant. Give **each `.tscn` one owner at a time**:
  - Agree in chat ("I'm in `chapel.tscn` today").
  - Split big scenes into instanced sub-scenes (for example a `chapel_archive.tscn`), so two people rarely need the same file.
- Prefer data over scenes for content (dialogue, quests, flags). JSON diffs and merges cleanly.
- Branch per feature (`feature/forge-hammer-minigame`, `story/act2-dialogue`). Keep pull requests small. Run the test suite before merging:

  ```powershell
  & "<path>\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/test_runner.tscn
  ```
- If a `.tscn` does conflict, keep one side whole and redo the other person's change in the editor. Don't hand-merge node lists.
- Re-running `tools/build/levels.py` rewrites the area scenes. Only one person should run it, on a branch, and only when nobody else has editor changes pending in those scenes.

## Ideas this prototype sets up

- More echoes, used for puzzles: put fragments in order, compare two echoes, or find the place a voice belongs.
- The bell's thirteen marks as a recurring motif: other bells, other bargains.
- Consequence tracking already works through flags and the epilogue. Expand it into a "what the village remembers" system that persists across chapters.
