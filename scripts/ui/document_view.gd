extends Control
## Paged reader for letters, notices and the Bellkeeper's Ledger.
## Documents live in data/documents.json. Reaching the last page sets the
## flag "read_<id>".

signal closed

const DOCS_PATH := "res://data/documents.json"

var _docs: Dictionary = {}
var _doc_id := ""
var _pages: Array = []
var _page := 0

@onready var title: Label = %DocTitle
@onready var body: RichTextLabel = %DocBody
@onready var image: TextureRect = %DocImage
@onready var page_label: Label = %DocPage
@onready var hint: Label = %DocHint


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DOCS_PATH))
	_docs = parsed if parsed is Dictionary else {}


func has_document(id: String) -> bool:
	return _docs.has(id)


func open(doc_id: String) -> Signal:
	if not _docs.has(doc_id):
		push_warning("DocumentView: unknown document '%s'" % doc_id)
		call_deferred("emit_signal", "closed")
		return closed
	_doc_id = doc_id
	var doc: Dictionary = _docs[doc_id]
	title.text = str(doc.get("title", ""))
	_pages = doc.get("pages", [])
	_page = 0
	visible = true
	get_tree().paused = true
	AudioManager.play_sfx("page", -6.0)
	_show_page()
	return closed


func _show_page() -> void:
	var page: Variant = _pages[_page] if _page < _pages.size() else {}
	var text := ""
	var img := ""
	if page is Dictionary:
		text = str(page.get("text", ""))
		img = str(page.get("image", ""))
	else:
		text = str(page)
	body.text = text
	image.visible = img != "" and ResourceLoader.exists(img)
	if image.visible:
		image.texture = load(img)
	page_label.text = "%d / %d" % [_page + 1, _pages.size()] if _pages.size() > 1 else ""
	var last := _page >= _pages.size() - 1
	hint.text = "E: close" if last else "E: next page   ◀ ▶: turn"
	if last:
		GameState.set_flag("read_" + _doc_id, true)


func _close() -> void:
	visible = false
	get_tree().paused = false
	AudioManager.play_sfx("page", -10.0, 0.8)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	var accept := event.is_action_pressed("interact") or event.is_action_pressed("dialogue_advance") or event.is_action_pressed("ui_accept")
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close()
	elif accept:
		if _page >= _pages.size() - 1:
			_close()
		else:
			_page += 1
			AudioManager.play_sfx("page", -8.0)
			_show_page()
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		if _page < _pages.size() - 1:
			_page += 1
			AudioManager.play_sfx("page", -8.0)
			_show_page()
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		if _page > 0:
			_page -= 1
			AudioManager.play_sfx("page", -8.0)
			_show_page()
