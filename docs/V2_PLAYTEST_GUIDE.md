# Prototype V2: playtest guide

**Goal:** find out whether V2 is actually more engaging, using 3–5 people who have never seen the game. Only real players can answer that. The automated tests show that the game *works*, not that it is *fun*.

> Record only what testers actually said and did. Don't fill in or estimate missing answers. A blank is useful data.

## 1. Before the session (facilitator)

- **Build:** use the same build for every tester. Either:
  - the Windows `.exe` from `builds/windows_v2/`, or
  - the web build served from `builds/web_v2/` (see `V2_RELEASE_NOTES.md`). Desktop browser, keyboard, sound on.
- **Fresh state:** start every tester from New Game with no save.
  - Windows: delete `%APPDATA%\Godot\app_userdata\The Thirteenth Bell\`.
  - Browser: use a private window or clear the site's data.
- **Equipment:** headphones or speakers, and a timer. Screen recording is optional and needs the tester's OK.
- **Facilitator:** sit behind the tester, say as little as possible, and take notes on the observation sheet (section 3).
- **If someone is stuck:** wait 3 minutes before helping. Then give the smallest hint you can and mark it on the sheet ("HINT at 07:40: told them to check the journal").

## 2. What to tell the tester (read aloud; spoiler-free)

> "This is a short story game, about 15 minutes. Play it however you like; there are no wrong ways. I can't help you while you play, because I want to see where the game itself is unclear. If you'd like, say out loud what you're thinking or looking for. When you finish, I'll ask a few questions. You can stop at any time."

Controls card (show it, then leave it on the table):

| Move | Interact / talk | Listen (Echo) | Journal | Pause |
|---|---|---|---|---|
| WASD / arrows | E | F | J | Esc |

Don't mention the well mystery, the ritual, the endings or the optional song.

## 3. Observation sheet (one per tester)

Write the time from New Game for each event.

| # | Watch for | Time | Notes (what they did or said) |
|---|---|---|---|
| 1 | First time they press F (Echo) without being told | | |
| 2 | Find the forge; spot the pin on the bench | | |
| 3 | Chapel seals: wrong orders (count); did selection ever surprise them? | | |
| 4 | Read the ledger; leave the chapel | | |
| 5 | Open the journal (J) on their own? How often? | | |
| 6 | **Optional:** listen at the well; notice the lamp and bench; open the board? | | |
| 7 | **Board:** answers tried in order; time on the board; their comments | | |
| 8 | Tobin after the board: tell or spare? | | |
| 9 | **Optional:** learn Pip's song (offers the third ending) | | |
| 10 | Sentinel: understand (riddle) or endure (mist)? Hits taken | | |
| 11 | Tower: which ending did they choose, and what did they say about it? | | |
| 12 | **Ritual** (if The Chorus): wrong notes; stepped back? time to finish | | |
| 13 | Reached the ending and Return to Title | | |

Throughout, mark **C** (confused or lost), **B** (bored, rushing dialogue, sighing) and **E** (enjoying: smiles, comments, leaning in), with times:

```
C 04:10  walked past the forge twice
E 09:30  laughed at Pip's line about Mara
B 12:05  skipping Orin's lines fast
```

Also note any bug, freeze, unclear text or audio problem, with the time and what was on screen.

## 4. Post-game evaluation (tester fills in)

Rate each from **1** (very poor) to **10** (excellent):

| Category | Weight | Score 1–10 |
|---|---:|---:|
| Gameplay and responsiveness | 25% | |
| Atmosphere and pixel-art quality | 25% | |
| Story and dialogue | 20% | |
| Technical stability | 20% | |
| Replayability and consequences | 10% | |

Then answer in your own words:

1. Which moment did you enjoy the most?
2. Which part felt boring or frustrating?
3. Would you want to play another 30 minutes? Why or why not?

Quick yes / no / unsure:

| | |
|---|---|
| Did you understand what "Listen" (F) does? | |
| Did you find the mystery at the well? Did you solve it? | |
| (If you reached it) Was the bell ritual clear? Did you finish it? | |
| Did you understand what your final choice would cost? | |
| Do you think your earlier choices changed anything? Which ones? | |
| Would you play again to see a different ending? | |

## 5. Results template (facilitator, after all sessions)

**Per tester**

| Tester | Date | Build | Finished? | Time to end | Ending | Board solved? | Ritual done? | Hints given |
|---|---|---|---|---|---|---|---|---|
| T1 | | | | | | | | |
| T2 | | | | | | | | |
| T3 | | | | | | | | |
| T4 | | | | | | | | |
| T5 | | | | | | | | |

**Scores** (weighted total = 2.5·Gameplay + 2.5·Atmosphere + 2.0·Story + 2.0·Stability + 1.0·Replay, out of 100)

| Tester | Gameplay | Atmosphere | Story | Stability | Replay | Weighted /100 |
|---|---:|---:|---:|---:|---:|---:|
| T1 | | | | | | |
| … | | | | | | |
| **Median** | | | | | | |

Compare with: the developers' V1 score (70.5) and the Codex audit's V1 score (67.25: Gameplay 5.5, Atmosphere 8.0, Story 8.5, Stability 5.0, Replay 6.5).

**Patterns:** list each issue seen in two or more testers, its times, and a proposed fix. Treat an issue seen only once as a lead, not a conclusion.

| Issue | Testers | Where / when | Proposed change |
|---|---|---|---|
| | | | |

**Decisions:** what to change before the next round, and what to leave alone because players liked it.
