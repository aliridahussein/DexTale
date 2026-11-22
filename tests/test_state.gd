extends Node
## GameState conditions, input locks, quest derivation and save round-trips.

var runner: Node


func setup() -> void:
	GameState.reset()


func test_conditions() -> void:
	GameState.set_flag("a", true)
	GameState.set_flag("n", 2)
	GameState.set_flag("word", "chorus")
	runner.check(GameState.check(""), "empty condition is true")
	runner.check(GameState.check("a"), "flag a")
	runner.check(not GameState.check("!a"), "!a")
	runner.check(GameState.check("!missing"), "!missing")
	runner.check(GameState.check("n>=2") and not GameState.check("n>2"), "numeric comparison")
	runner.check(GameState.check("word==chorus") and GameState.check("word!=keeper"), "string comparison")
	runner.check(GameState.check(["a", "n>=1", "!missing"]), "list = AND")
	runner.check(not GameState.check(["a", "missing"]), "list fails when one fails")
	runner.check(GameState.inc_flag("n") == 3, "inc_flag")


func test_input_locks_nest() -> void:
	GameState.lock_input("x")
	GameState.lock_input("y")
	GameState.unlock_input("x")
	runner.check(GameState.is_input_locked(), "still locked by y")
	GameState.unlock_input("y")
	runner.check(not GameState.is_input_locked(), "unlocked")


func test_objectives_follow_flags() -> void:
	runner.check(QuestManager.get_primary().is_empty(), "no objective before meeting Pip")
	GameState.set_flag("met_pip", true)
	runner.check(QuestManager.get_primary().get("id") == "find_silence", "objective 1")
	GameState.set_flag("spoke_to_mara", true)
	runner.check(QuestManager.get_primary().get("id") == "mara_pin", "objective 2")
	GameState.set_flag("has_tuning_pin", true)
	runner.check(QuestManager.get_primary().get("id") == "chapel_records", "objective 3")
	GameState.set_flag("solved_chapel_puzzle", true)
	GameState.set_flag("read_bellkeeper_ledger", true)
	GameState.set_flag("saw_song_marks", true)
	runner.check(QuestManager.get_primary().get("id") == "reach_tower", "objective 5")
	runner.check(QuestManager.get_optional_active().size() == 1, "optional song objective appears")
	GameState.set_flag("passed_sentinel", true)
	GameState.set_flag("met_orin_echo", true)
	runner.check(QuestManager.get_primary().get("id") == "decide", "final objective")
	runner.check(QuestManager.get_completed().size() >= 5, "completed list grows")


func test_discoveries_logged_in_order() -> void:
	GameState.set_flag("met_pip", true)
	GameState.set_flag("echo_well", true)
	var ids: Array = QuestManager.get_discoveries().map(func(d: Dictionary) -> String: return d["id"])
	runner.check(ids == ["forgetting", "well_names"], "discovery order %s" % [ids])
	GameState.set_flag("echo_well", true)
	runner.check(QuestManager.get_discoveries().size() == 2, "no duplicate discoveries")


func test_save_round_trip() -> void:
	var real_path: String = SaveManager.save_path
	SaveManager.save_path = "user://test_savegame.json"
	GameState.set_flag("has_tuning_pin", true)
	GameState.set_flag("seal_attempts", 2)
	GameState.set_flag("ending_hint", "chorus")
	GameState.current_area = "chapel"
	GameState.current_spawn = "from_village"
	GameState.discovery_log.append("letter")
	runner.check(SaveManager.write_save(SaveManager.build_save_data(Vector2(100, 120))), "save written")
	GameState.reset()
	var data := SaveManager.load_game()
	runner.check(not data.is_empty(), "save loads")
	runner.check(GameState.current_area == "chapel", "area restored")
	runner.check(GameState.has_flag("has_tuning_pin"), "flag restored")
	runner.check(int(GameState.get_flag("seal_attempts")) == 2, "number flag restored")
	runner.check(GameState.discovery_log == ["letter"], "journal restored")
	runner.check(data.get("position") == [100.0, 120.0], "position stored")
	# corrupt and old saves are rejected rather than crashing
	runner.allow_errors(1)  # the JSON parser reports the corrupt file
	var f := FileAccess.open(SaveManager.save_path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	runner.check(not SaveManager.has_save(), "corrupt save ignored")
	SaveManager.write_save({"version": 999, "flags": {}, "area": "village"})
	runner.check(not SaveManager.has_save(), "wrong version ignored")
	SaveManager.delete_save()
	runner.check(not SaveManager.has_save(), "save deleted")
	SaveManager.save_path = real_path


func teardown() -> void:
	GameState.reset()
