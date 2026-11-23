extends Node
## Global story state: flags, the current area and input locks.
##
## Everything that should survive a scene change or a save lives here.
## Story progress is a flat dictionary of named flags (see data/flags.json for
## the documented list). Systems read conditions through `check()`.

signal flag_changed(flag: String, value: Variant)
signal state_reset
signal state_loaded

## Area id -> scene path. The single source of truth for area scenes.
const AREAS: Dictionary = {
	"village": "res://scenes/world/village.tscn",
	"forge": "res://scenes/world/forge.tscn",
	"chapel": "res://scenes/world/chapel.tscn",
	"mist_path": "res://scenes/world/mist_path.tscn",
	"crossing": "res://scenes/world/crossing.tscn",
	"watchhouse": "res://scenes/world/watchhouse.tscn",
	"bell_tower": "res://scenes/world/bell_tower.tscn",
}

var flags: Dictionary = {}
var current_area: String = ""
var current_spawn: String = "default"
var play_time: float = 0.0
## Journal discoveries in the order they were found (ids from quests.json).
var discovery_log: Array = []

var _locks: Dictionary = {}
var _cond_regex: RegEx


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_cond_regex = RegEx.new()
	_cond_regex.compile("^\\s*(!)?\\s*([A-Za-z0-9_]+)\\s*(==|!=|>=|<=|>|<)?\\s*(.*?)\\s*$")


func _process(delta: float) -> void:
	if current_area != "":
		play_time += delta


func reset() -> void:
	flags.clear()
	discovery_log.clear()
	current_area = ""
	current_spawn = "default"
	play_time = 0.0
	_locks.clear()
	state_reset.emit()


# ------------------------------------------------------------------ flags --
func set_flag(flag: String, value: Variant = true) -> void:
	if flags.has(flag) and flags[flag] == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


## True when the flag exists and is truthy (non-zero, non-empty, true).
func has_flag(flag: String) -> bool:
	var v: Variant = flags.get(flag, false)
	if v is bool:
		return v
	if v is int or v is float:
		return v != 0
	if v is String:
		return v != ""
	return v != null


func inc_flag(flag: String, amount: int = 1) -> int:
	var v: int = int(flags.get(flag, 0)) + amount
	set_flag(flag, v)
	return v


## Evaluates a condition used by dialogue, quests and interactables.
## Accepts "" / null (always true), "flag", "!flag", "flag>=2", "flag==value",
## an Array of those, or the same list written as one string "a, !b, c"
## (handy for exported scene properties). Lists mean all must hold.
func check(condition: Variant) -> bool:
	if condition == null:
		return true
	if condition is Array:
		for c in condition:
			if not check(c):
				return false
		return true
	var text: String = str(condition).strip_edges()
	if text == "":
		return true
	if text.contains(","):
		return check(Array(text.split(",", false)))
	var m: RegExMatch = _cond_regex.search(text)
	if m == null:
		push_warning("GameState: cannot parse condition '%s'" % text)
		return false
	var negate: bool = m.get_string(1) == "!"
	var flag: String = m.get_string(2)
	var op: String = m.get_string(3)
	var result: bool
	if op == "":
		result = has_flag(flag)
	else:
		result = _compare(flags.get(flag, 0), op, _parse_value(m.get_string(4)))
	return not result if negate else result


func _parse_value(raw: String) -> Variant:
	if raw.is_valid_int():
		return raw.to_int()
	if raw.is_valid_float():
		return raw.to_float()
	if raw == "true":
		return true
	if raw == "false":
		return false
	return raw.trim_prefix("\"").trim_suffix("\"")


func _compare(a: Variant, op: String, b: Variant) -> bool:
	if (a is int or a is float or a is bool) and (b is int or b is float):
		var fa: float = float(a)
		var fb: float = float(b)
		match op:
			"==": return is_equal_approx(fa, fb)
			"!=": return not is_equal_approx(fa, fb)
			">=": return fa >= fb
			"<=": return fa <= fb
			">": return fa > fb
			"<": return fa < fb
	match op:
		"==": return str(a) == str(b)
		"!=": return str(a) != str(b)
	return false


# ------------------------------------------------------------ input locks --
## Several systems may lock player control at once (dialogue, a cutscene, a
## transition). Control returns only when every reason has been released.
func lock_input(reason: String) -> void:
	_locks[reason] = int(_locks.get(reason, 0)) + 1


func unlock_input(reason: String) -> void:
	if not _locks.has(reason):
		return
	_locks[reason] = int(_locks[reason]) - 1
	if int(_locks[reason]) <= 0:
		_locks.erase(reason)


func clear_lock(reason: String) -> void:
	_locks.erase(reason)


func is_input_locked() -> bool:
	return not _locks.is_empty()


func lock_reasons() -> Array:
	return _locks.keys()


# ----------------------------------------------------------- persistence --
func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"area": current_area,
		"spawn": current_spawn,
		"play_time": play_time,
		"discoveries": discovery_log.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	reset()
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	current_area = str(data.get("area", "village"))
	current_spawn = str(data.get("spawn", "default"))
	play_time = float(data.get("play_time", 0.0))
	discovery_log = (data.get("discoveries", []) as Array).duplicate()
	if not AREAS.has(current_area):
		current_area = "village"
		current_spawn = "default"
	state_loaded.emit()
