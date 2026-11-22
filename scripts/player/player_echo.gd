extends Node2D
## "Listen to the Echo" (F). Shows a short spectral effect and reveals the
## nearest EchoPoint in range. Also drives the [F] Listen hint.

const QUIET_LINES := [
	"Only your own heartbeat.",
	"Nothing lingers here.",
	"The past is quiet in this spot.",
	"Just wind, and the smell of smoke.",
]

@export var cooldown := 1.4

var _cd := 0.0
var _hint_target: EchoPoint = null
var _quiet_index := 0

@onready var player: Player = get_parent() as Player
@onready var sensor: Area2D = player.get_node("EchoSensor")
@onready var motes: CPUParticles2D = $Motes
@onready var ripple: Sprite2D = $Ripple


func _ready() -> void:
	ripple.visible = false


func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var target: EchoPoint = best_target() if player.can_act() else null
	if target != _hint_target:
		_hint_target = target
		UI.set_echo_focus(target)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("echo") and player.can_act():
		get_viewport().set_input_as_handled()
		activate()


func best_target() -> EchoPoint:
	var best: EchoPoint = null
	var best_d := INF
	for a in sensor.get_overlapping_areas():
		var ep := a as EchoPoint
		if ep == null or not ep.is_available():
			continue
		var d := ep.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = ep
	return best


func activate() -> void:
	if _cd > 0.0:
		return
	_cd = cooldown
	UI.play_echo_effect()
	AudioManager.play_sfx("echo_listen", -4.0)
	motes.restart()
	motes.emitting = true
	_play_ripple()
	for a in sensor.get_overlapping_areas():
		if a is EchoPoint:
			(a as EchoPoint).shimmer()
	var target := best_target()
	if target:
		GameState.lock_input("echo")
		await get_tree().create_timer(0.45).timeout
		GameState.unlock_input("echo")
		target.reveal(player)
	else:
		await get_tree().create_timer(0.5).timeout
		UI.show_toast(QUIET_LINES[_quiet_index % QUIET_LINES.size()])
		_quiet_index += 1


func _play_ripple() -> void:
	ripple.visible = true
	ripple.scale = Vector2(0.15, 0.1)
	ripple.modulate = Color(0.7, 0.8, 1.0, 0.9)
	var t := create_tween().set_parallel(true)
	t.tween_property(ripple, "scale", Vector2(2.6, 1.7), 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(ripple, "modulate:a", 0.0, 0.9)
	t.chain().tween_callback(func() -> void: ripple.visible = false)
