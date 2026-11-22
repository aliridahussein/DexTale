class_name Interactable
extends Area2D
## Anything Rowan can use with E: NPCs, signs, doors, clues, puzzle pieces.
##
## Set `conversation_id` to start a dialogue, or connect to `interacted` for
## custom behaviour (both may be used together).

signal interacted(by: Node)
## Emitted when this becomes (or stops being) Rowan's selected target.
signal focused(on: bool)

@export var prompt := "Inspect"
@export var conversation_id := ""
## Condition that must hold for the interaction to be offered (see GameState.check).
@export var requires := ""
## Condition that hides the interaction (e.g. once something is solved).
@export var hidden_when := ""
@export var one_shot := false
@export var focus_priority := 0
## Where the prompt bubble appears, relative to this node.
@export var prompt_offset := Vector2(0, -22)
@export var sfx := ""
## Rows of small targets (the chapel seals): select the one Rowan stands in
## front of, whatever way he faces, instead of the facing-probe rule.
@export var align_select := false
## Optional sprite (or any CanvasItem) to brighten while this is selected.
@export var highlight_path: NodePath
## Story-relevant targets get a gold prompt, so they read differently from
## flavour objects without making anything glow in the world.
@export var important := false

var enabled := true
var _used := false
var _highlight: CanvasItem
var _highlight_tween: Tween


func _ready() -> void:
	collision_layer = 1 << 3  # "interactable"
	collision_mask = 0
	monitoring = false
	monitorable = true
	if not highlight_path.is_empty():
		_highlight = get_node_or_null(highlight_path) as CanvasItem


func is_available() -> bool:
	if not enabled or (one_shot and _used):
		return false
	if not GameState.check(requires):
		return false
	if hidden_when != "" and GameState.check(hidden_when):
		return false
	return true


func interact(by: Node) -> void:
	if not is_available():
		return
	_used = true
	if sfx != "":
		AudioManager.play_sfx(sfx)
	interacted.emit(by)
	if conversation_id != "":
		DialogueManager.start(conversation_id, self)


## Called by the player when selection moves on or off this target.
func set_focused(on: bool) -> void:
	focused.emit(on)
	if _highlight == null or not is_instance_valid(_highlight):
		return
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	var target := Color(1.45, 1.35, 1.15) if on else Color(1, 1, 1)
	_highlight_tween.tween_property(_highlight, "modulate", target, 0.12)


func get_prompt_position() -> Vector2:
	return global_position + prompt_offset
