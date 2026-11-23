extends Control
## The winch at the Watchman's Crossing (V2.2). A panel under the mechanism
## with a tension gauge (loose / SAFE / tight), the counterweight rising as
## the chain tightens, and a turning gear. Hold A/D or Left/Right (or the
## on-screen buttons) to turn the wheel, E to release the counterweight, Esc to
## step back. Zones are told apart by shape and text, not only by colour.
## Logic lives in WinchPuzzle.

signal closed(success: bool)

const GOLD := Color("#e8c86e")
const LOOSE := Color(0.45, 0.6, 0.85)
const TIGHT := Color(0.85, 0.42, 0.38)
const TRACK_X := 44.0
const TRACK_W := 270.0
const TRACK_Y := 22.0
const TRACK_H := 12.0

var puzzle := WinchPuzzle.new()
var _gear := 0.0
var _click := 0.0
var _shake := 0.0
var _mouse_dir := 0
var _locked := false

@onready var gauge: Control = %WinchGauge
@onready var status: Label = %WinchStatus
@onready var message: Label = %WinchMessage
@onready var btn_slack: Label = %WinchSlack
@onready var btn_tight: Label = %WinchTight
@onready var btn_release: Label = %WinchRelease


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	gauge.draw.connect(_draw_gauge)
	for pair in [[btn_slack, -1], [btn_tight, 1]]:
		var l: Label = pair[0]
		var d: int = pair[1]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
				_mouse_dir = d if ev.pressed else 0)
	btn_release.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_release.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			release())


func open() -> Signal:
	puzzle = WinchPuzzle.new()
	_locked = false
	_mouse_dir = 0
	message.text = "The chain is secured. Bring it to safe tension, then release the weight."
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	_update_status()
	return closed


func is_open() -> bool:
	return visible


## Turn the wheel (tests call this directly): dir +1 tighten, -1 slacken.
func turn(dir: int, seconds: float) -> void:
	puzzle.adjust(dir, seconds)
	_gear += dir * seconds * 6.0
	_update_status()


## Release the counterweight. Returns the zone it was released in.
func release() -> WinchPuzzle.Result:
	if _locked or not visible:
		return WinchPuzzle.Result.TOO_LOOSE
	var r := puzzle.confirm()
	match r:
		WinchPuzzle.Result.SAFE:
			_locked = true
			message.text = "The counterweight takes the strain. The wheel begins to turn."
			AudioManager.play_sfx("winch_click", -2.0, 0.8)
			_finish()
		WinchPuzzle.Result.TOO_LOOSE:
			message.text = "The chain slips and sags. Too loose: tighten it first."
			AudioManager.play_sfx("chain_rattle", -4.0, 1.2)
			_shake = 1.0
		WinchPuzzle.Result.TOO_TIGHT:
			message.text = "The chain groans and the wheel kicks back. Too tight: ease it off."
			AudioManager.play_sfx("seal_wrong", -6.0, 0.7)
			_shake = 1.0
	_update_status()
	return r


func step_back() -> void:
	if visible and not _locked:
		AudioManager.play_sfx("ui_back", -8.0)
		_close(false)


func _finish() -> void:
	await get_tree().create_timer(0.9).timeout
	_close(true)


func _close(success: bool) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	await t.finished
	visible = false
	closed.emit(success)


func _process(delta: float) -> void:
	if not visible:
		return
	_shake = maxf(0.0, _shake - delta * 2.5)
	if _locked:
		_gear += delta * 4.0
		gauge.queue_redraw()
		return
	var dir := _mouse_dir
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right"):
		dir = 1
	elif Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left"):
		dir = -1
	var before := puzzle.tension
	puzzle.adjust(dir, delta)
	if dir != 0 and absf(puzzle.tension - before) > 0.0:
		_gear += dir * delta * 6.0 * puzzle.resistance()
		_click -= delta
		if _click <= 0.0:
			_click = 0.12 / puzzle.resistance()
			AudioManager.play_sfx("winch_click", -14.0, 0.9 + puzzle.tension / 200.0)
	_update_status()
	gauge.queue_redraw()


func _update_status() -> void:
	match puzzle.zone():
		WinchPuzzle.Result.TOO_LOOSE:
			status.text = "Too loose: the chain sags"
			status.add_theme_color_override("font_color", LOOSE)
		WinchPuzzle.Result.SAFE:
			status.text = "SAFE tension"
			status.add_theme_color_override("font_color", GOLD)
		WinchPuzzle.Result.TOO_TIGHT:
			status.text = "Too tight: the chain groans"
			status.add_theme_color_override("font_color", TIGHT)
	gauge.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		release()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		step_back()


# --------------------------------------------------------------- drawing --
func _x(t: float) -> float:
	return TRACK_X + TRACK_W * t / 100.0


func _hatch(r: Rect2, col: Color, step: int) -> void:
	gauge.draw_rect(r, Color(col, 0.18))
	var x := r.position.x
	while x < r.end.x:
		for y in range(int(r.size.y)):
			var px := x + y
			if px < r.end.x:
				gauge.draw_rect(Rect2(px, r.position.y + y, 1, 1), Color(col, 0.55))
		x += step


func _draw_gauge() -> void:
	var off := Vector2(randf_range(-1, 1), 0).round() * _shake
	# the track: loose (diagonal hatch), SAFE (solid gold), tight (dense hatch)
	var loose := Rect2(_x(0) + off.x, TRACK_Y, _x(WinchPuzzle.SAFE_MIN) - _x(0), TRACK_H)
	var safe := Rect2(_x(WinchPuzzle.SAFE_MIN) + off.x, TRACK_Y, _x(WinchPuzzle.SAFE_MAX) - _x(WinchPuzzle.SAFE_MIN), TRACK_H)
	var tight := Rect2(_x(WinchPuzzle.SAFE_MAX) + off.x, TRACK_Y, _x(100) - _x(WinchPuzzle.SAFE_MAX), TRACK_H)
	_hatch(loose, LOOSE, 6)
	gauge.draw_rect(safe, Color(GOLD, 0.45))
	gauge.draw_rect(safe, GOLD, false, 1.0)
	_hatch(tight, TIGHT, 3)
	gauge.draw_rect(Rect2(_x(0) + off.x, TRACK_Y, TRACK_W, TRACK_H), Color(1, 1, 1, 0.35), false, 1.0)
	# the needle
	var nx := roundf(_x(puzzle.tension)) + off.x
	gauge.draw_rect(Rect2(nx, TRACK_Y - 4, 1, TRACK_H + 8), Color.WHITE)
	gauge.draw_colored_polygon(PackedVector2Array([Vector2(nx - 3, TRACK_Y - 7), Vector2(nx + 4, TRACK_Y - 7),
		Vector2(nx + 0.5, TRACK_Y - 3)]), Color.WHITE)
	# the counterweight on the left rises as the chain takes the strain
	var wy := 40.0 - puzzle.tension * 0.32
	gauge.draw_rect(Rect2(10, 4, 2, 44), Color(0.36, 0.24, 0.16))
	gauge.draw_rect(Rect2(28, 4, 2, 44), Color(0.36, 0.24, 0.16))
	gauge.draw_rect(Rect2(19, 4, 2, wy - 4), Color(0.6, 0.62, 0.68))
	gauge.draw_rect(Rect2(13, wy, 14, 10), Color(0.35, 0.39, 0.45))
	gauge.draw_rect(Rect2(13, wy, 14, 10), Color(0.18, 0.2, 0.25), false, 1.0)
	# a gear on the right turns with the wheel
	var c := Vector2(TRACK_X + TRACK_W + 22, 28)
	gauge.draw_circle(c, 9.0, Color(0.3, 0.32, 0.38))
	for k in 8:
		var a := _gear + k * TAU / 8.0
		gauge.draw_rect(Rect2(c + Vector2(cos(a), sin(a)) * 9.5 - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.45, 0.48, 0.55))
	for k in 3:
		var a := _gear + k * TAU / 3.0
		gauge.draw_line(c, c + Vector2(cos(a), sin(a)) * 7.0, Color(0.62, 0.65, 0.72), 1.0)
	gauge.draw_circle(c, 2.0, GOLD)
