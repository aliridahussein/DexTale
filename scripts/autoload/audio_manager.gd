extends Node
## Music, ambience and sound effects with crossfades.
##
## Tracks are referenced by name: "village_dusk" -> res://assets/audio/music/village_dusk.wav.
## Missing files only print a warning once, so the game never depends on audio.

const MUSIC_DIR := "res://assets/audio/music/"
const AMBIENCE_DIR := "res://assets/audio/ambience/"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_VOICES := 10

var _music: Array[AudioStreamPlayer] = []
var _ambience: Array[AudioStreamPlayer] = []
var _music_index := 0
var _ambience_index := 0
var _current_music := ""
var _current_ambience := ""
var _sfx: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _missing: Dictionary = {}
var _reverb: AudioEffectReverb


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in 2:
		_music.append(_make_player("Music"))
		_ambience.append(_make_player("Ambience"))
	for i in SFX_VOICES:
		_sfx.append(_make_player("SFX"))
	apply_volumes()
	Settings.changed.connect(apply_volumes)
	# Quit through quit_game() so audio is released before the engine shuts down.
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Stop and release all audio, give the audio server a couple of frames to let
## go of the streams, then quit (avoids "resources still in use" at exit).
func quit_game() -> void:
	for p in _music + _ambience + _sfx:
		p.stop()
		p.stream = null
	_cache.clear()
	_current_music = ""
	_current_ambience = ""
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _ensure_buses() -> void:
	for bus_name in ["Music", "Ambience", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_idx) == 0:
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.7
		_reverb.damping = 0.45
		_reverb.wet = 0.0
		_reverb.dry = 1.0
		AudioServer.add_bus_effect(sfx_idx, _reverb)
	else:
		_reverb = AudioServer.get_bus_effect(sfx_idx, 0) as AudioEffectReverb


func apply_volumes() -> void:
	_set_bus_volume("Master", Settings.master_volume)
	_set_bus_volume("Music", Settings.music_volume)
	_set_bus_volume("Ambience", Settings.ambience_volume)
	_set_bus_volume("SFX", Settings.sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


## Room reverb for the SFX bus (chapel and tower sound larger).
func set_reverb(amount: float) -> void:
	if _reverb:
		_reverb.wet = clampf(amount, 0.0, 1.0) * 0.45


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		if not _missing.has(path):
			_missing[path] = true
			push_warning("AudioManager: missing audio '%s'" % path)
		return null
	var stream := load(path) as AudioStream
	_cache[path] = stream
	return stream


func play_music(track: String, fade: float = 1.5, volume_db: float = 0.0) -> void:
	if track == _current_music:
		return
	_current_music = track
	_crossfade(_music, track, MUSIC_DIR, fade, volume_db, true)


func play_ambience(track: String, fade: float = 1.5, volume_db: float = 0.0) -> void:
	if track == _current_ambience:
		return
	_current_ambience = track
	_crossfade(_ambience, track, AMBIENCE_DIR, fade, volume_db, false)


func stop_music(fade: float = 1.5) -> void:
	play_music("", fade)


func stop_all(fade: float = 1.0) -> void:
	play_music("", fade)
	play_ambience("", fade)


func current_music() -> String:
	return _current_music


func _crossfade(players: Array[AudioStreamPlayer], track: String, dir: String, fade: float,
		volume_db: float, is_music: bool) -> void:
	var old_i := _music_index if is_music else _ambience_index
	var new_i := 1 - old_i
	var old := players[old_i]
	var new := players[new_i]
	if is_music:
		_music_index = new_i
	else:
		_ambience_index = new_i
	if old.playing:
		var t_out := create_tween()
		t_out.tween_property(old, "volume_db", -60.0, maxf(fade, 0.01))
		t_out.tween_callback(old.stop)
	if track == "":
		return
	var stream := _load(dir + track + ".wav")
	if stream == null:
		return
	new.stream = stream
	new.volume_db = -60.0
	new.play()
	var t_in := create_tween()
	t_in.tween_property(new, "volume_db", volume_db, maxf(fade, 0.01))


## Fire-and-forget sound effect by name (file in assets/audio/sfx/).
func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.0) -> void:
	if sfx_name == "":
		return
	var stream := _load(SFX_DIR + sfx_name + ".wav")
	if stream == null:
		return
	var voice: AudioStreamPlayer = null
	for p in _sfx:
		if not p.playing:
			voice = p
			break
	if voice == null:
		voice = _sfx[0]
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = maxf(0.05, pitch + randf_range(-pitch_jitter, pitch_jitter))
	voice.play()
