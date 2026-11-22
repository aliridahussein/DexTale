extends Node
## End-to-end playthrough on the real scenes, headless, at 6x speed.
## Drives interactions, exits, echoes, the puzzle, the Sentinel and the tower
## the way a player would (through the same Interactable / EchoPoint / AreaExit
## code), and checks story flags and objectives at every step.

const SPEED := 6.0

var runner: Node
var _real_save := ""


func setup() -> void:
	Engine.time_scale = SPEED
	_real_save = SaveManager.save_path
	SaveManager.save_path = "user://test_playthrough_save.json"
	SaveManager.delete_save()
	DialogueManager.stop()
	GameState.reset()
	DialogueManager.missing_events.clear()


func teardown() -> void:
	DialogueManager.stop()
	SaveManager.delete_save()
	SaveManager.save_path = _real_save
	Engine.time_scale = 1.0
	GameState.reset()


# ---------------------------------------------------------------- helpers --
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func area() -> GameArea:
	return SceneManager.current_area as GameArea


func player() -> Player:
	return area().get_player()


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


func objective() -> String:
	return str(QuestManager.get_primary().get("id", ""))


func has(flag: String) -> bool:
	return GameState.has_flag(flag)


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
	for s in ["flame", "moon", "crown"]:
		(chapel.get_node("Interactions/Seal%sUse" % s.capitalize()) as Interactable).interact(player())
		await wait(0.1)
	await play([0])
	runner.check(int(GameState.get_flag("seal_attempts")) == 1 and not has("solved_chapel_puzzle"), "wrong order resets")
	for s in ["moon", "flame", "crown"]:
		(chapel.get_node("Interactions/Seal%sUse" % s.capitalize()) as Interactable).interact(player())
		await wait(0.1)
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
	# --- the tower
	await step_on("Triggers/ToTower")
	await wait_area("bell_tower")
	await use("Interactions/MechanismUse", [0, 0, 0, 0, 0, 2])
	runner.check(has("pin_installed") and has("orin_appeared") and has("met_orin_echo"), "Orin's echo appeared")
	runner.check(has("asked_orin_lullaby") and has("asked_orin_voice") and has("asked_orin_why"), "asked Orin everything")
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
