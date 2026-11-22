extends GameArea
## The Forgotten Chapel: the Three Seals puzzle and the archive.
## Solution order comes from the inscription: Moon -> Flame -> Crown.

const SOLUTION: Array[String] = ["moon", "flame", "crown"]
const ARCHIVE_SPOT := Vector2(252, 108)
## A wrong order used to open a dialogue box every time. Now the seals answer
## with a short line that floats over them and fades, and Rowan can keep going.
const WRONG_LINE := "The seals grind back into place."
const WRONG_LINE_HINT := "The seals grind back. The inscription must give the order."

var puzzle := SealPuzzle.new(SOLUTION)
var _busy := false

@onready var door: Node2D = $Objects/ArchiveDoor
@onready var seals := {
	"flame": $Objects/SealFlame,
	"moon": $Objects/SealMoon,
	"crown": $Objects/SealCrown,
}


func _area_ready() -> void:
	for sym in seals:
		var it := get_node("Interactions/Seal%sUse" % String(sym).capitalize()) as Interactable
		it.interacted.connect(_on_seal_pressed.bind(sym))
	if GameState.has_flag("solved_chapel_puzzle"):
		puzzle.mark_solved()
	_refresh()
	if GameState.has_flag("alden_confessed"):
		var alden := npc("Alden")
		alden.global_position = ARCHIVE_SPOT
		alden.facing_name = "right"
		alden.set_facing("right")


func area_events() -> Dictionary:
	return {
		"archive_open": _open_archive,
		"alden_enter": _alden_enter,
	}


func _refresh() -> void:
	var open := GameState.has_flag("solved_chapel_puzzle")
	_seal_frames(2 if open else 0)
	(door.get_node("Sprite") as Sprite2D).frame = 1 if open else 0
	(door.get_node("Shape") as CollisionShape2D).set_deferred("disabled", open)


func _seal_frames(frame: int) -> void:
	for sym in seals:
		var lit := puzzle.entered.has(sym)
		(seals[sym].get_node("Sprite") as Sprite2D).frame = frame if frame != 0 else (1 if lit else 0)


func _on_seal_pressed(_by: Node, symbol: String) -> void:
	if _busy or puzzle.solved:
		return
	var result := puzzle.press(symbol)
	if result == SealPuzzle.Result.IGNORED:
		return
	AudioManager.play_sfx("seal_press", -4.0, 0.9 + 0.1 * puzzle.entered.size())
	var sprite := seals[symbol].get_node("Sprite") as Sprite2D
	sprite.frame = 1
	var pop := create_tween()
	pop.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.06)
	pop.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	match result:
		SealPuzzle.Result.WRONG:
			_busy = true
			GameState.lock_input("puzzle")
			await get_tree().create_timer(0.6).timeout
			AudioManager.play_sfx("seal_wrong", -2.0)
			camera().shake(1.5, 0.3)
			_seal_frames(0)
			var attempts := GameState.inc_flag("seal_attempts")
			GameState.unlock_input("puzzle")
			_busy = false
			UI.caption(WRONG_LINE if attempts < 2 else WRONG_LINE_HINT,
				(seals["moon"] as Node2D).global_position + Vector2(0, -26))
		SealPuzzle.Result.SOLVED:
			_busy = true
			GameState.lock_input("puzzle")
			await get_tree().create_timer(0.5).timeout
			AudioManager.play_sfx("seal_solved", -1.0)
			_seal_frames(2)
			GameState.set_flag("solved_chapel_puzzle", true)
			GameState.unlock_input("puzzle")
			_busy = false
			DialogueManager.start("chapel_seal_solved")


func _open_archive() -> Signal:
	AudioManager.play_sfx("door_stone", 0.0)
	camera().shake(2.5, 0.9)
	var sprite := door.get_node("Sprite") as Sprite2D
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_callback(func() -> void:
		sprite.frame = 1
		(door.get_node("Shape") as CollisionShape2D).set_deferred("disabled", true))
	t.tween_interval(0.6)
	return t.finished


## Alden hurries in behind Rowan when the ledger has been read (coroutine:
## the conversation waits until he arrives).
func _alden_enter() -> void:
	var alden := npc("Alden")
	alden.global_position = Vector2(272, 156)
	alden.reset_physics_interpolation()
	alden.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(alden, "modulate:a", 1.0, 0.3)
	alden.facing_name = "right"
	await alden.walk_to(ARCHIVE_SPOT, 45.0)
	alden.set_facing("right")
	get_player().face_toward(alden.global_position)
	await get_tree().create_timer(0.2).timeout
