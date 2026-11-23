extends GameArea
## The Watchman's Crossing (V2.2): a raised drawbridge over a misty ravine
## between the Mistbound Path and the bell tower.
##
## Bridge states (persistent flags, in order, no skipping):
##   unrepaired -> chain_secured (Hooked Line used on the chain)
##              -> bridge_lowered (winch tension released safely)
## Then the Watchman's Shadow patrols the far bank until Rowan crosses
## (crossing_complete, set by the tower) or its memory is given back
## (watchman_resolved). Being caught only sends Rowan back to the bridge head.

const RAVINE_TOP := 222.0
const RAVINE_BOTTOM := 296.0
const LANE_X := 194.0
const LANE_W := 28.0
const PATROL := [Vector2(112, 196), Vector2(304, 196), Vector2(304, 112), Vector2(112, 112)]
const SHADOW_REST := Vector2(132, 204)       # where it stands aside once at peace
## The Shadow keeps to the far bank: it investigates up to the bridge head and
## looks down the deck, but never walks out over the ravine.
const FAR_BANK := Rect2(20, 96, 380, 118)
const WEAK_PLANKS := [Rect2(195, 250, 13, 5), Rect2(210, 275, 13, 5)]
## Locks this area's own scenes take. If the area is freed mid-scene (title,
## load, restart), they are released so Rowan is never frozen afterwards.
const SCENE_LOCKS := ["repair", "bridge", "token", "watchman_caught"]
const HINTS := [
	"Those stone pillars may be enough to hide the lantern's glow.",
	"With the shutter closed (L), it has to come much closer to see you.",
]

var _lane_shape: CollisionShape2D
var _capturing := false
var _weak_marks: Array[Sprite2D] = []
var _footprints: Array[Sprite2D] = []
var _lantern_frame_t := 0.0

@onready var shadow: WatchmanShadow = $Objects/Watchman
@onready var deck: Node2D = $Decals/BridgeDeck
@onready var raised: Node2D = $Objects/BridgeRaised
@onready var winch_sprite: Sprite2D = $Objects/Winch/Sprite
@onready var weight_sprite: Sprite2D = $Objects/Counterweight/Sprite
@onready var chain_sprite: Sprite2D = $Objects/ChainEnd/Sprite
@onready var post_sprite: Sprite2D = $Objects/WaitingPost/Sprite
@onready var far_lantern: Sprite2D = $Objects/WatchLantern/Sprite
@onready var far_light: PointLight2D = $Lights/FarLanternLight
@onready var chain_target: ItemTarget = $Interactions/ChainUse
@onready var post_target: ItemTarget = $Interactions/PostUse


func _area_ready() -> void:
	GameState.set_flag("entered_crossing", true)
	_migrate_old_save()
	_make_ravine()
	_make_weak_planks()
	_make_footprints()
	shadow.patrol = PackedVector2Array(PATROL)
	shadow.reach = FAR_BANK
	shadow.caught.connect(_on_caught)
	chain_target.item_used.connect(_on_chain_item)
	post_target.item_used.connect(_on_post_item)
	Inventory.lantern_changed.connect(_on_lantern_changed)
	GameState.flag_changed.connect(_on_flag_changed)
	_apply_state()
	_on_lantern_changed(Inventory.lantern_on())


func area_events() -> Dictionary:
	return {
		"winch_puzzle": _winch_puzzle,
		"winch_memory": _winch_memory,
		"post_memory": _post_memory,
	}


func _exit_tree() -> void:
	super._exit_tree()
	for reason in SCENE_LOCKS:
		GameState.clear_lock(reason)


## V1/V2 saves already past this point (inside the tower) never saw the
## crossing. Coming back down from the tower, the bridge is simply down.
func _migrate_old_save() -> void:
	if GameState.current_spawn == "from_tower" and not GameState.has_flag("bridge_lowered"):
		for f in ["chain_secured", "bridge_lowered", "crossing_complete"]:
			GameState.set_flag(f, true)


# ------------------------------------------------------------------ state --
func bridge_state() -> String:
	if GameState.has_flag("bridge_lowered"):
		return "lowered"
	if GameState.has_flag("chain_secured"):
		return "repaired"
	return "unrepaired"


func _apply_state() -> void:
	var lowered := GameState.has_flag("bridge_lowered")
	var secured := GameState.has_flag("chain_secured")
	deck.visible = lowered
	deck.scale = Vector2.ONE
	raised.visible = not lowered
	raised.scale = Vector2.ONE
	_lane_shape.set_deferred("disabled", lowered)
	chain_sprite.frame = 1 if secured else 0
	winch_sprite.frame = 1 if secured else 0
	weight_sprite.frame = 1 if lowered else 0
	post_sprite.frame = 1 if GameState.has_flag("token_placed") else 0
	post_target.auto_use = GameState.has_flag("watchman_promise_known")
	far_lantern.frame = 1 if lowered else 0
	far_light.energy = 1.1 if lowered else 0.0
	if not lowered:
		shadow.set_state(WatchmanShadow.State.DORMANT)
	elif GameState.has_flag("watchman_resolved"):
		shadow.position = SHADOW_REST
		shadow.resolve(SHADOW_REST)
	elif GameState.has_flag("crossing_complete"):
		shadow.be_quiet(PATROL[0])
	else:
		shadow.appear(false)


func _on_flag_changed(flag: String, _v: Variant) -> void:
	if flag == "watchman_promise_known":
		post_target.auto_use = true


func _process(delta: float) -> void:
	# the far lantern flickers once it has been lit
	if GameState.has_flag("bridge_lowered"):
		_lantern_frame_t += delta
		far_lantern.frame = 1 + int(_lantern_frame_t * 5.0) % 2


# ----------------------------------------------------------------- ravine --
## Collision over the ravine. On layer 3 ("bodies"): it stops Rowan, but the
## Shadow's line of sight (layer 1) passes over it, as it would over a gap.
func _make_ravine() -> void:
	var body := StaticBody2D.new()
	body.name = "Ravine"
	body.collision_layer = 1 << 2
	body.collision_mask = 0
	add_child(body)
	var h := RAVINE_BOTTOM - RAVINE_TOP
	for r in [Rect2(-16, RAVINE_TOP, LANE_X + 16, h), Rect2(LANE_X + LANE_W, RAVINE_TOP, 480, h)]:
		body.add_child(_rect_shape(r))
	_lane_shape = _rect_shape(Rect2(LANE_X, RAVINE_TOP, LANE_W, h))
	_lane_shape.name = "BridgeLane"
	body.add_child(_lane_shape)


func _rect_shape(r: Rect2) -> CollisionShape2D:
	var s := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	s.shape = shape
	s.position = r.get_center()
	return s


func lane_blocked() -> bool:
	return not _lane_shape.disabled


# ------------------------------------------------------------ weak planks --
## Two rotten half-planks: stepping on one creaks, and the Shadow comes to
## look. The lantern shows them clearly; in the dark they are hard to see.
func _make_weak_planks() -> void:
	for r in WEAK_PLANKS:
		var a := Area2D.new()
		a.collision_layer = 0
		a.collision_mask = 1 << 1
		a.monitorable = false
		a.position = r.get_center()
		a.add_child(_rect_shape(Rect2(-r.size / 2.0, r.size)))
		a.body_entered.connect(func(b: Node) -> void:
			if b is Player:
				_creak(a.global_position))
		add_child(a)
		var mark := Sprite2D.new()
		mark.texture = preload("res://assets/sprites/props/weak_plank.png")
		mark.position = r.get_center()
		mark.modulate.a = 0.0
		mark.z_index = 1
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mark.material = add
		$Decals.add_child(mark)
		_weak_marks.append(mark)


func _creak(at: Vector2) -> void:
	if not GameState.has_flag("bridge_lowered"):
		return
	AudioManager.play_sfx("creak", -2.0, 1.0, 0.1)
	camera().shake(1.0, 0.25)
	if shadow.is_hostile():
		shadow.hear(at)
		if not GameState.has_flag("heard_creak"):
			GameState.set_flag("heard_creak", true)
			UI.caption("The plank creaks. Something on the far bank turns.", at + Vector2(0, -20), 2.2)


## Faint footprints along the Shadow's round, shown only by lantern light.
func _make_footprints() -> void:
	var img := Image.create(3, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.7, 0.9, 1.0, 1.0))
	img.set_pixel(0, 3, Color(0, 0, 0, 0))
	img.set_pixel(2, 0, Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	for i in PATROL.size():
		var a: Vector2 = PATROL[i]
		var b: Vector2 = PATROL[(i + 1) % PATROL.size()]
		var n := int(a.distance_to(b) / 22.0)
		for k in n:
			var s := Sprite2D.new()
			s.texture = tex
			s.position = a.lerp(b, float(k) / n) + Vector2(0, 2 if k % 2 else -2)
			s.modulate = Color(1, 1, 1, 0)
			s.z_index = 1
			$Decals.add_child(s)
			_footprints.append(s)


func _on_lantern_changed(on: bool) -> void:
	var player := get_player()
	if player:
		player.refresh_light()
	var show := on and GameState.has_flag("bridge_lowered")
	for m in _weak_marks:  # the rotten planks only exist once the deck is down
		create_tween().tween_property(m, "modulate:a", 0.9 if show else 0.0, 0.3)
	for f in _footprints:
		create_tween().tween_property(f, "modulate:a", 0.35 if show else 0.0, 0.4)


# ----------------------------------------------------------------- repair --
func _on_chain_item(item_id: String, _by: Node) -> void:
	if item_id != "hooked_line" or GameState.has_flag("chain_secured"):
		return
	await _repair_chain()


## The hook goes down over the edge, catches the lower chain, and the chain
## is hauled up and lashed back onto the winch's drum.
func _repair_chain() -> void:
	GameState.lock_input("repair")
	var player := get_player()
	player.face_toward(chain_sprite.global_position)
	var start := player.global_position + Vector2(0, -10)
	var catch := chain_sprite.global_position + Vector2(-5, 2)
	var line := Line2D.new()
	line.width = 1.0
	line.default_color = Color("#cc9a3a")
	line.z_index = 5
	add_child(line)
	var hook := Sprite2D.new()
	hook.texture = preload("res://assets/sprites/props/item_hook.png")
	hook.z_index = 6
	add_child(hook)
	AudioManager.play_sfx("wind_gust", -16.0)
	var throw_step := func(t: float) -> void:
		var p := start.lerp(catch, t) + Vector2(0, -sin(t * PI) * 18.0)
		hook.position = p
		line.points = PackedVector2Array([start, p])
	var throw := create_tween()
	throw.tween_method(throw_step, 0.0, 1.0, 0.7)
	await throw.finished
	AudioManager.play_sfx("clank", -2.0)
	_burst(catch, Color("#ffe7a0"), 10)      # sparks as the hook bites
	camera().shake(1.5, 0.3)
	await get_tree().create_timer(0.3).timeout
	# haul it up: the line pulls tight toward the winch
	var drum := winch_sprite.global_position + Vector2(-2, -20)
	var haul_step := func(t: float) -> void:
		var p := catch.lerp(drum, t)
		hook.position = p
		line.points = PackedVector2Array([catch, p])
	var haul := create_tween()
	haul.tween_method(haul_step, 0.0, 1.0, 0.8)
	await haul.finished
	AudioManager.play_sfx("chain_rattle", -2.0)
	GameState.set_flag("chain_secured", true)   # the Hooked Line is now part of the mechanism
	chain_sprite.frame = 1
	winch_sprite.frame = 1
	_burst(drum, Color("#b0a090"), 12)        # dust from the drum
	hook.queue_free()
	var fade := create_tween()
	fade.tween_property(line, "modulate:a", 0.0, 0.5)
	fade.tween_callback(line.queue_free)
	GameState.unlock_input("repair")
	UI.caption("The hook bites. The chain is lashed back onto the winch.", drum + Vector2(0, -26), 2.6)


func _burst(at: Vector2, color: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.7
	p.texture = preload("res://assets/sprites/fx/px2.png")
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.gravity = Vector2(0, 90)
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.color = color
	p.z_index = 7
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ winch --
## Event from the winch conversation once the chain is secured.
func _winch_puzzle() -> void:
	if bridge_state() != "repaired":
		return  # never lower an unrepaired bridge, never lower it twice
	var ok: bool = await UI.open_winch()
	if not ok:
		return
	GameState.set_flag("bridge_lowered", true)  # saved state first; the rest is the show
	GameState.lock_input("bridge")
	await _lower_bridge()
	await _reveal_shadow()
	GameState.unlock_input("bridge")


func _lower_bridge() -> void:
	var cam := camera()
	await cam.pan_to(Vector2(208, 268), 0.8)
	AudioManager.play_sfx("chain_rattle", 0.0)
	var turning := create_tween().set_loops(6)
	turning.tween_callback(func() -> void: winch_sprite.frame = 2)
	turning.tween_interval(0.14)
	turning.tween_callback(func() -> void: winch_sprite.frame = 3)
	turning.tween_interval(0.14)
	weight_sprite.frame = 1
	deck.visible = true
	deck.scale = Vector2(1, 0.02)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(raised, "scale:y", 0.02, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(deck, "scale:y", 1.0, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await fall.finished
	raised.visible = false
	winch_sprite.frame = 1
	AudioManager.play_sfx("bridge_thud", 0.0)
	cam.shake(4.0, 0.6)
	for x in [196.0, 208.0, 220.0]:
		_burst(Vector2(x, 216), Color("#8a7a66"), 8)
	_lane_shape.set_deferred("disabled", true)
	await get_tree().create_timer(0.6).timeout
	await cam.pan_reset(0.8)


## The wind drops, the lantern across the ravine lights itself, and a figure
## that was not there before begins to walk.
func _reveal_shadow() -> void:
	AudioManager.play_ambience("", 2.5)
	await get_tree().create_timer(1.0).timeout
	AudioManager.play_sfx("lantern", -2.0, 0.8)
	far_lantern.frame = 1
	create_tween().tween_property(far_light, "energy", 1.1, 0.8)
	await get_tree().create_timer(0.6).timeout
	AudioManager.play_sfx("sentinel", -6.0, 0.8)
	shadow.appear(true)
	_on_lantern_changed(Inventory.lantern_on())
	await get_tree().create_timer(1.2).timeout
	var text := "Something on the other side has noticed your light." if Inventory.lantern_on() \
		else "Something on the other side is watching the bridge."
	UI.caption(text, get_player().global_position + Vector2(0, -34), 3.2)


# ---------------------------------------------------------------- capture --
func _on_caught() -> void:
	if _capturing:
		return
	_capturing = true
	GameState.lock_input("watchman_caught")
	SaveManager.block_saving("watchman_caught", self)
	AudioManager.play_sfx("shadow_alert", 0.0, 0.6)
	SceneManager.flash(Color(0.65, 0.8, 1.0), 0.8, 0.75)
	UI.play_echo_effect(0.4)
	await SceneManager.fade_to(1.0, 0.45)
	var player := get_player()
	player.teleport(get_spawn_position("checkpoint"))
	player.face("up")
	shadow.reset_patrol()
	var n := GameState.inc_flag("watchman_catches")
	await SceneManager.fade_to(0.0, 0.45)
	GameState.unlock_input("watchman_caught")
	SaveManager.unblock_saving("watchman_caught")
	_capturing = false
	if n >= 2:
		UI.caption(HINTS[mini(n - 2, HINTS.size() - 1)], player.global_position + Vector2(0, -34), 3.4)
	else:
		UI.caption("The cold lets go of you at the bridge head.", player.global_position + Vector2(0, -34), 2.4)


func is_capturing() -> bool:
	return _capturing


# --------------------------------------------- the last promise (optional) --
func _on_post_item(item_id: String, _by: Node) -> void:
	if item_id != "token" or GameState.has_flag("watchman_resolved"):
		return
	var at := post_sprite.global_position + Vector2(0, -42)
	if not GameState.has_flag("watchman_promise_known"):
		UI.caption("Not yet. What was he waiting for?", at, 2.4)
		return
	if not GameState.has_flag("bridge_lowered"):
		UI.caption("There's no one on the far side to see it. Not yet.", at, 2.4)
		return
	await _place_token()


## The token goes back on the post where he waited. The Shadow stops, its
## eyes dim, and for a moment it sees who it was waiting for.
func _place_token() -> void:
	GameState.lock_input("token")
	AudioManager.play_sfx("item", -4.0)
	GameState.set_flag("token_placed", true)
	post_sprite.frame = 1
	await get_tree().create_timer(0.6).timeout
	shadow.set_state(WatchmanShadow.State.RESOLVED)
	shadow.facing = (post_sprite.global_position - shadow.global_position).normalized()
	var cam := camera()
	await cam.pan_to((shadow.global_position + post_sprite.global_position) * 0.5, 1.0)
	AudioManager.play_sfx("memory_warm", -3.0)
	UI.play_echo_effect(3.0)
	var child := Sprite2D.new()
	child.texture = preload("res://assets/sprites/fx/echo_figure.png")
	child.scale = Vector2(0.65, 0.65)
	child.position = shadow.position + Vector2(18, 4)
	child.modulate = Color(1.0, 0.85, 0.6, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	child.material = add
	child.z_index = 8
	add_child(child)
	var t := create_tween()
	t.tween_property(child, "modulate:a", 0.85, 1.0)
	t.tween_interval(1.6)
	t.tween_property(child, "modulate:a", 0.0, 1.2)
	t.tween_callback(child.queue_free)
	await get_tree().create_timer(1.2).timeout
	shadow.resolve(SHADOW_REST)
	GameState.set_flag("watchman_resolved", true)
	await get_tree().create_timer(1.6).timeout
	await cam.pan_reset(1.0)
	GameState.unlock_input("token")
	DialogueManager.start("watch_resolved")


# ------------------------------------------------------- echo sequences --
## Winch Echo: a guard catches the loose chain with a hook, then turns the
## wheel, and the bridge comes down. Shown, not told.
func _winch_memory() -> Signal:
	var ghosts: Array[CanvasItem] = []
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var guard := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/sprites/characters/watchman.png")
	at.region = Rect2(0, 0, 24, 32)
	guard.texture = at
	guard.position = Vector2(236, 316)
	guard.material = add
	guard.modulate = Color(0.6, 0.85, 1.0, 0.0)
	guard.z_index = 8
	add_child(guard)
	ghosts.append(guard)
	var hook := Sprite2D.new()
	hook.texture = preload("res://assets/sprites/props/item_hook.png")
	hook.material = add
	hook.modulate = Color(0.7, 0.9, 1.0, 0.0)
	hook.position = Vector2(236, 312)
	hook.z_index = 9
	add_child(hook)
	ghosts.append(hook)
	var ghost_deck := Sprite2D.new()
	ghost_deck.texture = preload("res://assets/sprites/props/drawbridge_deck.png")
	ghost_deck.centered = false
	ghost_deck.offset = Vector2(-18, -92)
	ghost_deck.position = Vector2(208, 306)
	ghost_deck.scale = Vector2(1, 0.02)
	ghost_deck.material = add
	ghost_deck.modulate = Color(0.55, 0.8, 1.0, 0.0)
	ghost_deck.z_index = 1
	add_child(ghost_deck)
	ghosts.append(ghost_deck)
	var t := create_tween()
	t.tween_property(guard, "modulate:a", 0.8, 0.5)
	# 1. the hook drops over the edge and catches the chain
	t.tween_property(hook, "modulate:a", 0.9, 0.2)
	t.tween_property(hook, "position", Vector2(232, 300), 0.5)
	t.tween_callback(func() -> void: AudioManager.play_sfx("clank", -12.0, 1.2))
	t.tween_property(hook, "position", Vector2(252, 318), 0.6)
	# 2. the guard moves to the wheel and turns it
	t.parallel().tween_property(guard, "position", Vector2(272, 330), 0.6)
	t.tween_callback(func() -> void: AudioManager.play_sfx("winch_click", -10.0))
	# 3. the bridge lowers
	t.tween_property(ghost_deck, "modulate:a", 0.55, 0.2)
	t.parallel().tween_property(ghost_deck, "scale:y", 1.0, 1.4).set_ease(Tween.EASE_IN)
	t.tween_interval(0.6)
	t.tween_property(guard, "modulate:a", 0.0, 0.9)
	t.parallel().tween_property(hook, "modulate:a", 0.0, 0.9)
	t.parallel().tween_property(ghost_deck, "modulate:a", 0.0, 0.9)
	t.tween_callback(func() -> void:
		for g in ghosts:
			g.queue_free())
	return t.finished


## Post Echo: someone waiting by the post; a small figure on the road; the
## bell; a flicker; nothing. No explanation.
func _post_memory() -> Signal:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var guard := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = preload("res://assets/sprites/characters/watchman.png")
	at.region = Rect2(0, 64, 24, 32)   # seen from the side, facing the road
	guard.texture = at
	guard.position = Vector2(184, 314)
	guard.material = add
	guard.modulate = Color(0.6, 0.85, 1.0, 0.0)
	guard.z_index = 8
	add_child(guard)
	var child := Sprite2D.new()
	child.texture = preload("res://assets/sprites/fx/echo_figure.png")
	child.scale = Vector2(0.6, 0.6)
	child.position = Vector2(208, 400)
	child.material = add
	child.modulate = Color(0.75, 0.9, 1.0, 0.0)
	child.z_index = 8
	add_child(child)
	var t := create_tween()
	t.tween_property(guard, "modulate:a", 0.8, 0.6)
	t.tween_property(child, "modulate:a", 0.7, 0.4)
	t.parallel().tween_property(child, "position", Vector2(208, 352), 1.6)
	t.tween_callback(func() -> void:
		AudioManager.play_sfx("bell_toll_far", -2.0)
		SceneManager.flash(Color(0.8, 0.9, 1.0), 0.5, 0.55))
	for k in 3:   # a flicker, then gone
		t.tween_property(child, "modulate:a", 0.1, 0.08)
		t.tween_property(child, "modulate:a", 0.6, 0.08)
	t.tween_property(child, "modulate:a", 0.0, 0.1)
	t.tween_interval(0.5)
	t.tween_property(guard, "modulate:a", 0.0, 1.0)
	t.tween_callback(func() -> void:
		guard.queue_free()
		child.queue_free())
	return t.finished
