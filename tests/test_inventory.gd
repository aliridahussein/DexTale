extends "res://tests/driver.gd"
## V2.2 inventory: one source of truth (story flags), pickups that happen
## once, combinations in either order, refusals that never lose an item, the
## screen driven by the real input actions without moving Rowan, using a held
## item on the world, and saves (new and V1).

const ROAD := ["game_started", "has_tuning_pin", "has_gate_key", "read_bellkeeper_ledger", "gate_unlocked",
	"met_sentinel", "passed_sentinel"]
const V1_FIXTURE := "res://tests/fixtures/v1_save_tower_peaceful.json"


func setup() -> void:
	begin("user://test_inventory_save.json")


func teardown() -> void:
	Inventory.clear_held()
	if inv().visible:
		inv().call("close")
	finish()


func inv() -> Control:
	return UI.inventory_view


func toast_count() -> int:
	return (UI.get("_toast_queue") as Array).size() + (1 if UI.toast_box.visible else 0)


## "Received: ..." notes queued or on screen (objective and journal notes aside).
func received_count() -> int:
	var n := 0
	for item in (UI.get("_toast_queue") as Array):
		if str(item[0]).begins_with("Received"):
			n += 1
	if UI.toast_box.visible and UI.toast_label.text.begins_with("Received"):
		n += 1
	return n


## Let objective / journal notes from arriving finish before counting toasts.
func toasts_idle() -> void:
	var t := 0.0
	while toast_count() > 0 and t < 20.0:
		await wait(0.1)
		t += 0.1


# ------------------------------------------------------------------ model --
func test_existing_items_follow_their_flags() -> void:
	runner.check(Inventory.owned().is_empty(), "a new game starts empty-handed")
	GameState.set_flag("has_tuning_pin", true)
	runner.check(Inventory.owned() == ["tuning_pin"], "the tuning pin appears with Mara's flag, once")
	GameState.set_flag("has_gate_key", true)
	GameState.set_flag("has_tobin_lantern", true)
	runner.check(Inventory.owned() == ["tuning_pin", "gate_key", "tobin_lantern"], "key and Tobin's lantern join it")
	runner.check(not Inventory.can("tobin_lantern", "light") and not Inventory.lantern_on(),
		"Tobin's lantern is kept wrapped: it is not the Old Lantern")
	GameState.set_flag("has_tuning_pin", true)  # set again: still one pin
	runner.check(Inventory.owned().count("tuning_pin") == 1, "no duplicate pin")
	GameState.set_flag("pin_installed", true)
	runner.check(not Inventory.has("tuning_pin") and Inventory.has("gate_key"), "the pin leaves only when it goes into the bell")


func test_pickups_happen_once_and_stay_taken() -> void:
	set_flags(ROAD)
	await goto("watchhouse", "default")
	var take := area().get_node("Interactions/RopeTake") as Interactable
	runner.check(take.is_available() and take.prompt_text() == "Take Strong Rope", "the rope offers itself by name")
	await toasts_idle()
	take.interact(player())
	await frames(2)
	runner.check(Inventory.has("rope") and received_count() == 1, "took the rope, with one 'Received' note")
	runner.check(not take.is_available(), "the rope can't be taken twice")
	take.interact(player())  # a stray second press
	runner.check(Inventory.owned().count("rope") == 1 and not Inventory.give("rope"), "still exactly one rope")
	runner.check((area().get_node("Objects/RopePeg/Sprite") as Sprite2D).frame == 1, "the peg is empty now")
	await wait(0.6)
	await goto("crossing", "from_watchhouse")
	await goto("watchhouse", "from_crossing")
	runner.check(not (area().get_node("Interactions/RopeTake") as Interactable).is_available(),
		"coming back, the rope is still gone")
	runner.check((area().get_node("Objects/RopePeg/Sprite") as Sprite2D).frame == 1, "and the peg still empty")


func test_story_items_do_not_toast_twice() -> void:
	set_flags(["game_started", "passed_sentinel"])
	await goto("watchhouse", "default")
	await until_idle()
	await toasts_idle()
	# Mara's, Alden's and Tobin's scenes show their own "Received" toasts
	for f in ["has_tuning_pin", "has_gate_key", "has_tobin_lantern"]:
		GameState.set_flag(f, true)
	await frames(1)
	runner.check(Inventory.owned().size() == 3 and received_count() == 0, "the inventory adds no second toast for story items")
	(area().get_node("Interactions/LanternTake") as Interactable).interact(player())
	await frames(1)
	runner.check(received_count() == 1, "a pickup gets exactly one")


func test_combining_in_either_order() -> void:
	set_flags(["found_rope", "found_hook"])
	var r := Inventory.combine("hook", "rope")
	runner.check(r["ok"] and r["result"] == "hooked_line", "hook + rope makes the Hooked Line")
	runner.check(Inventory.owned() == ["hooked_line"], "the rope and hook are used up into it")
	GameState.reset()
	set_flags(["found_rope", "found_hook"])
	r = Inventory.combine("rope", "hook")
	runner.check(r["ok"] and Inventory.has("hooked_line"), "rope + hook works the same")
	var again := Inventory.combine("rope", "hook")
	runner.check(not again["ok"] and Inventory.owned().count("hooked_line") == 1, "the parts can't be combined twice")
	runner.check(not Inventory.combine("hooked_line", "hooked_line")["ok"], "an item can't combine with itself")


func test_wrong_combinations_explain_and_keep_both() -> void:
	set_flags(["has_tuning_pin", "has_gate_key", "found_rope", "found_hook", "found_lantern", "found_token"])
	var before := Inventory.owned()
	var cases := [
		["tuning_pin", "rope", "not the tool for this job"],
		["rope", "tuning_pin", "not the tool for this job"],
		["hook", "old_lantern", "nowhere to attach"],
		["old_lantern", "hook", "nowhere to attach"],
		["gate_key", "token", ""],
		["rope", "token", "Those don't go together."],
	]
	for c in cases:
		var r := Inventory.combine(c[0], c[1])
		runner.check(not r["ok"] and str(r["text"]) != "", "%s + %s is refused with a reason" % [c[0], c[1]])
		if c[2] != "":
			runner.check(str(r["text"]).contains(c[2]), "%s + %s: '%s' (got '%s')" % [c[0], c[1], c[2], r["text"]])
	runner.check(Inventory.owned() == before, "nothing was lost to a wrong combination")
	runner.check(Inventory.use_refusal("rope") == "That won't help here.", "a world refusal has a general line")
	runner.check(Inventory.use_refusal("gate_key").contains("one job"), "and items can have their own")
	runner.check(Inventory.has("tuning_pin"), "the pin is never lost before the tower")


# --------------------------------------------------------------------- UI --
func test_inventory_screen_by_keyboard_without_moving_rowan() -> void:
	set_flags(ROAD + ["found_rope", "found_hook"])
	await goto("watchhouse", "default")
	await until_idle()
	var start := player().global_position
	await press("inventory")
	runner.check(inv().visible and get_tree().paused, "I opens the inventory and pauses the game")
	runner.check(UI.is_menu_open(), "the HUD treats it as a menu")
	runner.check(inv().call("selected") == "tuning_pin", "the first slot is selected")
	await press("move_right")
	await press("move_right")
	runner.check(inv().call("selected") == "rope", "arrows move through the slots (pin, key, rope)")
	await press("interact")
	runner.check(inv().get("mode") == 1, "E opens the rope's actions")
	await press("ui_cancel")
	runner.check(inv().visible and inv().get("mode") == 0, "Esc steps back to the slots, not out of the screen")
	await press("interact")
	await press("move_right")
	await press("move_right")
	await press("interact")
	runner.check(inv().get("mode") == 2 and inv().get("combine_from") == "rope", "Combine asks for a second item")
	await press("move_right")
	runner.check(inv().call("selected") == "hook", "pick the hook")
	await press("interact")
	runner.check(Inventory.has("hooked_line") and inv().call("selected") == "hooked_line",
		"E combines them; the Hooked Line is selected")
	runner.check(str((inv().get_node("%InvMessage") as RichTextLabel).get_parsed_text()).contains("Hooked Line"),
		"the screen says what was made")
	await press("inventory")
	runner.check(not inv().visible and not get_tree().paused, "I closes it again")
	await press("inventory")
	await press("ui_cancel")
	runner.check(not inv().visible and not get_tree().paused, "Esc from the slots closes it too")
	await frames(6)
	runner.check(player().global_position.distance_to(start) < 0.5, "none of those keys moved Rowan")
	# not while talking
	DialogueManager.start("watch_shelf")
	await frames(1)
	await press("inventory")
	runner.check(not inv().visible, "I does nothing during a conversation")
	await play([0])


func test_disabled_actions_say_why() -> void:
	set_flags(ROAD + ["found_token"])
	await goto("watchhouse", "default")
	UI.open_inventory()
	inv().set("cursor", Inventory.owned().find("token"))
	inv().call("select")
	inv().call("do_action", "combine")
	runner.check(inv().get("mode") == 1 and str((inv().get_node("%InvMessage") as RichTextLabel).get_parsed_text())
		.contains("doesn't go with anything"), "a greyed-out action explains itself")
	inv().call("do_action", "light")
	runner.check(str((inv().get_node("%InvMessage") as RichTextLabel).get_parsed_text()).contains("Only a lantern"),
		"the shutter is only for the lantern")
	inv().call("close")


func test_hold_an_item_and_use_it_on_the_world() -> void:
	set_flags(ROAD + ["found_rope", "found_hook", "made_hooked_line"])
	await goto("crossing", "checkpoint")
	await until_idle()
	var chain := area().get_node("Interactions/ChainUse") as ItemTarget
	await hold_in_inventory("tuning_pin")
	runner.check(Inventory.held == "tuning_pin" and not inv().visible and not get_tree().paused,
		"Hold closes the inventory with the pin in hand")
	runner.check(UI.held_label.text == "Holding: Iron Tuning Pin" and UI.held_chip.visible, "the HUD shows what is held")
	runner.check(chain.prompt_text() == "Use Iron Tuning Pin", "the chain's prompt names the held item")
	chain.interact(player())
	await frames(2)
	runner.check(UI.caption_text().contains("The pin is for the bell") and not DialogueManager.is_active(),
		"the wrong item gets the pin's own short caption (got '%s')" % UI.caption_text())
	runner.check(Inventory.has("tuning_pin") and Inventory.held == "tuning_pin", "and is kept, still in hand")
	runner.check(not has("chain_secured"), "the chain is untouched")
	await hold_in_inventory("hooked_line")
	runner.check(chain.prompt_text() == "Use Hooked Line", "holding the right item")
	chain.interact(player())
	await until_idle()
	runner.check(has("chain_secured") and not Inventory.has("hooked_line"), "the Hooked Line is used on the chain")
	runner.check(Inventory.held == "" and not UI.held_chip.visible, "a used-up item is no longer held")
	runner.check(Inventory.has("tuning_pin") and Inventory.has("gate_key"), "the pin and key are untouched")


func test_pressing_e_with_nothing_held_uses_the_obvious_item() -> void:
	set_flags(ROAD + ["found_rope", "found_hook", "made_hooked_line"])
	await goto("crossing", "checkpoint")
	var chain := area().get_node("Interactions/ChainUse") as ItemTarget
	runner.check(chain.prompt_text() == "Use Hooked Line", "the chain offers the Hooked Line directly")
	chain.interact(player())
	await until_idle()
	runner.check(has("chain_secured"), "no need to open the inventory for the obvious step")


# ---------------------------------------------------------------- lantern --
func test_lantern_shutter_with_l() -> void:
	set_flags(ROAD)
	await goto("watchhouse", "default")
	await until_idle()
	await press("lantern")
	runner.check(not Inventory.lantern_on() and not has("lantern_on"), "L does nothing without a lantern")
	var light := player().get_node("CarriedLight") as PointLight2D
	var dark_energy := light.energy if light.enabled else 0.0
	(area().get_node("Interactions/LanternTake") as Interactable).interact(player())
	await frames(2)
	runner.check(Inventory.has("old_lantern") and Inventory.lantern_on(), "the Old Lantern is taken still burning")
	runner.check(light.enabled and light.energy > dark_energy, "Rowan's light is brighter with it open")
	runner.check(UI.lantern_label.text == "Lantern: lit", "the HUD says it is lit (in words, not only colour)")
	await press("lantern")
	runner.check(not Inventory.lantern_on() and UI.lantern_label.text == "Lantern: shuttered", "L closes the shutter")
	await press("lantern")
	runner.check(Inventory.lantern_on(), "and opens it again")
	DialogueManager.start("watch_shelf")
	await frames(1)
	await press("lantern")
	runner.check(Inventory.lantern_on(), "L is ignored while talking")
	await play([0])
	UI.open_inventory()
	inv().set("cursor", Inventory.owned().find("old_lantern"))
	inv().call("select")
	inv().call("do_action", "light")
	runner.check(not Inventory.lantern_on(), "the inventory's shutter action does the same")
	inv().call("close")


# ------------------------------------------------------------------ saves --
func test_inventory_survives_save_and_load() -> void:
	set_flags(ROAD + ["found_lantern", "found_rope", "found_hook", "made_hooked_line", "found_token"])
	await goto("crossing", "checkpoint")
	await until_idle()
	Inventory.set_held("hooked_line")
	var before := Inventory.owned()
	runner.check(before == ["tuning_pin", "gate_key", "old_lantern", "hooked_line", "token"], "carrying five things")
	runner.check(not Inventory.lantern_on(), "the shutter is closed before saving")
	runner.check(SaveManager.save_game(true), "saved")
	GameState.reset()
	runner.check(Inventory.owned().is_empty() and Inventory.held == "", "a reset empties the view")
	runner.check(SaveManager.continue_game(), "continue")
	await wait_area("crossing")
	runner.check(Inventory.owned() == before, "the same items after loading")
	runner.check(not Inventory.lantern_on(), "the shutter is still closed")
	runner.check(Inventory.held == "", "nothing is held after loading (a moment's choice, not progress)")


func test_v1_saves_have_the_right_inventory() -> void:
	write_raw(SaveManager.save_path, FileAccess.get_file_as_string(V1_FIXTURE))
	runner.check(SaveManager.continue_game(), "a V1 save continues")
	await wait_area("bell_tower")
	runner.check(Inventory.owned() == ["tuning_pin", "gate_key"], "a V1 save carries the pin and the key, nothing new")
	runner.check(not Inventory.lantern_on(), "no Old Lantern in a V1 save")
	await press("inventory")
	runner.check(inv().visible, "the inventory opens on a V1 save")
	await press("inventory")


func write_raw(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
