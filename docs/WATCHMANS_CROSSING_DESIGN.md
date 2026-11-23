# The Watchman's Crossing (V2.2): design

A new encounter between the Hollow Sentinel and the bell tower. The road from the Mistbound Path ends at a ravine. Its drawbridge is raised and the lifting chain is broken. Beside it stands the watchhouse of the guard who kept it. Across the ravine, once the bridge is down, something still walks his round.

The crossing adds three kinds of play the prototype didn't have:

- **An inventory and an environmental repair:** take the guard's tools, make the Hooked Line, mend the chain, then work the winch at safe tension.
- **Stealth:** get past the Watchman's Shadow with light, distance and cover.
- **An optional investigation, "The Last Promise":** find out what the watchman was waiting for, and give his memory back.

The crossing reuses V2's systems: Echo listening (F), the Echo Reconstruction board, the journal, the save format. The only new system is the inventory (see `docs/INVENTORY_SYSTEM.md`).

## Where it sits

```
Mistbound Path --(north road, needs passed_sentinel)--> The Watchman's Crossing --(bridge, needs bridge_lowered)--> Bell Tower
                                                            |                                                        |
                                                       Watchhouse                                   stairs down (back to the crossing)
```

- Both ways past the Sentinel (understood or endured) set `passed_sentinel`, so both lead here.
- A new main objective sits between the Sentinel and the tower: **"Find a way across the old crossing."** It is done when Rowan enters the tower (`crossing_complete`).
- **"Confront the truth of the bell"** now starts at `crossing_complete`.
- The tower's stairs lead back down to the crossing. The stairwell was walled in by a tile row in V1, so the exit there could never be reached. V2.2 opens it, so the optional thread stays possible after reaching the tower.

## The places

**The crossing** (26 × 38 tiles):
- **South:** the road up from the Mistbound Path, dark tall grass, and the watchhouse with its lit window.
- **The bridge head:**
  - the raised drawbridge;
  - the winch, with its lower chain torn free and hanging over the edge;
  - the counterweight;
  - an old post with a lantern hook, notches cut down its side;
  - a lantern post.
- **The ravine:** cliff faces and a deep blue void with mist rising out of it.
- **The far bank:** the Shadow's round, three stone supports, the far lantern, and the road on to the tower, which is visible in the distance.

**The watchhouse** (14 × 10 tiles):
- a desk with the logbook, a tin cup and a crust nobody came back for;
- the Old Lantern;
- a tool rack with the iron hook, and a peg with the coil of rope;
- shelves with spare wicks and a child's blue scarf, folded and never unfolded;
- crates and barrels;
- a chair facing the window, and on the sill an iron token;
- tally marks on the wall, in fives, hundreds of them, until they stop.

All art comes from the existing Python generators, in the same palette, outlines and lighting as the rest of the game. New props, tiles, the Shadow's sprite sheet, icons and sounds were appended after the existing ones, so every existing generated file is byte-identical. The one exception is the tower scene, whose stairwell row was opened.

## The bridge: three states, in order

| State | Flags | What the player sees |
|---|---|---|
| unrepaired | — | The bridge is raised; the ravine blocks the way. The chain hangs over the edge. |
| repaired | `chain_secured` | The chain is lashed back onto the winch drum. The bridge is still up. |
| lowered | `bridge_lowered` | The deck spans the ravine and the way is open. The Shadow walks the far bank. |

States only move forward, one step at a time. The winch refuses to drop an unrepaired bridge, and can't be worked twice. Nothing resets them: not leaving, not the watchhouse, not saving and loading, not being caught.

### Reading the problem

The game tells the player what to do in four ways, and never with a tutorial box:

1. **The chain:** "The lower chain has torn free of the winch. Its broken end hangs over the edge, just out of reach."
2. **The winch alone:** "Released now, the weight would only drop the bridge into the ravine."
3. **The logbook:** "When the lower chain fails, secure it before releasing the weight. The bridge must never fall freely."
4. **The winch's Echo (F):** a ghost guard drops a hook over the edge, catches the chain, then turns the wheel, and a ghost bridge comes down. Rowan: "Hook first. Then the wheel."

### The repair

The rope and the hook combine in the inventory into the **Hooked Line**, in either order. E at the chain uses it; there is no need to hold it first. In the short scene that follows:

- the line is thrown, and the hook arcs down over the edge and catches the chain with sparks;
- the chain is hauled up and lashed to the drum, with dust;
- a caption: "The hook bites. The chain is lashed back onto the winch."

### The winch (tension)

A panel under the mechanism shows a tension gauge from 0 to 100:

| Zone | Range | On the gauge |
|---|---|---|
| Too loose | below 40 | Light diagonal hatching. "Too loose: the chain sags". |
| **SAFE** | 40 to 66 | A solid gold band. "SAFE tension". |
| Too tight | above 66 | Dense red hatching. "Too tight: the chain groans". |

The zones differ by pattern and text, not only by colour.

**Controls:** hold A/D or ←/→ to turn (or hold the on-screen − / + labels with the mouse). E (or Enter, or the Release label) releases the counterweight. Esc steps back.

**How the chain behaves:**
- **Resistance:** the wheel gets heavier as the chain tightens (down to 30 % speed near the top). The needle slows as it nears the band.
- **Creep:** left alone above the safe band, the chain eases back by 3 per second.
- **Releasing too loose:** "The chain slips and sags. Too loose: tighten it first." Tension drops by 8.
- **Releasing too tight:** "The chain groans and the wheel kicks back. Too tight: ease it off." Tension is set to 72, still adjustable.
- **Releasing at safe tension:** the counterweight takes the strain and the bridge lowers.

The logic is `scripts/systems/winch_puzzle.gd`. It has no randomness and is unit-tested, and it can't break, jam or lock.

**The lowering:**
- The camera pans to the bridge. The winch turns and the counterweight drops.
- The raised span folds down as the deck swings into place.
- A deep thud, dust along the edge, a shake, and the bridge's collision opens.
- The wind drops, the lantern across the ravine lights itself, and a figure that wasn't there begins to walk. Caption: "Something on the other side is watching the bridge." (Or "…has noticed your light." if the lantern is open.)

## The Old Lantern

Rowan takes the Old Lantern from the watchhouse. It is still burning and never needs fuel.

**L** opens or closes its iron shutter. So does the inventory. The HUD says "Lantern: lit" or "Lantern: shuttered".

| | Shutter open | Shutter closed |
|---|---|---|
| Rowan's light | Brighter and wider | His usual soft light |
| The Shadow sees him from | 120 px | 44 px |
| Shows | Footprints along the Shadow's round, the two rotten planks | Nothing extra |

Light is both help and risk. It shows the safe footing, but it carries.

## The Watchman's Shadow

What is left of Edrin, the guard, who forgot why he waits. It is not an enemy to fight: it walks the round he walked and notices light.

**Its round:** a rectangle on the far bank, (112, 196) → (304, 196) → (304, 112) → (112, 112). It walks at 20 px/s and pauses 1 s at each corner.

**Sight.** It sees Rowan only if all three hold:

1. **Range:** within 120 px with the lantern open, 44 px with it closed (always within 16 px).
2. **Cone:** inside a cone of about ±62° around where it faces (not needed within 16 px).
3. **Line:** a clear line, a ray against world collision. Walls, props and the three stone supports block it. The ravine doesn't.

It never sees during dialogue, scenes or menus.

**Awareness (0 to 1)** is the warning system:

- While Rowan is seen, awareness rises: by 0.35/s at the edge of its range, up to 1.0/s right in front of it. While he isn't seen, it falls by 0.35/s.
- **At 0.25, SUSPICIOUS:**
  - it stops and turns toward him;
  - a pulsing **?** appears above it, with a low alert sound;
  - its cone, drawn on the ground, warms from pale blue to amber, and its eyes and lantern brighten.
- **At 1.0, caught.** From the first "?" that takes at least 0.75 s, and usually well over a second. A step behind a support or out of range lets it fade.

**States:**

| State | Behaviour |
|---|---|
| DORMANT | Before the bridge comes down: not there. |
| PATROL | Walks the round. |
| SUSPICIOUS | Stops, faces the last sighting, "?". After 1.2 s without seeing Rowan → INVESTIGATE. |
| INVESTIGATE | Walks to where it last saw or heard him, looks around for 2.2 s → RETURN. Seeing him again keeps it suspicious. |
| RETURN | Walks back to its round → PATROL (or SUSPICIOUS if it sees him on the way). |
| RESOLVED | At peace (the Last Promise). Lowered spear, dim eyes, stands aside. Never hostile again. |
| QUIET | After Rowan has crossed into the tower. Only a figure by its lantern. |

**It keeps to its bank.** Investigation targets are clamped to the far bank. Seeing or hearing Rowan on the bridge brings it to the bridge head to look down the deck, never out over the void. This was a fix found by the tests; it originally drifted straight over the ravine.

**The rotten planks.** Two half-planks on the deck are rotten: the west half at about a third of the way across, the east half further on. Stepping on one creaks, with a sound and a small shake. The first time, a caption reads: "The plank creaks. Something on the far bank turns." The Shadow becomes suspicious and comes to the bridge head to look. In lantern light the rotten planks show as pale marks; in the dark they are hard to see. That is the trade-off.

**Being caught** is a setback, not a failure:

- A cold flash, a fade, and Rowan is back at the bridge head. The Shadow is back at the start of its round.
- Nothing is lost: not items, not the lowered bridge, not flags.
- Saving pauses for the second this takes, then is allowed again. If the area is left or the game returns to the title mid-catch, every lock and save block is released.
- The first catch gets "The cold lets go of you at the bridge head." After that, hints, one per catch:
  1. "Those stone pillars may be enough to hide the lantern's glow."
  2. "With the shutter closed (L), it has to come much closer to see you."

**A route that works** (and that the tests walk): shutter closed, up the west side of the deck, across in the gap between the rotten halves, up the east side, then up the road while the Shadow is on the far side of its round. The supports give cover with the lantern open too.

## The Last Promise (optional)

An optional thread that rewards attention. It begins when Rowan takes the token from the window sill. Journal: "Find out what the watchman was waiting for."

**The clues:**

| Clue | Where | What it shows |
|---|---|---|
| The token (required) | Window sill | "Two initials scratched into iron: E., and one worn away by a thumb." |
| The chair (required) | Echo at the chair by the window | A child: "Will you still be here when I come back?" The guard: "Until the last lantern goes out." |
| The post (required) | Echo at the post by the bridge | Someone waiting by the lit post; a small figure on the road; the bell; a flicker; nothing. |
| The wall (supporting) | Tally marks | Nights counted in fives, hundreds of them, until they stop. |

**The deduction.** Inspecting the token in the inventory lays the clues out on the Echo Reconstruction board: **"What was the Watchman waiting for?"** With clues missing, the board says how many are still needed and can be put away. There are three answers:

- **Orders from the bellkeeper:** ruled out by the chair. "He made his promise to a child, not to a superior."
- **A signal to close the bridge:** ruled out by the post. "He kept the lantern lit and watched the road for someone coming."
- **Someone who promised to return:** correct.

Wrong answers are crossed off with the reason and cost nothing. Rowan: "He wasn't guarding the bridge. He was waiting at it, for someone who promised to come back."

**The resolution.** Before the promise is understood, E at the post only looks at it. Holding the token there gets a gentle "Not yet. What was he waiting for?". Afterwards, E at the post offers the token. Then:

- the token goes back on the post, and the Shadow stops mid-round and turns toward it;
- the camera finds them both, and a small warm figure appears beside him for a moment;
- his eyes dim, he lowers his spear and steps aside;
- the narrator: **"He no longer remembers her face. But he remembers that he waited."**

**Consequences:**
- The Shadow never patrols again, also after loading.
- **Orin** has a new line in the tower: "There was a watchman at the crossing." → "Edrin. He kept that crossing longer than I've kept this tower… Then the bell didn't take everything. It never quite does."
- **The epilogue** remembers it, in every ending. With The Chorus: "…someone walked out to the old crossing and lit the lantern on the post. The watchman wasn't there any more. He didn't need to be." Otherwise: "The lantern on the post by the old crossing is lit every evening now. Nobody remembers who started doing it."

The thread is fully optional. Sneaking past and never touching the token is a complete route. It can be finished before or after crossing.

## Saves and older saves

- No new save fields: all crossing state is flags. The save format stays `version: 1`, with V2's crash-safe write.
- **V1 and V2 saves made in the tower** have never seen the crossing. On arrival the tower marks the crossing as done (`crossing_complete`), so the objective resumes at "Confront the truth of the bell".
- If such a save goes back down the stairs, the crossing treats the bridge as already down (chain secured, bridge lowered). Rowan arrives on the far bank; the Shadow is quiet; the inventory holds just the pin and the key.
- **Saves on the Mistbound Path** past the Sentinel continue normally: the north road now leads to the crossing.
- **Lifecycle:** the crossing's scene locks ("repair", "bridge", "token", "watchman_caught") are released whenever the area leaves the tree. The capture's save block is owned by the area and released with it.

## Input and accessibility

- **Keyboard:** WASD/arrows move, E interacts, F listens, **I** inventory, **L** lantern, J journal, Esc pause or back.
- **Mouse:** works in the inventory (slots, actions) and on the winch (−, +, Release).
- **Controller:** Back / View opens the inventory and LB works the shutter, alongside the existing bindings (untested, like all gamepad input).
- **No input leaks:** the inventory pauses the game. The winch and every scene hold Rowan still, and movement keys can't carry over.
- **Not by colour alone:**
  - the winch zones use hatching, solid fill and text;
  - the Shadow uses "?" and "!" marks and a cone that changes size and brightness, plus sound;
  - creaks have sound, shake and a caption;
  - the lantern state is written on the HUD.
- Captions are short, sit near what they describe, and never block input.

## Code map

| File | Role |
|---|---|
| `scripts/world/crossing.gd` | Area: bridge states, repair, winch, lowering, ravine collision, rotten planks, capture and hints, the Last Promise, the Echo sequences, old-save migration. |
| `scripts/world/watchhouse.gd` | Interior: lantern light, the chair's memory. |
| `scripts/world/watchman_shadow.gd` | The Shadow: state machine, sight, awareness, visuals. |
| `scripts/systems/winch_puzzle.gd` | Pure winch logic. |
| `scripts/ui/winch_view.gd` | The winch panel. |
| `scripts/autoload/inventory.gd`, `scripts/ui/inventory_view.gd`, `scripts/interactables/item_*.gd` | The inventory (own doc). |
| `data/items.json`, `data/dialogue/crossing.json`, `data/reconstructions.json` (`watchman_promise`), `data/documents.json` (`watch_log`), `data/quests/quests.json`, `data/endings.json`, `data/dialogue/tower.json` | Content. |
| `tools/build/levels.py` (`crossing()`, `watchhouse()`), `tools/art/*.py`, `tools/audio/generate_audio.py` | Generated levels, art and sound. |

## Tuning values

| Value | Where | Now |
|---|---|---|
| Sight range, lantern open / closed / any direction | `watchman_shadow.gd` | 120 / 44 / 16 px |
| Cone half-angle | `watchman_shadow.gd` | 1.08 rad (about 62°) |
| Suspicion threshold / decay | `watchman_shadow.gd` | 0.25 / 0.35 per second |
| Walk speed, corner pause, search time | `watchman_shadow.gd` | 20 px/s, 1.0 s, 2.2 s |
| Safe band, start, turn rate, creep | `winch_puzzle.gd` | 40 to 66, 12, 46 per second, 3 per second |

These are first-pass values, chosen for readability and fairness, and checked by the automated tests and the windowed tour. They have **not** been tuned with real players yet; see `docs/V2_2_PLAYTEST_GUIDE.md`.
