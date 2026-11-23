class_name ItemPickup
extends Interactable
## A thing Rowan can take (V2.2). Gives `item_id` once (the item's found_flag
## stops it ever being given twice), lifts and fades the world sprite, and
## shows what was received. Hides itself once the item has been found, also
## after loading a save.

@export var item_id := ""
## The sprite in the world that represents the item (faded out on pickup).
@export var sprite_path: NodePath
## If >= 0, switch the sprite to this frame instead of fading it (a rope peg
## that stays on the wall once the rope is taken).
@export var sprite_frame_after := -1


func _ready() -> void:
	super._ready()
	var flag := str(Inventory.def(item_id).get("found_flag", ""))
	if hidden_when == "" and flag != "":
		hidden_when = flag
	if prompt == "Inspect":
		prompt = "Take " + Inventory.item_name(item_id)
	_sync_sprite.call_deferred()


func _sync_sprite() -> void:
	var s := _sprite()
	if s and not is_available():
		_taken_look(s)


func _taken_look(s: CanvasItem) -> void:
	if sprite_frame_after >= 0 and s is Sprite2D:
		(s as Sprite2D).frame = sprite_frame_after
	else:
		s.visible = false


func _sprite() -> CanvasItem:
	return get_node_or_null(sprite_path) as CanvasItem if not sprite_path.is_empty() else null


func interact(by: Node) -> void:
	if not is_available():
		return
	if not Inventory.give(item_id):
		return
	AudioManager.play_sfx("item_get", -4.0)
	var s := _sprite() as Node2D
	if s and sprite_frame_after >= 0:
		_taken_look(s)
	elif s:
		var start := s.position
		var t := create_tween().set_parallel(true)
		t.tween_property(s, "position:y", start.y - 8.0, 0.45).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "modulate:a", 0.0, 0.45)
		t.chain().tween_callback(func() -> void:
			s.visible = false
			s.position = start
			s.modulate.a = 1.0)
	interacted.emit(by)
	if conversation_id != "":
		DialogueManager.start(conversation_id, self)
