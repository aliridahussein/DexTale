extends Node
## Every area loads, contains the required structure, and its exits, spawns,
## conversations and echo points point at things that exist.

var runner: Node


func setup() -> void:
	pass


func _load_area(area_id: String) -> Node:
	var packed: PackedScene = load(GameState.AREAS[area_id])
	runner.check(packed != null, "%s scene loads" % area_id)
	return packed.instantiate() if packed else null


func test_areas_have_required_nodes() -> void:
	for area_id in GameState.AREAS:
		var area := _load_area(area_id)
		if area == null:
			continue
		for path in ["Ground", "Objects", "Objects/Player", "Spawns", "Spawns/default", "Ambient", "Bounds"]:
			runner.check(area.get_node_or_null(path) != null, "%s has %s" % [area_id, path])
		var ground := area.get_node_or_null("Ground") as TileMapLayer
		if ground:
			runner.check(ground.get_used_cells().size() > 50, "%s ground has tiles" % area_id)
		runner.check(str(area.get("area_id")) == area_id, "%s area_id export matches" % area_id)
		area.free()


func test_exits_point_to_real_spawns() -> void:
	var spawns := {}
	for area_id in GameState.AREAS:
		var area := _load_area(area_id)
		if area == null:
			continue
		var names: Array = []
		for m in area.get_node("Spawns").get_children():
			names.append(m.name)
		spawns[area_id] = names
		area.free()
	for area_id in GameState.AREAS:
		var area := _load_area(area_id)
		if area == null:
			continue
		for t in area.get_node("Triggers").get_children():
			if t is AreaExit:
				var ex := t as AreaExit
				runner.check(GameState.AREAS.has(ex.target_area), "%s/%s targets a real area" % [area_id, t.name])
				if spawns.has(ex.target_area):
					runner.check((spawns[ex.target_area] as Array).has(ex.target_spawn),
						"%s/%s spawn '%s' exists in %s" % [area_id, t.name, ex.target_spawn, ex.target_area])
		area.free()


func test_conversations_exist() -> void:
	for area_id in GameState.AREAS:
		var area := _load_area(area_id)
		if area == null:
			continue
		var nodes: Array = []
		for group in ["Interactions", "Triggers", "Objects"]:
			nodes.append_array(area.get_node(group).get_children())
		for n in nodes:
			var conv := ""
			if n is Interactable:
				conv = (n as Interactable).conversation_id
			elif n is EchoPoint:
				conv = (n as EchoPoint).conversation_id
			elif n is StoryTrigger:
				conv = (n as StoryTrigger).conversation_id
			elif n is AreaExit:
				conv = (n as AreaExit).locked_conversation
			elif n is NPC:
				conv = (n as NPC).conversation
			if conv != "":
				runner.check(DialogueManager.has_conversation(conv), "%s/%s uses missing conversation '%s'" % [area_id, n.name, conv])
		area.free()


func test_ui_scenes_load() -> void:
	for path in ["res://scenes/main/main_menu.tscn", "res://scenes/main/prologue.tscn", "res://scenes/main/ending.tscn",
			"res://scenes/ui/ui.tscn", "res://scenes/characters/player.tscn", "res://scenes/characters/npc.tscn"]:
		var packed: PackedScene = load(path)
		runner.check(packed != null and packed.can_instantiate(), "%s instantiates" % path)
