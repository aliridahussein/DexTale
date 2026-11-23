class_name WatchmanShadow
extends Node2D
## The Watchman's Shadow (V2.2): what is left of a guard who forgot why he
## waits. Not an enemy to fight: it walks a fixed round on the far bank and
## notices light.
##
## States: DORMANT (before the bridge lowers) -> PATROL -> SUSPICIOUS (stops,
## turns, "?") -> INVESTIGATE (walks to where it noticed something, looks
## around) -> RETURN (back to its round) -> PATROL. RESOLVED once its memory is
## given back; QUIET after Rowan has crossed (never hostile again).
##
## Seeing Rowan needs all of: within range (far longer while his lantern is
## open), inside the vision cone (or very close), and a clear line of sight:
## a ray against the world's collision, so stone supports really hide him.
## Awareness builds while he is seen and fades while he isn't; "?" appears
## well before it is full, which gives time to step behind cover.

signal caught
signal state_changed(state: int)

enum State { DORMANT, PATROL, SUSPICIOUS, INVESTIGATE, RETURN, RESOLVED, QUIET }

const CONE_HALF := 1.08          # radians (about 62 degrees either side)
const RANGE_LIT := 120.0         # Rowan's lantern open
const RANGE_DARK := 44.0         # shutter closed
const RANGE_NEAR := 16.0         # any direction, right beside it
const SUSPICIOUS_AT := 0.25
const DECAY := 0.35
const SIGHT_MASK := 1            # layer "world": walls, props, the stone supports
const SPEED := 20.0
const SEARCH_TIME := 2.2
const SUSPICIOUS_TIME := 1.2
const CORNER_PAUSE := 1.0

@export var patrol: PackedVector2Array = PackedVector2Array()
## Where it may walk to investigate (its own bank). Empty = anywhere. It still
## sees beyond this; it just never walks out over the ravine.
@export var reach := Rect2()

var state := State.DORMANT
var awareness := 0.0
var facing := Vector2.RIGHT
var last_seen := Vector2.ZERO
var target_index := 1
var seen_now := false

var _timer := 0.0
var _look_t := 0.0
var _caught_sent := false
var _sprite: AnimatedSprite2D
var _light: PointLight2D
var _cone: Polygon2D
var _cone_edge: Line2D
var _mark: Label


func _ready() -> void:
	_build()
	if patrol.is_empty():
		patrol = PackedVector2Array([position, position + Vector2(160, 0)])
	set_state(State.DORMANT)


func _build() -> void:
	# The vision cone is drawn on the ground (the area's Decals layer, under
	# every object) and follows the Shadow; see _process.
	_cone = Polygon2D.new()
	_cone.color = Color(0.55, 0.75, 1.0, 0.10)
	_cone_edge = Line2D.new()
	_cone_edge.width = 1.0
	_cone_edge.default_color = Color(0.65, 0.85, 1.0, 0.35)
	_attach_cone.call_deferred()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = load("res://assets/sprites/characters/watchman.tres")
	_sprite.offset = Vector2(0, -16)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/spectral.gdshader")
	_sprite.material = mat
	add_child(_sprite)
	_light = PointLight2D.new()
	_light.texture = preload("res://assets/sprites/fx/light_radial.png")
	_light.texture_scale = 0.5
	_light.color = Color("#9ad8ff")
	_light.energy = 0.6
	_light.position = Vector2(-8, -12)
	add_child(_light)
	_mark = Label.new()
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.size = Vector2(16, 14)
	_mark.scale = Vector2(2, 2)          # a crisp, pixel-doubled "?" / "!": the warning must read at a glance
	_mark.position = Vector2(-16, -62)
	_mark.add_theme_color_override("font_color", Color("#f0d27a"))
	_mark.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.04, 0.9))
	_mark.add_theme_constant_override("shadow_outline_size", 2)
	add_child(_mark)


func _attach_cone() -> void:
	var ground: Node = null
	if get_parent() and get_parent().get_parent():
		ground = get_parent().get_parent().get_node_or_null("Decals")
	var host: Node = ground if ground else self
	host.add_child(_cone)
	host.add_child(_cone_edge)
	_cone.visible = is_hostile()
	_cone_edge.visible = is_hostile()


func _exit_tree() -> void:
	for n in [_cone, _cone_edge]:
		if is_instance_valid(n) and n.get_parent() != self:
			n.queue_free()


# ------------------------------------------------------------- lifecycle --
func set_state(s: State) -> void:
	state = s
	_timer = 0.0
	var active := s in [State.PATROL, State.SUSPICIOUS, State.INVESTIGATE, State.RETURN]
	set_physics_process(active)   # no AI or sight checks unless it is actually hunting
	set_process(active)           # the cone, eye light and mark only animate while hostile
	visible = s != State.DORMANT
	_cone.visible = active
	_cone_edge.visible = active
	match s:
		State.SUSPICIOUS:
			_mark.text = "?"
			AudioManager.play_sfx("shadow_alert", -6.0)
		State.INVESTIGATE:
			_mark.text = "?"
		State.RESOLVED, State.QUIET, State.DORMANT, State.PATROL:
			_mark.text = ""
		State.RETURN:
			_mark.text = ""
	state_changed.emit(s)


## The bridge has come down: wake at the first post of the round.
func appear(fade: bool = true) -> void:
	start_at(0)
	if fade:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.6)


## Stand at post `i` of the round, calm, heading for the next post.
func start_at(i: int) -> void:
	position = patrol[i % patrol.size()]
	reset_physics_interpolation()
	target_index = (i + 1) % patrol.size()
	awareness = 0.0
	_caught_sent = false
	set_state(State.PATROL)
	_face(patrol[target_index] - position)


## After catching Rowan: back to the start of the round, calm.
func reset_patrol() -> void:
	start_at(0)


func resolve(rest_position: Vector2) -> void:
	set_state(State.RESOLVED)
	_sprite.play("lowered")
	var t := create_tween().set_parallel(true)
	t.tween_property(_light, "energy", 0.15, 1.5)
	t.chain().tween_property(self, "position", rest_position, 2.0)
	_mark.text = ""


## Seen from the far bank after Rowan has crossed: just a figure by its lantern.
func be_quiet(at: Vector2) -> void:
	position = at
	reset_physics_interpolation()
	set_state(State.QUIET)
	_sprite.play("idle_down")
	_light.energy = 0.35


func is_hostile() -> bool:
	return state in [State.PATROL, State.SUSPICIOUS, State.INVESTIGATE, State.RETURN]


## Something creaked (a weak plank): go and look.
func hear(at: Vector2) -> void:
	if not is_hostile():
		return
	last_seen = _within_reach(at)
	awareness = maxf(awareness, SUSPICIOUS_AT)
	if state != State.SUSPICIOUS:
		set_state(State.SUSPICIOUS)
	_face(at - position)


# -------------------------------------------------------------- detection --
func sight_range() -> float:
	return RANGE_LIT if Inventory.lantern_on() else RANGE_DARK


## True if the Shadow can see a point right now (range, cone, line of sight).
func can_see(p: Vector2) -> bool:
	var to := p - global_position
	var d := to.length()
	if d > maxf(sight_range(), RANGE_NEAR):
		return false
	if d > RANGE_NEAR and absf(facing.angle_to(to)) > CONE_HALF:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -3), p + Vector2(0, -3), SIGHT_MASK)
	q.collide_with_areas = false
	return space.intersect_ray(q).is_empty()


func _player() -> Node2D:
	var area := get_tree().get_first_node_in_group("area")
	return area.call("get_player") if area and area.has_method("get_player") else null


func _physics_process(delta: float) -> void:
	var player := _player()
	if player == null:
		return
	var p := player.global_position
	seen_now = can_see(p) and not GameState.is_input_locked()
	if seen_now:
		var closeness := 1.0 - clampf(p.distance_to(global_position) / sight_range(), 0.0, 1.0)
		awareness += delta * (0.35 + 0.65 * closeness)
		last_seen = _within_reach(p)
	else:
		awareness -= DECAY * delta
	awareness = clampf(awareness, 0.0, 1.0)
	if awareness >= 1.0 and not _caught_sent:
		_caught_sent = true
		_mark.text = "!"
		caught.emit()
		return
	match state:
		State.PATROL:
			if awareness >= SUSPICIOUS_AT:
				set_state(State.SUSPICIOUS)
			else:
				_walk_round(delta)
		State.SUSPICIOUS:
			_face(last_seen - position)
			_timer += delta
			if not seen_now and _timer >= SUSPICIOUS_TIME:
				set_state(State.INVESTIGATE)
		State.INVESTIGATE:
			if seen_now and awareness >= SUSPICIOUS_AT:
				_face(last_seen - position)
			elif _move_to(last_seen, delta):
				_timer += delta
				_look_around(delta)
				if _timer >= SEARCH_TIME:
					set_state(State.RETURN)
		State.RETURN:
			if awareness >= SUSPICIOUS_AT:
				set_state(State.SUSPICIOUS)
			elif _move_to(patrol[target_index], delta):
				set_state(State.PATROL)


func _within_reach(p: Vector2) -> Vector2:
	if reach.has_area():
		return p.clamp(reach.position, reach.end)
	return p


func _walk_round(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		_look_around(delta)
		return
	if _move_to(patrol[target_index], delta):
		target_index = (target_index + 1) % patrol.size()
		_timer = CORNER_PAUSE


## Step toward `p`. Returns true once there.
func _move_to(p: Vector2, delta: float) -> bool:
	var to := p - position
	if to.length() < 1.5:
		_sprite.play("idle_" + _dir_name())
		return true
	position += to.limit_length(SPEED * delta)
	_face(to)
	_sprite.play("walk_" + _dir_name())
	return false


func _look_around(delta: float) -> void:
	_look_t += delta
	var a := facing.angle() + sin(_look_t * 2.0) * 0.9 * delta
	facing = Vector2.from_angle(a)


func _face(v: Vector2) -> void:
	if v.length() > 0.01:
		facing = v.normalized()


func _dir_name() -> String:
	if absf(facing.x) > absf(facing.y):
		return "right" if facing.x > 0 else "left"
	return "down" if facing.y > 0 else "up"


# ---------------------------------------------------------------- visuals --
func _process(_delta: float) -> void:
	if state in [State.RESOLVED, State.QUIET]:
		return
	if not _sprite.is_playing() or _sprite.animation == "":
		_sprite.play("idle_" + _dir_name())
	var r := sight_range()
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps := 10
	for i in steps + 1:
		var a := facing.angle() - CONE_HALF + (2.0 * CONE_HALF) * i / steps
		pts.append(Vector2.from_angle(a) * r)
	_cone.polygon = pts
	_cone_edge.points = pts + PackedVector2Array([Vector2.ZERO])
	if _cone.get_parent() != self:
		_cone.global_position = global_position
		_cone_edge.global_position = global_position
	var alert := awareness
	_cone.color = Color(0.55, 0.75, 1.0, 0.09).lerp(Color(1.0, 0.72, 0.35, 0.22), alert)
	_cone_edge.default_color = Color(0.65, 0.85, 1.0, 0.35).lerp(Color(1.0, 0.8, 0.4, 0.8), alert)
	_light.energy = 0.6 + alert * 1.2           # the eyes and lantern brighten as it notices
	_sprite.modulate = Color(1, 1, 1, 0.85 + alert * 0.15)
	if state == State.SUSPICIOUS or state == State.INVESTIGATE:
		_mark.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 180.0))
	else:
		_mark.modulate.a = 1.0
