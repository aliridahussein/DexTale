# The Thirteenth Bell: game design

*Every night the bell saves the village. Every night, someone forgets why.*

A 10 to 20 minute narrative mystery in a medieval village. It's a top-down pixel-art adventure with light puzzles and no combat.

## Premise

For generations a great bell has rung twelve times each sundown to hide Dawnmere from the Hollow Mist. Tonight it is silent, and the old bellkeeper, Orin, is missing. Rowan, his former apprentice, comes home because of a one-line letter:

> "Come home before the thirteenth toll. There is something I need you to remember."

**The twist.** Each toll takes one cherished memory from someone in the village. The bell was cast as an easier substitute for an older ritual, in which the whole village sang a thirteen-note song together at dusk. The thirteenth mark on the bell is not a toll. It is the song's last note, the note that gives back.

## Themes

Memory and identity, the cost of safety, forgotten promises, and community as protection. The tone is unsettling but warm, with humour in the side details.

## Characters

| Character | Role | Voice |
|---|---|---|
| **Rowan** (player) | Orin's apprentice, back after years away. Because Rowan was away, the bell never reached them. | Observant, dry. The player sets the attitude through choices. |
| **Pip** (about 10) | Gives the first objective and keeps the old song alive. | Curious, strange, funny. |
| **Mara** | Blacksmith; her family keeps the bell's iron tuning pin. She lost the lullaby she sang her son. | Practical, dry humour. |
| **Brother Alden** | Archivist. He once helped Orin cut pages from the records, then forgot doing it. | Soft-spoken, guilty. |
| **Tobin** | Lamplighter (ambient NPC). He forgot Elsie, but still lights her lantern. | Kindly, absent-minded. |
| **The Hollow Sentinel** | A boy who guarded the road when the bell was cast. Nobody remembers his name. | Spare, formal. |
| **Orin's echo** | Fed the bell his own memories to spare everyone else; nothing of him is left but an echo. | Gentle, regretful. |

## Areas and pacing (critical path)

| # | Area | What happens | Typical time |
|---|---|---|---|
| 0 | Prologue | Twelve tolls in the dark (shown as marks too), then the letter. | 0.5 min |
| 1 | Village square | Arrival cutscene, Pip, the well's echo, Tobin, notices. | 2 to 3 min |
| 2 | Mara's forge | The pin and its hidden marking (Echo), Mara's lullaby. Mara gives Rowan the pin. | 2 to 3 min |
| 3 | The chapel | Alden, the inscription (Echo), the **Three Seals** puzzle, the Ledger, the key. | 3 to 4 min |
| 1 | Village at night | *Optional:* Pip's song. The north gate opens. | 1 to 2 min |
| 4 | Mistbound Path | The **Hollow Sentinel**: answer its riddle, or endure the mist. | 1.5 to 3 min |
| 5 | Bell tower | Install the pin, meet Orin's echo, make the **final choice**. | 3 to 4 min |
| | Ending | Narrated sequence, title card, epilogue, credits. | 1.5 min |

The village light shifts with the story: sunset, then dusk once Rowan has the pin, then night after the ledger.

## Mechanics

- **Interact (E):** the nearest available interactable in front of Rowan shows a prompt bubble.
- **Listen to the Echo (F).** The screen desaturates into violet, a ripple spreads, and the nearest echo point within range replays a fragment of the past. A "[F] Listen" hint appears whenever something nearby can be heard. Gameplay uses:
  - It reveals the pin's marking, which unlocks Mara's next conversation.
  - It makes the seal inscription readable, which gives the puzzle's answer.
  - It unlocks the Sentinel's story, which opens the peaceful route.
  - It reveals optional lore (the well, the cradle, the chorus, the ledger, the shrine, the bell's memories).
- **The Three Seals.** Flame, Moon and Crown sit beside the archive door. The inscription says *"Before the crown, the fire was born. Before the fire, the moon watched alone."*, so the answer is Moon, Flame, Crown.
  - The order is checked after three presses. A wrong order resets with a sound and a shake, and you can retry immediately.
  - Alden's hints get more direct after two failures.
- **The Hollow Sentinel** offers two routes:
  - *Understand:* listen to it (F), hear its story, then answer "The things they chose to do."
  - *Endure:* cross three telegraphed mist pulses. A pulse glows before it bursts. Being hit pushes you back to the start of the field. After three hits the pulses slow down, and walking back south cancels the attempt. You can never get stuck.
- **Choices with consequences.** About a dozen choices set flags that change later dialogue, the options available with Orin, and the epilogue: your attitude to Pip, the promise to Mara, accusing Alden, how you pass the Sentinel, and what you ask Orin.

## Endings

| Ending | Choice | Requirement | Feel |
|---|---|---|---|
| **The Keeper** | "Ring the bell. Pay the price." | always | Bittersweet. The village is safe, but Rowan loses their memory of Orin; a sepia memory dissolves. |
| **The Unbroken Promise** | "Break the bell. End the bargain." | always | Uncertain and hopeful. The mist comes, and lanterns light up one by one as the village gathers. |
| **The Chorus** | "Retune the bell. Sing the thirteenth note." | pin + full ledger + **Pip's song** (optional discovery) | Hopeful. The bell turns warm, memories rise as golden lights, and the village sings. |

After the ending, **"What Dawnmere remembers"** lists five to seven lines chosen from your flags, covering Orin, Mara, Pip, Alden, Tobin, the Sentinel and the village.

## Content in numbers

64 conversations with 317 spoken lines plus choices, 9 objectives (2 optional), 16 journal entries, 9 echo points, 46 documented flags, 3 endings, and a flag-driven epilogue.
