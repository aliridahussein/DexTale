class_name MistPulse
extends Node2D
## A reusable telegraphed hazard: a band of ground that glows (warning), then
## bursts with mist (danger), then rests. Emits `hit` once per burst if the
## player is inside. Builds its own visuals so it can be dropped anywhere.
##
## Readability (QA-07): soft ambient fog never has hard edges, so the hazard is
## marked by crisp dashed edge lines. They are faint while the lane rests,
## blink faster and faster during the warning, and turn solid on the burst.

signal hit

@export var width := 192.0
@export var height := 22.0
@export var phase := 0.0
@export var period := 3.2
@export var telegraph := 1.1
@export var burst := 0.7

const EDGE_COLOR := Color(0.78, 0.96, 1.0)
const WARN_COLOR := Color(0.42, 0.62, 1.0)
const BURST_COLOR := Color(0.9, 0.98, 1.0)

var active := false
var slow := false

var _t := 0.0
var _state := "off"
var _player_inside := false
var _hit_this_burst := false
var _band: TextureRect
var _edges: Array[TextureRect] = []
var _particles: CPUParticles2D
var _area: Area2D


func _ready() -> void:
	# soft-edged glow band (fades out at the top and bottom)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 32
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_band = TextureRect.new()
	_band.texture = gt
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.stretch_mode = TextureRect.STRETCH_SCALE
	_band.size = Vector2(width, height + 12)
	_band.position = Vector2(-width * 0.5, -(height + 12) * 0.5)
	_band.modulate = Color(WARN_COLOR, 0.0)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.material = add
	add_child(_band)
	# crisp dashed edges along the top and bottom of the danger zone
	var dash := Image.create(6, 1, false, Image.FORMAT_RGBA8)
	for x in 6:
		dash.set_pixel(x, 0, Color(1, 1, 1, 1) if x < 4 else Color(1, 1, 1, 0))
	var dash_tex := ImageTexture.create_from_image(dash)
	for y in [-height * 0.5 - 1.0, height * 0.5]:
		var e := TextureRect.new()
		e.texture = dash_tex
		e.stretch_mode = TextureRect.STRETCH_TILE
		e.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		e.size = Vector2(width, 1)
		e.position = Vector2(-width * 0.5, y)
		e.modulate = Color(EDGE_COLOR, 0.0)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.material = add
		e.z_index = 1
		add_child(e)
		_edges.append(e)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.amount = 46
	_particles.lifetime = 0.9
	_particles.texture = load("res://assets/sprites/fx/mote.png")
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(width * 0.5, height * 0.5)
	_particles.direction = Vector2(0, -1)
	_particles.spread = 50.0
	_particles.gravity = Vector2(0, -20)
	_particles.initial_velocity_min = 8.0
	_particles.initial_velocity_max = 26.0
	_particles.scale_amount_min = 1.0
	_particles.scale_amount_max = 2.5
	_particles.color = Color(0.82, 0.92, 1.0, 0.85)
	_particles.z_index = 2
	add_child(_particles)
	_area = Area2D.new()
	_area.collision_layer = 1 << 6  # hazard
	_area.collision_mask = 1 << 1   # player
	_area.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(func(b: Node) -> void: if b is Player: _player_inside = true)
	_area.body_exited.connect(func(b: Node) -> void: if b is Player: _player_inside = false)
	_set_state("off")


func set_active(on: bool) -> void:
	active = on
	_t = -phase
	_set_state("rest" if on else "off")


func set_slow(on: bool) -> void:
	slow = on


func state() -> String:
	return _state


func _process(delta: float) -> void:
	if not active:
		return
	var per := period * (1.6 if slow else 1.0)
	_t += delta
	if _t < 0.0:
		return
	var c := fposmod(_t, per)
	var warn_start := per - telegraph - burst
	var state := "rest"
	if c >= warn_start + telegraph:
		state = "burst"
	elif c >= warn_start:
		state = "warn"
	if state != _state:
		_set_state(state)
	if _state == "warn":
		var k := (c - warn_start) / telegraph
		_band.modulate.a = 0.06 + 0.3 * k
		# blink faster as the burst approaches: 3 Hz -> 12 Hz
		var hz := lerpf(3.0, 12.0, k)
		var on := fposmod((c - warn_start) * hz, 1.0) < 0.55
		_set_edges(0.95 if on else 0.3)
	elif _state == "burst" and _player_inside and not _hit_this_burst:
		_hit_this_burst = true
		hit.emit()


func _set_edges(alpha: float) -> void:
	for e in _edges:
		e.modulate.a = alpha


func _set_state(s: String) -> void:
	_state = s
	match s:
		"off":
			_band.modulate.a = 0.0
			_set_edges(0.0)
			_particles.emitting = false
		"rest":
			_band.modulate = Color(WARN_COLOR, 0.0)
			_set_edges(0.22)
			_particles.emitting = false
		"warn":
			_band.modulate = Color(WARN_COLOR, 0.06)
			AudioManager.play_sfx("mist_warn", -16.0, 1.0, 0.1)
		"burst":
			_hit_this_burst = false
			_band.modulate = Color(BURST_COLOR, 0.6)
			_set_edges(1.0)
			_particles.emitting = true
			AudioManager.play_sfx("mist_pulse", -9.0, 1.0, 0.1)
			if _player_inside:
				_hit_this_burst = true
				hit.emit()
