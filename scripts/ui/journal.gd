extends Control
## Journal (J): current objective, completed objectives, discoveries.

const INK := "#2b2130"
const HEAD := "#6a4614"
const DIM := "#7a6a58"

@onready var left: RichTextLabel = %Left
@onready var right: RichTextLabel = %Right


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_fill()
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("page", -6.0)
	right.scroll_to_line(0)


func close() -> void:
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("page", -10.0, 0.8)


func _fill() -> void:
	var l := ""
	var primary := QuestManager.get_primary()
	l += "[color=%s]CURRENT[/color]\n" % HEAD
	if primary.is_empty():
		l += "[color=%s]Nothing pressing. For now.[/color]\n" % DIM
	else:
		l += "[color=%s]▶ %s[/color]\n" % [INK, primary.get("title", "")]
		if str(primary.get("detail", "")) != "":
			l += "[color=%s]%s[/color]\n" % [DIM, primary["detail"]]
	var optional := QuestManager.get_optional_active()
	if not optional.is_empty():
		l += "\n[color=%s]OPTIONAL[/color]\n" % HEAD
		for o in optional:
			l += "[color=%s]• %s[/color]\n" % [INK, o.get("title", "")]
			if str(o.get("detail", "")) != "":
				l += "[color=%s]%s[/color]\n" % [DIM, o["detail"]]
	var done := QuestManager.get_completed()
	if not done.is_empty():
		l += "\n[color=%s]DONE[/color]\n" % HEAD
		for o in done:
			l += "[color=%s][s]%s[/s][/color]\n" % [DIM, o.get("title", "")]
	left.text = l
	var r := ""
	var found := QuestManager.get_discoveries()
	if found.is_empty():
		r = "[color=%s]Nothing written here yet.[/color]" % DIM
	for d in found:
		r += "[color=%s]%s[/color]\n[color=%s]%s[/color]\n\n" % [HEAD, d.get("title", ""), INK, d.get("text", "")]
	right.text = r


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("journal") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		right.get_v_scroll_bar().value += 22
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		right.get_v_scroll_bar().value -= 22
