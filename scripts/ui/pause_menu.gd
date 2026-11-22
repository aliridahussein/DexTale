extends Control
## Esc menu: resume, journal, save, settings, title, quit.

@onready var buttons: VBoxContainer = %PauseButtons
@onready var status: Label = %PauseStatus
@onready var resume_btn: Button = %Resume
@onready var journal_btn: Button = %JournalBtn
@onready var save_btn: Button = %SaveBtn
@onready var settings_btn: Button = %SettingsBtn
@onready var title_btn: Button = %TitleBtn
@onready var quit_btn: Button = %QuitBtn


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_btn.pressed.connect(close)
	journal_btn.pressed.connect(_on_journal)
	save_btn.pressed.connect(_on_save)
	settings_btn.pressed.connect(_on_settings)
	title_btn.pressed.connect(_on_title)
	quit_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		AudioManager.quit_game())
	quit_btn.visible = not OS.has_feature("web")
	for b in buttons.get_children():
		if b is Button:
			(b as Button).focus_entered.connect(func() -> void: AudioManager.play_sfx("ui_move", -12.0))


func open() -> void:
	visible = true
	get_tree().paused = true
	status.text = "Progress also saves when you enter an area."
	# Saving mid-conversation would restore into a broken scene, so it is disabled then.
	save_btn.disabled = DialogueManager.is_active() or GameState.lock_reasons().size() > 0 or SceneManager.current_area == null
	AudioManager.play_sfx("ui_open", -8.0)
	resume_btn.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_journal() -> void:
	close()
	if not DialogueManager.is_active():
		UI.open_journal()


func _on_save() -> void:
	get_tree().paused = false
	var ok := SaveManager.save_game(true)
	get_tree().paused = true
	status.text = "Game saved." if ok else "You can't save right now."
	AudioManager.play_sfx("ui_confirm" if ok else "ui_back", -6.0)


func _on_settings() -> void:
	visible = false
	UI.open_settings(self)


func _on_title() -> void:
	close()
	DialogueManager.stop()
	GameState.clear_lock("dialogue")
	UI.set_gameplay_hud(false)
	SceneManager.goto_scene("res://scenes/main/main_menu.tscn")


## Called by the settings menu when it closes.
func reopen() -> void:
	visible = true
	settings_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
