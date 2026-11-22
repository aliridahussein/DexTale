class_name AreaExit
extends Area2D
## Walk-in trigger that moves the player to another area.
## When `requires` fails, `locked_conversation` plays instead (once per entry).

@export var target_area := ""
@export var target_spawn := "default"
@export var requires := ""
@export var locked_conversation := ""
@export var sfx := "door"


func _ready() -> void:
	collision_layer = 1 << 5  # "trigger"
	collision_mask = 1 << 1   # player
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if not body is Player or SceneManager.transitioning:
		return
	if GameState.is_input_locked():
		return
	if not GameState.check(requires):
		if locked_conversation != "":
			DialogueManager.start(locked_conversation, self)
		return
	if sfx != "":
		AudioManager.play_sfx(sfx, -6.0)
	SceneManager.change_area(target_area, target_spawn)
