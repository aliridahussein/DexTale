extends Node
## Objectives and journal discoveries, all driven by story flags.
##
## data/quests/quests.json defines:
##   objectives:  {id, title, detail, start (condition), done (condition), optional}
##   discoveries: {id, when (condition), title, text}
## Nothing here is set directly: progress is just a view of GameState flags.

signal objective_changed(objective: Dictionary)
signal journal_updated(entry: Dictionary)

const PATH := "res://data/quests/quests.json"

var objectives: Array = []
var discoveries: Array = []
var _last_primary := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		objectives = parsed.get("objectives", [])
		discoveries = parsed.get("discoveries", [])
	else:
		push_error("QuestManager: cannot read %s" % PATH)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_reset.connect(refresh_silently)
	GameState.state_loaded.connect(refresh_silently)


func is_started(o: Dictionary) -> bool:
	return GameState.check(o.get("start", ""))


func is_done(o: Dictionary) -> bool:
	return GameState.check(o.get("done", "__never__"))


func get_active() -> Array:
	return objectives.filter(func(o: Dictionary) -> bool: return is_started(o) and not is_done(o))


func get_primary() -> Dictionary:
	for o in get_active():
		if not o.get("optional", false):
			return o
	return {}


func get_optional_active() -> Array:
	return get_active().filter(func(o: Dictionary) -> bool: return o.get("optional", false))


func get_completed() -> Array:
	return objectives.filter(func(o: Dictionary) -> bool: return is_started(o) and is_done(o))


func get_discovery(id: String) -> Dictionary:
	for d in discoveries:
		if d.get("id", "") == id:
			return d
	return {}


## Discoveries in the order the player found them.
func get_discoveries() -> Array:
	var out: Array = []
	for id in GameState.discovery_log:
		var d := get_discovery(str(id))
		if not d.is_empty():
			out.append(d)
	return out


func refresh_silently() -> void:
	_sync_discoveries(false)
	_last_primary = str(get_primary().get("id", ""))


func _on_flag_changed(_flag: String, _value: Variant) -> void:
	_sync_discoveries(true)
	var p := get_primary()
	var pid := str(p.get("id", ""))
	if pid != _last_primary:
		_last_primary = pid
		if pid != "":
			objective_changed.emit(p)
		SaveManager.request_autosave()


func _sync_discoveries(notify: bool) -> void:
	for d in discoveries:
		var id := str(d.get("id", ""))
		if id == "" or GameState.discovery_log.has(id):
			continue
		if GameState.check(d.get("when", "__never__")):
			GameState.discovery_log.append(id)
			if notify:
				journal_updated.emit(d)
