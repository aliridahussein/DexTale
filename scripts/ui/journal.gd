extends Control
## Journal (J): current objective, optional and completed objectives on the
## left page, discoveries on the right. Both pages scroll on their own
## (QA-05): W/S scroll the active page, A/D switch pages, the mouse wheel
## scrolls whichever page is under the pointer.

const INK := "#2b2130"
const HEAD := "#6a4614"
const DIM := "#7a6a58"
const ACTIVE_HEAD := Color("#6a4614")
const IDLE_HEAD := Color("#9a8a74")
const SCROLL_STEP := 13.0

## 0 = objectives (left), 1 = discoveries (right).
var active_page := 0

@onready var left: RichTextLabel = %Left
@onready var right: RichTextLabel = %Right
@onready var left_head: Label = %LeftHead
@onready var right_head: Label = %RightHead


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func open() -> void:
	_fill()
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("page", -6.0)
	left.scroll_to_line(0)
	right.scroll_to_line(0)
	_set_active(0)


func close() -> void:
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("page", -10.0, 0.8)


func page(index: int) -> RichTextLabel:
	return left if index == 0 else right


## Scroll one page by `pixels` (tests and input both use this).
func scroll_page(index: int, pixels: float) -> void:
	var bar := page(index).get_v_scroll_bar()
	bar.value = clampf(bar.value + pixels, 0.0, maxf(bar.max_value - bar.page, 0.0))


func page_at_end(index: int) -> bool:
	var bar := page(index).get_v_scroll_bar()
	return bar.value >= bar.max_value - bar.page - 1.0


func _set_active(index: int) -> void:
	active_page = clampi(index, 0, 1)
	left_head.add_theme_color_override("font_color", ACTIVE_HEAD if active_page == 0 else IDLE_HEAD)
	right_head.add_theme_color_override("font_color", ACTIVE_HEAD if active_page == 1 else IDLE_HEAD)
	left_head.text = ("▶ " if active_page == 0 else "") + "Objectives"
	right_head.text = ("▶ " if active_page == 1 else "") + "Discoveries"


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
		l += "\n[color=%s]DONE (%d)[/color]\n" % [HEAD, done.size()]
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
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_set_active(0)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_set_active(1)
	elif event.is_action_pressed("move_down", true) or event.is_action_pressed("ui_down", true):
		scroll_page(active_page, SCROLL_STEP * 2.0)
	elif event.is_action_pressed("move_up", true) or event.is_action_pressed("ui_up", true):
		scroll_page(active_page, -SCROLL_STEP * 2.0)
	elif event.is_action_pressed("ui_page_down", true):
		scroll_page(active_page, page(active_page).size.y - SCROLL_STEP)
	elif event.is_action_pressed("ui_page_up", true):
		scroll_page(active_page, -(page(active_page).size.y - SCROLL_STEP))
