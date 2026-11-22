extends Node
## Single-slot save in user://savegame.json.
##
## Saves only happen at safe moments: never during dialogue, cutscenes,
## transitions or the mist challenge. Loading always goes through a normal area
## transition, so the player is placed at a spawn point (or the free position
## they stood at when the save was made).
##
## Writes are crash-safe (QA-08): the new save is written to a temporary file,
## read back and validated, and only then moved into place. The previous good
## save is kept as `savegame.json.bak` and is used automatically if the main
## file is ever missing or damaged. V1 saves use the same format and still load.

signal saved
## Emitted when a save was attempted but could not be written.
signal save_failed(message: String)

const DEFAULT_PATH := "user://savegame.json"
const VERSION := 1
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"

## Tests point this somewhere else so they never touch the player's save.
var save_path := DEFAULT_PATH
## Human-readable reason for the last failed write ("" after a good one).
var last_error := ""
## Which file the last successful read came from ("main", "temp", "backup").
var last_read_source := ""

var _pending_autosave := false
var _save_blocks: Dictionary = {}
var _warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A new game or a loaded game never inherits restrictions from the last one.
	GameState.state_reset.connect(_on_state_reset)


func _process(_delta: float) -> void:
	if _pending_autosave and can_save_now():
		_pending_autosave = false
		save_game(true)


func has_save() -> bool:
	return not _read().is_empty()


func save_info() -> Dictionary:
	return _read()


## True when a save file exists but neither it nor its backup can be used.
func has_unreadable_save() -> bool:
	return FileAccess.file_exists(save_path) and _read().is_empty()


# ---------------------------------------------------------------- blocking --
## Saving can be blocked for a reason (e.g. the Sentinel challenge). Pass the
## node that owns the restriction: the block is released automatically when
## that node leaves the scene tree, so returning to the title or loading a
## save can never leave saving disabled (QA-02).
func block_saving(reason: String, owner: Node = null) -> void:
	_save_blocks[reason] = true
	if owner:
		var release := unblock_saving.bind(reason)
		if not owner.tree_exiting.is_connected(release):
			owner.tree_exiting.connect(release, CONNECT_ONE_SHOT)


func unblock_saving(reason: String) -> void:
	_save_blocks.erase(reason)


func is_saving_blocked() -> bool:
	return not _save_blocks.is_empty()


func save_blocks() -> Array:
	return _save_blocks.keys()


func _on_state_reset() -> void:
	_save_blocks.clear()
	_pending_autosave = false


func can_save_now() -> bool:
	return why_not_saving() == ""


## "" when a save is possible right now, otherwise a short reason for the player.
func why_not_saving() -> String:
	if GameState.current_area == "" or not GameState.AREAS.has(GameState.current_area):
		return "There is nothing to save yet."
	if GameState.has_flag("ending_selected"):
		return "The story has ended."
	if _save_blocks.has("sentinel_challenge"):
		return "Saving is paused during the mist trial."
	if not _save_blocks.is_empty():
		return "You can't save right now."
	if SceneManager.transitioning:
		return "You can't save while travelling."
	if DialogueManager.is_active():
		return "You can't save during a conversation."
	if GameState.is_input_locked():
		return "You can't save right now."
	if SceneManager.current_area == null or not is_instance_valid(SceneManager.current_area):
		return "There is nothing to save yet."
	return ""


## Ask for a save as soon as it is safe (e.g. right after a conversation).
func request_autosave() -> void:
	_pending_autosave = true


# ------------------------------------------------------------------ saving --
func save_game(include_position: bool = true) -> bool:
	if not can_save_now():
		return false
	var position: Variant = null
	var area: Node = SceneManager.current_area
	if include_position and area and area.has_method("get_player"):
		var player: Node2D = area.get_player()
		if player:
			position = player.global_position
	if not write_save(build_save_data(position)):
		return false
	saved.emit()
	return true


func build_save_data(position: Variant = null) -> Dictionary:
	var data := GameState.to_dict()
	data["version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	if position is Vector2:
		data["position"] = [position.x, position.y]
	return data


## Writes through a temporary file, verifies it, keeps the previous save as a
## backup, then moves the new file into place. Returns false (and emits
## save_failed) instead of ever leaving a half-written save behind.
func write_save(data: Dictionary) -> bool:
	var problem := validate(data)
	if problem != "":
		return _fail("refused to write an invalid save (%s)" % problem)
	var tmp := save_path + TEMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
	f.store_string(JSON.stringify(data, "\t"))
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		_remove(tmp)
		return _fail("writing the save failed (%s)" % error_string(write_error))
	if validate(_parse_file(tmp)) != "":
		_remove(tmp)
		return _fail("the written save did not read back correctly")
	var backup := save_path + BACKUP_SUFFIX
	if FileAccess.file_exists(save_path):
		if validate(_parse_file(save_path)) == "":
			_remove(backup)
			var keep := DirAccess.rename_absolute(_abs(save_path), _abs(backup))
			if keep != OK:
				_remove(tmp)
				return _fail("could not keep a backup of the previous save (%s)" % error_string(keep))
		else:
			_remove(save_path)  # damaged: never let it replace a good backup
	var err := DirAccess.rename_absolute(_abs(tmp), _abs(save_path))
	if err != OK:
		if not FileAccess.file_exists(save_path) and FileAccess.file_exists(backup):
			DirAccess.copy_absolute(_abs(backup), _abs(save_path))
		return _fail("could not move the new save into place (%s)" % error_string(err))
	last_error = ""
	return true


func _fail(message: String) -> bool:
	last_error = message
	push_warning("SaveManager: " + message)
	save_failed.emit(message)
	return false


# ----------------------------------------------------------------- loading --
func load_game() -> Dictionary:
	var data := _read()
	if data.is_empty():
		return {}
	GameState.from_dict(data)
	return data


## Loads the save and enters the saved area.
func continue_game() -> bool:
	var data := load_game()
	if data.is_empty():
		return false
	var pos: Variant = null
	var p: Variant = data.get("position", null)
	if p is Array and (p as Array).size() == 2:
		pos = Vector2(float(p[0]), float(p[1]))
	SceneManager.change_area(GameState.current_area, GameState.current_spawn, pos)
	return true


func delete_save() -> void:
	for path in [save_path, save_path + TEMP_SUFFIX, save_path + BACKUP_SUFFIX]:
		_remove(path)


## The newest usable save: the main file, else a verified temp file left by an
## interrupted write, else the backup of the previous save.
func _read() -> Dictionary:
	for source in [["main", save_path], ["temp", save_path + TEMP_SUFFIX], ["backup", save_path + BACKUP_SUFFIX]]:
		var path: String = source[1]
		if not FileAccess.file_exists(path):
			continue
		var data: Variant = _parse_file(path)
		var problem := validate(data)
		if problem == "":
			last_read_source = source[0]
			if source[0] != "main":
				_warn_once("recovered", "SaveManager: main save unusable, using the %s copy" % source[0])
			return data as Dictionary
		_warn_once(path, "SaveManager: ignoring %s (%s)" % [path.get_file(), problem])
	last_read_source = ""
	return {}


## "" when `data` is a usable save, otherwise what is wrong with it. Accepts
## every save written by V1 (same fields, same version).
func validate(data: Variant) -> String:
	if not data is Dictionary:
		return "not a save file"
	var d: Dictionary = data
	var version: Variant = d.get("version", null)
	if not (version is int or version is float) or int(version) != VERSION:
		return "unsupported version %s" % [version]
	var area: Variant = d.get("area", null)
	if not area is String or not GameState.AREAS.has(area):
		return "unknown area %s" % [area]
	if d.has("spawn") and not d["spawn"] is String:
		return "spawn is not text"
	var flags: Variant = d.get("flags", null)
	if not flags is Dictionary:
		return "flags are missing"
	for key in flags:
		var v: Variant = flags[key]
		if not (v is bool or v is int or v is float or v is String):
			return "flag %s has an unusable value" % [key]
	if d.has("discoveries"):
		if not d["discoveries"] is Array:
			return "journal is not a list"
		for item in d["discoveries"]:
			if not item is String:
				return "journal entry is not text"
	if d.has("play_time") and not (d["play_time"] is int or d["play_time"] is float):
		return "play time is not a number"
	if d.has("position") and d["position"] != null:
		var p: Variant = d["position"]
		if not p is Array or (p as Array).size() != 2:
			return "position is malformed"
		for c in p:
			if not (c is int or c is float) or not is_finite(float(c)):
				return "position is malformed"
	return ""


func _parse_file(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null  # reported once by _read() through validate()
	return json.data


func _warn_once(key: String, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)


func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_abs(path))
