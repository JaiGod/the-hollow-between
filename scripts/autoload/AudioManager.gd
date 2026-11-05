extends Node
## Procedural chiptune audio. Every sound effect and music loop is synthesized
## at runtime from note data below — no audio files needed to run the game.
## Drop real .ogg files into res://audio/music/<song>.ogg and they'll be used
## instead automatically (see docs/ARCHITECTURE.md → Audio).

const RATE := 22050

const SFX := {
	# name: [[f_start, f_end, seconds, wave, volume], ...]  (segments play in order)
	"blip": [[880, 880, 0.03, "square", 0.18]],
	"select": [[660, 990, 0.06, "square", 0.25]],
	"move": [[520, 520, 0.03, "square", 0.15]],
	"back": [[500, 300, 0.07, "square", 0.22]],
	"hit": [[300, 80, 0.12, "noise", 0.35]],
	"crit": [[900, 1500, 0.05, "square", 0.3], [300, 60, 0.15, "noise", 0.35]],
	"hurt": [[220, 90, 0.18, "square", 0.35]],
	"heal": [[520, 780, 0.08, "triangle", 0.3], [780, 1040, 0.1, "triangle", 0.3]],
	"graze": [[1400, 1800, 0.03, "triangle", 0.12]],
	"spare": [[523, 523, 0.08, "triangle", 0.3], [659, 659, 0.08, "triangle", 0.3], [784, 784, 0.18, "triangle", 0.3]],
	"save": [[392, 392, 0.1, "triangle", 0.3], [587, 587, 0.1, "triangle", 0.3], [784, 784, 0.25, "triangle", 0.3]],
	"encounter": [[200, 800, 0.15, "square", 0.3], [800, 800, 0.1, "square", 0.3]],
	"beam": [[120, 60, 0.35, "noise", 0.25]],
	"boom": [[160, 40, 0.3, "noise", 0.4]],
	"levelup": [[523, 523, 0.07, "square", 0.25], [659, 659, 0.07, "square", 0.25], [784, 784, 0.07, "square", 0.25], [1046, 1046, 0.2, "square", 0.25]],
	"death": [[400, 50, 0.9, "square", 0.3]],
}

## Songs: bpm + tracks of tokens (one token = one eighth note).
## "."=rest, "_"=hold. Motifs recur: the Hollow motif (A C E D C B A) appears in
## the title, the Archivist fight, and the ending — character/world motifs.
const SONGS := {
	"title": {"bpm": 76, "tracks": [
		["triangle", 0.22, "A4 _ C5 _ E5 _ D5 _ C5 _ B4 _ A4 _ _ _ F4 _ A4 _ C5 _ B4 _ A4 _ G4 _ E4 _ _ _"],
		["square", 0.07, "A2 . A2 . E3 . A2 . F2 . F2 . C3 . F2 . D2 . D2 . A2 . D2 . E2 . E2 . B2 . E2 ."],
	]},
	"forest": {"bpm": 92, "tracks": [
		["triangle", 0.2, "D5 _ F5 E5 D5 _ A4 _ C5 _ D5 _ E5 _ . . F5 _ G5 F5 E5 _ C5 _ D5 _ _ _ . . . ."],
		["square", 0.06, "D3 A3 D4 A3 D3 A3 D4 A3 C3 G3 C4 G3 C3 G3 C4 G3 B2 F3 B3 F3 B2 F3 B3 F3 A2 E3 A3 E3 A2 E3 A3 E3"],
	]},
	"village": {"bpm": 100, "tracks": [
		["triangle", 0.2, "E5 _ G5 _ C6 _ G5 _ A5 _ G5 E5 D5 _ _ _ C5 _ E5 _ G5 _ E5 _ D5 _ C5 _ C5 _ _ _"],
		["square", 0.06, "C3 . G3 . C3 . G3 . F3 . C4 . F3 . G3 . C3 . G3 . C3 . G3 . F3 . G3 . C3 . . ."],
	]},
	"battle": {"bpm": 150, "tracks": [
		["square", 0.13, "A4 . A4 C5 . E5 D5 C5 B4 . G4 . A4 _ _ . A4 . A4 C5 . E5 G5 E5 F5 . E5 . D5 _ _ ."],
		["square", 0.08, "A2 A2 A3 A2 A2 A2 A3 A2 G2 G2 G3 G2 G2 G2 G3 G2 F2 F2 F3 F2 F2 F2 F3 F2 E2 E2 E3 E2 E2 E2 G2 G#2"],
	]},
	"boss": {"bpm": 160, "tracks": [
		["square", 0.12, "A4 _ C5 _ E5 _ D5 _ C5 _ B4 _ A4 _ _ _ A4 C5 E5 A5 G5 E5 D5 B4 C5 _ B4 _ G#4 _ _ _"],
		["square", 0.08, "A2 A3 A2 A3 A2 A3 A2 A3 F2 F3 F2 F3 F2 F3 F2 F3 D2 D3 D2 D3 D2 D3 D2 D3 E2 E3 E2 E3 E2 E3 G#2 E3"],
		["noise", 0.05, "x . . . x . . . x . . . x . x . x . . . x . . . x . . . x . x x"],
	]},
	"ending": {"bpm": 70, "tracks": [
		["triangle", 0.22, "A4 _ C5 _ E5 _ D5 _ C5 _ B4 _ C5 _ _ _ C5 _ E5 _ G5 _ F5 _ E5 _ D5 _ C5 _ _ _"],
		["triangle", 0.1, "A3 _ _ _ E3 _ _ _ F3 _ _ _ G3 _ _ _ C3 _ _ _ G3 _ _ _ F3 _ _ _ C3 _ _ _"],
	]},
}

var _sfx_cache: Dictionary = {}
var _song_cache: Dictionary = {}
var _sfx_players: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _active: AudioStreamPlayer
var current_song: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	_active = _music_a


func _music_db() -> float:
	return linear_to_db(max(0.0001, float(SaveManager.setting("music", 0.7))))


func _sfx_db() -> float:
	return linear_to_db(max(0.0001, float(SaveManager.setting("sfx", 0.8))))


func play_sfx(sfx_name: String, pitch: float = 1.0) -> void:
	if not SFX.has(sfx_name):
		return
	if not _sfx_cache.has(sfx_name):
		_sfx_cache[sfx_name] = _render_sfx(SFX[sfx_name])
	for p in _sfx_players:
		if not p.playing:
			p.stream = _sfx_cache[sfx_name]
			p.pitch_scale = pitch
			p.volume_db = _sfx_db()
			p.play()
			return


func play_music(song: String, fade: float = 0.8) -> void:
	if song == current_song:
		return
	current_song = song
	var stream: AudioStream = _get_song(song)
	var old := _active
	_active = _music_b if _active == _music_a else _music_a
	_active.stream = stream
	_active.pitch_scale = 1.0
	_active.volume_db = -60.0
	if stream:
		_active.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_active, "volume_db", _music_db(), fade)
	if old.playing:
		tw.tween_property(old, "volume_db", -60.0, fade)
		tw.chain().tween_callback(old.stop)


func set_intensity(pitch: float) -> void:
	## Adaptive music: battles push this up as phases escalate.
	if _active:
		create_tween().tween_property(_active, "pitch_scale", pitch, 1.0)


func stop_music(fade: float = 0.6) -> void:
	current_song = ""
	if _active and _active.playing:
		var p := _active
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, fade)
		tw.tween_callback(p.stop)


func refresh_volume() -> void:
	if _active:
		_active.volume_db = _music_db()


func _get_song(song: String) -> AudioStream:
	if _song_cache.has(song):
		return _song_cache[song]
	var file_path := "res://audio/music/%s.ogg" % song
	var stream: AudioStream = null
	if ResourceLoader.exists(file_path):
		stream = load(file_path)
	elif SONGS.has(song):
		stream = _render_song(SONGS[song])
	_song_cache[song] = stream
	return stream


# ------------------------------------------------------------------ synthesis

static func note_freq(note: String) -> float:
	const NAMES := {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}
	var octave := int(note.substr(note.length() - 1))
	var pitch_name := note.substr(0, note.length() - 1)
	var semis: int = NAMES.get(pitch_name, 9) + (octave + 1) * 12
	return 440.0 * pow(2.0, (semis - 69) / 12.0)


static func _wave(kind: String, phase: float) -> float:
	match kind:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"triangle":
			var t := fmod(phase, 1.0)
			return 4.0 * t - 1.0 if t < 0.5 else 3.0 - 4.0 * t
		"noise":
			return randf() * 2.0 - 1.0
	return sin(phase * TAU)


func _make_stream(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _render_sfx(segments: Array) -> AudioStreamWAV:
	var out := PackedFloat32Array()
	var phase := 0.0
	for seg in segments:
		var n := int(seg[2] * RATE)
		for i in n:
			var t := float(i) / n
			var f: float = lerp(float(seg[0]), float(seg[1]), t)
			phase += f / RATE
			var env := 1.0 - t
			out.append(_wave(seg[3], phase) * seg[4] * env)
	return _make_stream(out, false)


func _render_song(song: Dictionary) -> AudioStreamWAV:
	var step := int(RATE * 60.0 / song["bpm"] / 2.0)  # eighth notes
	var length := 0
	for tr in song["tracks"]:
		length = max(length, (tr[2] as String).split(" ", false).size() * step)
	var buf := PackedFloat32Array()
	buf.resize(length)
	for tr in song["tracks"]:
		var kind: String = tr[0]
		var vol: float = tr[1]
		var tokens: PackedStringArray = (tr[2] as String).split(" ", false)
		var i := 0
		while i < tokens.size():
			var tok := tokens[i]
			if tok == "." or tok == "_":
				i += 1
				continue
			var held := 1
			while i + held < tokens.size() and tokens[i + held] == "_":
				held += 1
			var n := held * step
			var start := i * step
			var f := 0.0 if kind == "noise" else note_freq(tok)
			var phase := 0.0
			for s in n:
				var idx := start + s
				if idx >= length:
					break
				var env := minf(1.0, s / 200.0) * (1.0 - float(s) / n * 0.6)
				if kind == "noise":
					env = maxf(0.0, 1.0 - float(s) / (step * 0.4))
				phase += f / RATE
				buf[idx] += _wave(kind, phase) * vol * env
			i += held
	return _make_stream(buf, true)
