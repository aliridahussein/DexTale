extends GameArea
## The Mistbound Path: the Hollow Sentinel encounter.
##
## Two ways through:
##  - Understand: listen (F) to the Sentinel, hear its story, answer its riddle.
##  - Endure: walk north through three telegraphed mist pulses.
## Failing only pushes Rowan back to the start of the field; after three hits
## the pulses slow down. Walking back south cancels the challenge, so the
## player can never get stuck.

const GOAL_Y := 200.0
const CANCEL_Y := 456.0
const SENTINEL_HOME := Vector2(192, 426)
const SENTINEL_ASIDE := Vector2(226, 410)

var challenge_active := false
var hits := 0
var _block: StaticBody2D
var _block_shape: CollisionShape2D
var _silhouettes: Array[Node2D] = []

@onready var sentinel: NPC = npc("Sentinel")
@onready var sentinel_light: PointLight2D = $Lights/SentinelLight


func _area_ready() -> void:
	_make_block()
	for p in $Encounter.get_children():
		if p is MistPulse:
			(p as MistPulse).hit.connect(_on_hit)
	for n in $Objects.get_children():
		if n.name.begins_with("Silhouette"):
			_silhouettes.append(n)
	GameState.flag_changed.connect(func(f: String, _v: Variant) -> void:
		if f == "passed_sentinel":
			_refresh())
	_refresh()


func area_events() -> Dictionary:
	return {
		"sentinel_stir": _stir,
		"sentinel_challenge": _start_challenge,
		"sentinel_fade": _fade_sentinel,
	}


func _make_block() -> void:
	_block = StaticBody2D.new()
	_block.collision_layer = 1
	_block.collision_mask = 0
	_block.position = SENTINEL_HOME + Vector2(0, -4)
	_block_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(76, 12)
	_block_shape.shape = rect
	_block.add_child(_block_shape)
	add_child(_block)


func _refresh() -> void:
	var passed := GameState.has_flag("passed_sentinel")
	_block_shape.set_deferred("disabled", passed or challenge_active)
	sentinel_light.visible = not passed
	$Effects/Motes.emitting = not passed


func _process(_delta: float) -> void:
	var player := get_player()
	if player == null:
		return
	# Strange silhouettes in the mist fade away as Rowan gets close.
	for s in _silhouettes:
		var d := s.global_position.distance_to(player.global_position)
		s.modulate.a = clampf((d - 40.0) / 70.0, 0.0, 0.75)
	if challenge_active and not GameState.is_input_locked():
		if player.global_position.y < GOAL_Y:
			_challenge_won()
		elif player.global_position.y > CANCEL_Y:
			_challenge_cancel()


func _stir() -> Signal:
	AudioManager.play_sfx("sentinel", -3.0)
	camera().shake(1.5, 0.4)
	var t := create_tween()
	t.tween_property(sentinel_light, "energy", 1.6, 0.25)
	t.tween_property(sentinel_light, "energy", 0.7, 0.6)
	return t.finished


## Coroutine (the conversation waits for it): the Sentinel steps aside and
## Rowan is placed at the start of the field, north of the cancel line.
func _start_challenge() -> void:
	GameState.lock_input("challenge_intro")
	# Owned by this area: leaving it any way at all (title, load, quit) releases it.
	SaveManager.block_saving("sentinel_challenge", self)
	sentinel.walk_to(SENTINEL_ASIDE, 40.0)
	await SceneManager.fade_to(1.0, 0.35)
	get_player().teleport(get_spawn_position("challenge_start"))
	get_player().face("up")
	challenge_active = true
	hits = 0
	_refresh()
	await SceneManager.fade_to(0.0, 0.35)
	GameState.unlock_input("challenge_intro")
	for p in $Encounter.get_children():
		if p is MistPulse:
			(p as MistPulse).set_slow(GameState.has_flag("sentinel_mercy"))
			(p as MistPulse).set_active(true)
	UI.show_toast("Cross the mist. Walk back south to stop.")


func _stop_pulses() -> void:
	for p in $Encounter.get_children():
		if p is MistPulse:
			(p as MistPulse).set_active(false)


func _on_hit() -> void:
	if not challenge_active:
		return
	hits += 1
	GameState.lock_input("mist_hit")
	AudioManager.play_sfx("mist_hit", -2.0)
	SceneManager.flash(Color(0.75, 0.88, 1.0), 0.6, 0.75)
	camera().shake(3.0, 0.4)
	await get_tree().create_timer(0.25).timeout
	get_player().teleport(get_spawn_position("challenge_start"))
	get_player().face("up")
	await get_tree().create_timer(0.45).timeout
	GameState.unlock_input("mist_hit")
	if hits >= 3 and not GameState.has_flag("sentinel_mercy"):
		GameState.set_flag("sentinel_mercy", true)
		for p in $Encounter.get_children():
			if p is MistPulse:
				(p as MistPulse).set_slow(true)
		DialogueManager.start("sentinel_mercy")
	else:
		UI.show_toast("The mist pushes you back.")


func _challenge_won() -> void:
	challenge_active = false
	_stop_pulses()
	SaveManager.unblock_saving("sentinel_challenge")
	AudioManager.play_sfx("success", -4.0)
	get_player().face("down")
	sentinel.face_toward(get_player().global_position)
	DialogueManager.start("sentinel_endured", sentinel)


func _challenge_cancel() -> void:
	challenge_active = false
	_stop_pulses()
	SaveManager.unblock_saving("sentinel_challenge")
	sentinel.walk_to(SENTINEL_HOME, 40.0)
	_refresh()
	UI.show_toast("You step back out of the mist.")


func _fade_sentinel() -> void:
	AudioManager.play_sfx("sentinel_fade", -2.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(sentinel, "modulate:a", 0.0, 1.8)
	t.tween_property(sentinel_light, "energy", 0.0, 1.8)
	await t.finished
	_block_shape.set_deferred("disabled", true)
	# passed_sentinel is set by the conversation right after this event
	await get_tree().process_frame
	_refresh()
