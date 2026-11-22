extends Control
## Echo Reconstruction board (V2). Lays out the clues gathered for one mystery
## (data/reconstructions.json) and asks one question with several plausible
## answers. A wrong answer is crossed off with an explanation that points at
## the clue ruling it out: no penalty, try again. The right answer sets the
## mystery's flag. Opened from dialogue: {"event": "reconstruct", "args": [id]}.
##
## Keys: W/S or arrows choose, E/Enter decides, Esc steps back. The mouse can
## click an answer.

signal closed(solved: bool)

const DATA_PATH := "res://data/reconstructions.json"
const INK := "#2b2130"
const HEAD := "#6a4614"
const DIM := "#9a8a74"
const RULED := "#a08e7a"
const WRONG := "#8a2e1c"
const RIGHT := "#3f6a1c"

var entry_id := ""
var entry: Dictionary = {}
var cursor := 0
## answer index -> true for answers already ruled out this visit
var ruled_out: Dictionary = {}
var _highlight_clue := ""
var _locked := false

@onready var title_label: Label = %ReconTitle
@onready var intro_label: Label = %ReconIntro
@onready var clues_label: RichTextLabel = %ReconClues
@onready var question_label: Label = %ReconQuestion
@onready var answers_label: RichTextLabel = %ReconAnswers
@onready var feedback_label: RichTextLabel = %ReconFeedback


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	answers_label.meta_clicked.connect(func(meta: Variant) -> void:
		if not _locked:
			cursor = int(str(meta))
			choose(cursor))


func _data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## Opens the board for one mystery. The returned signal carries whether it was solved.
func open(id: String) -> Signal:
	entry_id = id
	entry = _data().get(id, {})
	ruled_out.clear()
	_highlight_clue = ""
	_locked = false
	cursor = 0
	if entry.is_empty():
		push_error("ReconstructionView: unknown reconstruction '%s'" % id)
		_close_later(false)
		return closed
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("page", -6.0)
	title_label.text = str(entry.get("title", ""))
	intro_label.text = str(entry.get("intro", ""))
	question_label.text = str(entry.get("question", ""))
	if not can_answer():
		feedback_label.text = "[color=%s]You need more to go on. (%d of %d found)[/color]" % [DIM,
			found_required(), required_count()]
	else:
		feedback_label.text = ""
	_refresh()
	return closed


func _close_later(solved: bool) -> void:
	await get_tree().process_frame
	closed.emit(solved)


# ------------------------------------------------------------------ logic --
func clues() -> Array:
	return entry.get("clues", [])


func answers() -> Array:
	return entry.get("answers", [])


func clue_found(c: Dictionary) -> bool:
	return GameState.check(c.get("when", "__never__"))


func required_count() -> int:
	return clues().filter(func(c: Dictionary) -> bool: return c.get("required", false)).size()


func found_required() -> int:
	return clues().filter(func(c: Dictionary) -> bool: return c.get("required", false) and clue_found(c)).size()


func can_answer() -> bool:
	return found_required() >= required_count()


## Choose answer `index`. Returns "correct", "ruled_out", "already", or "locked".
func choose(index: int) -> String:
	if _locked or index < 0 or index >= answers().size():
		return "locked"
	if not can_answer():
		AudioManager.play_sfx("ui_back", -8.0)
		return "locked"
	if ruled_out.has(index):
		return "already"
	var a: Dictionary = answers()[index]
	if a.get("correct", false):
		_solve()
		return "correct"
	ruled_out[index] = true
	GameState.inc_flag("reconstruction_misses")
	_highlight_clue = str(a.get("rule_out", ""))
	feedback_label.text = "[color=%s]%s[/color]" % [WRONG, a.get("feedback", "That doesn't fit.")]
	AudioManager.play_sfx("seal_wrong", -10.0)
	_move_cursor(1)
	_refresh()
	return "ruled_out"


func _solve() -> void:
	_locked = true
	GameState.set_flag(str(entry.get("solved_flag", "reconstructed_" + entry_id)), true)
	feedback_label.text = "[color=%s]%s[/color]" % [RIGHT, entry.get("solved_line", "That's it.")]
	_highlight_clue = ""
	_refresh()
	AudioManager.play_sfx("memory_warm", -4.0)
	await get_tree().create_timer(1.3).timeout  # timers run while paused by default
	_close(true)


func _close(solved: bool) -> void:
	visible = false
	get_tree().paused = false
	closed.emit(solved)


func _move_cursor(step: int) -> void:
	var n := answers().size()
	if n == 0:
		return
	for i in n:
		cursor = posmod(cursor + step, n)
		if not ruled_out.has(cursor):
			return


# --------------------------------------------------------------- drawing --
func _refresh() -> void:
	var c := ""
	for clue in clues():
		var marker := "▶ " if str(clue.get("id", "")) == _highlight_clue else "• "
		if clue_found(clue):
			var head := WRONG if str(clue.get("id", "")) == _highlight_clue else HEAD
			c += "[color=%s]%s%s[/color]\n[color=%s]%s[/color]\n" % [head, marker, clue.get("title", ""), INK, clue.get("text", "")]
		elif clue.get("required", false):
			c += "[color=%s]• ???[/color]\n[color=%s]%s[/color]\n" % [DIM, DIM, clue.get("missing", "")]
	clues_label.text = c
	var a := ""
	var answerable := can_answer()
	for i in answers().size():
		var text := str(answers()[i].get("text", ""))
		var pointer := "▶ " if i == cursor and not _locked else "   "
		if ruled_out.has(i):
			a += "[url=%d][color=%s]   [s]%s[/s][/color][/url]\n" % [i, RULED, text]
		elif not answerable:
			a += "[color=%s]   %s[/color]\n" % [DIM, text]
		else:
			var col := HEAD if i == cursor else INK
			a += "[url=%d][color=%s]%s%s[/color][/url]\n" % [i, col, pointer, text]
	answers_label.text = a


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if _locked:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		AudioManager.play_sfx("ui_back", -8.0)
		_close(false)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		_move_cursor(1)
		AudioManager.play_sfx("ui_move", -12.0)
		_refresh()
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		_move_cursor(-1)
		AudioManager.play_sfx("ui_move", -12.0)
		_refresh()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		choose(cursor)
	elif event.is_action_pressed("ui_page_down", true) or event.is_action_pressed("ui_page_up", true):
		var bar := clues_label.get_v_scroll_bar()
		bar.value += 60.0 if event.is_action_pressed("ui_page_down", true) else -60.0
