class_name WinchPuzzle
extends RefCounted
## The crossing's winch (V2.2): bring the chain to safe tension before
## releasing the counterweight. Pure, deterministic logic (no randomness);
## the view in scripts/ui/winch_view.gd draws it and feeds it input.
##
## Tension runs 0..100. Turning tightens; the wheel gets heavier the tighter
## the chain is (mechanical resistance). Left alone, a tight chain creeps back
## a little. Releasing outside the safe band fails harmlessly: the chain slips
## or groans, and the player can simply keep adjusting.

enum Result { TOO_LOOSE, TOO_TIGHT, SAFE }

const SAFE_MIN := 40.0
const SAFE_MAX := 66.0
const START := 12.0
const RATE := 46.0          # tension per second when turning, before resistance
const CREEP := 3.0          # tension lost per second above the safe band when idle

var tension := START
var attempts := 0
var done := false


## dir: +1 tighten, -1 slacken, 0 let go. dt in seconds.
func adjust(dir: int, dt: float) -> void:
	if done:
		return
	if dir > 0:
		tension += RATE * resistance() * dt
	elif dir < 0:
		tension -= RATE * dt
	elif tension > SAFE_MAX:
		tension -= CREEP * dt
	tension = clampf(tension, 0.0, 100.0)


## 1.0 when slack, getting heavier as the chain tightens (never stuck).
func resistance() -> float:
	return clampf(1.0 - tension / 140.0, 0.3, 1.0)


func zone() -> Result:
	if tension < SAFE_MIN:
		return Result.TOO_LOOSE
	if tension > SAFE_MAX:
		return Result.TOO_TIGHT
	return Result.SAFE


## Release the counterweight at the current tension.
func confirm() -> Result:
	if done:
		return Result.SAFE
	attempts += 1
	var z := zone()
	match z:
		Result.SAFE:
			done = true
		Result.TOO_LOOSE:
			tension = maxf(0.0, tension - 8.0)   # the chain slips back a little
		Result.TOO_TIGHT:
			tension = SAFE_MAX + 6.0             # it groans and eases off, still adjustable
	return z
