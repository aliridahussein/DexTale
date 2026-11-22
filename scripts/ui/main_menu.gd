extends Control
## Title screen: New Game, Continue (only when a valid save exists),
## Settings, Credits, Quit.

const PROLOGUE := "res://scenes/main/prologue.tscn"

var _t := 0.0

@onready var new_btn: Button = %NewGame
@onready var continue_btn: Button = %Continue
@onready var settings_btn: Button = %SettingsBtn
@onready var credits_btn: Button = %CreditsBtn
@onready var quit_btn: Button = %QuitBtn
@onready var save_info: Label = %SaveInfo
@onready var credits: Control = %Credits
@onready var confirm: Control = %Confirm


func _ready() -> void:
	get_tree().paused = false
	for reason in GameState.lock_reasons():
		GameState.clear_lock(reason)
	UI.set_gameplay_hud(false)
	AudioManager.play_music("title", 2.0)
	AudioManager.play_ambience("", 1.0)
	AudioManager.set_reverb(0.2)
	new_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(func() -> void: UI.open_settings(self))
	credits_btn.pressed.connect(_show_credits)
	quit_btn.pressed.connect(AudioManager.quit_game)
	%CreditsBack.pressed.connect(_hide_credits)
	%ConfirmYes.pressed.connect(_start_new_game)
	%ConfirmNo.pressed.connect(func() -> void:
		confirm.visible = false
		new_btn.grab_focus())
	for b in [new_btn, continue_btn, settings_btn, credits_btn, quit_btn]:
		(b as Button).focus_entered.connect(func() -> void: AudioManager.play_sfx("ui_move", -12.0))
	_refresh_save()
	_fill_credits()
	%Logo.modulate.a = 0.0
	create_tween().tween_property(%Logo, "modulate:a", 1.0, 1.6)


func _refresh_save() -> void:
	var info := SaveManager.save_info()
	continue_btn.disabled = info.is_empty()
	if info.is_empty():
		save_info.text = ""
		new_btn.grab_focus()
	else:
		var minutes := int(float(info.get("play_time", 0.0)) / 60.0)
		var area := str(info.get("area", ""))
		var names := {"village": "Village square", "forge": "Mara's forge", "chapel": "The chapel",
			"mist_path": "The Mistbound Path", "bell_tower": "The bell tower"}
		save_info.text = "Saved: %s  -  %d min" % [names.get(area, area), minutes]
		continue_btn.grab_focus()


func _fill_credits() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/endings.json"))
	var lines: Array = parsed.get("credits", []) if parsed is Dictionary else []
	%CreditsText.text = "[center]" + "\n".join(lines) + "[/center]"


func _process(delta: float) -> void:
	_t += delta
	%MistA.position.x = -fposmod(_t * 6.0, 480.0)
	%MistB.position.x = -fposmod(_t * 3.5 + 200.0, 480.0)
	%TowerGlow.modulate.a = 0.35 + 0.15 * sin(_t * 1.2)


## Called by the settings menu when it closes.
func reopen() -> void:
	settings_btn.grab_focus()


func _on_new_game() -> void:
	AudioManager.play_sfx("ui_confirm", -6.0)
	if SaveManager.has_save():
		confirm.visible = true
		%ConfirmNo.grab_focus()
	else:
		_start_new_game()


func _start_new_game() -> void:
	confirm.visible = false
	GameState.reset()
	AudioManager.stop_music(1.5)
	SceneManager.goto_scene(PROLOGUE, 1.0)


func _on_continue() -> void:
	AudioManager.play_sfx("ui_confirm", -6.0)
	AudioManager.stop_music(1.0)
	if not SaveManager.continue_game():
		_refresh_save()


func _show_credits() -> void:
	credits.visible = true
	%CreditsBack.grab_focus()


func _hide_credits() -> void:
	credits.visible = false
	credits_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if credits.visible:
			_hide_credits()
			get_viewport().set_input_as_handled()
		elif confirm.visible:
			confirm.visible = false
			new_btn.grab_focus()
			get_viewport().set_input_as_handled()
