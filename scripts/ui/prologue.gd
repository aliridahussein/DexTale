extends Control
## Opening: twelve distant tolls in the dark, two lines, Orin's letter,
## then the village. The toll marks make the count readable without sound.

const TOLL_GAP := 0.95

var _skipping := false
var _dots: Array[ColorRect] = []

@onready var tolls: HBoxContainer = %Tolls
@onready var line: Label = %Line
@onready var letter: Control = %Letter
@onready var letter_text: RichTextLabel = %LetterText


func _ready() -> void:
	UI.set_gameplay_hud(false)
	AudioManager.stop_all(1.0)
	line.modulate.a = 0.0
	letter.visible = false
	for i in 12:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(4, 4)
		d.color = Color(0.85, 0.75, 0.5, 0.12)
		tolls.add_child(d)
		_dots.append(d)
	_run()


func _run() -> void:
	await _wait(1.2)
	for i in 12:
		if _skipping:
			return
		AudioManager.play_sfx("bell_toll_far", -6.0, 1.0 - i * 0.004)
		var d := _dots[i]
		var t := create_tween()
		t.tween_property(d, "color:a", 1.0, 0.15)
		t.tween_property(d, "color:a", 0.55, 0.8)
		await _wait(TOLL_GAP)
	await _wait(1.8)
	var fade := create_tween()
	fade.tween_property(tolls, "modulate:a", 0.0, 1.5)
	await _show_line("In Dawnmere, the bell had never missed a night.", 3.2)
	await _show_line("Until tonight.", 2.4, 18)
	if _skipping:
		return
	letter_text.text = "Rowan,\n\nCome home before the thirteenth toll.\nThere is something I need you to remember.\n\n[right]- O.[/right]"
	letter.visible = true
	letter.modulate.a = 0.0
	AudioManager.play_sfx("page", -6.0)
	var lt := create_tween()
	lt.tween_property(letter, "modulate:a", 1.0, 1.0)
	await _wait(5.0)
	var lo := create_tween()
	lo.tween_property(letter, "modulate:a", 0.0, 1.0)
	await _wait(1.2)
	_begin()


func _show_line(text: String, hold: float, size: int = 9) -> void:
	if _skipping:
		return
	line.text = text
	line.add_theme_font_size_override("font_size", size)
	var t := create_tween()
	t.tween_property(line, "modulate:a", 1.0, 1.0)
	t.tween_interval(hold)
	t.tween_property(line, "modulate:a", 0.0, 1.0)
	await t.finished


func _wait(seconds: float) -> void:
	if _skipping:
		return
	await get_tree().create_timer(seconds).timeout


func _begin() -> void:
	if GameState.has_flag("game_started"):
		return
	GameState.set_flag("game_started", true)
	GameState.set_flag("read_letter", true)
	SceneManager.change_area("village", "start")


func _unhandled_input(event: InputEvent) -> void:
	if _skipping:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_skipping = true
		get_viewport().set_input_as_handled()
		_begin()
