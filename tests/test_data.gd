extends Node
## Static checks on the data files: dialogue structure, flags, quests,
## documents, speakers and endings. Catches typos before anyone plays.

const GLOBAL_EVENTS := ["toast", "sfx", "music", "ambience", "shake", "flash", "open_document", "fade_out",
	"fade_in", "echo_effect", "reconstruct", "caption_here", "give_item"]

var runner: Node


func _flag_registry() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/flags.json"))
	return parsed if parsed is Dictionary else {}


func _known(flag: String, reg: Dictionary) -> bool:
	if (reg.get("flags", {}) as Dictionary).has(flag):
		return true
	for p in reg.get("auto_prefixes", []):
		if flag.begins_with(str(p)):
			return true
	return false


func _area_events() -> Array:
	var events: Array = GLOBAL_EVENTS.duplicate()
	for area_id in GameState.AREAS:
		var inst: Node = (load(GameState.AREAS[area_id]) as PackedScene).instantiate()
		events.append_array((inst.call("area_events") as Dictionary).keys())
		inst.free()
	return events


func test_dialogue_is_valid() -> void:
	var errors := DialogueManager.validate(_area_events())
	for e in errors:
		runner.fail(e)
	runner.check(DialogueManager.conversations.size() > 40, "expected a full set of conversations")


func test_every_flag_is_registered() -> void:
	var reg := _flag_registry()
	runner.check(not reg.is_empty(), "data/flags.json loads")
	var re := RegEx.new()
	re.compile("[A-Za-z0-9_]+")
	var used := DialogueManager.referenced_flags()
	var conds: Array = []
	for o in QuestManager.objectives:
		conds.append(o.get("start", ""))
		conds.append(o.get("done", ""))
	for d in QuestManager.discoveries:
		conds.append(d.get("when", ""))
	var endings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/endings.json"))
	for e in (endings as Dictionary).get("epilogue", []):
		conds.append(e.get("if", ""))
	for c in conds:
		for item in (c if c is Array else [c]):
			var m := re.search(str(item))
			if m:
				used[m.get_string()] = true
	for flag in used:
		runner.check(_known(str(flag), reg), "flag '%s' is not documented in data/flags.json" % flag)


## V2.2: items.json. Every flag an item, combination or reconstruction uses
## is registered; icons exist; combinations and refusals name real items.
func test_items_are_well_formed() -> void:
	var reg := _flag_registry()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	runner.check(parsed is Dictionary, "data/items.json loads")
	var data: Dictionary = parsed
	var ids: Array[String] = []
	var flag_names: Array[String] = []
	for d in data.get("items", []):
		var id := str(d.get("id", ""))
		runner.check(id != "" and not ids.has(id), "item ids are unique and set (%s)" % id)
		ids.append(id)
		runner.check(str(d.get("name", "")) != "" and str(d.get("description", "")) != "", "%s has a name and description" % id)
		runner.check(ResourceLoader.exists(str(d.get("icon", ""))), "%s icon exists" % id)
		for a in d.get("actions", []):
			runner.check(a in Inventory.ACTIONS, "%s: action '%s' is known" % [id, a])
		for part in str(d.get("owned", "")).split(",", false):
			flag_names.append(part.strip_edges().trim_prefix("!"))
		if d.has("found_flag"):
			flag_names.append(str(d["found_flag"]))
		if d.has("inspect_reconstruction"):
			var recon: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/reconstructions.json"))
			runner.check((recon as Dictionary).has(str(d["inspect_reconstruction"])), "%s: reconstruction exists" % id)
	for c in data.get("combinations", []):
		for i in c.get("items", []):
			runner.check(ids.has(str(i)), "combination uses known item '%s'" % i)
		runner.check(ids.has(str(c.get("result", ""))), "combination result '%s' is an item" % c.get("result", ""))
		for k in (c.get("set", {}) as Dictionary):
			flag_names.append(str(k))
	for r in data.get("refusals", []):
		for i in r.get("items", []):
			runner.check(i == "*" or ids.has(str(i)), "refusal uses known item '%s'" % i)
		runner.check(str(r.get("text", "")) != "", "every refusal says something")
	for f in flag_names:
		runner.check(_known(f, reg), "item flag '%s' is not documented in data/flags.json" % f)
	var recon_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/reconstructions.json"))
	for rid in (recon_data as Dictionary):
		if str(rid).begins_with("_"):
			continue
		var entry: Dictionary = recon_data[rid]
		for c in entry.get("clues", []):
			runner.check(_known(str(c.get("when", "")), reg), "%s clue flag '%s' is registered" % [rid, c.get("when", "")])
		if entry.has("solved_flag"):
			runner.check(_known(str(entry["solved_flag"]), reg), "%s solved flag is registered" % rid)


func test_quests_are_well_formed() -> void:
	var ids := {}
	for o in QuestManager.objectives:
		for key in ["id", "title", "start", "done"]:
			runner.check(o.has(key), "objective missing '%s': %s" % [key, o])
		runner.check(not ids.has(o.get("id")), "duplicate objective id %s" % o.get("id"))
		ids[o.get("id")] = true
	var primary := QuestManager.objectives.filter(func(o: Dictionary) -> bool: return not o.get("optional", false))
	runner.check(primary.size() >= 6, "at least six main objectives")
	for d in QuestManager.discoveries:
		for key in ["id", "when", "title", "text"]:
			runner.check(d.has(key), "discovery missing '%s': %s" % [key, d])


func test_documents_and_speakers_exist() -> void:
	var docs: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/documents.json"))
	runner.check(docs is Dictionary, "documents.json loads")
	for conv_id in DialogueManager.conversations:
		for s in DialogueManager.conversations[conv_id]:
			if s is Dictionary and s.get("event", "") == "open_document":
				var doc := str((s["args"] as Array)[0])
				runner.check((docs as Dictionary).has(doc), "%s opens unknown document '%s'" % [conv_id, doc])
	for doc_id in docs:
		for page in docs[doc_id]["pages"]:
			if page is Dictionary and page.has("image"):
				runner.check(ResourceLoader.exists(page["image"]), "document image exists: %s" % page["image"])
	for sp in DialogueManager.speakers:
		var portrait := str(DialogueManager.speakers[sp].get("portrait", ""))
		if portrait != "":
			runner.check(ResourceLoader.exists(portrait), "portrait for %s exists" % sp)


func test_endings_are_complete() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/endings.json"))
	for kind in ["keeper", "promise", "chorus"]:
		var e: Dictionary = data["endings"].get(kind, {})
		runner.check(e.has("title") and (e.get("lines", []) as Array).size() >= 3, "ending %s has title and lines" % kind)
	var ending_script: GDScript = load("res://scripts/ui/ending.gd")
	for kind in ["keeper", "promise", "chorus"]:
		var lines: Array = ending_script.call("epilogue_lines", kind, data)
		runner.check(lines.size() >= 3, "epilogue for %s has at least three lines" % kind)


func test_conversations_are_reachable() -> void:
	# Soft check: list conversations that nothing references (not a failure).
	var referenced := {}
	for conv_id in DialogueManager.conversations:
		for s in DialogueManager.conversations[conv_id]:
			if s is Dictionary and s.has("run"):
				referenced[s["run"]] = true
	var text := ""
	for dir in ["res://scenes/world/", "res://scripts/world/", "res://scripts/ui/", "res://scripts/systems/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".tscn") or f.ends_with(".gd"):
				text += FileAccess.get_file_as_string(dir + f)
	var orphans: Array = []
	for conv_id in DialogueManager.conversations:
		if not referenced.has(conv_id) and not text.contains("\"%s\"" % conv_id):
			orphans.append(conv_id)
	if not orphans.is_empty():
		print("        (note) unreferenced conversations: ", orphans)
	runner.check(orphans.size() <= 2, "too many unreferenced conversations: %s" % [orphans])


func test_audio_assets_exist_and_loop() -> void:
	var sfx := ["anvil", "bell_crack", "bell_hum", "bell_toll", "bell_toll_far", "bell_warm", "blip", "clank", "door",
		"door_stone", "echo_listen", "echo_whisper", "gate", "hum", "hum_slow", "item", "item_get", "lantern",
		"memory_fade", "mist_hit", "mist_pulse", "mist_warn", "orin_appear", "page", "seal_press", "seal_solved",
		"seal_wrong", "sentinel", "sentinel_fade", "step_cloth", "step_dirt", "step_grass", "step_stone",
		"step_wood", "success", "ui_back", "ui_confirm", "ui_move", "ui_open", "wind_gust"]
	for n in sfx:
		runner.check(ResourceLoader.exists(AudioManager.SFX_DIR + n + ".wav"), "sfx %s exists" % n)
	var looping := []
	for area_id in GameState.AREAS:
		var inst: Node = (load(GameState.AREAS[area_id]) as PackedScene).instantiate()
		if str(inst.get("music")) != "":
			looping.append(AudioManager.MUSIC_DIR + str(inst.get("music")) + ".wav")
		if str(inst.get("ambience")) != "":
			looping.append(AudioManager.AMBIENCE_DIR + str(inst.get("ambience")) + ".wav")
		inst.free()
	for n in ["title", "orin", "ending_keeper", "ending_promise", "ending_chorus"]:
		looping.append(AudioManager.MUSIC_DIR + n + ".wav")
	looping.append(AudioManager.AMBIENCE_DIR + "village_night.wav")
	for path in looping:
		var stream := load(path) as AudioStreamWAV
		runner.check(stream != null, "%s loads" % path)
		if stream:
			runner.check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops" % path.get_file())
