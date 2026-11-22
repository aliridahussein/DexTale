extends Node
## Persistent UI (autoload "UI"): HUD, prompts, toasts, dialogue box, journal,
## documents, pause and settings. Also owns the Echo screen effect.
##
## Gameplay code talks to the UI only through the small public API below.

const KEY_ICONS := {
	"interact": preload("res://assets/sprites/ui/key_e.png"),
	"echo": preload("res://assets/sprites/ui/key_f.png"),
}

var _gameplay_hud := false
var _focus: Node = null
var _echo_focus: Node = null
var _toast_queue: Array = []
var _toast_busy := false
var _echo_tween: Tween

@onready var hud: Control = %Hud
@onready var objective_box: Control = %Objective
@onready var objective_label: Label = %ObjectiveLabel
@onready var prompt: Control = %Prompt
@onready var prompt_label: Label = %PromptLabel
@onready var echo_prompt: Control = %EchoPrompt
@onready var toast_box: Control = %Toast
@onready var toast_label: Label = %ToastLabel
@onready var toast_icon: TextureRect = %ToastIcon
@onready var area_title: Control = %AreaTitle
@onready var area_title_label: Label = %AreaTitleLabel
@onready var area_sub_label: Label = %AreaSubLabel
@onready var save_note: Control = %SaveNote
@onready var echo_overlay: ColorRect = %EchoOverlay
@onready var vignette: TextureRect = %Vignette
@onready var dialogue_box: Control = %DialogueBox
@onready var journal: Control = %Journal
@onready var document_view: Control = %DocumentView
@onready var pause_menu: Control = %PauseMenu
@onready var settings_menu: Control = %SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	prompt.visible = false
	echo_prompt.visible = false
	toast_box.visible = false
	area_title.visible = false
	save_note.visible = false
	echo_overlay.visible = false
	set_gameplay_hud(false)
	QuestManager.objective_changed.connect(_on_objective_changed)
	QuestManager.journal_updated.connect(_on_journal_updated)
	SaveManager.saved.connect(_on_saved)
	Settings.changed.connect(_refresh_objective)
	GameState.flag_changed.connect(func(_f: String, _v: Variant) -> void: _refresh_objective())
	_register_global_events()


# ------------------------------------------------------------------- HUD --
func set_gameplay_hud(on: bool) -> void:
	_gameplay_hud = on
	hud.visible = on
	vignette.visible = on
	if not on:
		set_interact_focus(null)
		set_echo_focus(null)
	_refresh_objective()


func is_gameplay_hud() -> bool:
	return _gameplay_hud


func _refresh_objective() -> void:
	var p := QuestManager.get_primary()
	objective_label.text = str(p.get("title", ""))
	objective_box.reset_size()
	objective_box.visible = _gameplay_hud and Settings.show_objective and objective_label.text != ""


func _on_objective_changed(objective: Dictionary) -> void:
	_refresh_objective()
	if _gameplay_hud:
		show_toast("New objective: " + str(objective.get("title", "")), "bell")


func _on_journal_updated(entry: Dictionary) -> void:
	if _gameplay_hud:
		show_toast("Journal: " + str(entry.get("title", "")), "quill")


func _on_saved() -> void:
	save_note.visible = true
	save_note.modulate.a = 1.0
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(save_note, "modulate:a", 0.0, 0.6)
	t.tween_callback(func() -> void: save_note.visible = false)


# --------------------------------------------------------------- prompts --
func set_interact_focus(target: Node) -> void:
	_focus = target
	if target and "prompt" in target:
		prompt_label.text = str(target.get("prompt"))
	prompt.visible = target != null and _gameplay_hud


func set_echo_focus(target: Node) -> void:
	_echo_focus = target
	echo_prompt.visible = target != null and _gameplay_hud


func hide_prompts() -> void:
	set_interact_focus(null)
	set_echo_focus(null)


func _process(_delta: float) -> void:
	var busy := DialogueManager.is_active() or GameState.is_input_locked() or is_menu_open()
	if _focus and is_instance_valid(_focus) and _gameplay_hud and not busy:
		prompt.visible = true
		_place_over(prompt, _focus.call("get_prompt_position"))
	else:
		prompt.visible = false
	if _echo_focus and is_instance_valid(_echo_focus) and _gameplay_hud and not busy:
		echo_prompt.visible = true
		var pos: Vector2 = _echo_focus.call("get_prompt_position")
		if prompt.visible:
			pos.y -= 13.0
		_place_over(echo_prompt, pos)
	else:
		echo_prompt.visible = false


func _place_over(c: Control, world_pos: Vector2) -> void:
	var vp := get_viewport()
	var screen := vp.get_canvas_transform() * world_pos
	var size := c.size
	var p := (screen - Vector2(size.x * 0.5, size.y)).round()
	p.x = clampf(p.x, 2.0, 478.0 - size.x)
	p.y = clampf(p.y, 2.0, 268.0 - size.y)
	c.position = p


# ---------------------------------------------------------------- toasts --
func show_toast(text: String, icon: String = "") -> void:
	_toast_queue.append([text, icon])
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		toast_box.visible = false
		return
	_toast_busy = true
	var item: Array = _toast_queue.pop_front()
	toast_label.text = item[0]
	var icon_name: String = item[1]
	var path := "res://assets/sprites/ui/icon_%s.png" % icon_name
	toast_icon.visible = icon_name != "" and ResourceLoader.exists(path)
	if toast_icon.visible:
		toast_icon.texture = load(path)
	toast_box.visible = true
	toast_box.modulate.a = 0.0
	toast_box.reset_size()
	await get_tree().process_frame
	toast_box.reset_size()
	toast_box.position.x = round((480.0 - toast_box.size.x) * 0.5)
	var t := create_tween()
	t.tween_property(toast_box, "modulate:a", 1.0, 0.25)
	t.tween_interval(2.1)
	t.tween_property(toast_box, "modulate:a", 0.0, 0.4)
	await t.finished
	_next_toast()


func show_area_title(title: String, sub: String = "") -> void:
	area_title_label.text = title
	area_sub_label.text = sub
	area_sub_label.visible = sub != ""
	area_title.visible = true
	area_title.modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(area_title, "modulate:a", 1.0, 0.8)
	t.tween_interval(2.2)
	t.tween_property(area_title, "modulate:a", 0.0, 1.0)
	t.tween_callback(func() -> void: area_title.visible = false)


# ------------------------------------------------------------ echo effect --
func play_echo_effect(hold: float = 1.6) -> void:
	var mat := echo_overlay.material as ShaderMaterial
	echo_overlay.visible = true
	if _echo_tween and _echo_tween.is_valid():
		_echo_tween.kill()
	_echo_tween = create_tween()
	_echo_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 0.0, 1.0, 0.25)
	_echo_tween.tween_interval(hold)
	_echo_tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("strength", v), 1.0, 0.0, 0.7)
	_echo_tween.tween_callback(func() -> void: echo_overlay.visible = false)


# ------------------------------------------------------------------ menus --
func is_menu_open() -> bool:
	return journal.visible or document_view.visible or pause_menu.visible or settings_menu.visible


func open_document(doc_id: String) -> Signal:
	return document_view.call("open", doc_id)


func open_journal() -> void:
	journal.call("open")


func open_pause() -> void:
	pause_menu.call("open")


func open_settings(return_to: Control = null) -> void:
	settings_menu.call("open", return_to)


func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_hud or SceneManager.transitioning:
		return
	if event.is_action_pressed("pause"):
		if is_menu_open():
			return  # menus close themselves
		get_viewport().set_input_as_handled()
		open_pause()
	elif event.is_action_pressed("journal"):
		if is_menu_open() or DialogueManager.is_active() or GameState.is_input_locked():
			return
		get_viewport().set_input_as_handled()
		open_journal()


# -------------------------------------------------- global dialogue events --
func _register_global_events() -> void:
	DialogueManager.register_event("toast", func(text: String, icon: String = "") -> void: show_toast(text, icon))
	DialogueManager.register_event("sfx", func(n: String, vol: float = 0.0) -> void: AudioManager.play_sfx(n, vol))
	DialogueManager.register_event("music", func(track: String, fade: float = 2.0) -> void: AudioManager.play_music(track, fade))
	DialogueManager.register_event("ambience", func(track: String, fade: float = 2.0) -> void: AudioManager.play_ambience(track, fade))
	DialogueManager.register_event("shake", _event_shake)
	DialogueManager.register_event("flash", func(c: String = "#ffffff", d: float = 0.6) -> void: SceneManager.flash(Color(c), d))
	DialogueManager.register_event("open_document", func(doc: String) -> Signal: return open_document(doc))
	DialogueManager.register_event("fade_out", func(d: float = 0.6) -> Signal: return SceneManager.fade_to(1.0, d))
	DialogueManager.register_event("fade_in", func(d: float = 0.6) -> Signal: return SceneManager.fade_to(0.0, d))
	DialogueManager.register_event("echo_effect", func(hold: float = 1.6) -> void: play_echo_effect(hold))


func _event_shake(strength: float = 3.0, duration: float = 0.5) -> void:
	var area := SceneManager.current_area
	if area and is_instance_valid(area) and area.has_method("camera"):
		var cam: GameCamera = area.call("camera")
		if cam:
			cam.shake(strength, duration)
