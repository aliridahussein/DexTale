# Prototype V2: changelog

V2 builds on the V1 prototype that the independent Codex audit scored 67.25/100 on 22 Nov 2026. The audit was run on commit `29073ce`, and the V1 code is tagged `v1-baseline`. V2 keeps the story, the five areas, the art direction, the controls and all three endings. It fixes every defect the audit confirmed, then adds two gameplay mechanics: an investigation the player has to piece together, and a ritual the player performs.

Branch: `prototype-v2`. There are three commits, one per milestone.

## 1. Fixed defects (from the audit)

| ID | What was wrong | What V2 does | Verified by |
|---|---|---|---|
| **QA-01** (critical) | The Keeper froze after its last narration line. It never showed the title card, the epilogue or Return to Title. | Cause: `ending.gd` waited for the memory dissolve's `finished` signal (a 4 s tween) *after* a 5.9 s narration line. By then the signal had already fired, so the wait never ended. The sequence now checks whether the tween is still running before waiting on it. | `test_endings.gd`: all three endings run through card, epilogue, scrolling and Return to Title via input. Re-adding the V1 line makes `test_keeper_completes` fail again. Windowed tour, and the web build in the browser. |
| **QA-02** (high) | After starting the mist trial, returning to the title and continuing, saving stayed disabled. | Save restrictions now belong to the node that sets them and are released when that node leaves the scene tree. New Game and loading a save also clear them. The pause menu says why saving is off ("Saving is paused during the mist trial.") instead of failing silently. | `test_save.gd` follows the audit's exact steps and fails with the V1 code. |
| **QA-08** | The save was written straight over the only save file, and only a few fields were checked. | New saves go to `savegame.json.tmp`, are read back and validated, and are then moved into place. The previous good save is kept as `savegame.json.bak`. If the main file is damaged, the backup (or a finished temp file) is used automatically. Every field is validated. The format is unchanged (`version: 1`), and two genuine V1 saves from the audit load and re-save. | `test_save.gd`: backup, damage recovery, interrupted write, invalid data refused, V1 fixtures. |
| **QA-03** | Long epilogues were cut off at the bottom. | The epilogue scrolls with W/S, the arrow keys, Page Up/Down and the mouse wheel. ▲/▼ markers and a hint appear when there is more text. Return to Title always stays visible. | `test_endings.gd` (the longest possible epilogue for each ending), tour screenshots 21–23. |
| **QA-04** | The chapel seals: standing under Moon while facing left selected Flame. | The seals are chosen by where Rowan stands, not which way he faces. The prompt names the seal ("Press Moon"), the selected seal brightens, and the choice doesn't flicker between neighbours. | `test_ui.gd` checks all 3 seals × 4 facings. Tour screenshot 08. |
| **QA-05** | The journal's completed objectives ran off the page. | Both pages scroll on their own. W/S scrolls, A/D switches pages (the active page has a ▶ heading), and the mouse wheel scrolls the page under the pointer. The DONE list shows its count. | `test_ui.gd`. Tour screenshots 12–14. |
| **QA-07** | The forge pin was hard to spot; Rowan disappeared in fog; hazard warnings looked like ambient mist. | Forge: a small warm light on the bench and an occasional glint on the pin, only while the pin is the goal. Mistbound Path: Rowan carries a soft light. Hazard lanes now have crisp dashed edges (ambient fog never has edges). The edges are faint at rest, blink faster and faster during the warning, and turn solid on the burst. | `test_ui.gd`. Tour screenshots 05, 15–17. |
| **QA-09** | The village subtitle still said "at sundown" at night. | The subtitle follows the light: sundown, dusk, after dark. | `test_ui.gd`, tour screenshot 11. |
| **QA-10** | Camera2D warning on every launch. | The camera's physics process mode is now set explicitly; physics interpolation already required it. | Launch log: 0 warnings (was 1). |
| **QA-11** | Toasts and prompts covered Echo visions. | While a vision shows, prompts hide and toasts wait. A toast already on screen pauses, without being cancelled, and resumes afterwards. Visions get a soft dark halo so pale art reads on bright ground. | `test_ui.gd` (including leaving the area mid-vision), tour screenshots 03, 07, 10. |

**Defects found during V2 work:**
- `used_echo` was never set, so the "(Stand close and press F to listen.)" tutorial lines repeated all game.
- A vision interrupted by an area change left prompts hidden in the next area. The windowed tour caught this; the bug was introduced and fixed within V2.
- Tobin's "Elsie" conversation never set `talked_tobin`.
- In the browser test, an Enter press meant for dialogue landed on the ritual and counted as a wrong note. E/Enter now only counts on the circled final note.

## 2. New gameplay

- **Echo Reconstruction** is a reusable, data-driven investigation board (`data/reconstructions.json`). The first one, **The Forgotten Promise**, is an optional mystery at the village well.
  - **Clues:** the well's voice (existing), a new Echo at the well's lamp, the worn bench, and Tobin's habit as supporting evidence.
  - **The deduction:** at the well, "Piece it together" asks what Tobin promised Elsie, with four plausible answers.
  - **Wrong answers** are crossed off, with feedback pointing at the clue that rules them out. There is no penalty.
  - **The right answer** plays a warm reconstructed memory (Elsie and young Tobin) and updates the journal.
- **Tobin's choice (new consequence):** tell Tobin what his lamp is for, or let him keep the habit.
  - Telling him earns **Tobin's lantern**, which lights the Mistbound Path more widely and warmly.
  - Both choices change his lines and get their own epilogue lines.
  - The bell's memory echo then names Tobin and Elsie.
- **The Bell's Resonance:** choosing *Retune the bell* now opens a short ritual before The Chorus.
  - The player follows the Gathering Song's shape from the ledger margin: W for a higher note, S for a lower one, E for the circled 13th note.
  - Each correct note rings at its real pitch and lights one of the bell's 13 marks.
  - A wrong note sours the bell and restarts that phrase. A note the player has missed then shows its direction.
  - No timing, unlimited retries, and Esc steps back to the final choice.
  - The Keeper and The Unbroken Promise are unchanged and never require it.

## 3. Feedback and pacing changes

| Area | Change |
|---|---|
| Everywhere | Story-relevant prompts are gold; flavour objects stay plain. An empty Echo answers with a short line floating over Rowan instead of a top-of-screen toast. |
| Forge | The pin brightens when selected. |
| Chapel | Seals pop and brighten when pressed. A wrong order answers with a caption over the seals: "The seals grind back into place." From the second miss: "...The inscription must give the order." There is no dialogue box to dismiss. |
| Village | New lamp by the well; the reconstruction board; the memory scene. |
| Tower | The mechanism brightens when selected; the bell's marks light during the ritual. |

### Dialogue removed or modified
- **Removed:** `chapel_seal_wrong` (replaced by the captions above).
- **Removed:** the first line of `chapel_seal_solved` ("Moon. Flame. Crown. The seals blaze..."). The seals now show it.
- **`tower_memories_echo`:** two narrator lines merged into one. Rowan names the memories the player pieced together, if any.
- **Orin, "Whose voice?":** if Rowan already learned the song, Orin says "But you already know..." in one line instead of re-explaining it.
- **Orin, "Why me?":** if Rowan read Orin's notes, the "I taught you the song" line is shortened.
- **`orin_decide`:** the Chorus branch runs the ritual. Stepping back plays Orin's new line "Take your time. The bell has waited this long. It can wait for you." and returns to the choice.
- **Tobin:** new branches (the promise, tell or spare, and afterwards). His "Elsie" line now ends "...Twice a night, that one. Never knew why."
- **`village_well`:** two new conditional Rowan lines.
- **New conversations:** `well_lamp`, `well_lamp_echo`, `well_bench`, `well_reconstruct`, `well_promise_memory`.
- **New speakers:** `elsie`, `young_tobin` (memory voices).

## 4. Consequences, by kind

| Kind | Examples |
|---|---|
| Cosmetic | Rowan naming Tobin and Elsie in the bell's memories; Orin's shorter answers. |
| Persistent story | Tobin's lines after the reconstruction; journal entries; the well's inspect text. |
| Gameplay | Tobin's lantern lights the Mistbound Path more brightly; the ritual gates The Chorus by performance instead of a menu option. |
| Ending | Four new Tobin epilogue lines (reconstructed for The Chorus, told plus lantern for The Unbroken Promise, told, and kept secret). |

## 5. Compatibility and tools
- **Save format:** unchanged (`version: 1`). V1 saves load; new flags default to false. Two extra files may appear next to the save: `.bak` (previous save) and, rarely, `.tmp`.
- **Controls:** unchanged. New keys only inside new screens: A/D switches journal pages; on the board, W/S chooses and E decides; in the ritual, W/S/E.
- **Conditions:** scene exports can list several conditions in one string (`"a, b, !c"`).
- **Generators:** every V1 asset regenerates bit-identically.
  - New sounds: `ritual_note`, `ritual_sour`, `memory_warm`.
  - New icon: `icon_lantern`.
  - The generators also produce the new board and ritual scenes.
