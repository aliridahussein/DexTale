extends Node
## Player preferences, stored in user://settings.cfg (separate from the save).

signal changed

const PATH := "user://settings.cfg"
const TEXT_SPEED_NAMES := ["Slow", "Normal", "Fast", "Instant"]
const TEXT_SPEED_CPS := [24.0, 44.0, 90.0, 0.0]

var master_volume: float = 0.85
var music_volume: float = 0.7
var ambience_volume: float = 0.75
var sfx_volume: float = 0.8
var text_speed: int = 1
var fullscreen: bool = false
var screen_shake: bool = true
var show_objective: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_augment_ui_actions()
	apply_display()


func _unhandled_input(event: InputEvent) -> void:
	# Alt+Enter / F11 toggle fullscreen anywhere.
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed):
			fullscreen = not fullscreen
			apply_display()
			save_settings()
			changed.emit()
			get_viewport().set_input_as_handled()


## Characters per second for the dialogue typewriter (0 = instant).
func chars_per_second() -> float:
	return TEXT_SPEED_CPS[clampi(text_speed, 0, TEXT_SPEED_CPS.size() - 1)]


func set_value(key: String, value: Variant) -> void:
	set(key, value)
	if key == "fullscreen":
		apply_display()
	save_settings()
	changed.emit()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in ["master_volume", "music_volume", "ambience_volume", "sfx_volume", "text_speed",
			"fullscreen", "screen_shake", "show_objective"]:
		cfg.set_value("settings", key, get(key))
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Settings: could not save (%s)" % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in cfg.get_section_keys("settings"):
		if key in self:
			set(key, cfg.get_value("settings", key))


## Menus use the built-in ui_* actions; let WASD and E drive them too.
func _augment_ui_actions() -> void:
	var extra := {
		"ui_up": [KEY_W], "ui_down": [KEY_S], "ui_left": [KEY_A], "ui_right": [KEY_D],
		"ui_accept": [KEY_E],
	}
	for action in extra:
		if not InputMap.has_action(action):
			continue
		for code in extra[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
