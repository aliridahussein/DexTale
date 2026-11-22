class_name Player
extends CharacterBody2D
## Rowan. Four-direction movement, facing, interaction focus and scripted walks.

signal focus_changed(target: Interactable)
signal arrived

@export var walk_speed := 74.0
@export var footstep_interval := 0.32

var facing := Vector2.DOWN
var focus: Interactable = null

var _auto_target: Variant = null
var _auto_speed := 1.0
var _auto_stuck := 0.0
var _auto_last_dist := INF
var _step_timer := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sensor: Area2D = $InteractionSensor
@onready var camera: GameCamera = $Camera


func _ready() -> void:
	add_to_group("player")
	sprite.play("idle_down")


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if _auto_target != null:
		dir = _auto_walk_step(delta)
		velocity = dir * walk_speed * _auto_speed
	elif can_move():
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * walk_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_facing(dir)
	_update_animation()
	_update_footsteps(delta)
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and can_act() and focus != null:
		get_viewport().set_input_as_handled()
		var target := focus
		_set_focus(null)
		target.interact(self)


## Player-controlled movement allowed right now?
func can_move() -> bool:
	return not GameState.is_input_locked() and not get_tree().paused


func can_act() -> bool:
	return can_move() and _auto_target == null


# ---------------------------------------------------------------- facing --
func face(direction: Variant) -> void:
	if direction is String:
		match direction:
			"up": facing = Vector2.UP
			"left": facing = Vector2.LEFT
			"right": facing = Vector2.RIGHT
			_: facing = Vector2.DOWN
	elif direction is Vector2 and (direction as Vector2).length() > 0.01:
		var v: Vector2 = direction
		facing = Vector2(signf(v.x), 0) if absf(v.x) > absf(v.y) else Vector2(0, signf(v.y))
	_update_animation()


func face_toward(world_pos: Vector2) -> void:
	face(world_pos - global_position)


func facing_name() -> String:
	if facing.x < 0:
		return "left"
	if facing.x > 0:
		return "right"
	if facing.y < 0:
		return "up"
	return "down"


func _update_facing(dir: Vector2) -> void:
	if dir.length() < 0.2:
		return
	if absf(dir.x) > absf(dir.y) + 0.01:
		facing = Vector2(signf(dir.x), 0)
	elif absf(dir.y) > absf(dir.x) + 0.01:
		facing = Vector2(0, signf(dir.y))
	else:
		# perfect diagonal: keep the current facing if it is one of the components
		var keep := (facing.x != 0 and signf(facing.x) == signf(dir.x)) or (facing.y != 0 and signf(facing.y) == signf(dir.y))
		if not keep:
			facing = Vector2(0, signf(dir.y))


func _update_animation() -> void:
	if sprite == null:
		return
	var moving := velocity.length() > 4.0
	var anim := ("walk_" if moving else "idle_") + facing_name()
	if sprite.animation != anim:
		sprite.play(anim)


func _update_footsteps(delta: float) -> void:
	if velocity.length() < 4.0:
		_step_timer = 0.06
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = footstep_interval / maxf(_auto_speed if _auto_target != null else 1.0, 0.5)
		var surface := "stone"
		var area := get_tree().get_first_node_in_group("area")
		if area and area.has_method("surface_at"):
			surface = area.surface_at(global_position)
		AudioManager.play_sfx("step_" + surface, -14.0, 1.0, 0.12)


# ----------------------------------------------------------- interaction --
func _update_focus() -> void:
	var best: Interactable = null
	if can_act():
		var best_score := INF
		var focus_score := INF
		for a in sensor.get_overlapping_areas():
			var it := a as Interactable
			if it == null or not it.is_available():
				continue
			var score := focus_score_for(it)
			if it == focus:
				focus_score = score
			if score < best_score:
				best_score = score
				best = it
		# Keep the current target unless another is clearly closer, so the
		# selection never flickers between two neighbours.
		if focus != null and best != focus and focus_score < best_score + 2.0:
			best = focus
	if best != focus:
		_set_focus(best)


## Lower is better. Normal targets are ranked from a point just ahead of
## Rowan, in the direction he faces. Rows of small wall targets (align_select)
## are ranked by how squarely Rowan stands in front of them, so turning left
## or right under the Moon seal can no longer select the Flame seal (QA-04).
func focus_score_for(it: Interactable) -> float:
	var score: float
	if it.align_select:
		var d := it.global_position - global_position
		score = absf(d.x) + absf(d.y) * 0.25
	else:
		var probe := global_position + facing * 10.0 + Vector2(0, -6)
		score = it.global_position.distance_to(probe)
	return score - float(it.focus_priority) * 100.0


func _set_focus(target: Interactable) -> void:
	if focus != null and is_instance_valid(focus):
		focus.set_focused(false)
	focus = target
	if focus != null:
		focus.set_focused(true)
	focus_changed.emit(focus)
	UI.set_interact_focus(focus)


# ------------------------------------------------------- scripted motion --
## Walk to a point (cutscenes). Returns a signal emitted on arrival.
func walk_to(target: Vector2, speed_scale: float = 0.8) -> Signal:
	_auto_target = target
	_auto_speed = speed_scale
	_auto_stuck = 0.0
	_auto_last_dist = INF
	return arrived


func _auto_walk_step(delta: float) -> Vector2:
	var to: Vector2 = (_auto_target as Vector2) - global_position
	var dist := to.length()
	if dist < 1.5:
		_finish_auto_walk()
		return Vector2.ZERO
	# never get stuck on a corner during a cutscene
	if dist > _auto_last_dist - 0.05:
		_auto_stuck += delta
	else:
		_auto_stuck = 0.0
	_auto_last_dist = dist
	if _auto_stuck > 0.8:
		global_position = _auto_target
		reset_physics_interpolation()
		_finish_auto_walk()
		return Vector2.ZERO
	return to / dist


func _finish_auto_walk() -> void:
	_auto_target = null
	velocity = Vector2.ZERO
	arrived.emit()


## Turn the light Rowan carries on (energy > 0) or off.
func set_carried_light(energy: float) -> void:
	var light := get_node_or_null("CarriedLight") as PointLight2D
	if light == null:
		return
	light.enabled = energy > 0.0
	light.energy = energy


func carried_light() -> float:
	var light := get_node_or_null("CarriedLight") as PointLight2D
	return light.energy if light and light.enabled else 0.0


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_auto_target = null
	reset_physics_interpolation()
