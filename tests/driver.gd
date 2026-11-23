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
		elif UI.ritual_view.visible:
			await perform_ritual()
		elif UI.reconstruction_view.visible:
			await solve_board()
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


## Sings the Gathering Song on the bell (the V2 ritual) through the view's
## own input method, waiting out each note's short ring.
func perform_ritual() -> void:
	var view: Control = UI.ritual_view
	for note in ResonanceRitual.solution():
		var t := 0.0
		while view.call("play_note", note) == ResonanceRitual.Result.IGNORED and t < 6.0:
			await wait(0.05)
			t += 0.05
	var t2 := 0.0
	while view.visible and t2 < 8.0:
		await wait(0.05)
		t2 += 0.05


## Answers the open reconstruction board correctly.
func solve_board() -> void:
	var board: Control = UI.reconstruction_view
	var answers: Array = board.call("answers")
	for i in answers.size():
		if answers[i].get("correct", false):
			board.call("choose", i)
	var t := 0.0
	while board.visible and t < 8.0:
		await wait(0.05)
		t += 0.05


# --------------------------------------------- V2.2: the Watchman's Crossing --
## A careful route over the bridge, around both rotten half-planks (west half
## at y 250-255, east half at y 275-280; Rowan's feet are 10x6): up the west
## side, across in the gap between them, up the east side, then up the road.
## Ends just short of the exit; step_on() then takes Rowan through it.
const SNEAK_PATH := [Vector2(202, 300), Vector2(202, 268), Vector2(215, 268), Vector2(215, 240),
	Vector2(208, 214), Vector2(208, 120), Vector2(208, 28)]


func take(path: String) -> void:
	var it := area().get_node(path) as Interactable
	runner.check(it != null and it.is_available(), "%s can be taken" % path)
	it.interact(player())
	await wait(0.6)


## Combine two items through the inventory screen, as a player would.
func combine_in_inventory(a: String, b: String) -> void:
	UI.open_inventory()
	var inv: Control = UI.inventory_view
	inv.set("cursor", Inventory.owned().find(a))
	inv.call("select")
	inv.call("do_action", "combine")
	inv.set("cursor", Inventory.owned().find(b))
	inv.call("select")
	inv.call("close")
	await get_tree().process_frame


## Turn the winch into the safe band and release it.
func operate_winch() -> void:
	var view: Control = UI.winch_view
	var t := 0.0
	while not view.visible and t < 10.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.05)
		t += 0.05
	runner.check(view.visible, "the winch opens once the chain is secured")
	var puzzle: WinchPuzzle = view.get("puzzle")
	while puzzle.zone() != WinchPuzzle.Result.SAFE:
		view.call("turn", 1, 0.1)
	view.call("turn", 1, 0.2)
	runner.check(view.call("release") == WinchPuzzle.Result.SAFE, "released at safe tension")
	t = 0.0
	while (DialogueManager.is_active() or GameState.is_input_locked() or view.visible) and t < 30.0:
		await wait(0.05)
		t += 0.05


## Walks waypoint to waypoint with the real movement code (collision, the
## weak planks' triggers). Stops early, returning false, if the walk is cut
## short (caught and sent back) or the area changes.
func walk_path(points: Array) -> bool:
	for p in points:
		if area() == null or area().area_id != "crossing":
			return false
		var rowan := player()
		await rowan.walk_to(p, 1.0)
		if not is_instance_valid(rowan) or rowan.global_position.distance_to(p) > 3.0:
			return false
	return true


## Where the Shadow is and what it is doing, for failure messages.
func shadow_report() -> String:
	var s := area().get_node_or_null("Objects/Watchman") as WatchmanShadow
	if s == null:
		return "no shadow"
	return "shadow %s state %d awareness %.2f facing %s; Rowan %s; lantern %s" % [s.position.round(), s.state,
		s.awareness, s.facing.snapped(Vector2(0.01, 0.01)), player().global_position.round(), Inventory.lantern_on()]


## Pick an item in the inventory screen and choose Hold, as a player would.
func hold_in_inventory(id: String) -> void:
	UI.open_inventory()
	var inv: Control = UI.inventory_view
	inv.set("cursor", Inventory.owned().find(id))
	inv.call("select")
	inv.call("do_action", "hold")
	await get_tree().process_frame


## Plays the whole crossing: watchhouse items, the repair, the winch, then
## either sneaking past the Shadow or giving its memory back. Ends in the tower.
func complete_crossing(peaceful: bool = false) -> void:
	runner.check(area().area_id == "crossing", "arrived at the crossing")
	await until_idle()
	if not has("crossing_arrived"):
		await step_on("Triggers/Arrive")  # walking up the road: the first look at the raised bridge
		await play([0])
	await step_on("Triggers/ToWatchhouse")
	await wait_area("watchhouse")
	for p in ["Interactions/LanternTake", "Interactions/RopeTake", "Interactions/HookTake"]:
		await take(p)
	if peaceful:
		await take("Interactions/TokenTake")
		await listen("Interactions/ChairEcho")
	await combine_in_inventory("rope", "hook")
	runner.check(Inventory.has("hooked_line"), "made the Hooked Line")
	await step_on("Triggers/ToCrossing")
	await wait_area("crossing")
	(area().get_node("Interactions/ChainUse") as Interactable).interact(player())
	await until_idle()
	runner.check(has("chain_secured") and not Inventory.has("hooked_line"), "the chain is secured with the line")
	(area().get_node("Interactions/WinchUse") as Interactable).interact(player())
	await operate_winch()
	runner.check(has("bridge_lowered"), "the bridge is down")
	var shadow := area().get_node("Objects/Watchman") as WatchmanShadow
	if peaceful:
		await listen("Interactions/PostEcho")
		UI.inspect_token("watchman_promise")
		await wait(0.2)
		var board: Control = UI.reconstruction_view
		runner.check(board.call("choose", 0) == "ruled_out", "a wrong guess about the watchman can be retried")
		runner.check(board.call("choose", 1) == "correct", "he was waiting for someone to come back")
		await play([0])
		player().teleport(Vector2(172, 342))
		await frames(2)
		(area().get_node("Interactions/PostUse") as Interactable).interact(player())
		await play([0])
		runner.check(has("watchman_resolved") and not shadow.is_hostile(), "the watchman is at peace")
	else:
		# a known moment of the round: at the east post, heading north
		shadow.start_at(1)
		if Inventory.lantern_on():
			player().toggle_lantern()
	var catches := int(GameState.get_flag("watchman_catches", 0))
	player().teleport(SNEAK_PATH[0])
	await frames(2)
	var whole: bool = await walk_path(SNEAK_PATH)
	runner.check(whole and int(GameState.get_flag("watchman_catches", 0)) == catches,
		"crossed the bridge without being caught (%s)" % shadow_report())
	runner.check(not has("heard_creak"), "stepped around the rotten planks")
	await step_on("Triggers/ToTower")
	await wait_area("bell_tower")


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
