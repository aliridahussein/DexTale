extends Node
## Visual playtest: drives the real game (windowed) through every area, the
## V2 fixes and all three endings, saving screenshots to docs/screenshots/v2/.
## Unlike V1's tour it also asserts: an ending that never reaches its card,
## epilogue and title menu fails the run.
## Run:  godot --path . res://tests/tour.tscn  [-- --only=story|endings|v2|crossing]
## (The crossing's screenshots go to docs/screenshots/v2_2/.)
## Lives under the root (not as the current scene) so scene changes don't free it.

const OUT := "res://docs/screenshots/v2/"
const OUT_V2_2 := "res://docs/screenshots/v2_2/"

var _out := OUT

var _errors: Array[String] = []
var _failures: Array[String] = []


class TourLogger extends Logger:
	var sink: Array[String]

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == 1:
			return
		sink.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function])

	func _log_message(_m: String, _e: bool) -> void:
		pass


func _ready() -> void:
	var lg := TourLogger.new()
	lg.sink = _errors
	OS.add_logger(lg)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	SaveManager.save_path = "user://tour_save.json"
	SaveManager.delete_save()
	await _tour()
	SaveManager.delete_save()
	print("\n=== tour finished: %d engine/script errors, %d failed checks ===" % [_errors.size(), _failures.size()])
	for e in _errors.slice(0, 40):
		print("  ! " + e)
	for f in _failures:
		print("  x " + f)
	AudioManager.quit_game(0 if _errors.is_empty() and _failures.is_empty() else 1)


# ---------------------------------------------------------------- helpers --
func check(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok" if ok else "FAILED", what])
	if not ok:
		_failures.append(what)


func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(_out + file_name + ".png"))
	print("  shot: %s (%dx%d)" % [file_name, img.get_width(), img.get_height()])


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func goto_area(area_id: String, spawn: String = "default") -> GameArea:
	await drain()
	while SceneManager.transitioning:
		await wait(0.05)
	SceneManager.change_area(area_id, spawn)
	await SceneManager.area_ready
	await wait(1.2)
	return SceneManager.current_area as GameArea


func area() -> GameArea:
	return SceneManager.current_area as GameArea


func player() -> Player:
	return area().get_player()


func put(pos: Vector2, facing: String = "up") -> void:
	player().teleport(pos)
	player().face(facing)
	await wait(0.3)


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


## Plays a conversation to the end, always picking choice `pick` (clamped).
func talk(conv: String, pick: int = 0, shot_name: String = "", shot_at_line: int = 2) -> void:
	await drain()
	if not DialogueManager.start(conv):
		print("  ! could not start ", conv)
		return
	await follow(pick, shot_name, shot_at_line)


## Advances the running conversation; optionally screenshots line N.
func follow(pick: int = 0, shot_name: String = "", shot_at_line: int = 2) -> void:
	var lines := 0
	var guard := 0
	while DialogueManager.is_active() and guard < 4000:
		guard += 1
		if DialogueManager.is_waiting_for_advance():
			lines += 1
			if shot_name != "" and lines == shot_at_line:
				await wait(1.6)
				await shot(shot_name)
			await wait(0.05)
			DialogueManager.advance()
		elif DialogueManager.is_waiting_for_choice():
			await wait(0.2)
			DialogueManager.choose(pick)
		await get_tree().process_frame
		if UI.document_view.visible:
			await wait(0.3)
			UI.document_view.call("_close")


## Advance through any conversation that is already running.
func drain(pick: int = 0) -> void:
	var guard := 0
	while (DialogueManager.is_active() or UI.document_view.visible) and guard < 4000:
		guard += 1
		if UI.document_view.visible:
			UI.document_view.call("_close")
		elif DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		elif DialogueManager.is_waiting_for_choice():
			DialogueManager.choose(pick)
		await wait(0.05)


func flags(names: Array) -> void:
	for n in names:
		GameState.set_flag(n, true)


func listen_here() -> void:
	player().get_node("Echo").call("activate")


# ------------------------------------------------------------------- tour --
func _tour() -> void:
	print("=== visual tour (V2) ===")
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	if only in ["", "story"]:
		await _story()
	if only in ["", "v2"]:
		await _v2_features()
	if only in ["", "crossing"]:
		await _crossing()
	if only in ["", "endings"]:
		await _endings()


## V2.2: the Watchman's Crossing, played through the real interactions.
## Screenshots go to docs/screenshots/v2_2/.
func _crossing() -> void:
	_out = OUT_V2_2
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	while SceneManager.transitioning:
		await wait(0.1)
	GameState.reset()
	flags(["game_started", "met_pip", "spoke_to_mara", "mara_showed_pin", "has_tuning_pin", "solved_chapel_puzzle",
		"read_ledger", "read_bellkeeper_ledger", "has_gate_key", "gate_unlocked", "saw_song_marks",
		"learned_village_song", "met_sentinel", "passed_sentinel", "sentinel_resolved_peacefully"])
	await goto_area("crossing", "from_path")
	await wait(1.5)
	await drain()
	await shot("01_crossing_arrival")
	await put(Vector2(208, 380), "up")
	await wait(0.6)
	await drain()
	await shot("02_crossing_bridge_up")
	await put(Vector2(240, 352), "up")
	await wait(0.4)
	await shot("03_chain_prompt")
	await put(Vector2(258, 356), "up")
	listen_here()
	await wait(2.2)
	await shot("04_winch_echo")
	await drain()
	await wait(2.5)
	# the watchhouse
	await goto_area("watchhouse", "from_crossing")
	await wait(0.8)
	await shot("05_watchhouse")
	var wh := area()
	for p in ["LanternTake", "RopeTake", "HookTake", "TokenTake"]:
		var it := wh.get_node("Interactions/" + p) as Interactable
		await put(it.global_position + Vector2(0, 12), "up")
		await press("interact")
		await wait(0.8)
		await drain()
	await shot("06_watchhouse_items_taken")
	await put(Vector2(112, 104), "up")
	listen_here()
	await wait(1.4)
	await shot("07_chair_memory")
	await drain()
	await wait(2.0)
	UI.open_inventory()
	await wait(0.4)
	await shot("08_inventory")
	var inv: Control = UI.inventory_view
	inv.set("cursor", Inventory.owned().find("rope"))
	inv.call("select")
	inv.set("action_cursor", 2)
	inv.call("do_action", "combine")
	await wait(0.2)
	inv.set("cursor", Inventory.owned().find("hook"))
	await shot("09_inventory_combine")
	inv.call("select")
	await wait(0.4)
	await shot("10_inventory_hooked_line")
	inv.call("do_action", "hold")  # Hold: closes the screen with the line in hand
	# repair and the winch
	await goto_area("crossing", "from_watchhouse")
	var cr := area()
	await put(Vector2(232, 336), "up")
	await wait(0.6)
	await shot("11_holding_the_line_at_the_chain")
	await press("interact")
	await wait(0.9)
	await shot("12_repair_hook_thrown")
	await wait(2.6)
	await shot("13_chain_secured")
	await put(Vector2(258, 356), "up")
	await press("interact")
	var wv: Control = UI.winch_view
	var t := 0.0
	while not wv.visible and t < 8.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	await wait(0.5)
	await shot("14_winch_loose")
	wv.call("release")  # too early: the chain slips, nothing falls
	await wait(0.5)
	await shot("15_winch_released_too_loose")
	var wp: WinchPuzzle = wv.get("puzzle")
	while wp.zone() != WinchPuzzle.Result.SAFE:
		wv.call("turn", 1, 0.1)
		await wait(0.05)
	wv.call("turn", 1, 0.25)
	await wait(0.3)
	await shot("16_winch_safe")
	wv.call("release")
	await wait(2.4)
	await shot("17_bridge_lowering")
	t = 0.0
	while (GameState.is_input_locked() or DialogueManager.is_active()) and t < 15.0:
		await wait(0.1)
		t += 0.1
	await wait(1.0)
	await shot("18_shadow_revealed")
	# stealth: the cone with the shutter open, then closed
	var shadow := cr.get_node("Objects/Watchman") as WatchmanShadow
	await put(Vector2(208, 300), "up")
	await wait(1.5)
	await shot("19_stealth_lantern_open")
	player().toggle_lantern()
	await wait(0.8)
	await shot("20_stealth_shutter_closed")
	check(not cr.call("lane_blocked"), "the bridge lane is walkable once lowered")
	# a rotten plank creaks and the Shadow turns toward it
	shadow.start_at(0)
	await put(Vector2(201, 268), "up")
	await put(Vector2(201.5, 253.5), "up")
	await wait(0.6)
	await shot("21_plank_creaks")
	check(GameState.has_flag("heard_creak"), "the rotten plank creaked")
	await put(Vector2(208, 340), "up")
	await wait(5.0)
	# seen with the lantern open: the "?" warning, then caught and sent back
	player().toggle_lantern()
	shadow.start_at(0)
	await put(Vector2(196, 196), "left")
	t = 0.0
	while shadow.state != WatchmanShadow.State.SUSPICIOUS and t < 6.0:
		await wait(0.05)
		t += 0.05
	await wait(0.25)
	await shot("22_shadow_suspicious")
	while not cr.call("is_capturing") and t < 14.0:
		await wait(0.05)
		t += 0.05
	await wait(0.2)
	await shot("23_caught")
	while cr.call("is_capturing") and t < 20.0:
		await wait(0.05)
		t += 0.05
	await wait(0.5)
	await shot("24_back_at_the_bridge_head")
	shadow.start_at(0)
	await put(Vector2(150, 196), "left")
	t = 0.0
	while int(GameState.get_flag("watchman_catches", 0)) < 2 and t < 10.0:
		await wait(0.05)
		t += 0.05
	while cr.call("is_capturing") and t < 16.0:
		await wait(0.05)
		t += 0.05
	await wait(0.6)
	await shot("25_hint_after_two_catches")
	check(UI.caption_text().contains("stone pillars"), "a hint after the second catch")
	# sneaking over with the shutter closed, around the rotten planks
	player().toggle_lantern()
	shadow.start_at(1)
	await put(Vector2(202, 300), "up")
	for p in [Vector2(202, 268), Vector2(215, 268), Vector2(215, 246)]:
		await player().walk_to(p, 1.0)
	await wait(0.2)
	await shot("26_sneaking_shutter_closed")
	check(int(GameState.get_flag("watchman_catches", 0)) == 2, "sneaking with the shutter closed is not noticed")
	# the peaceful route: too early at the post, the post's echo, the deduction, the token on the post
	await put(Vector2(172, 342), "up")
	Inventory.set_held("token")
	await press("interact")
	await wait(0.5)
	await shot("27_token_not_yet")
	Inventory.clear_held()
	listen_here()
	await wait(2.0)
	await shot("28_post_memory")
	await drain()
	await wait(2.5)
	UI.inspect_token("watchman_promise")
	await wait(0.5)
	await shot("29_token_board")
	var board: Control = UI.reconstruction_view
	board.call("choose", 0)
	await wait(0.4)
	await shot("30_token_board_wrong")
	board.call("choose", 1)
	await wait(2.0)
	await drain()
	await put(Vector2(172, 342), "up")
	await press("interact")
	await wait(3.2)
	await shot("31_shadow_at_peace")
	t = 0.0
	while (DialogueManager.is_active() or GameState.is_input_locked()) and t < 20.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	check(GameState.has_flag("watchman_resolved"), "the watchman was given his memory back")
	await put(Vector2(208, 60), "up")
	await wait(0.6)
	await shot("32_far_bank")
	# up into the tower, and back down its stairs
	player().teleport(Vector2(208, 6))
	await wait_for_area("bell_tower")
	await wait(1.0)
	await drain()
	await shot("33_tower_from_the_crossing")
	await put(Vector2(160, 236), "down")
	await wait(0.4)
	await shot("34_tower_stairwell_open")
	player().teleport(Vector2(160, 246))
	await wait_for_area("crossing")
	await wait(1.0)
	await shot("35_back_down_at_the_crossing")
	check(SceneManager.current_area.get("area_id") == "crossing", "the tower's stairs lead back down to the crossing")
	_out = OUT


func wait_for_area(area_id: String) -> void:
	var t := 0.0
	while t < 15.0:
		var a: Variant = SceneManager.current_area
		if is_instance_valid(a) and a.get("area_id") == area_id and not SceneManager.transitioning:
			return
		await wait(0.1)
		t += 0.1
	check(false, "reached %s" % area_id)


## Milestone 2: the Echo Reconstruction at the well and the bell ritual.
func _v2_features() -> void:
	while SceneManager.transitioning:
		await wait(0.1)
	GameState.reset()
	flags(["game_started", "met_pip", "spoke_to_mara", "talked_tobin"])
	await goto_area("village", "default")
	await put(Vector2(386, 360), "up")
	listen_here()
	await wait(0.6)
	await drain()
	await wait(3.0)
	await put(Vector2(352, 360), "up")
	await wait(0.4)
	await shot("30_lamp_echo_prompt")
	listen_here()
	await wait(1.5)
	await shot("31_lamp_echo_vision")
	await drain()
	await wait(3.0)
	await put(Vector2(344, 392), "up")
	await talk("well_bench")
	await wait(2.5)
	await put(Vector2(384, 358), "up")
	await wait(0.4)
	await shot("32_piece_it_together_prompt")
	await press("interact")
	var board: Control = UI.reconstruction_view
	var t := 0.0
	while not board.visible and t < 10.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	check(board.visible, "the reconstruction board opens at the well")
	await wait(0.4)
	await shot("33_reconstruction_board")
	await press("interact")  # the first answer (a wrong one)
	await wait(0.4)
	await shot("34_reconstruction_wrong_answer")
	while int(board.get("cursor")) != 2:
		await press("move_down")
	await press("interact")
	await wait(0.6)
	await shot("35_reconstruction_solved")
	t = 0.0
	while board.visible and t < 5.0:
		await wait(0.1)
		t += 0.1
	var lines := 0
	while DialogueManager.is_active() and t < 30.0:
		if DialogueManager.is_waiting_for_advance():
			lines += 1
			if lines == 2:
				await wait(1.2)
				await shot("36_memory_elsie_and_tobin")
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	check(GameState.has_flag("promise_reconstructed"), "the promise was reconstructed")
	await wait(3.0)
	await talk("tobin", 0, "37_tobin_told", 5)
	await wait(2.5)
	UI.open_journal()
	await wait(0.3)
	await press("move_right")
	for i in 40:
		await press("move_down")
	await wait(0.2)
	await shot("38_journal_promise_entry")
	UI.journal.call("close")
	# Tobin's lantern on the Mistbound Path
	flags(["has_tuning_pin", "solved_chapel_puzzle", "read_ledger", "read_bellkeeper_ledger", "has_gate_key",
		"gate_unlocked", "learned_village_song", "met_sentinel"])
	await goto_area("mist_path", "from_village")
	await put(Vector2(192, 560), "up")
	await wait(0.6)
	await shot("39_mist_path_tobins_lantern")
	# the bell ritual
	flags(["passed_sentinel", "pin_installed", "orin_appeared", "met_orin_echo"])
	await goto_area("bell_tower", "from_path")
	area().npc("Orin").talk.interact(player())
	t = 0.0
	while not DialogueManager.is_waiting_for_choice() and t < 30.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	await wait(0.4)
	await shot("40_final_choice_three_options")
	DialogueManager.choose(2)
	var view: Control = UI.ritual_view
	t = 0.0
	while not view.visible and t < 15.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	check(view.visible, "the ritual opens after choosing The Chorus")
	await wait(1.2)
	await shot("41_ritual_start")
	var r: ResonanceRitual = view.get("ritual")
	var sol := ResonanceRitual.solution()
	for i in 5:
		while view.call("play_note", sol[i]) == ResonanceRitual.Result.IGNORED:
			await wait(0.05)
		await wait(0.25)
	await wait(0.3)
	await shot("42_ritual_five_notes")
	while view.call("play_note", ResonanceRitual.Note.UP) == ResonanceRitual.Result.IGNORED:  # wrong: needs DOWN
		await wait(0.05)
	await wait(0.12)
	await shot("43_ritual_soured")
	await wait(1.0)
	await shot("44_ritual_missed_note_hinted")
	for i in sol.size():
		if r.done:
			break
		while view.call("play_note", ResonanceRitual.needed_for(r.sung)) == ResonanceRitual.Result.IGNORED:
			await wait(0.05)
		await wait(0.2)
		if r.sung == 12:
			await wait(0.4)
			await shot("45_ritual_last_note_circled")
	await wait(0.6)
	await shot("46_ritual_complete")
	t = 0.0
	while get_tree().current_scene != null and get_tree().current_scene.name != "Ending" and t < 20.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.1)
		t += 0.1
	check(GameState.has_flag("bell_retuned") and str(GameState.get_flag("ending_selected")) == "chorus",
		"the ritual leads into The Chorus")
	await wait(2.0)
	SceneManager.goto_scene("res://scenes/main/main_menu.tscn", 0.3)
	await wait(1.5)


func _story() -> void:
	while SceneManager.transitioning:
		await wait(0.1)
	await wait(2.6)
	await shot("01_title")
	# the arrival
	GameState.reset()
	GameState.set_flag("game_started", true)
	SceneManager.change_area("village", "start")
	await SceneManager.area_ready
	while not DialogueManager.is_active():
		await get_tree().process_frame
	await drain()
	await wait(2.0)
	await put(Vector2(384, 392), "up")
	await wait(1.0)
	await shot("02_village_sunset")
	# Echo at the well: the vision now has room (no toast, no prompt on top)
	await put(Vector2(386, 360), "up")
	listen_here()
	await wait(1.4)
	await shot("03_echo_well_clear")
	await drain()
	await wait(3.0)
	await shot("04_journal_toast_after_vision")
	# the forge: the pin is easier to find
	flags(["spoke_to_mara", "mara_showed_pin"])
	await goto_area("forge", "from_village")
	await put(Vector2(160, 150), "up")
	area().set("_glint_t", 0.28)
	await wait(0.05)
	await shot("05_forge_pin_cue_from_room")
	await put(Vector2(250, 96), "up")
	area().set("_glint_t", 0.28)
	await wait(0.2)
	await shot("06_forge_pin_selected")
	listen_here()
	await wait(1.6)
	await shot("07_echo_pin_clear")
	await drain()
	await talk("mara_marks", 0)
	# the chapel: named, highlighted seals and non-modal feedback
	await goto_area("chapel", "from_village")
	var moon := area().get_node("Interactions/SealMoonUse") as Interactable
	await put(Vector2(moon.global_position.x, 166), "left")
	await wait(0.4)
	check(player().focus == moon, "facing left under Moon selects Moon (QA-04)")
	await shot("08_seal_moon_selected_facing_left")
	for s in ["Flame", "Moon", "Crown"]:
		var it := area().get_node("Interactions/Seal%sUse" % s) as Interactable
		await put(Vector2(it.global_position.x, 166), "up")
		await press("interact")
		await wait(0.3)
	await wait(0.9)
	await shot("09_seal_wrong_caption")
	check(not DialogueManager.is_active(), "a wrong order does not open a dialogue box")
	await put(Vector2(232, 168), "up")
	listen_here()
	await wait(1.5)
	await shot("10_echo_inscription_clear")
	await drain()
	await wait(2.5)
	for s in ["Moon", "Flame", "Crown"]:
		var it := area().get_node("Interactions/Seal%sUse" % s) as Interactable
		await put(Vector2(it.global_position.x, 166), "up")
		await press("interact")
		await wait(0.4)
	await wait(1.0)
	await drain()
	await put(Vector2(272, 112), "up")
	await talk("chapel_ledger", 0)
	# night falls; the song; the journal with a long history
	await goto_area("village", "from_chapel")
	await wait(3.5)
	await shot("11_village_night_title")
	await put(Vector2(404, 340), "up")
	await talk("pip_song", 0)
	flags(["promised_mara", "echo_cradle", "mara_lullaby_told", "echo_chorus", "echo_ledger"])
	await wait(0.5)
	UI.open_journal()
	await wait(0.5)
	await shot("12_journal_late_top")
	for i in 30:
		await press("move_down")
	await wait(0.2)
	await shot("13_journal_done_list_scrolled")
	await press("move_right")
	for i in 40:
		await press("move_down")
	await wait(0.2)
	await shot("14_journal_discoveries_scrolled")
	UI.journal.call("close")
	await put(Vector2(384, 196), "up")
	await talk("village_gate", 0)
	# the mistbound path: Rowan's light and readable hazards
	await goto_area("mist_path", "from_village")
	await put(Vector2(192, 560), "up")
	await wait(0.6)
	await shot("15_mist_path_rowan_lit")
	flags(["met_sentinel"])  # skip the greeting so the trial itself is on screen
	await put(Vector2(192, 490), "up")
	await wait(0.6)
	var path_area := area()
	await path_area.call("_start_challenge")
	await wait(0.4)
	var pulse := path_area.get_node("Encounter/MistPulse2") as MistPulse
	var t := 0.0
	while pulse.state() != "warn" and t < 8.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await wait(0.5)
	await shot("16_mist_pulse_warning")
	while pulse.state() != "burst" and t < 16.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await wait(0.15)
	await shot("17_mist_pulse_burst")
	UI.open_pause()
	await wait(0.4)
	await shot("18_pause_save_paused_during_trial")
	UI.pause_menu.call("close")
	path_area.call("_challenge_cancel")
	await wait(0.5)
	await talk("sentinel_story", 2)
	await wait(2.5)
	# the tower
	await goto_area("bell_tower", "from_path")
	await put(Vector2(224, 196), "up")
	await wait(0.4)
	await shot("19_tower_mechanism_selected")
	var tower := area()
	await tower.call("_install_pin")
	await tower.call("_orin_appear")
	await wait(0.5)
	await shot("20_orin")


func _endings() -> void:
	var shots := {"keeper": "21", "promise": "22", "chorus": "23"}
	for kind in ["keeper", "promise", "chorus"]:
		while SceneManager.transitioning:
			await wait(0.1)
		GameState.reset()
		flags(["learned_village_song", "rowan_kind_to_pip", "asked_orin_lullaby", "told_mara_truth", "echo_well",
			"sentinel_resolved_peacefully"])
		GameState.set_flag("ending_selected", kind)
		SceneManager.goto_scene("res://scenes/main/ending.tscn")
		await wait(1.0)
		var ending := get_tree().current_scene
		var t := 0.0
		var card_shot := false
		while is_instance_valid(ending) and str(ending.get("phase")) != "summary" and t < 90.0:
			if not card_shot and str(ending.get("phase")) == "title" and (ending.get_node("%TitleCard") as Label).modulate.a > 0.95:
				card_shot = true
				await shot("%s_%s_title_card" % [shots[kind], kind])
			await wait(0.1)
			t += 0.1
		check(card_shot, "%s: the title card appeared (QA-01)" % kind)
		check(is_instance_valid(ending) and str(ending.get("phase")) == "summary", "%s: the epilogue appeared" % kind)
		await wait(1.3)
		await shot("%s_%s_epilogue_top" % [shots[kind], kind])
		if ending.call("summary_overflows"):
			for i in 30:
				await press("move_down")
			await wait(0.2)
			check(ending.call("summary_at_end"), "%s: the last epilogue line can be reached (QA-03)" % kind)
			await shot("%s_%s_epilogue_end" % [shots[kind], kind])
		(ending.get_node("%ToTitle") as Button).grab_focus()
		await press("ui_accept")
		t = 0.0
		while (get_tree().current_scene == null or get_tree().current_scene.name != "MainMenu" or SceneManager.transitioning) and t < 10.0:
			await wait(0.1)
			t += 0.1
		check(get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu",
			"%s: Return to Title reached the main menu" % kind)
	await wait(1.5)
	await shot("24_back_at_title")
