extends "res://tests/driver.gd"
## V2 gameplay: the Echo Reconstruction at the well ("The Forgotten Promise")
## and the bell ritual before The Chorus. Driven through the real scenes and
## the same input actions a player uses.

const TOWER_FLAGS := ["game_started", "has_tuning_pin", "read_bellkeeper_ledger", "passed_sentinel", "pin_installed",
	"orin_appeared", "met_orin_echo"]


func setup() -> void:
	begin("user://test_v2_save.json")


func teardown() -> void:
	finish()


func board() -> Control:
	return UI.reconstruction_view


func ritual() -> Control:
	return UI.ritual_view


## Advance any dialogue lines until `c` shows (the board and the ritual open
## from an event after a line or two).
func until_visible(c: Control, timeout: float = 15.0) -> bool:
	var t := 0.0
	while not c.visible and t < timeout:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.03)
		t += 0.03
	return c.visible


## Gather the three clues the way a player would, in the village.
func gather_clues(talk_to_tobin: bool) -> void:
	await listen("Interactions/WellEcho")
	runner.check(not area().get_node("Interactions/WellReconstruct").call("is_available"),
		"the board is not offered with one clue")
	runner.check(QuestManager.get_optional_active().any(func(o: Dictionary) -> bool: return o["id"] == "the_promise"),
		"the optional mystery appears in the journal")
	await use("Interactions/WellLampLook")
	await listen("Interactions/WellLampEcho")
	runner.check(has("echo_well_lamp"), "the lamp's echo was heard")
	await use("Interactions/BenchInspect")
	runner.check(has("seen_well_bench"), "the bench was inspected")
	if talk_to_tobin:
		await talk("Tobin")
	runner.check(QuestManager.get_optional_active().any(func(o: Dictionary) -> bool: return o["id"] == "the_promise_solve"),
		"the journal asks Rowan to piece it together")


# -------------------------------------------------------- reconstruction --
func test_reconstruction_with_wrong_answers_then_right() -> void:
	set_flags(["game_started", "met_pip"])
	await goto("village", "default")
	await gather_clues(true)
	var it := area().get_node("Interactions/WellReconstruct") as Interactable
	runner.check(it.is_available() and it.important, "the board is offered at the well once all clues are found")
	player().teleport(it.global_position + Vector2(0, 16))
	player().face("up")
	await frames(3)
	runner.check(player().focus == it, "standing at the well selects 'Piece it together'")
	await press("interact")
	var shown: bool = await until_visible(board())
	runner.check(shown, "the reconstruction board opens")
	runner.check(get_tree().paused, "the world waits while the board is open")
	runner.check(board().call("can_answer"), "all required clues are present")
	var clue_text := (board().get_node("%ReconClues") as RichTextLabel).get_parsed_text().to_lower()
	runner.check(clue_text.contains("you promised you'd wait") and clue_text.contains("worn smooth") and
		clue_text.contains("twice a night"), "the board lists the gathered clues, including Tobin's habit")
	var clue_bar := (board().get_node("%ReconClues") as RichTextLabel).get_v_scroll_bar()
	runner.check(clue_bar.max_value - clue_bar.page <= 1.0, "all four clues fit on the board without scrolling")
	# a wrong answer: crossed off, explained, no penalty
	await press("interact")  # cursor starts on answer 0 (marriage)
	runner.check((board().get("ruled_out") as Dictionary).has(0), "a wrong answer is ruled out")
	var fb := (board().get_node("%ReconFeedback") as RichTextLabel).get_parsed_text()
	runner.check(fb.contains("wait"), "the feedback points at the clue that rules it out: %s" % fb)
	runner.check(not has("promise_reconstructed"), "a wrong answer does not solve it")
	runner.check(board().visible, "the board stays open to try again")
	# the cursor moved on; choose the last wrong answer through the keyboard
	await press("move_down")
	await press("move_down")
	runner.check(int(board().get("cursor")) == 3, "W/S move between the remaining answers (cursor %s)" % board().get("cursor"))
	await press("interact")
	runner.check((board().get("ruled_out") as Dictionary).has(3), "the second wrong answer is ruled out too")
	# move to the right one and decide
	while int(board().get("cursor")) != 2:
		await press("move_up")
	await press("interact")
	runner.check(has("promise_reconstructed"), "the right answer solves the mystery")
	runner.check(int(GameState.get_flag("reconstruction_misses")) == 2, "the two misses were counted")
	await play([0])  # the reconstructed memory plays
	runner.check(not board().visible and not get_tree().paused, "the board closed and the game resumed")
	runner.check(GameState.discovery_log.has("promise"), "the journal records The Forgotten Promise")
	runner.check(not QuestManager.get_optional_active().any(func(o: Dictionary) -> bool: return o["id"] == "the_promise_solve"),
		"the optional objective is complete")
	runner.check(not it.is_available(), "the board is not offered again")
	# consequence: Tobin's conversation changes, and telling him gives his lantern
	await talk("Tobin", [0])
	runner.check(has("told_tobin_promise") and has("has_tobin_lantern"), "telling Tobin earns his lantern")
	await talk("Tobin")
	runner.check(not DialogueManager.is_active(), "Tobin has a new line afterwards")
	# save/load keeps all of it
	runner.check(SaveManager.save_game(true), "saved after the reconstruction")
	GameState.reset()
	SaveManager.load_game()
	runner.check(has("promise_reconstructed") and has("has_tobin_lantern") and GameState.discovery_log.has("promise"),
		"save and load preserve the new state")
	# the lantern is a gameplay consequence on the Mistbound Path
	set_flags(["read_bellkeeper_ledger", "has_gate_key", "gate_unlocked"])
	await goto("mist_path", "from_village")
	runner.check(player().carried_light() > 1.0, "Tobin's lantern lights the path more brightly")


func test_reconstruction_needs_its_clues_and_can_be_left() -> void:
	set_flags(["game_started", "met_pip", "echo_well"])
	board().call("open", "well_promise")
	await get_tree().process_frame
	runner.check(board().visible and not board().call("can_answer"), "with one clue the question is locked")
	runner.check((board().get_node("%ReconFeedback") as RichTextLabel).get_parsed_text().contains("1 of 3"),
		"the board says how many clues are missing")
	runner.check(board().call("choose", 2) == "locked", "answering is not possible yet")
	await press("ui_cancel")
	runner.check(not board().visible and not get_tree().paused, "Esc steps back from the board")
	runner.check(not has("promise_reconstructed"), "nothing was decided")
	# leave and come back: the board at the well still works
	set_flags(["echo_well_lamp", "seen_well_bench"])
	await goto("village", "default")
	await use("Interactions/WellReconstruct")
	runner.check(has("promise_reconstructed"), "coming back later still solves it")


func test_keeping_tobins_secret_changes_the_epilogue() -> void:
	set_flags(["game_started", "met_pip", "echo_well", "echo_well_lamp", "seen_well_bench", "promise_reconstructed"])
	await goto("village", "default")
	await talk("Tobin", [1])
	runner.check(has("kept_tobin_secret") and not has("has_tobin_lantern"), "Rowan let Tobin keep his habit")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/endings.json"))
	var ending_script: GDScript = load("res://scripts/ui/ending.gd")
	var keeper: Array = ending_script.call("epilogue_lines", "keeper", data)
	runner.check(keeper.any(func(l: String) -> bool: return l.contains("Some promises keep themselves")),
		"the keeper epilogue remembers the kept secret")
	GameState.set_flag("kept_tobin_secret", false)
	GameState.set_flag("told_tobin_promise", true)
	GameState.set_flag("has_tobin_lantern", true)
	var promise: Array = ending_script.call("epilogue_lines", "promise", data)
	runner.check(promise.any(func(l: String) -> bool: return l.contains("lantern came back down the tower road")),
		"the promise epilogue remembers Tobin's lantern")
	var chorus: Array = ending_script.call("epilogue_lines", "chorus", data)
	runner.check(chorus.any(func(l: String) -> bool: return l.contains("Tobin got Elsie back")), "the chorus epilogue returns Elsie")


func test_tower_echo_acknowledges_the_reconstruction() -> void:
	set_flags(["game_started", "has_tuning_pin", "read_bellkeeper_ledger", "passed_sentinel", "promise_reconstructed"])
	await goto("bell_tower", "from_path")
	var lines: Array[String] = []
	var record := func(_s: String, text: String) -> void: lines.append(text)
	DialogueManager.line_shown.connect(record)
	await listen("Interactions/BellEcho")
	DialogueManager.line_shown.disconnect(record)
	runner.check(lines.any(func(l: String) -> bool: return l.contains("Tobin and Elsie")),
		"the bell's memories name what Rowan pieced together")


# ---------------------------------------------------------------- ritual --
func test_ritual_logic() -> void:
	var r := ResonanceRitual.new()
	var sol := ResonanceRitual.solution()
	runner.check(sol.size() == 12 and sol[-1] == ResonanceRitual.Note.SING, "12 inputs, the last one sings")
	runner.check(sol[0] == ResonanceRitual.Note.UP and sol[1] == ResonanceRitual.Note.UP and sol[2] == ResonanceRitual.Note.DOWN,
		"it starts 'up, and up, and down' like the song's description")
	runner.check(r.press(ResonanceRitual.Note.DOWN) == ResonanceRitual.Result.WRONG and r.sung == 1, "a wrong first note keeps you at the start")
	runner.check(r.hinted(1), "a missed note is hinted")
	for i in 7:
		r.press(sol[i])
	runner.check(r.sung == 8, "first phrase sung")
	runner.check(r.press(ResonanceRitual.Note.SING) == ResonanceRitual.Result.WRONG and r.sung == 8,
		"a wrong note in the second phrase keeps the first phrase")
	for i in range(7, 11):
		runner.check(r.press(sol[i]) != ResonanceRitual.Result.WRONG, "note %d" % (i + 2))
	runner.check(r.press(ResonanceRitual.Note.DOWN) == ResonanceRitual.Result.WRONG and r.sung == 8,
		"the circled note must be sung, not stepped down to")
	for i in range(7, 12):
		r.press(sol[i])
	runner.check(r.done and r.sung == 13, "the whole song completes")
	runner.check(r.press(ResonanceRitual.Note.UP) == ResonanceRitual.Result.IGNORED, "nothing after the end")
	runner.check(is_equal_approx(ResonanceRitual.pitch_scale(4), 2.0), "the highest note is an octave above the lowest")


func test_ritual_in_the_tower_with_keyboard_retry_and_step_back() -> void:
	set_flags(TOWER_FLAGS + ["learned_village_song"])
	await goto("bell_tower", "from_path")
	await until_idle()
	area().npc("Orin").talk.interact(player())
	var t := 0.0
	while not DialogueManager.is_waiting_for_choice() and t < 20.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.02)
		t += 0.02
	DialogueManager.choose(2)  # Retune the bell
	t = 0.0
	while not ritual().visible and t < 15.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.02)
		t += 0.02
	runner.check(ritual().visible, "choosing The Chorus opens the ritual")
	runner.check(not has("ending_selected"), "the ending is not chosen before the ritual is done")
	await wait(1.0)
	var tower := area()
	runner.check(int(tower.call("lit_marks")) == 1, "the bell gives the first note (one mark lit)")
	# keyboard: two correct notes, then a wrong one sours and resets the phrase
	var view := ritual()
	var r: ResonanceRitual = view.get("ritual")
	# a stray Enter/E (e.g. still advancing dialogue) is not a wrong note
	await press("interact")
	await press("ui_accept")
	runner.check(r.mistakes == 0 and r.sung == 1, "E before the circled note does not sour the bell")
	for action in ["move_up", "move_up"]:
		var before := r.sung
		var g := 0.0
		while r.sung == before and g < 3.0:
			await press(action)
			await wait(0.05)
			g += 0.05
	runner.check(r.sung == 3, "W/Up sings higher notes (sung %d)" % r.sung)
	await wait(0.3)
	runner.check(int(tower.call("lit_marks")) == 3, "each sung note lights a mark on the bell")
	await press("move_up")  # the third step goes DOWN
	runner.check(r.sung == 1 and r.mistakes == 1, "a wrong note sours the bell and restarts the phrase")
	await wait(0.9)
	runner.check(int(tower.call("lit_marks")) == 1, "the bell's marks reset with the phrase")
	# Esc steps back to the final choice without choosing anything
	await press("ui_cancel")
	t = 0.0
	while not DialogueManager.is_waiting_for_choice() and t < 10.0:
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.02)
		t += 0.02
	runner.check(not ritual().visible and DialogueManager.is_waiting_for_choice(), "stepping back returns to the choice")
	runner.check(not has("ending_selected") and not has("bell_retuned"), "no ending flag was set")
	# try again and finish it
	DialogueManager.choose(2)
	var shown: bool = await until_visible(ritual())
	runner.check(shown, "the ritual can be retried")
	await perform_ritual()
	runner.check(has("bell_retuned"), "completing the song retunes the bell")
	await play([0], false)
	runner.check(str(GameState.get_flag("ending_selected")) == "chorus", "The Chorus follows the ritual")
	var ending := await scene_named("Ending", 30.0)
	runner.check(ending != null, "the Chorus ending scene plays")


func test_other_endings_never_need_the_ritual() -> void:
	set_flags(TOWER_FLAGS + ["learned_village_song"])
	await goto("bell_tower", "from_path")
	await talk("Orin", [1])
	runner.check(str(GameState.get_flag("ending_selected")) == "promise" and not ritual().visible,
		"The Unbroken Promise is still chosen directly, with no ritual")
	var ending := await scene_named("Ending", 30.0)
	runner.check(ending != null, "its ending plays")
	SceneManager.goto_scene("res://scenes/main/main_menu.tscn", 0.1)
	await scene_named("MainMenu")
