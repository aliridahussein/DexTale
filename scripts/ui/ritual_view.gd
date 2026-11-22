extends Control
## The Bell's Resonance (V2): the interactive retuning before The Chorus.
## A panel under the bell shows the Gathering Song as Rowan remembers it from
## the ledger: thirteen marks rising and falling, the last one circled. The
## player follows the shape: W/Up for a higher note, S/Down for a lower one,
## E for the circled thirteenth. Each correct note rings and lights a mark on
## the bell itself; a wrong one sours and restarts the current phrase. No
## timing, unlimited retries, Esc steps back to the final choice.
## Logic lives in ResonanceRitual; this script draws and handles input.

signal closed(completed: bool)
## For the tower: light the first `count` marks on the bell.
signal marks_changed(count: int)
signal note_sung(index: int)
signal soured

const GOLD := Color("#e8c86e")
const GOLD_HI := Color("#f8e8aa")
const REF := Color(0.58, 0.76, 0.95, 0.7)
const COL_X0 := 14.0
const COL_W := 29.0
const ROW_Y0 := 42.0
const ROW_H := 7.0
const MSG_START := "The bell gives you the first note. Follow the shape of the song."
const MSG_BREATH := "A breath. Then the rest of it."
const MSG_SOUR := "The bell sours. Back to the start of the phrase."
const MSG_DONE := "The thirteenth note. The one that gives back."

var ritual := ResonanceRitual.new()
var _busy_until := 0.0
var _t := 0.0
var _sour_flash := 0.0

@onready var staff: Control = %Staff
@onready var progress: Label = %RitualProgress
@onready var message: Label = %RitualMessage


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	staff.draw.connect(_draw_staff)


## Starts a fresh attempt. The returned signal carries whether it was completed.
func open() -> Signal:
	ritual.reset()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)
	_busy_until = _t + 0.9
	message.text = MSG_START
	_update_progress()
	marks_changed.emit(ritual.sung)
	_ring(0)
	return closed


func is_open() -> bool:
	return visible


## One input from the player (also used by tests). Returns the result.
func play_note(note: ResonanceRitual.Note) -> ResonanceRitual.Result:
	if not visible or _t < _busy_until:
		return ResonanceRitual.Result.IGNORED
	var index := ritual.sung
	var result := ritual.press(note)
	match result:
		ResonanceRitual.Result.NEXT:
			_ring(index)
			_busy_until = _t + 0.15
			if message.text == MSG_START or message.text == MSG_SOUR or message.text == MSG_BREATH:
				message.text = ""
		ResonanceRitual.Result.PHRASE_DONE:
			_ring(index)
			message.text = MSG_BREATH
			_busy_until = _t + 0.8
		ResonanceRitual.Result.WRONG:
			AudioManager.play_sfx("ritual_sour", -3.0)
			_sour_flash = 1.0
			message.text = MSG_SOUR
			_busy_until = _t + 0.7
			soured.emit()
		ResonanceRitual.Result.DONE:
			_ring(index)
			message.text = MSG_DONE
			_finish()
	_update_progress()
	marks_changed.emit(ritual.sung)
	staff.queue_redraw()
	return result


func _ring(index: int) -> void:
	AudioManager.play_sfx("ritual_note", -3.0, ResonanceRitual.pitch_scale(index))
	note_sung.emit(index)


func _finish() -> void:
	_busy_until = INF
	await get_tree().create_timer(1.8).timeout
	_close(true)


func step_back() -> void:
	if visible and ritual.done == false:
		AudioManager.play_sfx("ui_back", -8.0)
		_close(false)


func _close(completed: bool) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	visible = false
	closed.emit(completed)


func _update_progress() -> void:
	progress.text = "%d / %d" % [ritual.sung, ResonanceRitual.SONG.size()]


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_sour_flash = maxf(0.0, _sour_flash - delta * 2.0)
	staff.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		play_note(ResonanceRitual.Note.UP)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		play_note(ResonanceRitual.Note.DOWN)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		play_note(ResonanceRitual.Note.SING)
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		step_back()


# --------------------------------------------------------------- drawing --
## A crisp 1-pixel line made of single pixels (pixel-art style).
func _pixel_line(a: Vector2, b: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
	for s in range(1, steps):
		var p := a.lerp(b, float(s) / steps).round()
		staff.draw_rect(Rect2(p, Vector2.ONE), color)


func _col(i: int) -> float:
	return COL_X0 + i * COL_W


func _row(i: int) -> float:
	return ROW_Y0 - ResonanceRitual.SONG[i] * ROW_H


func _draw_staff() -> void:
	var song := ResonanceRitual.SONG
	var size_y := staff.size.y
	if _sour_flash > 0.0:
		staff.draw_rect(Rect2(Vector2.ZERO, staff.size), Color(0.55, 0.12, 0.2, 0.35 * _sour_flash))
	# faint staff lines
	for r in 6:
		staff.draw_rect(Rect2(4, ROW_Y0 - r * ROW_H, staff.size.x - 8, 1), Color(1, 1, 1, 0.04))
	# the breath between the phrases
	var bx := (_col(7) + _col(8)) * 0.5
	staff.draw_rect(Rect2(bx, 2, 1, 4), Color(1, 1, 1, 0.35))
	# the current note's column
	var current := ritual.sung
	if not ritual.done and current < song.size():
		var pulse := 0.08 + 0.06 * sin(_t * 6.0)
		staff.draw_rect(Rect2(_col(current) - 5, 0, 11, size_y), Color(1.0, 0.85, 0.5, pulse))
	# the remembered shape (the ledger's margin)
	for i in song.size():
		var p := Vector2(_col(i), _row(i))
		staff.draw_rect(Rect2(p.x - 2, p.y, 5, 2), REF)
		if i == song.size() - 1:
			var ring := GOLD if (current == i and not ritual.done) else REF
			ring.a = 0.5 + (0.4 * sin(_t * 5.0) if current == i else 0.0)
			staff.draw_arc(p + Vector2(0.5, 1), 5.5, 0, TAU, 14, ring, 1.0, false)
	# what has been sung so far, joined like a line of ink
	for i in range(1, mini(ritual.sung, song.size())):
		_pixel_line(Vector2(_col(i - 1), _row(i - 1)), Vector2(_col(i), _row(i)), Color(GOLD, 0.55))
	for i in mini(ritual.sung, song.size()):
		var p := Vector2(_col(i), _row(i))
		staff.draw_rect(Rect2(p.x - 2, p.y - 2, 5, 5), GOLD)
		staff.draw_rect(Rect2(p.x - 1, p.y - 1, 2, 1), GOLD_HI)
	# a missed note shows which way to go
	if not ritual.done and current < song.size() and ritual.hinted(current):
		var p := Vector2(_col(current), _row(current))
		var need := ResonanceRitual.needed_for(current)
		var a := 0.6 + 0.4 * sin(_t * 8.0)
		if need == ResonanceRitual.Note.UP:
			staff.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -5), p + Vector2(4, -5), p + Vector2(0.5, -9)]), Color(GOLD, a))
		elif need == ResonanceRitual.Note.DOWN:
			staff.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 6), p + Vector2(4, 6), p + Vector2(0.5, 10)]), Color(GOLD, a))
