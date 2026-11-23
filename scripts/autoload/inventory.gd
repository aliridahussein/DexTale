extends Node
## Inventory (V2.2): what Rowan carries, as a view over story flags.
##
## Items are defined in data/items.json. Ownership is the condition `owned`
## evaluated on GameState flags, so there is a single source of truth: the
## same flags the dialogue, quests and save system already use. Old saves
## simply lack the new flags and therefore own none of the new items.
##
## Picking up sets an item's `found_flag` (once, never cleared: no duplicates).
## Using an item up sets the flag that makes `owned` false. Nothing here keeps
## a second list that could drift out of sync.

signal changed
signal item_gained(item_id: String)
signal held_changed(item_id: String)
signal lantern_changed(on: bool)

const DATA_PATH := "res://data/items.json"
const ACTIONS := ["inspect", "hold", "combine", "light"]

var defs: Array = []
var combinations: Array = []
var refusals: Array = []
var fallback := "Those don't go together."
## When a held item is used on something in the world that doesn't take it.
var use_fallback := "That won't help here."
## The item Rowan is holding ready to use on something in the world ("" = none).
## Not saved: it is a moment-to-moment choice, not progress.
var held := ""

var _by_id: Dictionary = {}
var _owned: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_reset.connect(_resync)
	GameState.state_loaded.connect(_resync)
	_owned = _compute_owned()


func load_data() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		push_error("Inventory: cannot read %s" % DATA_PATH)
		return
	defs = parsed.get("items", [])
	combinations = parsed.get("combinations", [])
	refusals = parsed.get("refusals", [])
	fallback = str(parsed.get("fallback", fallback))
	use_fallback = str(parsed.get("use_fallback", use_fallback))
	_by_id.clear()
	for d in defs:
		_by_id[str(d.get("id", ""))] = d


# ------------------------------------------------------------------ query --
func def(id: String) -> Dictionary:
	return _by_id.get(id, {})


func item_name(id: String) -> String:
	return str(def(id).get("name", id))


func has(id: String) -> bool:
	var d := def(id)
	return not d.is_empty() and GameState.check(d.get("owned", "__never__"))


## Owned item ids, in definition order (stable slots).
func owned() -> Array[String]:
	return _owned.duplicate()


func can(id: String, action: String) -> bool:
	return action in (def(id).get("actions", []) as Array)


# ---------------------------------------------------------------- changes --
## Pick an item up. Returns false if it was already found (never duplicates).
func give(id: String) -> bool:
	var flag := str(def(id).get("found_flag", ""))
	if flag == "" or GameState.has_flag(flag):
		return false
	GameState.set_flag(flag, true)
	if id == "old_lantern":
		GameState.set_flag("lantern_on", true)  # it has been burning all along
	return true


## Combine two owned items. Order doesn't matter. Nothing is used up on failure.
## Returns {ok, text, result}.
func combine(a: String, b: String) -> Dictionary:
	if a == b or not has(a) or not has(b):
		return {"ok": false, "text": "Choose two different things you are carrying.", "result": ""}
	for c in combinations:
		var pair: Array = c.get("items", [])
		if (pair == [a, b]) or (pair == [b, a]):
			var values: Dictionary = c.get("set", {})
			for k in values:
				GameState.set_flag(k, values[k])
			return {"ok": true, "text": str(c.get("text", "")), "result": str(c.get("result", ""))}
	return {"ok": false, "text": refusal_text(a, b), "result": ""}


## The most specific refusal for an invalid pair: exact pair, then a rule for
## either item ("*"), then the general fallback.
func refusal_text(a: String, b: String) -> String:
	for r in refusals:
		var pair: Array = r.get("items", [])
		if (pair == [a, b]) or (pair == [b, a]):
			return str(r.get("text", fallback))
	for r in refusals:
		var pair: Array = r.get("items", [])
		if pair.size() == 2 and pair[1] == "*" and (pair[0] == a or pair[0] == b):
			return str(r.get("text", fallback))
	return fallback


## Rowan tries a held item on something that doesn't take it: the item's own
## line if it has one (["tuning_pin", "*"]), else the general one.
func use_refusal(id: String) -> String:
	for r in refusals:
		var pair: Array = r.get("items", [])
		if pair.size() == 2 and pair[0] == id and pair[1] == "*":
			return str(r.get("text", use_fallback))
	return use_fallback


func set_held(id: String) -> void:
	if id != "" and (not has(id) or not can(id, "hold")):
		return
	if held != id:
		held = id
		held_changed.emit(held)


func clear_held() -> void:
	set_held("")


# ---------------------------------------------------------------- lantern --
func lantern_on() -> bool:
	return has("old_lantern") and GameState.has_flag("lantern_on")


## Open or close the lantern's shutter. Returns the new state.
func toggle_lantern() -> bool:
	if not has("old_lantern"):
		return false
	GameState.set_flag("lantern_on", not GameState.has_flag("lantern_on"))
	return lantern_on()


# --------------------------------------------------------------- internal --
func _compute_owned() -> Array[String]:
	var out: Array[String] = []
	for d in defs:
		var id := str(d.get("id", ""))
		if GameState.check(d.get("owned", "__never__")):
			out.append(id)
	return out


func _on_flag_changed(flag: String, _value: Variant) -> void:
	var now := _compute_owned()
	if now != _owned:
		var before := _owned
		_owned = now
		for id in now:
			if not before.has(id):
				item_gained.emit(id)
		if held != "" and not now.has(held):
			clear_held()
		changed.emit()
	if flag == "lantern_on" or flag == "found_lantern":
		lantern_changed.emit(lantern_on())


func _resync() -> void:
	_owned = _compute_owned()
	held = ""
	held_changed.emit("")
	lantern_changed.emit(lantern_on())
	changed.emit()
