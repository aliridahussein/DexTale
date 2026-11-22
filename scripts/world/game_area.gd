class_name GameArea
extends Node2D
## Base script for every playable area (village, forge, chapel, path, tower).
##
## Expected children (created by the level builder, editable in the editor):
##   Ground (TileMapLayer)    floors, paths, walls
##   Overlay (TileMapLayer)   canopy and grass fringes
##   Objects (Node2D, y-sorted) Player, NPCs, props
##   Interactions             Interactable / EchoPoint nodes without sprites
##   Triggers                 AreaExit / StoryTrigger nodes
##   Spawns                   Marker2D nodes; metadata "facing" = up/down/left/right
##   Ambient (CanvasModulate) the area's light level
##
## Subclasses override `_area_ready()` and `area_events()`.

@export var area_id := ""
@export var display_name := ""
@export var subtitle := ""
@export var music := ""
@export var ambience := ""
@export_range(0.0, 1.0) var reverb := 0.0
@export var footstep_surface := "stone"
## Camera limits in pixels.
@export var bounds := Rect2(0, 0, 480, 270)
## Energy of the soft light Rowan carries in this area (0 = none). Keeps him
## readable in dense fog (QA-07).
@export var player_light := 0.0

var _registered_events: Array = []

@onready var ground: TileMapLayer = get_node_or_null("Ground")
@onready var ambient: CanvasModulate = get_node_or_null("Ambient")


func _ready() -> void:
	add_to_group("area")
	var player := get_player()
	if player:
		player.camera.set_bounds(bounds)
		player.set_carried_light(player_light)
	AudioManager.play_music(music)
	AudioManager.play_ambience(ambience)
	AudioManager.set_reverb(reverb)
	var events := area_events()
	for ev in events:
		DialogueManager.register_event(ev, events[ev])
		_registered_events.append(ev)
	SceneManager.register_area(self)
	UI.set_gameplay_hud(true)
	_area_ready()
	if display_name != "":
		UI.show_area_title(display_name, area_subtitle())


func _exit_tree() -> void:
	for ev in _registered_events:
		DialogueManager.unregister_event(ev)
	if DialogueManager.is_active():
		DialogueManager.stop()


## Override in subclasses.
func _area_ready() -> void:
	pass


## Override when the subtitle depends on the story (e.g. time of day).
func area_subtitle() -> String:
	return subtitle


## Override: event name -> Callable, available to dialogue while this area is loaded.
func area_events() -> Dictionary:
	return {}


func get_player() -> Player:
	return get_node_or_null("Objects/Player") as Player


func get_spawn_position(spawn_id: String) -> Vector2:
	var m := _spawn(spawn_id)
	if m:
		return m.global_position
	var p := get_player()
	return p.global_position if p else Vector2.ZERO


func get_spawn_facing(spawn_id: String) -> String:
	var m := _spawn(spawn_id)
	if m and m.has_meta("facing"):
		return str(m.get_meta("facing"))
	return "down"


func _spawn(spawn_id: String) -> Node2D:
	var m := get_node_or_null("Spawns/" + spawn_id) as Node2D
	if m == null:
		m = get_node_or_null("Spawns/default") as Node2D
	return m


## Footstep surface under a world position (tile custom data "surface").
func surface_at(world_pos: Vector2) -> String:
	if ground and ground.tile_set:
		var cell := ground.local_to_map(ground.to_local(world_pos))
		var data := ground.get_cell_tile_data(cell)
		if data:
			var s: Variant = data.get_custom_data("surface")
			if s is String and s != "":
				return s
	return footstep_surface


func npc(node_name: String) -> NPC:
	return get_node_or_null("Objects/" + node_name) as NPC


## Tween the area's ambient light (CanvasModulate).
func set_ambient(color: Color, duration: float = 0.0) -> void:
	if ambient == null:
		return
	if duration <= 0.0:
		ambient.color = color
		return
	var t := create_tween()
	t.tween_property(ambient, "color", color, duration)


func camera() -> GameCamera:
	var p := get_player()
	return p.camera if p else null
