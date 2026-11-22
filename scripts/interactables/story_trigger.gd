class_name StoryTrigger
extends Area2D
## Fires when the player walks in: starts a conversation and/or emits
## `triggered` for the area script. `once_flag` makes it fire only once ever.

signal triggered

@export var conversation_id := ""
@export var requires := ""
@export var once_flag := ""


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return
	if not GameState.check(requires):
		return
	if once_flag != "":
		if GameState.has_flag(once_flag):
			return
		GameState.set_flag(once_flag, true)
	triggered.emit()
	if conversation_id != "":
		DialogueManager.start(conversation_id, self)
