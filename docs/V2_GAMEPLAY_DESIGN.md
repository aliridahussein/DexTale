# Prototype V2: gameplay design

**The problem V2 addresses:** most of V1's route was walk, interact, read, get an objective, walk. The audit's biggest weakness was "the investigation seldom asks Rowan to do anything with a clue." V2 adds two moments where the player has to understand something and act on it. Neither adds combat, fetch quests, walking distance or a new map.

## 1. The Echo (unchanged core)

F listens near an Echo point and reveals a fragment of the past. V2 keeps this exactly as it was, with two changes:
- A vision now has the screen to itself: no prompts, and toasts wait.
- Some echoes now become **clues** that feed a reconstruction (below). For example, the well lamp's echo appears only after you've heard the well, so the square "wakes up" around the first clue.

## 2. Echo Reconstruction (new, reusable)

**The idea:** gather fragments, compare them, then commit to one interpretation of what happened. The game rewards understanding, not clicking.

**Flow**
1. Clues come from things the player already does: an Echo (F), an inspection (E) or a conversation. Each sets a flag.
2. The journal shows an optional objective as soon as the first clue is found. A second objective appears when all required clues are in.
3. An interactable (gold prompt "Piece it together") opens the **board**:
   - **Left side:** the clues, with missing required ones shown as "???" and a hint.
   - **Right side:** one question and 3–4 plausible answers.
4. **Wrong answer:** it is crossed off, the clue that contradicts it turns red, and one sentence explains why. There's no penalty and no lost progress. Ruled-out answers can't be picked again, so the player always gets there.
5. **Right answer:** the solved flag is set, and the conversation plays the reconstructed memory and updates the journal.
6. Esc steps back at any point; the board can be reopened later.

**Data:** `data/reconstructions.json`. One entry per mystery:

```json
"well_promise": {
  "title": "...", "intro": "...", "question": "...",
  "clues":   [{"id", "when": "<condition>", "required": true, "title", "text", "missing"}],
  "answers": [{"text", "correct": true} or {"text", "rule_out": "<clue id>", "feedback"}],
  "solved_flag": "promise_reconstructed",
  "solved_line": "That's it..."
}
```

**Code**
- `scripts/ui/reconstruction_view.gd` holds the board. It is generic, knows nothing about the well, and is opened through `UI.open_reconstruction(id)`.
- A conversation opens it with `{"event": "reconstruct", "args": ["well_promise"]}` and branches on the solved flag afterwards.

**Adding another reconstruction** (for example in the chapel):
1. Make the clues: echo points or interactables that set flags.
2. Add an entry to `reconstructions.json`. Each wrong answer must name a clue that genuinely rules it out.
3. Add an interactable with `requires = "clue_a, clue_b, clue_c"` and `hidden_when = <solved_flag>`, and a conversation that fires the event.
4. Add the journal objectives, discoveries and at least one later line or epilogue that reacts to the solved flag.
5. Register the new flags in `data/flags.json` (the tests enforce this).

**Design rules for good boards**
- Every wrong answer should be something a reasonable player might believe after one clue, and should be ruled out by another clue. That makes comparing clues the actual task.
- Keep it to 3–4 answers and one question. A second question rarely adds understanding.
- The reward is a scene and a consequence, not an item.

## 3. "The Forgotten Promise" (the first reconstruction)

| Clue | How it's found | What it shows |
|---|---|---|
| Her voice in the stone (required) | F at the well (existing V1 Echo) | TOBIN + ELSIE, and "You promised you'd wait for me." |
| The lamp she hung (required) | F at the new lamp beside the well; it unlocks after the well's Echo | A young woman hanging the lamp: "If I can see a light from the road, I can find the way back." |
| The worn bench (required) | E on the bench nearest the well | Worn smooth at one end, candle wax, facing the road: someone waited there every night. |
| Tobin's habit (supporting) | Talking to Tobin | He lights the well lamp twice a night and never knew why. |

**Question:** what did Tobin promise Elsie?
- *To marry her when the harvest was in.* Ruled out by her voice: she asked him to wait, not to marry.
- *To leave Dawnmere with her before the mist came.* Ruled out by the bench: someone stayed behind.
- **To keep a light burning by the well until she found her way home.** Correct.
- *To forget her if she never came back.* Ruled out by the lamp: he never stopped tending it; the forgetting was done to him.

**Reward:** a warm memory at the well. It is gold rather than the usual cold blue, so it reads as *reconstructed*, not merely heard. Elsie: "...light the lamp by the well. I'll follow it back." Young Tobin: "Every night. Twice, if I have to." It is the payoff of his "twice a night" line from the first conversation.

**Consequences**
- Tobin gets a new branch, with a choice:
  - **Tell him.** He remembers nothing but his hands do; he gives Rowan his lantern ("Bring it back lit.").
  - **Let him keep the habit in peace.**
- **Tobin's lantern** makes Rowan's light on the Mistbound Path wider and warmer.
- **Epilogue:** new Tobin lines for The Chorus (he gets Elsie's memory back), The Unbroken Promise (the lantern comes back lit), and the told and kept-secret variants for any ending.
- **The tower:** the bell's memory echo names "Tobin and Elsie".
- **Optional:** nothing in the main story checks these flags. A player who skips the mystery loses nothing but the scene and the lines.

Expected extra time is about 1–2 minutes. This is a design estimate; it hasn't been measured with players.

## 4. The Bell's Resonance (the Chorus ritual)

**Why:** in V1, The Chorus was a menu option followed by a cutscene, even though the game had already taught the song's shape. Now the player performs it.

**Rules**
- The panel under the bell shows the Gathering Song the way Rowan remembers it from the ledger margin: thirteen marks rising and falling, a breath after the eighth, and the last one circled.
- The bell gives the first note. For each next note, W means higher and S means lower. The circled thirteenth note is sung with E. The opening three steps match the song document's own words, "Up, and up, and down".
- **Feedback without sound:** each correct note turns gold on the staff and lights one of the thirteen marks on the bell sprite itself. The counter reads n / 13, and the 13th mark pulses when it's next.
- **Wrong note:** the bell sours (a sound, a red flash and a small shake) and the current phrase restarts. The first phrase, once finished, is kept. The missed note then shows an arrow the next time it comes up.
- No timing, unlimited retries, and Esc steps back to the final choice with no flags set.
- E/Enter before the circled note is ignored with a hint, so leftover dialogue key presses never count as mistakes.
- **Length:** 12 inputs, roughly 20–60 seconds depending on mistakes. Estimated, not measured with players.

**Integration**
1. `orin_decide` → *Retune the bell* → Orin's line → event `bell_ritual`.
2. If it completes, the event sets `bell_retuned`. Then `ending_selected = chorus` and the existing Chorus cinematic and ending play unchanged.
3. If the player steps back, Orin says one line and the choice returns.
4. The Keeper and The Unbroken Promise never touch it, and the ending flags are set exactly as before.

**Code**
- `scripts/systems/resonance_ritual.gd` is pure logic and is unit-tested.
- `scripts/ui/ritual_view.gd` handles drawing and input.
- `bell_tower.gd::_bell_ritual()` handles the marks on the bell.

## 5. How the pieces connect

```
well Echo ─┐
lamp Echo ─┼─> reconstruction ─> memory ─> Tobin: tell? ─> lantern (Mistbound Path) ─┐
bench ─────┘                                            └─> epilogue lines ──────────┼─> "What Dawnmere remembers"
ledger margin + Pip's song ─> Chorus option ─> ritual (performed) ─> The Chorus ─────┘
```

## 6. Not done on purpose
- **No encounter between the Sentinel and the tower.** The brief reserves it for a separate design discussion.
- **No new characters.** Elsie and young Tobin are memories, voiced only in the reconstructed scene.
- **No inventory.** Tobin's lantern is a flag with a visible effect.
