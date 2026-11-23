extends "res://tests/driver.gd"
## V2.2: the Watchman's Crossing, on the real scenes. The bridge (repair,
## winch tension, persistence), the Watchman's Shadow (sight, warning, states,
## capture and hints, creaks), sneaking across, the optional Last Promise,
## old saves arriving from the tower side, and leaving mid-scene.

## Everything up to and including the Sentinel (as in test_save's PRE_SENTINEL).
const ROAD := ["game_started", "met_pip", "spoke_to_mara", "mara_showed_pin", "has_tuning_pin", "solved_chapel_puzzle",
	"read_ledger", "read_bellkeeper_ledger", "has_gate_key", "gate_unlocked", "met_sentinel", "passed_sentinel",
	"sentinel_resolved_peacefully"]
const LOWERED := ["found_lantern", "found_rope", "found_hook", "made_hooked_line", "chain_secured", "bridge_lowered"]
const V1_FIXTURE := "res://tests/fixtures/v1_save_tower_endured.json"
const WEST_POST := Vector2(112, 196)


func setup() -> void:
	begin("user://test_crossing_save.json")


func teardown() -> void:
	Inventory.clear_held()
	for c in [UI.inventory_view, UI.winch_view, UI.reconstruction_view]:
		c.visible = false
	finish()


func shadow() -> WatchmanShadow:
	return area().get_node("Objects/Watchman") as WatchmanShadow


func catches() -> int:
	return int(GameState.get_flag("watchman_catches", 0))


## Could Rowan's body move 40 px north from the bridge head (real collision)?
func can_walk_onto_bridge() -> bool:
	var p := player()
	p.teleport(Vector2(208, 306))
	await frames(2)
	return not p.test_move(p.global_transform, Vector2(0, -40))


## True if every leg of the route is free of walls for Rowan's body.
func route_is_clear(points: Array) -> bool:
	var p := player()
	for i in points.size() - 1:
		p.teleport(points[i])
		await frames(1)
		if p.test_move(p.global_transform, (points[i + 1] as Vector2) - (points[i] as Vector2)):
			return false
	return true


func wait_state(s: WatchmanShadow, state: int, timeout: float = 20.0) -> bool:
	var t := 0.0
	while is_instance_valid(s) and s.state != state and t < timeout:
		await wait(0.05)
		t += 0.05
	return is_instance_valid(s) and s.state == state


func wait_capture(timeout: float = 10.0) -> bool:
	var t := 0.0
	while not area().call("is_capturing") and t < timeout:
		await wait(0.02)
		t += 0.02
	return area().call("is_capturing")


func write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ----------------------------------------------------------------- bridge --
func test_bridge_starts_raised_and_the_winch_waits_for_the_chain() -> void:
	set_flags(ROAD)
	await goto("crossing", "from_path")
	var cr := area()
	runner.check(has("entered_crossing") and objective() == "cross", "arrived; the objective is to cross")
	runner.check(cr.call("bridge_state") == "unrepaired" and cr.call("lane_blocked"), "the bridge starts raised")
	var walkable: bool = await can_walk_onto_bridge()
	runner.check(not walkable, "Rowan can't step out over the ravine")
	runner.check(not shadow().visible and shadow().state == WatchmanShadow.State.DORMANT, "nothing walks the far bank yet")
	await use("Interactions/WinchUse")
	runner.check(not UI.winch_view.visible and cr.call("bridge_state") == "unrepaired",
		"the winch only explains why it can't be used yet")
	cr.call("_winch_puzzle")
	await frames(1)
	runner.check(not UI.winch_view.visible, "even called directly, the winch refuses an unrepaired bridge")
	await use("Interactions/ChainUse")
	runner.check(not has("chain_secured"), "looking at the broken chain changes nothing")
	await listen("Interactions/WinchEcho")
	runner.check(has("echo_winch") and GameState.discovery_log.has("winch_memory"), "the winch remembers: hook first, then the wheel")


func test_winch_tension_fails_safely_then_lowers_the_bridge() -> void:
	set_flags(ROAD + ["found_lantern", "found_rope", "found_hook", "made_hooked_line"])
	await goto("crossing", "checkpoint")
	await until_idle()
	var cr := area()
	(cr.get_node("Interactions/ChainUse") as Interactable).interact(player())
	runner.check(GameState.is_input_locked(), "the repair plays as a short scene")
	await until_idle()
	runner.check(cr.call("bridge_state") == "repaired" and cr.call("lane_blocked"), "chain secured, but the bridge is still up")
	runner.check(UI.caption_text().contains("lashed back onto the winch"), "a caption says what the hook did")
	var view: Control = UI.winch_view
	(cr.get_node("Interactions/WinchUse") as Interactable).interact(player())
	await frames(2)
	runner.check(view.visible, "the winch opens once the chain is secured")
	var puzzle: WinchPuzzle = view.get("puzzle")
	var msg := view.get_node("%WinchMessage") as Label
	runner.check(puzzle.zone() == WinchPuzzle.Result.TOO_LOOSE, "it starts slack")
	runner.check(view.call("release") == WinchPuzzle.Result.TOO_LOOSE and msg.text.contains("Too loose"),
		"releasing a slack chain fails, and says so")
	runner.check(view.visible and not has("bridge_lowered"), "nothing falls")
	view.call("turn", 1, 6.0)
	runner.check(puzzle.zone() == WinchPuzzle.Result.TOO_TIGHT, "the chain can be over-tightened")
	runner.check(view.call("release") == WinchPuzzle.Result.TOO_TIGHT and msg.text.contains("Too tight"),
		"releasing it too tight fails too, and says so")
	runner.check(view.visible and not has("bridge_lowered") and puzzle.tension < 100.0, "the wheel kicks back; still adjustable")
	await press("ui_cancel")
	await until_idle()
	runner.check(not view.visible and not has("bridge_lowered"), "Esc steps back from the winch")
	(cr.get_node("Interactions/WinchUse") as Interactable).interact(player())
	await operate_winch()
	runner.check(has("bridge_lowered") and not cr.call("lane_blocked"), "released at safe tension: the bridge is down")
	runner.check(UI.caption_text().contains("on the other side"), "a caption: something across the ravine has noticed")
	var walkable: bool = await can_walk_onto_bridge()
	runner.check(walkable, "Rowan can walk onto the deck")
	runner.check(shadow().is_hostile() and shadow().visible, "a figure has begun to walk the far bank")
	await use("Interactions/WinchUse")
	runner.check(not view.visible, "the winch can't be worked twice")


func test_winch_logic_is_deterministic() -> void:
	var a := WinchPuzzle.new()
	var b := WinchPuzzle.new()
	for i in 30:
		a.adjust(1, 0.05)
		b.adjust(1, 0.05)
	runner.check(is_equal_approx(a.tension, b.tension), "the same input gives the same tension")
	var w := WinchPuzzle.new()
	runner.check(w.zone() == WinchPuzzle.Result.TOO_LOOSE and w.confirm() == WinchPuzzle.Result.TOO_LOOSE, "starts loose")
	w.tension = 50.0
	runner.check(w.confirm() == WinchPuzzle.Result.SAFE and w.done, "safe in the middle of the band")
	w.adjust(1, 5.0)
	runner.check(is_equal_approx(w.tension, 50.0), "once released, it can't be changed")
	var heavy := WinchPuzzle.new()
	heavy.tension = 90.0
	runner.check(heavy.resistance() < WinchPuzzle.new().resistance(), "the wheel gets heavier as it tightens")
	heavy.adjust(0, 2.0)
	runner.check(heavy.tension < 90.0, "left alone, an over-tight chain creeps back")
	for edge in [[WinchPuzzle.SAFE_MIN - 0.01, WinchPuzzle.Result.TOO_LOOSE], [WinchPuzzle.SAFE_MIN, WinchPuzzle.Result.SAFE],
			[WinchPuzzle.SAFE_MAX, WinchPuzzle.Result.SAFE], [WinchPuzzle.SAFE_MAX + 0.01, WinchPuzzle.Result.TOO_TIGHT]]:
		var e := WinchPuzzle.new()
		e.tension = edge[0]
		runner.check(e.zone() == edge[1], "zone at %.2f" % edge[0])


func test_the_bridge_stays_down() -> void:
	set_flags(ROAD + LOWERED)
	await goto("crossing", "checkpoint")
	await until_idle()
	runner.check(area().call("bridge_state") == "lowered" and not area().call("lane_blocked"), "loads lowered")
	runner.check((area().get_node("Decals/BridgeDeck") as Node2D).visible
		and not (area().get_node("Objects/BridgeRaised") as Node2D).visible, "and is drawn lowered")
	await step_on("Triggers/ToWatchhouse")
	await wait_area("watchhouse")
	await step_on("Triggers/ToCrossing")
	await wait_area("crossing")
	var walkable: bool = await can_walk_onto_bridge()
	runner.check(area().call("bridge_state") == "lowered" and walkable, "still down after the watchhouse")
	player().teleport(area().get_spawn_position("checkpoint"))
	await frames(2)
	runner.check(SaveManager.save_game(true), "saved by the bridge")
	GameState.reset()
	runner.check(SaveManager.continue_game(), "continue")
	await wait_area("crossing")
	walkable = await can_walk_onto_bridge()
	runner.check(area().call("bridge_state") == "lowered" and walkable, "still down after loading")
	runner.check(shadow().is_hostile(), "and the Shadow is back on its round")
	await goto("mist_path", "from_crossing")
	await goto("crossing", "from_path")
	runner.check(area().call("bridge_state") == "lowered", "still down after leaving the crossing")


# ----------------------------------------------------------------- shadow --
func test_shadow_sight_lantern_and_pillars() -> void:
	set_flags(ROAD + LOWERED + ["lantern_on"])
	await goto("crossing", "checkpoint")
	await until_idle()
	var s := shadow()
	s.start_at(0)
	s.set_physics_process(false)  # hold still for the geometry
	runner.check(s.facing.x > 0.9, "at the west post, looking east along the road")
	var ahead := Vector2(205, 196)  # 93 px ahead
	runner.check(Inventory.lantern_on() and s.can_see(ahead), "an open lantern is seen far down the road")
	runner.check(not s.can_see(Vector2(130, 140)), "outside its cone, even an open lantern is missed")
	Inventory.toggle_lantern()
	runner.check(not s.can_see(ahead), "with the shutter closed, the same spot is safe")
	runner.check(s.can_see(Vector2(150, 196)), "but close in front it still sees")
	runner.check(s.can_see(Vector2(100, 196)), "right beside it, even behind")
	runner.check(not s.can_see(Vector2(80, 196)), "a little further behind, nothing")
	Inventory.toggle_lantern()
	s.position = Vector2(150, 165)
	s.facing = Vector2.RIGHT
	runner.check(not s.can_see(Vector2(210, 165)), "a stone support between them hides the lantern's glow")
	runner.check(s.can_see(Vector2(210, 196)), "step out from behind it and it sees again")


func test_warning_investigation_and_return() -> void:
	set_flags(ROAD + LOWERED + ["lantern_on"])
	await goto("crossing", "checkpoint")
	await until_idle()
	var s := shadow()
	s.start_at(0)
	player().teleport(Vector2(205, 196))
	runner.check(await wait_state(s, WatchmanShadow.State.SUSPICIOUS, 5.0), "seen at the edge of its light, it stops")
	runner.check((s.get("_mark") as Label).text == "?" and s.awareness < 1.0, "a '?' warns before anything happens")
	runner.check(catches() == 0, "not caught yet")
	player().teleport(area().get_spawn_position("checkpoint"))  # duck back over the bridge
	runner.check(await wait_state(s, WatchmanShadow.State.INVESTIGATE, 10.0), "it goes to look")
	runner.check(s.last_seen.distance_to(Vector2(205, 196)) < 3.0, "where it last saw Rowan")
	runner.check(await wait_state(s, WatchmanShadow.State.RETURN, 20.0), "finds nothing and turns back")
	runner.check(await wait_state(s, WatchmanShadow.State.PATROL, 20.0), "and resumes its round")
	runner.check(catches() == 0 and s.awareness < WatchmanShadow.SUSPICIOUS_AT, "never caught; it has calmed down")


func test_capture_returns_to_the_bridge_head_and_keeps_everything() -> void:
	set_flags(ROAD + LOWERED + ["lantern_on", "found_token"])
	await goto("crossing", "checkpoint")
	await until_idle()
	var cr := area()
	var s := shadow()
	var items := Inventory.owned()
	s.start_at(0)
	player().teleport(Vector2(150, 196))
	var warned := false
	var t := 0.0
	while not cr.call("is_capturing") and t < 10.0:
		warned = warned or s.state == WatchmanShadow.State.SUSPICIOUS
		await wait(0.02)
		t += 0.02
	runner.check(cr.call("is_capturing"), "standing in its light, Rowan is caught")
	runner.check(warned, "it warned first ('?') before catching him")
	runner.check(not SaveManager.can_save_now() and GameState.is_input_locked(), "no saving or moving during the catch")
	await until_idle()
	runner.check(player().global_position.distance_to(cr.get_spawn_position("checkpoint")) < 2.0, "back at the bridge head")
	runner.check(Inventory.owned() == items and has("bridge_lowered") and has("chain_secured"),
		"items and the lowered bridge are kept")
	runner.check(SaveManager.can_save_now(), "saving is allowed again")
	# it begins its round again from the west post (it may take a step while the screen fades back in)
	runner.check(s.state == WatchmanShadow.State.PATROL and s.target_index == 1 and absf(s.position.y - WEST_POST.y) < 0.5
		and s.position.x >= WEST_POST.x and s.position.x < WEST_POST.x + 40.0,
		"the Shadow starts its round again from the west post (%s)" % shadow_report())
	runner.check(catches() == 1 and UI.caption_text().contains("cold lets go"), "the first time, just a short line")
	var hints := {2: "Those stone pillars may be enough to hide the lantern's glow.", 3: "shutter closed (L)"}
	for n in [2, 3]:
		player().teleport(Vector2(150, 196))
		runner.check(await wait_capture(), "caught again (%d)" % n)
		await until_idle()
		runner.check(catches() == n and UI.caption_text().contains(hints[n]),
			"after %d failures, a hint (got '%s')" % [n, UI.caption_text()])


func test_a_creaking_plank_draws_the_shadow_to_the_bridge_head() -> void:
	set_flags(ROAD + LOWERED)
	await goto("crossing", "checkpoint")
	await until_idle()
	var s := shadow()
	s.start_at(0)
	var plank := Rect2(195, 250, 13, 5)
	player().teleport(Vector2(201, 266))
	await frames(2)
	player().teleport(plank.get_center() + Vector2(0, 1))
	await frames(3)
	runner.check(has("heard_creak"), "the rotten plank creaks")
	runner.check(s.state == WatchmanShadow.State.SUSPICIOUS, "the Shadow turns toward the sound")
	runner.check(UI.caption_text().contains("plank creaks"), "the first creak is explained in words")
	runner.check(s.last_seen.y <= 214.0 and absf(s.last_seen.x - plank.get_center().x) < 2.0,
		"it will look from the bridge head, never walking out over the ravine")
	player().teleport(area().get_spawn_position("checkpoint"))
	runner.check(await wait_state(s, WatchmanShadow.State.INVESTIGATE, 10.0), "and comes to look")
	runner.check(await wait_state(s, WatchmanShadow.State.RETURN, 20.0), "then goes back to its round")
	runner.check(s.position.y <= 214.5, "it stayed on its own bank")


func test_sneaking_across_reaches_the_tower() -> void:
	set_flags(ROAD + LOWERED)
	await goto("crossing", "checkpoint")
	await until_idle()
	var clear: bool = await route_is_clear(SNEAK_PATH)
	runner.check(clear, "the careful route over the bridge is free of walls")
	var s := shadow()
	s.start_at(1)
	runner.check(not Inventory.lantern_on(), "shutter closed")
	player().teleport(SNEAK_PATH[0])
	await frames(2)
	var whole: bool = await walk_path(SNEAK_PATH)
	runner.check(whole and catches() == 0 and not has("heard_creak"), "across unseen and unheard (%s)" % shadow_report())
	runner.check(player().global_position.distance_to(SNEAK_PATH[-1]) < 3.0, "reached the far end of the road")
	await step_on("Triggers/ToTower")
	await wait_area("bell_tower")
	runner.check(has("crossing_complete") and objective() == "truth", "the crossing is behind; the tower ahead")
	await step_on("Triggers/ToPath")
	await wait_area("crossing")
	runner.check(shadow().state == WatchmanShadow.State.QUIET and not shadow().is_hostile(),
		"coming back down, it no longer hunts")
	runner.check(not area().call("lane_blocked"), "and the bridge is still down")


# ------------------------------------------------------- the last promise --
func test_the_last_promise() -> void:
	set_flags(ROAD + LOWERED + ["found_token"])
	await goto("crossing", "checkpoint")
	await until_idle()
	runner.check(QuestManager.get_optional_active().any(func(o: Dictionary) -> bool: return o["id"] == "the_watchman"),
		"the token opens an optional thread in the journal")
	var post := area().get_node("Interactions/PostUse") as ItemTarget
	player().teleport(Vector2(172, 342))
	await frames(2)
	await hold_in_inventory("token")
	post.interact(player())
	await frames(2)
	runner.check(UI.caption_text().contains("What was he waiting for") and Inventory.has("token"),
		"too early: a gentle no, and the token is kept")
	await get_tree().process_frame
	await get_tree().process_frame
	var cap := UI.get("_caption") as Label
	var prompt_box: Control = UI.prompt
	runner.check(prompt_box.visible and not Rect2(cap.position, cap.size).intersects(Rect2(prompt_box.position, prompt_box.size)),
		"the caption lifts above the post's prompt instead of covering it")
	Inventory.clear_held()
	await use("Interactions/PostUse")
	runner.check(not has("token_placed"), "just looking at the post doesn't use the token")
	var board: Control = UI.reconstruction_view
	UI.inspect_token("watchman_promise")
	await frames(2)
	runner.check(board.visible and not board.call("can_answer"), "with only the token, the board asks for more")
	await press("ui_cancel")
	await frames(2)
	runner.check(not board.visible and not get_tree().paused, "and can be put away")
	# the memories: the post here, the chair and the wall in the watchhouse
	await listen("Interactions/PostEcho")
	runner.check(has("echo_watch_post"), "the post remembers someone waiting")
	await step_on("Triggers/ToWatchhouse")
	await wait_area("watchhouse")
	await listen("Interactions/ChairEcho")
	runner.check(has("echo_watch_chair"), "the chair remembers a child's question")
	await use("Interactions/TallyLook")
	runner.check(has("seen_tally"), "the tally marks on the wall")
	# inspect the token in the inventory: the board opens; wrong guesses can be retried
	UI.open_inventory()
	UI.inventory_view.set("cursor", Inventory.owned().find("token"))
	UI.inventory_view.call("select")
	UI.inventory_view.call("do_action", "inspect")
	await frames(2)
	runner.check(not UI.inventory_view.visible and board.visible and board.call("can_answer"),
		"inspecting the token lays out what Rowan knows")
	var feedback := board.get_node("%ReconFeedback") as RichTextLabel
	runner.check(board.call("choose", 0) == "ruled_out" and feedback.get_parsed_text().contains("promise to a child"),
		"'orders from the bellkeeper' is ruled out by the chair")
	runner.check(board.call("choose", 2) == "ruled_out", "'a signal to close the bridge' is ruled out by the post")
	runner.check(board.call("choose", 1) == "correct", "he was waiting for someone to come back")
	await play([0])
	runner.check(has("watchman_promise_known") and Inventory.has("token"), "understood; the token is still carried")
	await step_on("Triggers/ToCrossing")
	await wait_area("crossing")
	player().teleport(Vector2(172, 342))
	await frames(2)
	post = area().get_node("Interactions/PostUse") as ItemTarget
	runner.check(post.prompt_text() == "Use Watchman's Token", "the post now offers the token")
	post.interact(player())
	await play([0])
	runner.check(has("token_placed") and has("watchman_resolved") and not Inventory.has("token"), "the token is back on its post")
	runner.check(shadow().state == WatchmanShadow.State.RESOLVED and not shadow().is_hostile(), "the Shadow is at peace")
	runner.check(not post.is_available(), "the post has nothing more to ask")
	runner.check(QuestManager.get_completed().any(func(o: Dictionary) -> bool: return o["id"] == "the_watchman_rest"),
		"the optional thread is complete")
	# at peace for good: standing in front of it is safe, also after loading
	player().teleport(Vector2(150, 204))
	await wait(3.0)
	runner.check(catches() == 0, "it never catches Rowan again")
	player().teleport(area().get_spawn_position("checkpoint"))
	await frames(2)
	runner.check(SaveManager.save_game(true), "saved")
	GameState.reset()
	runner.check(SaveManager.continue_game(), "continue")
	await wait_area("crossing")
	runner.check(shadow().state == WatchmanShadow.State.RESOLVED, "still at peace after loading")
	# every ending remembers it
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/endings.json"))
	var ending_script: GDScript = load("res://scripts/ui/ending.gd")
	for kind in ["keeper", "promise", "chorus"]:
		var lines: Array = ending_script.call("epilogue_lines", kind, data)
		var want := "He didn't need to be" if kind == "chorus" else "post by the old crossing"
		runner.check(lines.any(func(l: String) -> bool: return l.contains(want)), "the %s epilogue remembers the watchman" % kind)
	GameState.set_flag("watchman_resolved", false)
	var plain: Array = ending_script.call("epilogue_lines", "keeper", data)
	runner.check(not plain.any(func(l: String) -> bool: return l.contains("old crossing")), "without it, no watchman line")


## With the tower's stairs open, the promise can still be kept after crossing.
func test_the_promise_can_be_kept_after_crossing() -> void:
	set_flags(ROAD + LOWERED + ["found_token", "echo_watch_chair", "echo_watch_post", "watchman_promise_known",
		"crossing_complete"])
	await goto("crossing", "from_tower")
	await until_idle()
	runner.check(shadow().state == WatchmanShadow.State.QUIET, "after crossing, the Shadow is only a figure by its lantern")
	runner.check(QuestManager.get_optional_active().any(func(o: Dictionary) -> bool: return o["id"] == "the_watchman_rest"),
		"the journal still offers to give him back what he waited for")
	player().teleport(Vector2(172, 342))
	await frames(2)
	var post := area().get_node("Interactions/PostUse") as ItemTarget
	runner.check(post.prompt_text() == "Use Watchman's Token", "the post offers the token")
	post.interact(player())
	await play([0])
	runner.check(has("watchman_resolved") and shadow().state == WatchmanShadow.State.RESOLVED, "kept after crossing too")


# --------------------------------------------------------------- old saves --
func test_old_saves_come_down_to_a_lowered_bridge() -> void:
	write_raw(SaveManager.save_path, FileAccess.get_file_as_string(V1_FIXTURE))
	runner.check(SaveManager.continue_game(), "a V1 save continues")
	await wait_area("bell_tower")
	runner.check(has("crossing_complete") and objective() == "truth", "the tower counts the crossing as done")
	await step_on("Triggers/ToPath")
	await wait_area("crossing")
	runner.check(has("bridge_lowered") and has("chain_secured"), "coming down, the bridge is simply down")
	runner.check(player().global_position.y < 222.0, "Rowan arrives on the tower side")
	runner.check(not shadow().is_hostile(), "nothing hunts on the way back")
	runner.check(Inventory.owned() == ["tuning_pin", "gate_key"], "no stray new items")
	var back := [Vector2(208, 214), Vector2(215, 240), Vector2(215, 268), Vector2(202, 268), Vector2(202, 330)]
	var clear: bool = await route_is_clear(back)
	runner.check(clear, "the way back over the bridge is open")
	player().teleport(back[0])
	await frames(2)
	var whole: bool = await walk_path(back)
	runner.check(whole, "walked the whole way back")
	runner.check(player().global_position.y > 296.0, "walked back over to the near bank")
	await step_on("Triggers/ToPath")
	await wait_area("mist_path")


# ------------------------------------------------------ leaving mid-scene --
func test_title_mid_capture_leaves_no_locks() -> void:
	set_flags(ROAD + LOWERED + ["lantern_on"])
	await goto("crossing", "checkpoint")
	await until_idle()
	runner.check(SaveManager.save_game(true), "saved at the bridge head")
	shadow().start_at(0)
	player().teleport(Vector2(150, 196))
	runner.check(await wait_capture(), "caught")
	UI.pause_menu.call("_on_title")
	var menu := await scene_named("MainMenu")
	runner.check(menu != null, "returned to the title mid-capture")
	runner.check(GameState.lock_reasons().is_empty() and not SaveManager.is_saving_blocked(),
		"no lock or save block survives (%s / %s)" % [GameState.lock_reasons(), SaveManager.save_blocks()])
	runner.check(SaveManager.continue_game(), "continue")
	await wait_area("crossing")
	runner.check(not GameState.is_input_locked() and SaveManager.can_save_now(), "free to move and to save")
	runner.check(area().call("bridge_state") == "lowered" and not area().call("is_capturing"), "progress kept, nothing half-done")


func test_area_change_mid_capture_and_mid_lowering_leaves_no_locks() -> void:
	set_flags(ROAD + LOWERED + ["lantern_on"])
	await goto("crossing", "checkpoint")
	await until_idle()
	shadow().start_at(0)
	player().teleport(Vector2(150, 196))
	runner.check(await wait_capture(), "caught")
	SceneManager.change_area("watchhouse", "from_crossing")
	await wait_area("watchhouse")
	runner.check(not GameState.is_input_locked() and SaveManager.can_save_now(),
		"leaving mid-capture releases it (%s / %s)" % [GameState.lock_reasons(), SaveManager.save_blocks()])
	# and while the bridge is coming down
	GameState.reset()
	set_flags(ROAD + ["found_lantern", "found_rope", "found_hook", "made_hooked_line", "chain_secured"])
	await goto("crossing", "checkpoint")
	await until_idle()
	(area().get_node("Interactions/WinchUse") as Interactable).interact(player())
	await frames(2)
	var view: Control = UI.winch_view
	var puzzle: WinchPuzzle = view.get("puzzle")
	puzzle.tension = 50.0
	view.call("release")
	var t := 0.0
	while not GameState.lock_reasons().has("bridge") and t < 10.0:
		await wait(0.02)
		t += 0.02
	runner.check(GameState.lock_reasons().has("bridge"), "the bridge is coming down")
	SceneManager.change_area("watchhouse", "from_crossing")
	await wait_area("watchhouse")
	runner.check(not GameState.is_input_locked(), "leaving mid-scene releases the lock (%s)" % [GameState.lock_reasons()])
	await goto("crossing", "from_watchhouse")
	runner.check(area().call("bridge_state") == "lowered" and not area().call("lane_blocked"),
		"the bridge counts as down: its state was saved first")


