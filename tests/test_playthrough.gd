extends "res://tests/driver.gd"
## End-to-end playthrough on the real scenes, headless, at 6x speed.
## Drives interactions, exits, echoes, the puzzle, the Sentinel and the tower
## the way a player would (through the same Interactable / EchoPoint / AreaExit
## code), and checks story flags and objectives at every step.


func setup() -> void:
	begin("user://test_playthrough_save.json")


func teardown() -> void:
	finish()


## Stand under a seal (facing away from it, the case QA-04 reported) and
## press E through the real input path. The named prompt must match.
func press_seal(chapel: GameArea, symbol: String) -> void:
	await until_idle()
	var it := chapel.get_node("Interactions/Seal%sUse" % symbol.capitalize()) as Interactable
	player().teleport(Vector2(it.global_position.x, 166))
	player().face("left" if symbol != "flame" else "right")
	await frames(3)
	runner.check(player().focus == it, "standing under %s selects %s (got %s)" % [symbol, symbol,
		player().focus.name if player().focus else "nothing"])
	await press("interact")
	await wait(0.15)


# ------------------------------------------------------------------ tests --
func test_full_story_to_the_chorus_ending() -> void:
	GameState.set_flag("game_started", true)
	await goto("village", "start")
	# the arrival cutscene runs by itself and hands over to Pip
	await play([0])
	runner.check(has("met_pip") and has("rowan_kind_to_pip"), "met Pip (kindly)")
	runner.check(objective() == "find_silence", "objective 1 active")
	await listen("Interactions/WellEcho")
	runner.check(has("echo_well") and GameState.discovery_log.has("well_names"), "the well's echo is in the journal")
	await talk("Tobin")
	runner.check(has("tobin_elsie"), "asked Tobin about Elsie")
	for i in 3:
		await talk("Cat")
	runner.check(int(GameState.get_flag("cat_pets")) == 3, "the cat was petted three times")
	# --- forge (walk in through the door trigger)
	await step_on("Triggers/ToForge")
	await wait_area("forge")
	await talk("Mara", [0])
	runner.check(has("spoke_to_mara") and has("mara_showed_pin"), "Mara showed the pin")
	runner.check(objective() == "mara_pin", "objective 2 active")
	await use("Interactions/PinInspect")
	await listen("Interactions/PinEcho")
	runner.check(has("discovered_bell_markings"), "Echo revealed the thirteen marks")
	await talk("Mara", [0, 0])
	runner.check(has("has_tuning_pin") and has("promised_mara") and has("mara_lullaby_told"), "received the pin and promised Mara")
	runner.check(objective() == "chapel_records", "objective 3 active")
	runner.check(not (area().get_node("Objects/TuningPin") as Node2D).visible, "pin left the workbench")
	# --- chapel
	await goto("chapel", "from_village")
	await talk("Alden", [1])
	runner.check(has("alden_mentioned_seals"), "Alden explained the seals")
	await listen("Interactions/PlaqueEcho")
	runner.check(has("inscription_clear"), "Echo made the inscription readable")
	var chapel := area()
	# press the seals the way a player does: stand in front, press E
	for s in ["flame", "moon", "crown"]:
		await press_seal(chapel, s)
	await until_idle()
	runner.check(int(GameState.get_flag("seal_attempts")) == 1 and not has("solved_chapel_puzzle"), "wrong order resets")
	runner.check(not DialogueManager.is_active() and UI.caption_text().contains("grind back"),
		"a wrong order answers with a short caption, not a dialogue box")
	for s in ["moon", "flame", "crown"]:
		await press_seal(chapel, s)
	await play([0])
	runner.check(has("solved_chapel_puzzle"), "Moon, Flame, Crown opens the archive")
	runner.check((chapel.get_node("Objects/ArchiveDoor/Shape") as CollisionShape2D).disabled, "archive door no longer blocks")
	player().teleport(Vector2(272, 112))
	await use("Interactions/LedgerRead", [1])
	runner.check(has("read_ledger") and has("read_bellkeeper_ledger") and has("has_gate_key"), "ledger read, key found")
	runner.check(has("accused_alden") and has("alden_confessed"), "Alden's scene played")
	runner.check(objective() == "reach_tower", "objective 5 active")
	runner.check(QuestManager.get_optional_active().any(func(o: Dictionary) -> bool: return o["id"] == "the_song"),
		"optional song objective offered")
	await listen("Interactions/LedgerEcho")
	runner.check(has("echo_ledger"), "heard the kneeling figure")
	# --- back to the village at night: Pip's song and the gate
	await goto("village", "from_chapel")
	runner.check(area().call("stage") == "night", "night has fallen in the village")
	await talk("Pip", [1])
	runner.check(has("learned_village_song") and has("read_song"), "learned the Gathering Song")
	await use("Interactions/GateUse")
	runner.check(has("gate_unlocked"), "north gate unlocked")
	runner.check((area().get_node("Objects/Gate/Shape") as CollisionShape2D).disabled, "gate no longer blocks")
	await step_on("Triggers/ToPath")
	await wait_area("mist_path")
	# --- the Sentinel: understand (wrong answer first, then the right one)
	await step_on("Triggers/SentinelApproach")
	await play([0])
	runner.check(has("met_sentinel") and not has("passed_sentinel"), "the Sentinel blocks the road")
	await listen("Interactions/SentinelEcho", [0, 0, 2])
	runner.check(int(GameState.get_flag("sentinel_wrong_answers")) == 1, "a wrong answer is allowed")
	runner.check(has("passed_sentinel") and has("sentinel_resolved_peacefully"), "answered the riddle")
	await wait(0.5)
	runner.check(not area().npc("Sentinel").visible, "the Sentinel is gone")
	# --- saving mid-story and loading it back
	runner.check(SaveManager.save_game(true), "can save in a calm moment")
	var saved := SaveManager.save_info()
	runner.check(saved.get("area") == "mist_path" and (saved["flags"] as Dictionary).has("passed_sentinel"), "save holds progress")
	# --- the Watchman's Crossing (V2.2): mend the bridge, then give the watchman his memory back
	await step_on("Triggers/ToCrossing")
	await wait_area("crossing")
	runner.check(objective() == "cross", "objective: cross the ravine")
	await complete_crossing(true)
	runner.check(has("crossing_complete") and has("watchman_resolved"), "crossed, and the watchman is at peace")
	runner.check(Inventory.has("tuning_pin"), "the tuning pin is still in Rowan's pocket")
	# --- the tower
	runner.check(objective() == "truth", "objective: the truth in the tower")
	await use("Interactions/MechanismUse", [0, 0, 0, 0, 0, 0, 2])
	runner.check(has("pin_installed") and has("orin_appeared") and has("met_orin_echo"), "Orin's echo appeared")
	runner.check(has("asked_orin_lullaby") and has("asked_orin_voice") and has("asked_orin_why"), "asked Orin everything")
	runner.check(has("told_orin_watchman"), "Orin heard about the watchman")
	runner.check(str(GameState.get_flag("ending_selected")) == "chorus", "the Chorus ending was available and chosen")
	var t := 0.0
	while (get_tree().current_scene == null or get_tree().current_scene.name != "Ending") and t < 20.0:
		await wait(0.1)
		t += 0.1
	runner.check(get_tree().current_scene != null and get_tree().current_scene.name == "Ending", "ending scene loaded")
	t = 0.0
	var ending := get_tree().current_scene
	while is_instance_valid(ending) and not (ending.get_node("%Summary") as Control).visible and t < 60.0:
		await wait(0.2)
		t += 0.2
	runner.check(is_instance_valid(ending) and (ending.get_node("%Summary") as Control).visible, "epilogue shown")
	var text := str((ending.get_node("%SummaryText") as RichTextLabel).text)
	runner.check(text.contains("Mara woke humming"), "epilogue remembers asking about the lullaby")
	runner.check(text.contains("Tobin stopped lighting"), "epilogue remembers the well")
	runner.check(text.contains("chosen to remember a soldier"), "epilogue remembers the peaceful Sentinel")
	runner.check(text.contains("He didn't need to be"), "epilogue remembers the watchman (Chorus variant)")
	runner.check(DialogueManager.missing_events.is_empty(), "no dialogue event lacked a handler: %s" % [DialogueManager.missing_events])


func test_endure_route_and_no_softlock() -> void:
	for f in ["game_started", "met_pip", "spoke_to_mara", "mara_showed_pin", "has_tuning_pin", "solved_chapel_puzzle",
			"read_ledger", "read_bellkeeper_ledger", "has_gate_key", "gate_unlocked"]:
		GameState.set_flag(f, true)
	await goto("mist_path", "from_village")
	var path := area()
	await step_on("Triggers/SentinelApproach")
	await play([2])  # "I won't turn back."
	runner.check(path.get("challenge_active"), "the mist challenge started")
	runner.check(not SaveManager.can_save_now(), "saving is blocked during the challenge")
	# get caught by a pulse: Rowan is pushed back, nothing else happens
	var pulse := path.get_node("Encounter/MistPulse1") as MistPulse
	player().teleport(pulse.global_position)
	var t := 0.0
	while int(path.get("hits")) == 0 and t < 10.0:
		await wait(0.05)
		t += 0.05
	runner.check(int(path.get("hits")) == 1, "a pulse caught Rowan")
	await until_idle()
	runner.check(player().global_position.distance_to(path.call("get_spawn_position", "challenge_start")) < 2.0,
		"pushed back to the start of the field")
	# walking back south cancels; the Sentinel blocks again; talking resumes the encounter
	player().teleport(Vector2(192, 470))
	await frames(3)
	await until_idle()
	runner.check(not path.get("challenge_active"), "walking back cancels the challenge")
	await talk("Sentinel", [1, 1])  # "Let me pass." -> "Not yet."
	runner.check(not has("passed_sentinel"), "still blocked, but never stuck")
	await talk("Sentinel", [2])
	runner.check(path.get("challenge_active"), "challenge can be retried")
	# three hits in one attempt switch on mercy mode
	for i in 3:
		player().teleport(pulse.global_position)
		var before := int(path.get("hits"))
		t = 0.0
		while int(path.get("hits")) == before and t < 10.0:
			await wait(0.05)
			t += 0.05
		await wait(1.2)  # knock-back
	await play([0])
	runner.check(has("sentinel_mercy") and pulse.slow, "after three hits the pulses slow down")
	# reach the far side
	player().teleport(Vector2(192, 190))
	await frames(3)
	await play([0])
	runner.check(has("passed_sentinel") and has("sentinel_endured"), "endured the mist")
	runner.check(SaveManager.can_save_now(), "saving allowed again")
	# V2.2: this route also leads on to the crossing, and over it by stealth
	await until_idle()
	await step_on("Triggers/ToCrossing")
	await wait_area("crossing")
	runner.check(objective() == "cross", "the endure route reaches the crossing")
	await complete_crossing(false)
	runner.check(has("crossing_complete") and not has("watchman_resolved"), "crossed past the Shadow unseen")
	runner.check(objective() == "truth", "objective moves on to the tower")


func test_other_endings_play() -> void:
	for kind_pick in [["keeper", 0], ["promise", 1]]:
		GameState.reset()
		for f in ["game_started", "has_tuning_pin", "read_bellkeeper_ledger", "passed_sentinel", "pin_installed",
				"orin_appeared", "met_orin_echo"]:
			GameState.set_flag(f, true)
		await goto("bell_tower", "from_path")
		await talk("Orin", [kind_pick[1]])
		runner.check(str(GameState.get_flag("ending_selected")) == kind_pick[0], "%s ending chosen" % kind_pick[0])
		runner.check(not has("learned_village_song"), "chorus was not offered without the song")
		var t := 0.0
		while (get_tree().current_scene == null or get_tree().current_scene.name != "Ending") and t < 20.0:
			await wait(0.1)
			t += 0.1
		runner.check(get_tree().current_scene != null and get_tree().current_scene.name == "Ending",
			"%s ending scene loaded" % kind_pick[0])
		await wait(2.0)
