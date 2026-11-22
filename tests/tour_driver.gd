extends Node
## Visual playtest: drives the real game (windowed) through every area and
## key story beat and saves screenshots to docs/screenshots/.
## Run:  godot --path . res://tests/tour.tscn
## Lives under the root (not as the current scene) so scene changes don't free it.

const OUT := "res://docs/screenshots/"

var _errors: Array[String] = []


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
	await _tour()
	print("\n=== tour finished: %d engine/script errors ===" % _errors.size())
	for e in _errors.slice(0, 40):
		print("  ! " + e)
	get_tree().quit(0 if _errors.is_empty() else 1)


# ---------------------------------------------------------------- helpers --
func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path(OUT + file_name + ".png"))
	print("  shot: %s (%dx%d)" % [file_name, img.get_width(), img.get_height()])


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func goto_area(area_id: String, spawn: String = "default") -> GameArea:
	DialogueManager.stop()
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


## Plays a conversation to the end, always picking choice `pick` (clamped).
func talk(conv: String, pick: int = 0, shot_name: String = "", shot_at_line: int = 2) -> void:
	await drain()
	if not DialogueManager.start(conv):
		print("  ! could not start ", conv)
		return
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


# ------------------------------------------------------------------- tour --
func _tour() -> void:
	print("=== visual tour ===")
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	if only != "endings":
		await _story()
	if only != "story":
		await _endings()


func _story() -> void:
	while SceneManager.transitioning:
		await wait(0.1)
	await wait(2.6)
	await shot("01_title")
	# new game -> prologue
	GameState.reset()
	SceneManager.goto_scene("res://scenes/main/prologue.tscn")
	await wait(7.0)
	await shot("02_prologue_tolls")
	# the arrival cutscene
	GameState.reset()
	GameState.set_flag("game_started", true)
	SceneManager.change_area("village", "start")
	await SceneManager.area_ready
	await wait(3.6)
	await shot("03_intro_tower_pan")
	while not DialogueManager.is_active():
		await get_tree().process_frame
	await wait(1.8)
	await shot("04_dialogue_pip")
	while DialogueManager.is_active():
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		elif DialogueManager.is_waiting_for_choice():
			await wait(0.4)
			await shot("05_dialogue_choice")
			DialogueManager.choose(0)
		await wait(0.05)
	await wait(2.0)
	await shot("06_objective_toast")
	await put(Vector2(384, 392), "up")
	await wait(1.0)
	await shot("07_village_sunset")
	# Echo at the well
	await put(Vector2(386, 360), "up")
	await wait(0.5)
	await shot("08_echo_prompt")
	player().get_node("Echo").call("activate")
	await wait(1.3)
	await shot("09_echo_well")
	while DialogueManager.is_active():
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.05)
	UI.open_journal()
	await wait(0.4)
	await shot("10_journal")
	UI.journal.call("close")
	# the forge
	flags(["spoke_to_mara", "mara_showed_pin"])
	await goto_area("forge", "from_village")
	await put(Vector2(236, 92), "up")
	await wait(0.8)
	await shot("11_forge")
	player().get_node("Echo").call("activate")
	await wait(1.4)
	await shot("12_echo_pin")
	while DialogueManager.is_active():
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.05)
	await talk("mara_marks", 0)
	# the chapel and the seals
	await goto_area("chapel", "from_village")
	await wait(0.5)
	await shot("13_chapel")
	await put(Vector2(300, 168), "up")
	var chapel := area()
	chapel.call("_on_seal_pressed", player(), "flame")
	await wait(0.4)
	chapel.call("_on_seal_pressed", player(), "moon")
	await wait(0.6)
	await shot("14_seals_lit")
	chapel.call("_on_seal_pressed", player(), "crown")
	await wait(2.2)
	await talk("chapel_seal_wrong")
	await put(Vector2(232, 168), "up")
	player().get_node("Echo").call("activate")
	await wait(1.5)
	await shot("15_echo_inscription")
	while DialogueManager.is_active():
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.05)
	for s in ["moon", "flame", "crown"]:
		chapel.call("_on_seal_pressed", player(), s)
		await wait(0.5)
	await wait(1.6)
	await talk("chapel_seal_solved")
	await wait(0.8)
	await put(Vector2(272, 112), "up")
	await wait(0.6)
	await shot("16_archive")
	UI.open_document("ledger")
	await wait(0.6)
	await shot("17_ledger")
	UI.document_view.call("_close")
	await talk("chapel_ledger", 0)
	# night falls on the village
	await goto_area("village", "from_chapel")
	await wait(3.5)
	await shot("18_village_night")
	await put(Vector2(404, 340), "up")
	await talk("pip_song", 0, "19_pip_song", 3)
	await put(Vector2(384, 196), "up")
	await talk("village_gate", 0)
	await wait(1.0)
	await shot("20_gate_open")
	# the mistbound path
	await goto_area("mist_path", "from_village")
	await wait(0.5)
	await shot("21_mist_path")
	await put(Vector2(192, 476), "up")
	await wait(1.0)
	await shot("22_sentinel")
	var path_area := area()
	path_area.call("_start_challenge")
	await put(Vector2(150, 330), "up")
	await wait(2.4)
	await shot("23_mist_challenge")
	path_area.call("_challenge_cancel")
	await wait(0.5)
	await talk("sentinel_story", 2)
	await wait(2.5)
	await shot("24_sentinel_gone")
	# the tower
	await goto_area("bell_tower", "from_path")
	await wait(0.5)
	await shot("25_tower")
	var tower := area()
	await tower.call("_install_pin")
	await tower.call("_orin_appear")
	await wait(0.5)
	await shot("26_orin")
	await tower.call("_show_vista")
	await wait(0.5)
	await shot("27_vista")


func _endings() -> void:
	for kind in ["keeper", "promise", "chorus"]:
		while SceneManager.transitioning:
			await wait(0.1)
		GameState.set_flag("ending_selected", kind)
		SceneManager.goto_scene("res://scenes/main/ending.tscn")
		await wait(9.0)
		await shot("28_ending_%s" % kind)
		var ending := get_tree().current_scene
		print("  ending scene: ", ending.name if ending else "<none>")
		var t := 0.0
		while is_instance_valid(ending) and not (ending.get_node("%Summary") as Control).visible and t < 60.0:
			await wait(0.5)
			t += 0.5
		await wait(1.2)
		await shot("29_summary_%s" % kind)
