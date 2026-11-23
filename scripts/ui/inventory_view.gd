extends Control
## Inventory screen (I), V2.2. Eight slots on dark leather, the selected
## item's name and description, and its actions: Inspect, Hold (to use on
## something in the world), Combine, and the lantern's shutter. Actions an
## item doesn't support are shown greyed out and say why if chosen.
##
## Keys: arrows / WASD move, E or Enter selects, Esc goes back, I closes.
## Mouse: click a slot, click an action. The game is paused while open, so
## nothing reaches Rowan.

const COLS := 4
const SLOTS := 8
const SLOT := 30
const GAP := 4
const GOLD := Color("#e8c86e")
const GOLD_DIM := Color("#8c6826")
const CREAM := Color("#ebdec7")
const GREY := Color("#6e6482")
const ACTION_IDS := ["inspect", "hold", "combine", "light"]

enum Mode { GRID, ACTIONS, COMBINE }

var mode := Mode.GRID
var cursor := 0
var action_cursor := 0
var combine_from := ""
var _items: Array[String] = []
var _flash_slot := -1
var _flash_t := 0.0
var _icons: Dictionary = {}

@onready var slots: Control = %Slots
@onready var name_label: Label = %InvName
@onready var desc_label: RichTextLabel = %InvDesc
@onready var message: RichTextLabel = %InvMessage
@onready var hint: Label = %InvHint
@onready var action_labels: Array[Label] = [%ActInspect, %ActHold, %ActCombine, %ActLight]


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	slots.draw.connect(_draw_slots)
	slots.gui_input.connect(_on_slots_input)
	for i in action_labels.size():
		var l := action_labels[i]
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if mode == Mode.GRID and selected() != "":
					mode = Mode.ACTIONS
				if mode == Mode.ACTIONS:
					action_cursor = i
					do_action(ACTION_IDS[i]))
	Inventory.changed.connect(func() -> void:
		if visible:
			_reload())


func open() -> void:
	_reload()
	mode = Mode.GRID
	combine_from = ""
	cursor = clampi(cursor, 0, maxi(_items.size() - 1, 0))
	message.text = "" if not _items.is_empty() else "[color=#9a8eaa]You aren't carrying anything useful yet.[/color]"
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("page", -8.0)
	_refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("page", -12.0, 0.8)


func selected() -> String:
	return _items[cursor] if cursor >= 0 and cursor < _items.size() else ""


func _reload() -> void:
	_items = Inventory.owned()
	if cursor >= _items.size():
		cursor = maxi(_items.size() - 1, 0)
	_refresh()


# ---------------------------------------------------------------- actions --
func action_enabled(action: String, id: String) -> bool:
	return id != "" and Inventory.can(id, action)


func do_action(action: String) -> void:
	var id := selected()
	if id == "":
		return
	if not action_enabled(action, id):
		var why := {"inspect": "There's nothing more to see.", "hold": "That isn't something to use on anything.",
			"combine": "That doesn't go with anything.", "light": "Only a lantern can be lit."}
		_say("[color=#9a8eaa]%s[/color]" % why.get(action, "You can't do that."))
		AudioManager.play_sfx("ui_back", -10.0)
		return
	match action:
		"inspect":
			_inspect(id)
		"hold":
			if Inventory.held == id:
				Inventory.clear_held()
				_say("You put the %s away." % Inventory.item_name(id))
			else:
				Inventory.set_held(id)
				AudioManager.play_sfx("ui_confirm", -8.0)
				close()  # walk to where it should go and press E
				return
		"combine":
			combine_from = id
			mode = Mode.COMBINE
			_say("Combine the %s with...?" % Inventory.item_name(id))
		"light":
			var on := Inventory.toggle_lantern()
			AudioManager.play_sfx("lantern", -6.0)
			_say("You slide the shutter open. Warm light spills out." if on else "You close the shutter. The light is hidden.")
	_refresh()


func _inspect(id: String) -> void:
	var recon := str(Inventory.def(id).get("inspect_reconstruction", ""))
	if recon != "" and not GameState.has_flag("watchman_promise_known"):
		# the token: inspecting it again lays out what you know about it
		close()
		UI.inspect_token(recon)
		return
	_say(str(Inventory.def(id).get("inspect", Inventory.def(id).get("description", ""))))


## Combine the chosen first item with the item at the cursor.
func combine_with_selected() -> Dictionary:
	var b := selected()
	var result := Inventory.combine(combine_from, b)
	mode = Mode.GRID
	combine_from = ""
	if result["ok"]:
		AudioManager.play_sfx("item_get", -4.0)
		_items = Inventory.owned()
		var idx := _items.find(str(result["result"]))
		if idx >= 0:
			cursor = idx
			_flash_slot = idx
			_flash_t = 1.0
		_say("[color=#e8c86e]%s[/color]\n%s" % [Inventory.item_name(str(result["result"])), result["text"]])
	else:
		AudioManager.play_sfx("ui_back", -8.0)
		_say(str(result["text"]))
	_refresh()
	return result


func _say(text: String) -> void:
	message.text = text


# ------------------------------------------------------------------ input --
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("inventory"):
		close()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if mode == Mode.GRID:
			close()
		else:
			mode = Mode.GRID
			combine_from = ""
			_say("")
			AudioManager.play_sfx("ui_back", -10.0)
			_refresh()
		return
	var dx := 0
	var dy := 0
	if event.is_action_pressed("move_left", true) or event.is_action_pressed("ui_left", true):
		dx = -1
	elif event.is_action_pressed("move_right", true) or event.is_action_pressed("ui_right", true):
		dx = 1
	elif event.is_action_pressed("move_up", true) or event.is_action_pressed("ui_up", true):
		dy = -1
	elif event.is_action_pressed("move_down", true) or event.is_action_pressed("ui_down", true):
		dy = 1
	var confirm := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if mode == Mode.ACTIONS:
		if dx != 0:
			action_cursor = posmod(action_cursor + dx, ACTION_IDS.size())
			AudioManager.play_sfx("ui_move", -14.0)
			_refresh()
		elif confirm:
			do_action(ACTION_IDS[action_cursor])
		return
	if dx != 0 or dy != 0:
		move_cursor(dx, dy)
	elif confirm:
		select()


func move_cursor(dx: int, dy: int) -> void:
	var c := cursor % COLS + dx
	var r := cursor / COLS + dy
	c = posmod(c, COLS)
	r = posmod(r, SLOTS / COLS)
	cursor = r * COLS + c
	AudioManager.play_sfx("ui_move", -14.0)
	_refresh()


## E on a slot: open its actions, or finish a combination.
func select() -> void:
	if selected() == "":
		return
	if mode == Mode.COMBINE:
		if selected() == combine_from:
			_say("Choose a different item to combine with.")
			return
		combine_with_selected()
		return
	mode = Mode.ACTIONS
	action_cursor = 0
	AudioManager.play_sfx("ui_confirm", -12.0)
	_refresh()


func _on_slots_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = ev.position
	var c := int(p.x / (SLOT + GAP))
	var r := int(p.y / (SLOT + GAP))
	var i := r * COLS + c
	if i < 0 or i >= SLOTS:
		return
	if i == cursor and selected() != "":
		select()
	else:
		cursor = i
		if mode == Mode.ACTIONS:
			mode = Mode.GRID
		_refresh()


# ---------------------------------------------------------------- drawing --
func _process(delta: float) -> void:
	if visible and _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta * 1.5)
		slots.queue_redraw()


func _refresh() -> void:
	var id := selected()
	name_label.text = Inventory.item_name(id) if id != "" else ""
	desc_label.text = str(Inventory.def(id).get("description", "")) if id != "" else ""
	for i in action_labels.size():
		var a: String = ACTION_IDS[i]
		var l := action_labels[i]
		var text: String = {"inspect": "Inspect", "hold": "Hold", "combine": "Combine", "light": "Shutter"}[a]
		if a == "hold" and id != "" and Inventory.held == id:
			text = "Put away"
		if a == "light" and id == "old_lantern":
			text = "Close shutter" if Inventory.lantern_on() else "Open shutter"
		var enabled := action_enabled(a, id)
		var current := mode == Mode.ACTIONS and action_cursor == i
		l.text = ("▶ " if current else "  ") + text
		l.add_theme_color_override("font_color", GOLD if current and enabled else (CREAM if enabled else GREY))
	match mode:
		Mode.GRID:
			hint.text = "Arrows: choose    E: select    I / Esc: close"
		Mode.ACTIONS:
			hint.text = "Left/Right: action    E: do it    Esc: back"
		Mode.COMBINE:
			hint.text = "Choose the second item    E: combine    Esc: cancel"
	slots.queue_redraw()


func _icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := str(Inventory.def(id).get("icon", ""))
		_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _icons[id]


func _draw_slots() -> void:
	for i in SLOTS:
		var r := Rect2((i % COLS) * (SLOT + GAP), (i / COLS) * (SLOT + GAP), SLOT, SLOT)
		slots.draw_rect(r, Color(0.04, 0.03, 0.06, 0.85))
		slots.draw_rect(r, GOLD_DIM, false, 1.0)
		if i < _items.size():
			var tex := _icon(_items[i])
			if tex:
				var s := tex.get_size()
				slots.draw_texture(tex, (r.position + (r.size - s) * 0.5).round())
			if _items[i] == Inventory.held:
				slots.draw_rect(Rect2(r.position + Vector2(2, SLOT - 4), Vector2(SLOT - 4, 2)), GOLD)
			if _items[i] == combine_from:
				slots.draw_rect(r.grow(-2), Color("#9ad8f0"), false, 1.0)
		if i == _flash_slot and _flash_t > 0.0:
			slots.draw_rect(r, Color(1.0, 0.9, 0.6, 0.45 * _flash_t))
		if i == cursor:
			var c := GOLD if mode != Mode.COMBINE else Color("#9ad8f0")
			slots.draw_rect(r.grow(1), c, false, 1.0)
			slots.draw_rect(r.grow(2), Color(c, 0.35), false, 1.0)
