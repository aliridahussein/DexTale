extends "res://tests/driver.gd"
## Save safety: the Sentinel save block (QA-02), crash-safe writes and
## validation (QA-08), V1 save compatibility, and the Title / Continue loop.

const PRE_SENTINEL := ["game_started", "met_pip", "spoke_to_mara", "mara_showed_pin", "has_tuning_pin",
	"solved_chapel_puzzle", "read_ledger", "read_bellkeeper_ledger", "has_gate_key", "gate_unlocked"]
const V1_FIXTURES := ["res://tests/fixtures/v1_save_tower_peaceful.json",
	"res://tests/fixtures/v1_save_tower_endured.json"]

var _saves := 0
var _failures: Array[String] = []


func setup() -> void:
	begin("user://test_save_lifecycle.json")
	_saves = 0
	_failures.clear()
	if not SaveManager.saved.is_connected(_on_saved):
		SaveManager.saved.connect(_on_saved)
		SaveManager.save_failed.connect(_on_failed)


func teardown() -> void:
	finish()


func _on_saved() -> void:
	_saves += 1


func _on_failed(message: String) -> void:
	_failures.append(message)


func write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# ------------------------------------------------------------- lifecycle --
## The audit's exact repro: start the mist trial, return to title, Continue,
## then save. Saving must work again, both manual and automatic.
func test_title_during_mist_trial_releases_saving() -> void:
	set_flags(PRE_SENTINEL)
	await goto("mist_path", "from_village")
	await until_idle()
	var t0 := 0.0
	while not SaveManager.has_save() and t0 < 3.0:  # the autosave runs on the next frame
		await wait(0.05)
		t0 += 0.05
	runner.check(SaveManager.has_save(), "autosaved on arrival")
	await step_on("Triggers/SentinelApproach")
	await play([2])  # "I won't turn back."
	var path := area()
	runner.check(path.get("challenge_active"), "the mist trial started")
	runner.check(not SaveManager.can_save_now(), "saving is paused during the trial")
	runner.check(SaveManager.why_not_saving().contains("mist trial"), "the pause menu can say why")
	# Esc -> Return to Title, through the pause menu's own handler
	UI.open_pause()
	runner.check(UI.pause_menu.get_node("%SaveBtn").disabled, "Save Game is disabled during the trial")
	runner.check(str(UI.pause_menu.get_node("%PauseStatus").text).contains("mist trial"), "the menu says why")
	UI.pause_menu.call("_on_title")
	var menu := await scene_named("MainMenu")
	runner.check(menu != null, "returned to the title")
	runner.check(not SaveManager.is_saving_blocked(), "leaving the area released the trial's save block (%s)" % [SaveManager.save_blocks()])
	# Continue, exactly like the menu button
	_saves = 0
	runner.check(SaveManager.continue_game(), "Continue loads the save")
	await wait_area("mist_path")
	runner.check(not area().get("challenge_active"), "the trial is not running after Continue")
	runner.check(SaveManager.can_save_now(), "saving is allowed after Continue: %s" % SaveManager.why_not_saving())
	var t := 0.0
	while _saves == 0 and t < 5.0:
		await wait(0.05)
		t += 0.05
	runner.check(_saves >= 1, "autosave ran after Continue")
	runner.check(SaveManager.save_game(true), "manual save works after Continue")
	# and after another transition
	_saves = 0
	await goto("village", "from_path")
	t = 0.0
	while _saves == 0 and t < 5.0:
		await wait(0.05)
		t += 0.05
	runner.check(_saves >= 1, "autosave after the next area change")
	runner.check(_failures.is_empty(), "no save failed: %s" % [_failures])


func test_retreat_and_area_change_release_saving() -> void:
	set_flags(PRE_SENTINEL)
	await goto("mist_path", "from_village")
	await step_on("Triggers/SentinelApproach")
	await play([2])
	runner.check(not SaveManager.can_save_now(), "blocked during the trial")
	# walking back south cancels the trial and frees saving
	player().teleport(Vector2(192, 470))
	await frames(3)
	await until_idle()
	runner.check(SaveManager.can_save_now(), "retreating releases saving")
	# start again, then leave the area some other way (a scene change)
	await talk("Sentinel", [2])
	runner.check(not SaveManager.can_save_now(), "blocked again on retry")
	await goto("village", "from_path")
	runner.check(not SaveManager.is_saving_blocked(), "changing area releases saving")
	runner.check(SaveManager.can_save_now(), "can save in the village")


func test_new_game_and_load_clear_blocks() -> void:
	SaveManager.block_saving("stale_from_last_session")
	GameState.reset()
	runner.check(not SaveManager.is_saving_blocked(), "New Game clears stale save blocks")
	SaveManager.block_saving("stale_again")
	GameState.from_dict({"flags": {}, "area": "village", "spawn": "default"})
	runner.check(not SaveManager.is_saving_blocked(), "loading a save clears stale save blocks")


# ------------------------------------------------------------ file safety --
func test_writes_keep_a_backup() -> void:
	GameState.current_area = "village"
	GameState.set_flag("first", true)
	runner.check(SaveManager.write_save(SaveManager.build_save_data(Vector2(10, 20))), "first save written")
	runner.check(not FileAccess.file_exists(SaveManager.save_path + ".tmp"), "no temp file left behind")
	GameState.set_flag("second", true)
	runner.check(SaveManager.write_save(SaveManager.build_save_data(Vector2(30, 40))), "second save written")
	var bak := JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path + ".bak")) as Dictionary
	runner.check(bak != null and (bak["flags"] as Dictionary).has("first") and not (bak["flags"] as Dictionary).has("second"),
		"the backup holds the previous save")
	# damage the main file: the backup is used instead of losing everything
	write_raw(SaveManager.save_path, "{ \"area\": \"vill")
	runner.check(SaveManager.has_save(), "a damaged save falls back to the backup")
	runner.check(SaveManager.last_read_source == "backup", "and says so (%s)" % SaveManager.last_read_source)
	var data := SaveManager.load_game()
	runner.check(GameState.has_flag("first") and not GameState.has_flag("second"), "backup progress restored")
	runner.check(data.get("position") == [10.0, 20.0], "backup position restored")
	# the next save replaces the damaged file but never the good backup
	GameState.set_flag("third", true)
	runner.check(SaveManager.write_save(SaveManager.build_save_data()), "saving over a damaged file works")
	runner.check(SaveManager.last_read_source == "main" or SaveManager.save_info().get("flags", {}).has("third"),
		"main save is good again")
	bak = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.save_path + ".bak")) as Dictionary
	runner.check(bak != null and (bak["flags"] as Dictionary).has("first"), "the good backup was kept")


func test_interrupted_write_recovers_from_temp() -> void:
	GameState.current_area = "chapel"
	GameState.set_flag("in_temp", true)
	var text := JSON.stringify(SaveManager.build_save_data(), "\t")
	SaveManager.delete_save()
	write_raw(SaveManager.save_path + ".tmp", text)  # as if the game died before the final rename
	runner.check(SaveManager.has_save(), "a finished temp file is recovered")
	runner.check(SaveManager.last_read_source == "temp", "from the temp copy")
	write_raw(SaveManager.save_path + ".tmp", text.substr(0, text.length() / 2))  # died mid-write
	runner.check(not SaveManager.has_save(), "a half-written temp file is ignored")


func test_invalid_data_is_refused() -> void:
	var good := {"version": 1, "area": "village", "spawn": "default", "flags": {"a": true}, "discoveries": ["letter"],
		"play_time": 3.0, "position": [1.0, 2.0]}
	runner.check(SaveManager.validate(good) == "", "a normal save validates")
	var cases := {
		"flags is a list": {"flags": ["a"]},
		"unknown area": {"area": "moon"},
		"bad position": {"position": [1.0]},
		"position not finite": {"position": [NAN, 2.0]},
		"journal holds numbers": {"discoveries": [1, 2]},
		"nested flag value": {"flags": {"a": {"b": 1}}},
		"wrong version": {"version": 2},
		"version is text": {"version": "1"},
	}
	for name in cases:
		var bad := good.duplicate(true)
		bad.merge(cases[name], true)
		runner.check(SaveManager.validate(bad) != "", "%s is rejected" % name)
		runner.check(not SaveManager.write_save(bad), "%s is never written" % name)
	runner.check(SaveManager.last_error != "", "a refused write reports why")
	runner.check(_failures.size() == cases.size(), "every refused write emitted save_failed")
	write_raw(SaveManager.save_path, JSON.stringify({"version": 999, "flags": {}, "area": "village"}))
	runner.check(not SaveManager.has_save(), "a save from an unknown version is ignored")
	runner.check(SaveManager.has_unreadable_save(), "and the menu can say the save could not be read")


func test_v1_saves_still_load() -> void:
	for fixture in V1_FIXTURES:
		GameState.reset()
		SaveManager.delete_save()
		var raw := FileAccess.get_file_as_string(fixture)
		var original := JSON.parse_string(raw) as Dictionary
		write_raw(SaveManager.save_path, raw)
		runner.check(SaveManager.has_save(), "%s is accepted" % fixture.get_file())
		runner.check(SaveManager.continue_game(), "%s continues" % fixture.get_file())
		await wait_area("bell_tower")
		runner.check(GameState.has_flag("passed_sentinel") and GameState.has_flag("has_tuning_pin"),
			"%s: story flags restored" % fixture.get_file())
		var saved_pos := Vector2(float(original["position"][0]), float(original["position"][1]))
		runner.check(player().global_position.distance_to(saved_pos) < 3.0,
			"%s: Rowan stands where the V1 save left him" % fixture.get_file())
		runner.check(QuestManager.get_primary().get("id") == "truth", "%s: objective resumes at the tower" % fixture.get_file())
		runner.check(SaveManager.save_game(true), "%s: can be saved again in V2" % fixture.get_file())
		var resaved := SaveManager.save_info()
		runner.check(int(resaved["version"]) == 1 and resaved["area"] == "bell_tower", "%s: re-saved in the same format" % fixture.get_file())
