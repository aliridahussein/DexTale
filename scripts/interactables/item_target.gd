class_name ItemTarget
extends Interactable
## Something an inventory item can be used on (V2.2): the broken chain, the
## old lantern post. The target validates the item; the area script reacts to
## `item_used` and decides what happens (and which flags use the item up).
##
## Pressing E here:
##  - while holding an accepted item  -> uses it;
##  - while holding any other item    -> a short refusal, nothing is lost;
##  - holding nothing, but carrying an accepted item -> uses that item
##    directly (no need to open the inventory for the obvious action);
##  - otherwise -> the normal inspection (conversation_id).

signal item_used(item_id: String, by: Node)

## Item ids this target accepts, e.g. "hooked_line" or "token, old_lantern".
@export var accepts := ""
## What Rowan says when a held item doesn't fit (else the item's own refusal).
@export var refusal := ""
## Offer an accepted item the player carries without having to hold it first.
@export var auto_use := true


func accepted_items() -> Array[String]:
	var out: Array[String] = []
	for s in accepts.split(",", false):
		out.append(s.strip_edges())
	return out


## The accepted item that would be used right now, or "".
func usable_item() -> String:
	var held := Inventory.held
	if held != "" and accepted_items().has(held):
		return held
	if held == "" and auto_use:
		for id in accepted_items():
			if Inventory.has(id):
				return id
	return ""


func prompt_text() -> String:
	var held := Inventory.held
	if held != "":
		return "Use " + Inventory.item_name(held)
	var id := usable_item()
	if id != "":
		return "Use " + Inventory.item_name(id)
	return prompt


func interact(by: Node) -> void:
	if not is_available():
		return
	var id := usable_item()
	if id != "":
		if sfx != "":
			AudioManager.play_sfx(sfx)
		item_used.emit(id, by)
		return
	if Inventory.held != "":
		var text := refusal if refusal != "" else Inventory.use_refusal(Inventory.held)
		UI.caption(text, get_prompt_position() + Vector2(0, -4))
		AudioManager.play_sfx("ui_back", -8.0)
		return
	super.interact(by)
