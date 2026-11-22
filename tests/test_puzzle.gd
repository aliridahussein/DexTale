extends Node
## The Three Seals state machine and the mist pulse hazard timing.

var runner: Node


func test_wrong_order_resets() -> void:
	var p := SealPuzzle.new(["moon", "flame", "crown"])
	runner.check(p.press("flame") == SealPuzzle.Result.PROGRESS, "first press progresses")
	runner.check(p.press("flame") == SealPuzzle.Result.IGNORED, "same seal twice is ignored")
	runner.check(p.press("moon") == SealPuzzle.Result.PROGRESS, "second press progresses")
	runner.check(p.press("crown") == SealPuzzle.Result.WRONG, "wrong order fails on the third press")
	runner.check(p.entered.is_empty(), "sequence resets for an immediate retry")
	runner.check(not p.solved, "not solved")


func test_right_order_solves() -> void:
	var p := SealPuzzle.new(["moon", "flame", "crown"])
	p.press("moon")
	p.press("flame")
	runner.check(p.press("crown") == SealPuzzle.Result.SOLVED, "Moon, Flame, Crown solves it")
	runner.check(p.press("moon") == SealPuzzle.Result.IGNORED, "presses after solving are ignored")


func test_mist_pulse_telegraphs_before_bursting() -> void:
	var pulse := MistPulse.new()
	add_child(pulse)
	pulse.set_active(true)
	var states: Array = []
	var t := 0.0
	while t < pulse.period * 2.0:
		pulse._process(0.05)
		t += 0.05
		if states.is_empty() or states[-1] != pulse._state:
			states.append(pulse._state)
	runner.check(states.has("warn") and states.has("burst"), "pulse warns and bursts: %s" % [states])
	var warn_i := states.find("warn")
	var burst_i := states.find("burst")
	runner.check(warn_i != -1 and warn_i < burst_i, "warning always comes first")
	var hits := [0]
	pulse.hit.connect(func() -> void: hits[0] += 1)
	pulse._player_inside = true
	pulse.set_active(true)
	t = 0.0
	while t < pulse.period * 2.0 + 0.1:
		pulse._process(0.05)
		t += 0.05
	runner.check(hits[0] == 2, "one hit per burst while standing in it (got %d)" % hits[0])
	pulse.set_slow(true)
	runner.check(pulse.slow, "mercy mode can slow the pulses")
	pulse.queue_free()
