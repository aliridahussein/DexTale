extends Node
## Single-slot save in user://savegame.json.
##
## Saves only happen at safe moments: never during dialogue, cutscenes,
## transitions or the mist challenge. Loading always goes through a normal area
## transition, so the player is placed at a spawn point (or the free position
## they stood at when the save was made).

signal saved

const DEFAULT_PATH := "user://savegame.json"
const VERSION := 1

## Tests point this somewhere else so they never touch the player's save.
var save_path := DEFAULT_PATH

var _pending_autosave := false
var _save_blocks: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _pending_autosave and can_save_now():
		_pending_autosave = false
		save_game(true)


func has_save() -> bool:
	return not _read().is_empty()


func save_info() -> Dictionary:
	return _read()


## Saving can be blocked for a reason (e.g. the Sentinel challenge).
func block_saving(reason: String) -> void:
	_save_blocks[reason] = true


func unblock_saving(reason: String) -> void:
	_save_blocks.erase(reason)


func can_save_now() -> bool:
	if GameState.current_area == "" or not GameState.AREAS.has(GameState.current_area):
		return false
	if GameState.has_flag("ending_selected"):
		return false
	if GameState.is_input_locked() or SceneManager.transitioning:
		return false
	if not _save_blocks.is_empty():
		return false
	return SceneManager.current_area != null and is_instance_valid(SceneManager.current_area)


## Ask for a save as soon as it is safe (e.g. right after a conversation).
func request_autosave() -> void:
	_pending_autosave = true


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


func write_save(data: Dictionary) -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


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
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _read() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("SaveManager: save file is corrupt, ignoring it")
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION or not data.has("flags") or not data.has("area"):
		return {}
	if not GameState.AREAS.has(str(data["area"])):
		return {}
	return data
