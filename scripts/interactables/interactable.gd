class_name Interactable
extends Area2D
## Anything Rowan can use with E: NPCs, signs, doors, clues, puzzle pieces.
##
## Set `conversation_id` to start a dialogue, or connect to `interacted` for
## custom behaviour (both may be used together).

signal interacted(by: Node)

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

var enabled := true
var _used := false


func _ready() -> void:
	collision_layer = 1 << 3  # "interactable"
	collision_mask = 0
	monitoring = false
	monitorable = true


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


func get_prompt_position() -> Vector2:
	return global_position + prompt_offset
