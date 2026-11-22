extends Control
## Settings panel shared by the main menu and the pause menu.
## Rows are built in code so new options are a one-line addition.

var _return_to: Control = null
var _first_focus: Control = null

@onready var rows: VBoxContainer = %SettingsRows
@onready var back_btn: Button = %SettingsBack


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	back_btn.pressed.connect(close)
	_build()


func _build() -> void:
	_first_focus = _add_slider("Master volume", "master_volume")
	_add_slider("Music", "music_volume")
	_add_slider("Ambience", "ambience_volume")
	_add_slider("Effects", "sfx_volume")
	_add_cycle("Text speed", "text_speed", Settings.TEXT_SPEED_NAMES)
	_add_toggle("Fullscreen", "fullscreen")
	_add_toggle("Screen shake", "screen_shake")
	_add_toggle("Objective on screen", "show_objective")


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(112, 0)
	row.add_child(l)
	rows.add_child(row)
	return row


func _add_slider(label_text: String, key: String) -> Control:
	var row := _row(label_text)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(96, 12)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = float(Settings.get(key))
	var v := Label.new()
	v.custom_minimum_size = Vector2(28, 0)
	v.text = "%d%%" % roundi(s.value * 100)
	s.value_changed.connect(func(val: float) -> void:
		v.text = "%d%%" % roundi(val * 100)
		Settings.set_value(key, val)
		AudioManager.play_sfx("ui_move", -12.0))
	row.add_child(s)
	row.add_child(v)
	return s


func _add_cycle(label_text: String, key: String, names: Array) -> Control:
	var row := _row(label_text)
	var b := Button.new()
	b.text = "◀ %s ▶" % names[int(Settings.get(key))]
	b.custom_minimum_size = Vector2(96, 0)
	var step := func(d: int) -> void:
		var i: int = (int(Settings.get(key)) + d + names.size()) % names.size()
		Settings.set_value(key, i)
		b.text = "◀ %s ▶" % names[i]
		AudioManager.play_sfx("ui_move", -10.0)
	b.pressed.connect(step.bind(1))
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event()
		elif e.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event())
	row.add_child(b)
	return b


func _add_toggle(label_text: String, key: String) -> Control:
	var row := _row(label_text)
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 0)
	var refresh := func() -> void: b.text = "On" if bool(Settings.get(key)) else "Off"
	refresh.call()
	b.pressed.connect(func() -> void:
		Settings.set_value(key, not bool(Settings.get(key)))
		refresh.call()
		AudioManager.play_sfx("ui_confirm", -10.0))
	row.add_child(b)
	return b


func open(return_to: Control = null) -> void:
	_return_to = return_to
	visible = true
	AudioManager.play_sfx("ui_open", -8.0)
	if _first_focus:
		_first_focus.grab_focus()


func close() -> void:
	visible = false
	AudioManager.play_sfx("ui_back", -8.0)
	if _return_to and _return_to.has_method("reopen"):
		_return_to.call("reopen")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
