extends Control
## Presents DialogueManager lines: portrait, name plate, typewriter text,
## choices. Only presentation lives here; story logic stays in the manager.
##
## Text supports BBCode ([color], [wave], [shake]...) and "{p}" for a short
## dramatic pause inside a line.

const PAUSE_MARK := "{p}"
const PAUSE_TIME := 0.45
const INPUT_GUARD := 0.14
const TEXT_X_PORTRAIT := 60.0
const TEXT_X_PLAIN := 20.0

var _typing := false
var _visible_f := 0.0
var _total := 0
var _pauses: Array[int] = []
var _pause_timer := 0.0
var _guard := 0.0
var _choice_items: Array = []
var _choice_index := 0
var _blip_pitch := 1.0
var _blip_count := 0
var _plain := ""

@onready var panel: Control = %Panel
@onready var portrait_frame: Control = %PortraitFrame
@onready var portrait: TextureRect = %Portrait
@onready var name_plate: Control = %NamePlate
@onready var name_label: Label = %NameLabel
@onready var text: RichTextLabel = %Text
@onready var next_mark: Label = %Next
@onready var choices: Control = %Choices
@onready var choice_list: VBoxContainer = %ChoiceList


func _ready() -> void:
	visible = false
	choices.visible = false
	DialogueManager.line_shown.connect(_on_line)
	DialogueManager.choices_shown.connect(_on_choices)
	DialogueManager.box_hidden.connect(_on_box_hidden)
	DialogueManager.ended.connect(_on_ended)


func _on_line(speaker_id: String, raw: String) -> void:
	var sp := DialogueManager.get_speaker(speaker_id)
	visible = true
	choices.visible = false
	var speaker_name := str(sp.get("name", ""))
	name_plate.visible = speaker_name != ""
	name_label.text = speaker_name
	name_label.add_theme_color_override("font_color", Color(str(sp.get("color", "#e8d8b0"))))
	var portrait_path := str(sp.get("portrait", ""))
	var has_portrait := portrait_path != "" and ResourceLoader.exists(portrait_path)
	portrait_frame.visible = has_portrait
	portrait.visible = has_portrait
	if has_portrait:
		portrait.texture = load(portrait_path)
	var x := TEXT_X_PORTRAIT if has_portrait else TEXT_X_PLAIN
	text.position.x = x
	text.size.x = 470.0 - x - 10.0
	name_plate.position.x = x - 6.0
	_blip_pitch = float(sp.get("blip", 1.0))
	var italic := bool(sp.get("narration", false))
	_set_text(raw, italic)


func _set_text(raw: String, narration: bool) -> void:
	# record pause positions (in visible characters) and strip the markers
	_pauses.clear()
	var parts := raw.split(PAUSE_MARK)
	var bb := ""
	var visible_count := 0
	var tag_re := RegEx.new()
	tag_re.compile("\\[[^\\]]*\\]")
	for i in parts.size():
		bb += parts[i]
		visible_count += tag_re.sub(parts[i], "", true).length()
		if i < parts.size() - 1:
			_pauses.append(visible_count)
	if narration:
		bb = "[color=#c8bfd8]" + bb + "[/color]"
	text.text = bb
	_plain = tag_re.sub(bb, "", true)
	_total = text.get_total_character_count()
	_visible_f = 0.0
	_pause_timer = 0.0
	_blip_count = 0
	_guard = INPUT_GUARD
	next_mark.visible = false
	var cps := Settings.chars_per_second()
	if cps <= 0.0:
		_finish_typing()
	else:
		text.visible_characters = 0
		_typing = true


func _finish_typing() -> void:
	_typing = false
	text.visible_characters = -1
	next_mark.visible = true
	_guard = INPUT_GUARD


func _process(delta: float) -> void:
	_guard = maxf(0.0, _guard - delta)
	if not visible:
		return
	if next_mark.visible:
		next_mark.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
	if not _typing:
		return
	if _pause_timer > 0.0:
		_pause_timer -= delta
		return
	var before := int(_visible_f)
	_visible_f += Settings.chars_per_second() * delta
	var now := int(_visible_f)
	for p in _pauses:
		if before < p and now >= p:
			now = p
			_visible_f = float(p)
			_pause_timer = PAUSE_TIME
			break
	if now != before:
		text.visible_characters = now
		_blip(before, now)
	if now >= _total:
		_finish_typing()


func _blip(from: int, to: int) -> void:
	for i in range(from, mini(to, _plain.length())):
		var ch := _plain[i]
		if ch == " " or ch in ".,!?-'\"":
			continue
		_blip_count += 1
		if _blip_count % 3 == 1:
			AudioManager.play_sfx("blip", -20.0, _blip_pitch, 0.05)
		break


func _on_choices(options: Array) -> void:
	visible = true
	_typing = false
	text.visible_characters = -1
	next_mark.visible = false
	for c in choice_list.get_children():
		c.queue_free()
	_choice_items.clear()
	for opt in options:
		var l := Label.new()
		l.text = "  " + str(opt["text"])
		choice_list.add_child(l)
		_choice_items.append(l)
	_choice_index = 0
	choices.visible = true
	_guard = 0.25
	await get_tree().process_frame
	# grow the panel to fit and keep it above the dialogue box, right-aligned
	var h := choice_list.get_combined_minimum_size().y + 14.0
	var w := maxf(150.0, choice_list.get_combined_minimum_size().x + 22.0)
	choices.size = Vector2(w, h)
	choices.position = Vector2(470.0 - w, 194.0 - h)
	_highlight()


func _highlight() -> void:
	for i in _choice_items.size():
		var l: Label = _choice_items[i]
		var raw := l.text.substr(2)
		if i == _choice_index:
			l.text = "▶ " + raw
			l.add_theme_color_override("font_color", Color("#f8e8aa"))
		else:
			l.text = "  " + raw
			l.add_theme_color_override("font_color", Color("#a89cb8"))


func _on_box_hidden() -> void:
	visible = false


func _on_ended(_id: String) -> void:
	visible = false
	choices.visible = false
	_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not DialogueManager.is_active():
		return
	var accept := event.is_action_pressed("dialogue_advance") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if choices.visible:
		if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
			_choice_index = (_choice_index - 1 + _choice_items.size()) % _choice_items.size()
			AudioManager.play_sfx("ui_move", -10.0)
			_highlight()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
			_choice_index = (_choice_index + 1) % _choice_items.size()
			AudioManager.play_sfx("ui_move", -10.0)
			_highlight()
			get_viewport().set_input_as_handled()
		elif accept:
			get_viewport().set_input_as_handled()
			if _guard > 0.0:
				return
			choices.visible = false
			AudioManager.play_sfx("ui_confirm", -8.0)
			DialogueManager.choose(_choice_index)
		return
	if not accept:
		return
	get_viewport().set_input_as_handled()
	if _guard > 0.0:
		return
	if _typing:
		_finish_typing()
	elif DialogueManager.is_waiting_for_advance():
		next_mark.visible = false
		DialogueManager.advance()
