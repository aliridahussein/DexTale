# Prototype V2.2: playtest guide (the Watchman's Crossing)

**Goal:** find out whether the new crossing makes the game more engaging. Use 3–5 people who have never played it. The questions are whether people enjoy finding and combining the tools, repairing the bridge and working the winch, and getting past the Watchman's Shadow, and whether that part should grow.

The automated tests and the visual tour show that the crossing *works*. Only real players can show whether it is *fun*, *clear* and *fair*.

> **No feedback has been collected yet.** Every result table below is empty on purpose. Record only what testers actually said and did. Don't fill in, estimate or "smooth out" missing answers. A blank is useful data.

## 1. Before the session (facilitator)

- **Build:** use the same build for every tester. Either:
  - the Windows `.exe` exported from this branch, or
  - the web build exported to `builds/web_v2_2/` (see `V2_2_CHANGELOG.md`, "Compatibility"). Desktop browser, keyboard, sound on.

  The public website runs an older version; don't use it for this test.
- **Two kinds of session:**
  - **Full game** (about 25 minutes): New Game, played to an ending. Best for 1–2 testers. It shows whether the crossing fits the story's pacing.
  - **Crossing only** (about 10 minutes): for the rest. Load the prepared save that starts on the Mistbound Path just past the Sentinel. Make it once by playing up to the Sentinel and saving, then copy `savegame.json` aside. Copy it back before each tester.
- **Fresh state:** delete the save between full-game testers.
  - Windows: `%APPDATA%\Godot\app_userdata\The Thirteenth Bell\`.
  - Browser: a private window, or clear the site's data.
- **Equipment:** headphones or speakers and a timer. Screen recording is optional and needs the tester's OK.
- **Facilitator:** sit behind the tester, say as little as possible, and take notes on the observation sheet (section 3).
- **If someone is stuck:** wait 3 minutes before helping. Then give the smallest hint you can, and mark it on the sheet ("HINT at 06:10: said 'the watchhouse might have tools'").

## 2. What to tell the tester (read aloud; spoiler-free)

> "This is a short story game. Play it however you like; there are no wrong ways. I can't help you while you play, because I want to see where the game itself is unclear. If you'd like, say out loud what you're thinking or looking for. When you finish, I'll ask a few questions. You can stop at any time."

Controls card (show it, then leave it on the table):

| Move | Interact | Listen (Echo) | Inventory | Lantern | Journal | Pause / back |
|---|---|---|---|---|---|---|
| WASD / arrows | E | F | I | L | J | Esc |

Don't mention any of the following: the rope, hook or token; that items can be combined; the winch's safe zone; what the Shadow reacts to; the stone supports; the rotten planks; or that the Shadow can be put to rest.

## 3. Observation sheet (one per tester)

Write the time from arriving at the crossing for each event.

| # | Watch for | Time | Notes (what they did or said) |
|---|---|---|---|
| 1 | First reaction to the raised bridge; do they inspect the chain or the winch first? | | |
| 2 | Enter the watchhouse unprompted? | | |
| 3 | Open the inventory (I) on their own? How often? | | |
| 4 | Read the logbook? Listen (F) at the winch? Did either change what they did next? | | |
| 5 | **Combining:** time from holding both rope and hook to making the Hooked Line. Wrong combinations tried (which)? | | |
| 6 | Use the line on the chain: first try, or after wandering? Did they Hold it, or just press E? | | |
| 7 | **Winch:** releases while too loose or too tight (count); stepped back? Time to lower the bridge | | |
| 8 | Reaction when the bridge lowers (sound, comment, expression) | | |
| 9 | Reaction when the Shadow appears; did they stop to watch it? | | |
| 10 | Use L (shutter) without being told? When? | | |
| 11 | Use the stone supports as cover? Stepped on a rotten plank? | | |
| 12 | **Catches:** count, and what they said after each. Did the hints help? | | |
| 13 | Time from bridge down to entering the tower | | |
| 14 | **Optional:** took the token? Heard the chair and the post? Opened the token's board? | | |
| 15 | **Board:** answers tried in order; their comments | | |
| 16 | Put the token on the post? Reaction to the Shadow at peace | | |
| 17 | (Full game) Ending chosen; noticed Orin's line about the watchman? | | |

Throughout, mark **C** (confused or lost), **B** (bored, rushing, sighing), **E** (enjoying: smiles, comments, leaning in) and **T** (tense: leaning forward, holding breath, "oh no"), with times:

```
C 03:20  tried to walk off the bridge head into the ravine
E 07:45  "oh, the hook goes ON the rope"
T 10:05  froze behind the pillar while the "?" showed
```

Also note any bug, freeze, stuck moment, unclear text or audio problem, with the time and what was on screen.

## 4. Post-session questions (tester answers)

Ask these in order and write the answers down in the tester's own words:

1. Was finding the required items satisfying?
2. Was combining items intuitive?
3. Did the bridge puzzle make sense?
4. Was the winch interaction enjoyable?
5. Did you understand how the Shadow detected you?
6. Did you feel tension during the crossing?
7. Did failure feel fair?
8. Would you enjoy more gameplay like this?

Then:

9. Which moment did you enjoy most?
10. Which part felt boring, confusing or frustrating?
11. (If they found it) What did you think the Shadow was? Did that change?

Rate each from **1** (very poor) to **10** (excellent):

| Category | Score 1–10 |
|---|---:|
| The search and the inventory | |
| The bridge repair and the winch | |
| The stealth crossing | |
| Atmosphere and pixel art at the crossing | |
| Technical stability | |

Quick yes / no / unsure:

| | |
|---|---|
| Did you know what L did before you needed it? | |
| Did you notice the "?" before being caught? | |
| Did you realise the stone pillars could hide you? | |
| Did you find the token? Did you work out what it meant? | |
| Would you replay the crossing to do it differently? | |

## 5. Results template (facilitator, after all sessions)

**Per tester** (leave cells blank when unknown):

| Tester | Date | Build | Session type | Finished crossing? | Time at crossing | Wrong combos | Winch fails | Catches | Token resolved? | Hints given |
|---|---|---|---|---|---|---|---|---|---|---|
| T1 | | | | | | | | | | |
| T2 | | | | | | | | | | |
| T3 | | | | | | | | | | |
| T4 | | | | | | | | | | |
| T5 | | | | | | | | | | |

**Answers to the eight questions:** one row per tester. Quote short phrases, don't summarise.

| Tester | Items satisfying? | Combining intuitive? | Puzzle made sense? | Winch enjoyable? | Understood detection? | Felt tension? | Failure fair? | Want more? |
|---|---|---|---|---|---|---|---|---|
| T1 | | | | | | | | |
| … | | | | | | | | |

**Patterns:** list each issue seen in two or more testers, its times, and a proposed change. Treat an issue seen only once as a lead, not a conclusion.

| Issue | Testers | Where / when | Proposed change |
|---|---|---|---|
| | | | |

**Tuning to check against what you saw** (current values are in `WATCHMANS_CROSSING_DESIGN.md`, "Tuning values"):

- **Too many catches, or players never discovering the shutter:** raise the hints earlier, or shorten the closed-shutter range.
- **No catches and no tension:** widen the cone, or slow the awareness decay.
- **Many winch fails:** widen the safe band (now 40 to 66).

**Decisions:** what to change before the next round, and what to leave alone because players liked it.
