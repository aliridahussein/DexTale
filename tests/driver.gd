extends Node
## Shared helpers for gameplay tests: they drive the real scenes through the
## same Interactable / EchoPoint / AreaExit / dialogue code a player uses.
## Suites extend this file: extends "res://tests/driver.gd".

const SPEED := 6.0

var runner: Node
var _real_save := ""


func begin(save_file: String) -> void:
	Engine.time_scale = SPEED
	_real_save = SaveManager.save_path
	SaveManager.save_path = save_file
	SaveManager.delete_save()
	DialogueManager.stop()
	GameState.reset()
	UI.clear_toasts()
	DialogueManager.missing_events.clear()


func finish() -> void:
	DialogueManager.stop()
	for c in [UI.journal, UI.document_view, UI.pause_menu]:
		if c.visible:
			c.visible = false
	get_tree().paused = false
	SaveManager.delete_save()
	if _real_save != "":
		SaveManager.save_path = _real_save
	Engine.time_scale = 1.0
	GameState.reset()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func area() -> GameArea:
	return SceneManager.current_area as GameArea


func player() -> Player:
	return area().get_player()


func set_flags(names: Array) -> void:
	for f in names:
		GameState.set_flag(f, true)


func goto(area_id: String, spawn: String = "default") -> void:
	await until_idle()
	SceneManager.change_area(area_id, spawn)
	await SceneManager.area_ready
	while SceneManager.transitioning:
		await frames(1)
	runner.check(area() != null and area().area_id == area_id, "entered %s" % area_id)


## Walk onto a trigger (teleport onto it and let physics report the overlap).
func step_on(trigger_path: String) -> void:
	var t := area().get_node(trigger_path) as Node2D
	player().teleport(t.global_position)
	await frames(3)


## After walking into an exit: wait until the new area is up and idle.
func wait_area(area_id: String) -> void:
	var t := 0.0
	while (area() == null or area().area_id != area_id or SceneManager.transitioning) and t < 20.0:
		await wait(0.05)
		t += 0.05
	runner.check(area() != null and area().area_id == area_id, "arrived in %s" % area_id)
	await until_idle()


func scene_named(scene_name: String, timeout: float = 30.0) -> Node:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and not SceneManager.transitioning:
			return s
		await wait(0.05)
		t += 0.05
	return null


func until_idle(timeout: float = 30.0) -> void:
	var t := 0.0
	while (DialogueManager.is_active() or SceneManager.transitioning or GameState.is_input_locked()) and t < timeout:
		await wait(0.05)
		t += 0.05
	runner.check(t < timeout, "game returned to idle (locks: %s, conv: %s)" % [GameState.lock_reasons(), DialogueManager.current_conversation()])


## Play the current/next conversation to the end. `picks` are choice indices
## used in order (the last one repeats). Documents are read to the last page.
func play(picks: Array = [0], must_start: bool = true) -> void:
	var t := 0.0
	var window := 20.0 if must_start else 1.5
	while not DialogueManager.is_active() and t < window:
		await wait(0.05)
		t += 0.05
	if must_start:
		runner.check(DialogueManager.is_active(), "a conversation started")
	var i := 0
	var guard := 0
	while DialogueManager.is_active() and guard < 6000:
		guard += 1
		var doc: Control = UI.document_view
		if doc.visible:
			doc.set("_page", (doc.get("_pages") as Array).size() - 1)
			doc.call("_show_page")
			doc.call("_close")
		elif DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		elif DialogueManager.is_waiting_for_choice():
			DialogueManager.choose(int(picks[mini(i, picks.size() - 1)]))
			i += 1
		await wait(0.02)
	await until_idle()


func use(path: String, picks: Array = [0]) -> void:
	await until_idle()
	var it := area().get_node(path) as Interactable
	runner.check(it.is_available(), "%s is available" % path)
	it.interact(player())
	await play(picks)


func talk(npc_name: String, picks: Array = [0]) -> void:
	await until_idle()
	var n := area().npc(npc_name)
	runner.check(n != null and n.visible, "%s is here" % npc_name)
	n.talk.interact(player())
	await play(picks)


func listen(path: String, picks: Array = [0]) -> void:
	await until_idle()
	var ep := area().get_node(path) as EchoPoint
	runner.check(ep.is_available(), "%s can be heard" % path)
	player().teleport(ep.global_position + Vector2(0, 14))
	await frames(2)
	var echo := player().get_node("Echo")
	runner.check(echo.call("best_target") == ep, "Echo targets %s" % path)
	echo.call("activate")
	await play(picks)
	# the vision finishes fading before prompts and toasts come back
	var t := 0.0
	while UI.is_revealing() and t < 10.0:
		await wait(0.05)
		t += 0.05


func press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func objective() -> String:
	return str(QuestManager.get_primary().get("id", ""))


func has(flag: String) -> bool:
	return GameState.has_flag(flag)
