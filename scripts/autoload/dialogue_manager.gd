extends Node
## Runs conversations stored as JSON in data/dialogue/*.json.
##
## A conversation is a list of steps. A step is either a line
##   ["pip", "You're late."]
## or a dictionary with exactly one of these keys:
##   {"say": "pip", "text": "..."}           a line (same as the array form)
##   {"label": "name"}                       jump target
##   {"goto": "name"}                        jump
##   {"choice": [ {"text": "...", "goto": "label", "if": cond, "set": {...}, "once": true}, ... ]}
##   {"set": {"flag": value}}                change story flags
##   {"event": "name", "args": [...], "wait": 0.5, "hide": true}
##   {"wait": 0.8}                           dramatic beat (box hidden)
##   {"run": "other_conversation"}           continue in another conversation
##   {"end": true}
## Any step may carry "if": condition (see GameState.check) and is skipped when false.
##
## Events are handled by Callables registered with register_event(). The
## conversation waits for handlers that are coroutines or that return a Signal.

signal started(conversation_id: String)
signal line_shown(speaker_id: String, text: String)
signal choices_shown(options: Array)
signal box_hidden
signal ended(conversation_id: String)

signal _advanced
signal _chosen(index: int)

const DIALOGUE_DIR := "res://data/dialogue/"
const SPEAKERS_PATH := "res://data/speakers.json"
const STEP_KINDS := ["say", "label", "goto", "choice", "set", "event", "wait", "run", "end"]

var conversations: Dictionary = {}
var speakers: Dictionary = {}
## Event names that were triggered without a handler (useful for tests).
var missing_events: Array[String] = []

var _events: Dictionary = {}
var _active := false
var _conv_id := ""
var _steps: Array = []
var _labels: Dictionary = {}
var _ip := 0
var _context: Node = null
var _choice_map: Array = []
var _waiting := ""
var _token := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	load_data()


# ------------------------------------------------------------------ data --
func load_data() -> void:
	conversations.clear()
	var files := DirAccess.get_files_at(DIALOGUE_DIR)
	for file in files:
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_DIR + file))
		if not parsed is Dictionary:
			push_error("DialogueManager: %s is not a JSON object" % file)
			continue
		for id in parsed:
			if str(id).begins_with("_"):
				continue  # comments / metadata
			if conversations.has(id):
				push_error("DialogueManager: duplicate conversation id '%s' (%s)" % [id, file])
			conversations[id] = parsed[id]
	var sp: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPEAKERS_PATH))
	speakers = sp if sp is Dictionary else {}


func has_conversation(id: String) -> bool:
	return conversations.has(id)


func get_speaker(id: String) -> Dictionary:
	return speakers.get(id, {"name": id.capitalize()})


func register_event(event_name: String, handler: Callable) -> void:
	_events[event_name] = handler


func unregister_event(event_name: String) -> void:
	_events.erase(event_name)


# ---------------------------------------------------------------- runtime --
func is_active() -> bool:
	return _active


func current_conversation() -> String:
	return _conv_id if _active else ""


func context() -> Node:
	return _context


func is_waiting_for_advance() -> bool:
	return _active and _waiting == "advance"


func is_waiting_for_choice() -> bool:
	return _active and _waiting == "choice"


func start(id: String, ctx: Node = null) -> bool:
	if _active:
		return false
	if not conversations.has(id):
		push_error("DialogueManager: unknown conversation '%s'" % id)
		return false
	_active = true
	_conv_id = id
	_steps = conversations[id]
	_labels = _index_labels(_steps)
	_ip = 0
	_context = ctx
	_token += 1
	GameState.lock_input("dialogue")
	started.emit(id)
	_run(_token)
	return true


## Called by the dialogue box once the current line is fully shown and the
## player presses advance.
func advance() -> void:
	if _active and _waiting == "advance":
		_waiting = ""
		_advanced.emit()


func choose(index: int) -> void:
	if _active and _waiting == "choice":
		_waiting = ""
		_chosen.emit(index)


## Abort the current conversation (used when leaving a scene).
func stop() -> void:
	if not _active:
		return
	_token += 1
	_waiting = ""
	_advanced.emit()
	_chosen.emit(-1)
	_finish()


func _run(token: int) -> void:
	while _active and token == _token and _ip < _steps.size():
		var step: Variant = _steps[_ip]
		_ip += 1
		if step is Array:
			var arr: Array = step
			if arr.size() >= 2:
				await _say(str(arr[0]), str(arr[1]))
			continue
		if not step is Dictionary:
			continue
		var d: Dictionary = step
		if d.has("if") and not GameState.check(d["if"]):
			continue
		if d.has("say"):
			await _say(str(d["say"]), str(d.get("text", "")))
		elif d.has("label"):
			pass
		elif d.has("goto"):
			_jump(str(d["goto"]))
		elif d.has("choice"):
			await _choice(d)
		elif d.has("set"):
			_apply_set(d["set"])
		elif d.has("event"):
			await _event(d)
		elif d.has("wait"):
			box_hidden.emit()
			await get_tree().create_timer(float(d["wait"])).timeout
		elif d.has("run"):
			var next_id := str(d["run"])
			if conversations.has(next_id):
				_conv_id = next_id
				_steps = conversations[next_id]
				_labels = _index_labels(_steps)
				_ip = 0
		elif d.has("end"):
			break
	if token == _token and _active:
		_finish()


func _finish() -> void:
	var id := _conv_id
	_active = false
	_waiting = ""
	_context = null
	GameState.clear_lock("dialogue")
	ended.emit(id)


func _say(speaker: String, text: String) -> void:
	_waiting = "advance"
	line_shown.emit(speaker, text)
	await _advanced


func _choice(d: Dictionary) -> void:
	var options: Array = []
	_choice_map.clear()
	for opt in d["choice"]:
		if not opt is Dictionary:
			continue
		if opt.has("if") and not GameState.check(opt["if"]):
			continue
		if opt.get("once", false) and GameState.has_flag(_once_flag(opt)):
			continue
		_choice_map.append(opt)
		options.append({"text": str(opt.get("text", "...")), "index": _choice_map.size() - 1})
	if options.is_empty():
		return
	_waiting = "choice"
	choices_shown.emit(options)
	var idx: int = await _chosen
	if idx < 0 or idx >= _choice_map.size():
		return
	var chosen: Dictionary = _choice_map[idx]
	if chosen.get("once", false):
		GameState.set_flag(_once_flag(chosen), true)
	if chosen.has("set"):
		_apply_set(chosen["set"])
	if chosen.has("goto"):
		_jump(str(chosen["goto"]))


func _event(d: Dictionary) -> void:
	var event_name := str(d["event"])
	var args: Array = d.get("args", [])
	if d.get("hide", false):
		box_hidden.emit()
	if _events.has(event_name) and (_events[event_name] as Callable).is_valid():
		# Waits for coroutine handlers and for handlers that return a Signal.
		await (_events[event_name] as Callable).callv(args)
	else:
		push_warning("DialogueManager: no handler for event '%s'" % event_name)
		missing_events.append(event_name)
	if d.has("wait"):
		await get_tree().create_timer(float(d["wait"])).timeout


func _apply_set(values: Variant) -> void:
	if not values is Dictionary:
		return
	for key in values:
		var v: Variant = values[key]
		if v is String and (v as String).begins_with("+"):
			GameState.inc_flag(key, int((v as String).substr(1)))
		else:
			GameState.set_flag(key, v)


func _jump(label: String) -> void:
	if _labels.has(label):
		_ip = int(_labels[label])
	else:
		push_error("DialogueManager: missing label '%s' in '%s'" % [label, _conv_id])
		_ip = _steps.size()


func _once_flag(opt: Dictionary) -> String:
	var key: String = str(opt.get("id", str(opt.get("text", "")).md5_text().substr(0, 8)))
	return "chose_%s_%s" % [_conv_id, key]


static func _index_labels(steps: Array) -> Dictionary:
	var labels := {}
	for i in steps.size():
		var s: Variant = steps[i]
		if s is Dictionary and (s as Dictionary).has("label"):
			labels[str(s["label"])] = i + 1
	return labels


# ------------------------------------------------------------- validation --
## Static checks used by the test suite. Returns human-readable problems.
func validate(known_events: Array = []) -> Array[String]:
	var errors: Array[String] = []
	for id in conversations:
		var steps: Variant = conversations[id]
		if not steps is Array:
			errors.append("%s: conversation is not a list" % id)
			continue
		var labels := {}
		for s in steps:
			if s is Dictionary and (s as Dictionary).has("label"):
				if labels.has(s["label"]):
					errors.append("%s: duplicate label '%s'" % [id, s["label"]])
				labels[s["label"]] = true
		for i in (steps as Array).size():
			var s: Variant = steps[i]
			var where := "%s[%d]" % [id, i]
			if s is Array:
				if (s as Array).size() != 2:
					errors.append("%s: line must be [speaker, text]" % where)
				elif not speakers.has(str(s[0])):
					errors.append("%s: unknown speaker '%s'" % [where, s[0]])
				continue
			if not s is Dictionary:
				errors.append("%s: step must be a list or object" % where)
				continue
			var d: Dictionary = s
			var kinds := STEP_KINDS.filter(func(k: String) -> bool: return d.has(k))
			if kinds.has("event") and kinds.has("wait"):
				kinds.erase("wait")
			if kinds.size() != 1:
				errors.append("%s: step needs exactly one of %s (has %s)" % [where, STEP_KINDS, kinds])
				continue
			if d.has("if"):
				errors.append_array(_validate_condition(d["if"], where))
			match kinds[0]:
				"say":
					if not speakers.has(str(d["say"])):
						errors.append("%s: unknown speaker '%s'" % [where, d["say"]])
				"goto":
					if not labels.has(d["goto"]):
						errors.append("%s: goto unknown label '%s'" % [where, d["goto"]])
				"run":
					if not conversations.has(d["run"]):
						errors.append("%s: run unknown conversation '%s'" % [where, d["run"]])
				"event":
					if not known_events.is_empty() and not known_events.has(d["event"]):
						errors.append("%s: unknown event '%s'" % [where, d["event"]])
				"choice":
					if not d["choice"] is Array or (d["choice"] as Array).is_empty():
						errors.append("%s: choice needs a non-empty list" % where)
						continue
					for opt in d["choice"]:
						if not opt is Dictionary or not (opt as Dictionary).has("text"):
							errors.append("%s: choice option needs text" % where)
							continue
						if opt.has("goto") and not labels.has(opt["goto"]):
							errors.append("%s: option goto unknown label '%s'" % [where, opt["goto"]])
						if opt.has("if"):
							errors.append_array(_validate_condition(opt["if"], where))
	return errors


func _validate_condition(cond: Variant, where: String) -> Array[String]:
	var out: Array[String] = []
	var list: Array = cond if cond is Array else [cond]
	var re := RegEx.new()
	re.compile("^\\s*!?\\s*[A-Za-z0-9_]+\\s*((==|!=|>=|<=|>|<)\\s*\\S+)?\\s*$")
	for c in list:
		if re.search(str(c)) == null:
			out.append("%s: bad condition '%s'" % [where, c])
	return out


## Every flag name referenced by dialogue (for the flag registry test).
func referenced_flags() -> Dictionary:
	var found := {}
	var re := RegEx.new()
	re.compile("[A-Za-z0-9_]+")
	var add_cond := func(cond: Variant) -> void:
		var list: Array = cond if cond is Array else [cond]
		for c in list:
			var m := re.search(str(c))
			if m:
				found[m.get_string()] = true
	for id in conversations:
		for s in conversations[id]:
			if not s is Dictionary:
				continue
			if s.has("if"):
				add_cond.call(s["if"])
			if s.has("set") and s["set"] is Dictionary:
				for k in s["set"]:
					found[k] = true
			if s.has("choice") and s["choice"] is Array:
				for opt in s["choice"]:
					if opt is Dictionary:
						if opt.has("if"):
							add_cond.call(opt["if"])
						if opt.has("set") and opt["set"] is Dictionary:
							for k in opt["set"]:
								found[k] = true
	return found
