# Inventory system (V2.2)

The inventory is what Rowan carries, shown on its own screen (press **I**). It was added for the Watchman's Crossing, but nothing in it is specific to that area. Items, combinations and refusal texts live in `data/items.json`, so new items need no new code.

## One source of truth

The inventory does not keep its own list of items. Every item has an `owned` condition over story flags, written in the same `GameState.check` syntax the dialogue and quests use. For example:

| Item | `owned` | Meaning |
|---|---|---|
| Iron Tuning Pin | `has_tuning_pin, !pin_installed` | Mara gives it; it leaves only when it goes into the bell. |
| Iron Key | `has_gate_key` | Found in the ledger; kept as a keepsake after the gate. |
| Tobin's Lantern | `has_tobin_lantern` | V2's lantern. Inspect only: it is not the Old Lantern. |
| Old Lantern | `found_lantern` | Taken in the watchhouse. Never used up. |
| Strong Rope / Iron Hook | `found_rope, !made_hooked_line` (and the hook's version) | Used up when combined. |
| Hooked Line | `made_hooked_line, !chain_secured` | Used up on the broken chain. |
| Watchman's Token | `found_token, !token_placed` | Optional. Used up on the post. |

This has three consequences:

- **The save file needs no new fields.** Saving already stores the flags, so it stores the inventory too. The format stays `version: 1`.
- **Older saves just work.** A V1 or V2 save has none of the new flags, so it owns none of the new items. Its pin and key appear because their flags already exist.
- **Nothing can drift out of sync.** A second list could disagree with the story; a view over the flags can't.

## Picking things up once

Items found in the world have a `found_flag` (for example `found_rope`). `Inventory.give(id)` sets it once and refuses if it is already set. The flag is never cleared, even when the item is used up later, so:

- a pickup can't happen twice, even if E is pressed twice in one frame;
- after leaving and returning, or after loading a save, the pickup stays hidden (`ItemPickup` hides itself with `hidden_when = found_flag`), and its sprite stays gone, or an empty rope peg stays empty.

Items that come from story scenes (the pin, the key, Tobin's lantern) have no `found_flag`. Their scenes already show "Received: …", so the inventory doesn't add a second toast for them. Pickups get exactly one toast.

## Actions

Each item lists the actions it supports (`actions` in `items.json`):

| Action | What it does |
|---|---|
| **Inspect** | Shows a longer description. The token instead opens its Echo Reconstruction board until it is solved. |
| **Hold** | Closes the inventory with the item in hand. The HUD shows "Holding: …", and prompts become "Use …". E on a target uses it. Choosing Hold again shows "Put away". |
| **Combine** | Pick a second item. Order doesn't matter (rope + hook = hook + rope). |
| **Shutter** | The Old Lantern only. Opens or closes it (the same as **L**). |

Actions an item doesn't support are greyed out. Choosing one says why ("That doesn't go with anything."), so the screen never silently ignores a key.

## Combining

`combinations` in `items.json` pairs two item ids with a `result` and the flags to `set`:

```json
{"items": ["rope", "hook"], "result": "hooked_line", "set": {"made_hooked_line": true},
 "text": "You knot the hook to the rope's end. Now it can catch something out of reach."}
```

Invalid pairs never use anything up. The refusal text is the most specific one available:

1. an exact pair, for example *pin + rope*: "A fine instrument, but not the tool for this job.";
2. a rule for either item (`["tuning_pin", "*"]`);
3. the general fallback: "Those don't go together."

Combining an item with itself, or with something not carried, is refused the same way.

## Using items on the world

`ItemTarget` (`scripts/interactables/item_target.gd`) is an `Interactable` that accepts item ids (`accepts = "hooked_line"`). When Rowan presses E on it:

- **Holding an accepted item:** the item is used. The target emits `item_used(item_id, by)`, and the area script decides what happens and which flag uses the item up.
- **Holding something else:** a short caption refuses it, and the item stays in hand. The caption is the item's own line if it has one (the pin: "The pin is for the bell. You won't risk it on anything else."), else `use_fallback` ("That won't help here.").
- **Holding nothing, carrying an accepted item, `auto_use` on:** that item is used directly. Nobody has to open the inventory for the obvious step (the Hooked Line on the chain).
- **Otherwise:** the target's normal inspection conversation plays.

The waiting post starts with `auto_use = false`, so E there only looks at it. Before the Watchman's promise is understood, holding the token there gets a gentle "Not yet." Once the promise is known, the post offers the token by itself.

A used-up item stops being held automatically, because it is no longer owned.

## The Old Lantern

- **L** opens or closes the shutter. So does the inventory's Shutter action.
- L does nothing without the lantern, while talking, in menus or during scenes.
- The lantern is taken lit (`lantern_on`), because it has been burning all along. It has no fuel and never runs out.
- Open, it brightens Rowan's carried light and shows things only lantern light reveals: footprints on the Shadow's round, the rotten planks on the bridge.
- Open or closed, the HUD says it in words ("Lantern: lit" / "Lantern: shuttered"), not only by colour.
- The Watchman's Shadow sees an open lantern from 120 px away and a closed one from 44 px (see the design doc).

## Input, pausing and accessibility

- The screen pauses the game. Movement keys move the cursor and never reach Rowan, and nothing walks or sees while it is open.
- **Keyboard:** arrows or WASD move, E or Enter selects, Esc goes back one step (actions to slots, then closed), I closes.
- **Mouse:** click a slot, then click an action.
- I does nothing during dialogue, menus or scenes.
- The selected slot has a double gold frame; while combining, a blue frame marks the first item. The held item has a gold underline. The message line always says in words what happened.
- Icons are 16×16 on 30×30 slots. Names and descriptions use the game's font at its normal size.

## Code map

| File | Role |
|---|---|
| `data/items.json` | Items, combinations, refusals, fallback text. |
| `scripts/autoload/inventory.gd` | `Inventory` autoload: `owned()`, `has()`, `give()`, `combine()`, `refusal_text()`, `set_held()`, `toggle_lantern()`. Signals: `changed`, `item_gained`, `held_changed`, `lantern_changed`. |
| `scripts/interactables/item_pickup.gd` | Things to take. Gives once, lifts and fades the sprite (or switches it to an "empty" frame). |
| `scripts/interactables/item_target.gd` | Things to use items on. |
| `scripts/ui/inventory_view.gd` | The screen (8 slots, actions, combine mode, mouse support). Built by `tools/build/build_ui.py`. |
| `scripts/ui/ui.gd` | Opens it on I, shows "Received" toasts and the HUD's Holding / Lantern chips. |

## Adding an item

1. Draw a 16×16 icon in `tools/art/ui_art.py` (append it, so existing icons stay byte-identical), then run the art build.
2. Add the item to `data/items.json`: `id`, `name`, `icon`, `owned`, optionally `found_flag`, `actions`, `description`, `inspect`.
3. Register every new flag in `data/flags.json`. `test_data.gd` fails otherwise.
4. Put an `ItemPickup` in a level (`L.pickup(...)` in `tools/build/levels.py`), and an `ItemTarget` for wherever it is used (`L.item_target(...)`). Connect the target's `item_used` in the area script.
5. Add a test in `tests/test_inventory.gd`.

## Tests

- `tests/test_inventory.gd` (12 tests):
  - Existing items follow their flags.
  - Pickups happen once and stay taken.
  - Story items don't toast twice.
  - Combining works in either order, and wrong pairs explain themselves and keep both items.
  - The whole keyboard flow, with Rowan not moving.
  - Disabled actions say why.
  - Hold and use, including a wrong item being refused and kept.
  - Pressing E with nothing held uses the obvious item.
  - The L shutter.
  - Save and load.
  - A V1 save's inventory.
- `tests/test_data.gd` → `test_items_are_well_formed`: icons exist, actions are known, every item and combination flag is registered, and combinations and refusals name real items.
