extends Node
## Minimal test runner. Run headless:
##   godot --headless --path . res://tests/test_runner.tscn
## Optional filters:  -- --suite=test_data   -- --test=sneaking (method names containing it)
## Each suite is a script in res://tests/ named test_*.gd with methods test_*().
## Test methods may be coroutines (use await). Exit code: 0 = all passed.

const SUITES := [
	"res://tests/test_data.gd",
	"res://tests/test_state.gd",
	"res://tests/test_puzzle.gd",
	"res://tests/test_scenes.gd",
	"res://tests/test_save.gd",
	"res://tests/test_ui.gd",
	"res://tests/test_endings.gd",
	"res://tests/test_v2.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_crossing.gd",
	"res://tests/test_playthrough.gd",
]

## Counts engine/script errors so a crashing test is reported as a failure.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == 1:  # warnings are fine
			return
		count += 1
		last = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass


var errors := ErrorCounter.new()
## A test may call runner.allow_errors(n) when it deliberately triggers engine errors.
var _allowed := 0
var passed := 0
var failed := 0
var failures: Array[String] = []
var _current := ""


func _ready() -> void:
	OS.add_logger(errors)
	# Integration tests change scenes; stop being the "current scene" so the
	# runner isn't freed when they do.
	if get_tree().current_scene == self:
		get_tree().current_scene = null
	await get_tree().process_frame
	var only := ""
	var only_test := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			only = arg.substr(8)
		elif arg.begins_with("--test="):
			only_test = arg.substr(7)
	print("\n=== THE THIRTEENTH BELL - test run ===")
	for path in SUITES:
		if only != "" and not path.contains(only):
			continue
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		var suite: Object = script.new()
		if suite is Node:
			add_child(suite)
		suite.set("runner", self)
		print("\n-- %s" % path.get_file())
		for m in suite.get_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_") or (only_test != "" and not mname.contains(only_test)):
				continue
			_current = "%s.%s" % [path.get_file().get_basename(), mname]
			var before := failed
			var errors_before := errors.count
			_allowed = 0
			if suite.has_method("setup"):
				await suite.call("setup")
			await suite.call(mname)
			if suite.has_method("teardown"):
				await suite.call("teardown")
			if errors.count - errors_before > _allowed:
				fail("engine/script error: " + errors.last)
			if failed == before:
				passed += 1
				print("  PASS  %s" % mname)
			else:
				print("  FAIL  %s" % mname)
		if suite is Node:
			(suite as Node).queue_free()
	print("\n=== %d passed, %d failed ===" % [passed, failed])
	for f in failures:
		print("  - " + f)
	# leave the way the game does, so audio is released before shutdown
	var scene := get_tree().current_scene
	if scene:
		scene.queue_free()
	AudioManager.quit_game(1 if failed > 0 else 0)


func allow_errors(n: int) -> void:
	_allowed += n


## Assertions used by suites (suites call runner.check(...) / runner.fail(...)).
func check(condition: bool, message: String) -> bool:
	if not condition:
		fail(message)
	return condition


func fail(message: String) -> void:
	failed += 1
	failures.append("%s: %s" % [_current, message])
	print("        x %s" % message)
