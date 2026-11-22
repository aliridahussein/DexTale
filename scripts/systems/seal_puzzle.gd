class_name SealPuzzle
extends RefCounted
## Ordered-input puzzle used by the chapel's Three Seals.
##
## Press symbols; once as many symbols as the solution are entered the
## sequence is checked. A wrong sequence resets so the player can retry
## immediately. Pure logic (no nodes), so it is easy to unit test and reuse.

enum Result { PROGRESS, WRONG, SOLVED, IGNORED }

var solution: Array[String] = []
var entered: Array[String] = []
var solved := false


func _init(order: Array[String] = []) -> void:
	solution = order.duplicate()


func press(symbol: String) -> Result:
	if solved or entered.has(symbol):
		return Result.IGNORED
	entered.append(symbol)
	if entered.size() < solution.size():
		return Result.PROGRESS
	if entered == solution:
		solved = true
		return Result.SOLVED
	entered.clear()
	return Result.WRONG


func reset() -> void:
	entered.clear()


func mark_solved() -> void:
	solved = true
	entered = solution.duplicate()
