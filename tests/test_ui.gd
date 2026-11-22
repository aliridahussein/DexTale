extends "res://tests/driver.gd"
## Usability fixes from the QA audit: seal selection (QA-04), journal overflow
## (QA-05), readability cues (QA-07), stage-aware subtitle (QA-09) and Echo
## visions staying clear of UI (QA-11).

const ENDGAME_FLAGS := ["game_started", "met_pip", "spoke_to_mara", "mara_showed_pin", "has_tuning_pin",
	"solved_chapel_puzzle", "read_ledger", "read_bellkeeper_ledger", "has_gate_key", "gate_unlocked",
	"saw_song_marks", "learned_village_song", "promised_mara", "asked_orin_lullaby", "passed_sentinel",
	"met_orin_echo", "echo_well", "talked_tobin", "discovered_bell_markings", "mara_lullaby_told", "echo_cradle",
	"inscription_clear", "echo_chorus", "echo_ledger", "echo_shrine", "sentinel_story_heard",
	"echo_tower_memories", "echo_well_lamp", "seen_well_bench", "promise_reconstructed"]


func setup() -> void:
	begin("user://test_ui_save.json")


func teardown() -> void:
	finish()


func test_seal_selection_follows_where_rowan_stands() -> void:
	set_flags(["game_started", "has_tuning_pin"])
	await goto("chapel", "from_village")
	for sym in ["Flame", "Moon", "Crown"]:
		var it := area().get_node("Interactions/Seal%sUse" % sym) as Interactable
		for facing in ["up", "left", "right", "down"]:
			player().teleport(Vector2(it.global_position.x, 166))
			player().face(facing)
			await frames(3)
			runner.check(player().focus == it, "under %s facing %s selects %s (got %s)" % [sym, facing, sym,
				player().focus.name if player().focus else "nothing"])
		runner.check(str(UI.prompt_label.text).contains(sym), "the prompt names the %s seal" % sym)
		var sprite := area().get_node("Objects/Seal%s/Sprite" % sym) as CanvasItem
		await wait(0.1)
		runner.check(sprite.modulate.r > 1.1, "the selected %s seal is highlighted" % sym)
	# a few pixels off-centre still picks the nearer seal, and the choice holds steady
	var moon := area().get_node("Interactions/SealMoonUse") as Interactable
	player().teleport(Vector2(moon.global_position.x + 7, 166))
	await frames(3)
	runner.check(player().focus == moon, "slightly right of Moon is still Moon")
	runner.check((area().get_node("Objects/SealFlame/Sprite") as CanvasItem).modulate.r < 1.05,
		"seals that are not selected are not highlighted")


func test_journal_pages_scroll_independently() -> void:
	# early game: everything fits, nothing to scroll
	set_flags(["game_started", "met_pip"])
	UI.open_journal()
	await get_tree().process_frame
	var j: Control = UI.journal
	runner.check(j.visible, "journal opens")
	j.call("close")
	# end game: many objectives done and many discoveries
	set_flags(ENDGAME_FLAGS)
	UI.open_journal()
	await get_tree().process_frame
	await get_tree().process_frame
	var left := j.get_node("%Left") as RichTextLabel
	var right := j.get_node("%Right") as RichTextLabel
	runner.check(left.get_parsed_text().contains("DONE"), "completed objectives are listed")
	var left_bar := left.get_v_scroll_bar()
	runner.check(left_bar.max_value > left_bar.page, "the objectives page is longer than the book (the old clipping case)")
	# W/S scroll the active (left) page only
	for i in 40:
		await press("move_down")
	runner.check(j.call("page_at_end", 0), "S scrolls to the last completed objective")
	runner.check(right.get_v_scroll_bar().value < 1.0, "the other page did not move")
	# D switches to discoveries, which scroll on their own
	await press("move_right")
	runner.check(int(j.get("active_page")) == 1, "D switches to the discoveries page")
	for i in 60:
		await press("move_down")
	runner.check(j.call("page_at_end", 1), "S scrolls discoveries to the end")
	await press("move_left")
	await press("move_up")
	runner.check(left_bar.value < left_bar.max_value - left_bar.page, "A then W scrolls objectives back up")
	await press("journal")
	runner.check(not j.visible and not get_tree().paused, "J closes the journal and unpauses")


func test_echo_vision_holds_prompts_and_toasts() -> void:
	set_flags(["game_started", "met_pip"])
	await goto("village", "default")
	var well := area().get_node("Interactions/WellEcho") as EchoPoint
	player().teleport(well.global_position + Vector2(0, 14))
	await frames(2)
	var t0 := 0.0
	while UI.toast_box.visible and t0 < 10.0:  # let earlier toasts finish first
		await wait(0.05)
		t0 += 0.05
	player().get_node("Echo").call("activate")
	var t := 0.0
	while not UI.is_revealing() and t < 3.0:
		await wait(0.02)
		t += 0.02
	runner.check(UI.is_revealing(), "the vision holds the UI")
	var covered := ""
	var prompt_shown := ""
	while UI.is_revealing() and t < 15.0:
		if UI.toast_box.visible and UI.toast_box.modulate.a > 0.05:
			covered = str(UI.toast_label.text)
		if UI.prompt.visible or UI.echo_prompt.visible:
			prompt_shown = str(UI.prompt_label.text) if UI.prompt.visible else "Listen"
		if DialogueManager.is_waiting_for_advance():
			DialogueManager.advance()
		await wait(0.02)
		t += 0.02
	runner.check(covered == "", "no toast covers the vision (saw '%s')" % covered)
	runner.check(prompt_shown == "", "prompts stay hidden during the vision (saw '%s')" % prompt_shown)
	runner.check(not UI.is_revealing(), "the hold ends when the vision fades")
	t = 0.0
	while not UI.toast_box.visible and t < 3.0:
		await wait(0.02)
		t += 0.02
	runner.check(UI.toast_box.visible, "the journal toast appears after the vision")
	runner.check(has("used_echo"), "listening switches off the 'press F' tutorial hints")


## Found by the V2 visual tour: leaving an area while a vision was still
## fading left prompts hidden in the next area.
func test_leaving_mid_vision_releases_the_ui() -> void:
	set_flags(["game_started", "met_pip"])
	await goto("village", "default")
	var well := area().get_node("Interactions/WellEcho") as EchoPoint
	player().teleport(well.global_position + Vector2(0, 14))
	await frames(2)
	player().get_node("Echo").call("activate")
	var t := 0.0
	while not UI.is_revealing() and t < 3.0:
		await wait(0.02)
		t += 0.02
	DialogueManager.stop()
	SceneManager.change_area("forge", "from_village")
	await SceneManager.area_ready
	while SceneManager.transitioning:
		await frames(1)
	runner.check(not UI.is_revealing(), "the vision's hold ended with its area")
	set_flags(["spoke_to_mara", "mara_showed_pin"])
	player().teleport(Vector2(250, 96))
	await frames(4)
	await wait(0.2)
	runner.check(UI.prompt.visible, "prompts work in the next area")


func test_village_subtitle_follows_the_light() -> void:
	set_flags(["game_started", "met_pip"])
	await goto("village", "default")
	runner.check(str(area().call("area_subtitle")).contains("sundown"), "sundown before the pin")
	set_flags(["has_tuning_pin"])
	runner.check(str(area().call("area_subtitle")).contains("dusk"), "dusk after the pin")
	set_flags(["read_bellkeeper_ledger"])
	runner.check(not str(area().call("area_subtitle")).contains("sundown"), "never 'sundown' after nightfall")
	await goto("chapel", "from_village")
	await goto("village", "from_chapel")
	runner.check(str(UI.area_sub_label.text).contains("after dark"), "the title shown on return says it is night")


func test_readability_cues() -> void:
	set_flags(["game_started", "met_pip", "spoke_to_mara", "mara_showed_pin"])
	await goto("forge", "from_village")
	var glint := area().get_node("Effects/PinGlint") as CanvasItem
	var lamp := area().get_node("Lights/BenchLight") as PointLight2D
	runner.check(glint.visible and lamp.enabled, "the pin catches the light while it is the thing to find")
	set_flags(["has_tuning_pin"])
	await frames(2)
	runner.check(not glint.visible and not lamp.enabled, "the cue goes away once the pin is taken")
	await goto("mist_path", "from_village")
	runner.check(player().carried_light() > 0.3, "Rowan carries a soft light on the Mistbound Path")
	await goto("village", "from_path")
	runner.check(player().carried_light() == 0.0, "no carried light in the village")


func test_mist_pulse_warning_is_distinct() -> void:
	var p := MistPulse.new()
	p.period = 2.0
	p.telegraph = 0.8
	p.burst = 0.4
	add_child(p)
	p.set_active(true)
	var edge := p.get_child(1) as CanvasItem  # first dashed edge
	runner.check(p.state() == "rest" and edge.modulate.a > 0.1 and edge.modulate.a < 0.4, "resting lanes show faint edges")
	var seen := {}
	var t := 0.0
	while t < 2.2:
		await get_tree().process_frame
		t += get_process_delta_time()
		var s := p.state()
		if not seen.has(s):
			seen[s] = edge.modulate.a
	runner.check(seen.has("warn") and seen.has("burst"), "the lane warns and bursts (%s)" % [seen])
	runner.check(float(seen.get("burst", 0.0)) > 0.9, "edges are solid during the burst")
	p.queue_free()
