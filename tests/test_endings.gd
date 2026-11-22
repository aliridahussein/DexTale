extends Node
## Every ending plays to the end on the real ending scene (QA-01, QA-03):
## sequence -> title card -> "What Dawnmere remembers" -> Return to Title.
## Driven through the same input actions a player uses, at 6x speed.

const SPEED := 6.0
const ENDING := "res://scenes/main/ending.tscn"
## Flags that select the longest epilogue variant in every group.
const RICH_FLAGS := ["learned_village_song", "rowan_kind_to_pip", "asked_orin_lullaby", "told_mara_truth",
	"echo_well", "promise_reconstructed", "told_tobin_promise", "has_tobin_lantern",
	"sentinel_resolved_peacefully", "read_bellkeeper_ledger", "has_tuning_pin", "passed_sentinel",
	"met_orin_echo", "bell_retuned"]

var runner: Node


func setup() -> void:
	Engine.time_scale = SPEED
	DialogueManager.stop()
	GameState.reset()


func teardown() -> void:
	Engine.time_scale = 1.0
	GameState.reset()


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func scene_named(scene_name: String, timeout: float = 30.0) -> Node:
	var t := 0.0
	while t < timeout:
		var s := get_tree().current_scene
		if s != null and s.name == scene_name and not SceneManager.transitioning:
			return s
		await wait(0.05)
		t += 0.05
	return null


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


## Plays one ending and checks each stage. Returns the epilogue text.
func play_ending(kind: String, flags: Array) -> String:
	GameState.reset()
	for f in flags:
		GameState.set_flag(f, true)
	GameState.set_flag("ending_selected", kind)
	while SceneManager.transitioning:
		await wait(0.05)
	SceneManager.goto_scene(ENDING, 0.2)
	var ending := await scene_named("Ending")
	if not runner.check(ending != null, "%s: ending scene loaded" % kind):
		return ""
	var data: Dictionary = ending.get("data")
	var title_card := ending.get_node("%TitleCard") as Label
	# 1. the sequence must reach the title card ...
	var t := 0.0
	var card_seen := false
	while is_instance_valid(ending) and str(ending.get("phase")) != "summary" and t < 120.0:
		if str(ending.get("phase")) == "title" and title_card.modulate.a > 0.9:
			card_seen = true
		await wait(0.05)
		t += 0.05
	runner.check(card_seen, "%s: title card was shown" % kind)
	runner.check(title_card.text == str(data["endings"][kind]["title"]), "%s: title card reads %s" % [kind, title_card.text])
	# 2. ... then the epilogue, with the return button focused ...
	runner.check(is_instance_valid(ending) and str(ending.get("phase")) == "summary",
		"%s: epilogue reached (stuck in phase '%s')" % [kind, ending.get("phase") if is_instance_valid(ending) else "?"])
	if not is_instance_valid(ending) or str(ending.get("phase")) != "summary":
		return ""
	await wait(0.3)
	var summary := ending.get_node("%Summary") as Control
	var text_label := ending.get_node("%SummaryText") as RichTextLabel
	var to_title := ending.get_node("%ToTitle") as Button
	runner.check(summary.visible, "%s: epilogue panel visible" % kind)
	runner.check(text_label.get_parsed_text().strip_edges() != "", "%s: epilogue has text" % kind)
	runner.check(to_title.is_visible_in_tree() and to_title.has_focus(), "%s: Return to Title is visible and focused" % kind)
	# 3. ... where every line can be read: scroll with the keyboard to the end
	if ending.call("summary_overflows"):
		var guard := 0
		while not ending.call("summary_at_end") and guard < 80:
			await press("move_down")
			guard += 1
		runner.check(ending.call("summary_at_end"), "%s: keyboard scrolls to the last epilogue line" % kind)
		var bar := text_label.get_v_scroll_bar()
		runner.check(bar.value > 0.0, "%s: the epilogue actually moved" % kind)
	runner.check(to_title.is_visible_in_tree() and to_title.get_global_rect().end.y <= 270.0,
		"%s: Return to Title stays on screen while reading" % kind)
	var epilogue := text_label.get_parsed_text()
	# 4. Return to Title with the confirm key goes back to the menu
	to_title.grab_focus()
	await press("ui_accept")
	var menu := await scene_named("MainMenu")
	runner.check(menu != null, "%s: Return to Title reached the main menu" % kind)
	return epilogue


func test_keeper_completes() -> void:
	var text := await play_ending("keeper", ["read_bellkeeper_ledger", "met_orin_echo"])
	runner.check(text.contains("keep an old chair"), "keeper epilogue present")


func test_promise_completes() -> void:
	var text := await play_ending("promise", ["read_bellkeeper_ledger", "met_orin_echo", "sentinel_endured"])
	runner.check(text.contains("Orin's echo went quiet"), "promise epilogue present")
	runner.check(text.contains("feel watched"), "promise epilogue remembers the endured Sentinel")


func test_chorus_completes() -> void:
	var text := await play_ending("chorus", RICH_FLAGS)
	runner.check(text.contains("girl's laughter"), "chorus epilogue present")


func test_longest_epilogues_are_readable() -> void:
	for kind in ["keeper", "promise"]:
		var text := await play_ending(kind, RICH_FLAGS)
		runner.check(text.contains("•"), "%s: long epilogue played" % kind)


func test_epilogue_scrolls_with_page_keys_and_wheel() -> void:
	GameState.reset()
	for f in RICH_FLAGS:
		GameState.set_flag(f, true)
	GameState.set_flag("ending_selected", "chorus")
	SceneManager.goto_scene(ENDING, 0.2)
	var ending := await scene_named("Ending")
	var t := 0.0
	while str(ending.get("phase")) != "summary" and t < 120.0:
		await wait(0.1)
		t += 0.1
	await wait(0.3)
	runner.check(ending.call("summary_overflows"), "the richest epilogue is taller than the panel")
	await press("ui_page_down")
	await press("ui_page_down")
	await press("ui_page_down")
	runner.check(ending.call("summary_at_end"), "Page Down reaches the end")
	runner.check((ending.get_node("%SummaryUp") as Control).visible, "an arrow shows there is more above")
	await press("ui_page_up")
	await press("ui_page_up")
	await press("ui_page_up")
	var bar := (ending.get_node("%SummaryText") as RichTextLabel).get_v_scroll_bar()
	runner.check(bar.value < 1.0, "Page Up returns to the top")
	runner.check((ending.get_node("%SummaryDown") as Control).visible, "an arrow shows there is more below")
	# the mouse wheel over the text scrolls it too
	var text_label := ending.get_node("%SummaryText") as RichTextLabel
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = text_label.get_global_rect().get_center()
	wheel.global_position = wheel.position
	wheel.factor = 1.0
	text_label.get_viewport().push_input(wheel)
	await get_tree().process_frame
	runner.check(bar.value > 0.0, "mouse wheel scrolls the epilogue")
	SceneManager.goto_scene("res://scenes/main/main_menu.tscn", 0.2)
	await scene_named("MainMenu")
