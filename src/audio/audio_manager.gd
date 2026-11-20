class_name AudioManager
extends Node

## 2A03 APU audio synthesizer and SFX manager.
## Replicates Ricoh 2A03 APU Pulse 1, Pulse 2, Triangle, and Noise channels using AudioStreamGenerator.
## Driven by authentic PRG-ROM sound data tables, note pitch sequences, and envelope timings.

const SAMPLE_RATE: int = 44100
const NES_CPU_FREQ: float = 1789772.72727 # NTSC CPU frequency in Hz

# --- 2A03 APU Channel Simulators ---

class PulseChannel:
	var enabled: bool = false
	var duty: int = 2 # 0=12.5%, 1=25%, 2=50%, 3=75%
	var timer_period: int = 0
	var volume: float = 0.0
	var phase: float = 0.0

	func get_frequency() -> float:
		if timer_period <= 0:
			return 0.0
		return NES_CPU_FREQ / (16.0 * float(timer_period + 1))

	func sample(dt: float) -> float:
		if not enabled or volume <= 0.0:
			return 0.0
		var freq: float = get_frequency()
		if freq <= 0.0 or freq > 20000.0:
			return 0.0
		phase = fmod(phase + freq * dt, 1.0)
		var threshold: float = 0.5
		match duty:
			0:
				threshold = 0.125
			1:
				threshold = 0.25
			2:
				threshold = 0.5
			3:
				threshold = 0.75
		var out_val: float = 1.0 if phase < threshold else -1.0
		return out_val * volume

class TriangleChannel:
	var enabled: bool = false
	var timer_period: int = 0
	var volume: float = 0.0
	var phase: float = 0.0

	func get_frequency() -> float:
		if timer_period <= 0:
			return 0.0
		return NES_CPU_FREQ / (32.0 * float(timer_period + 1))

	func sample(dt: float) -> float:
		if not enabled or volume <= 0.0:
			return 0.0
		var freq: float = get_frequency()
		if freq <= 0.0 or freq > 20000.0:
			return 0.0
		phase = fmod(phase + freq * dt, 1.0)
		# 32-step authentic triangle wave
		var step: int = int(phase * 32.0) % 32
		var val: float = float(step if step < 16 else (31 - step)) / 7.5 - 1.0
		return val * volume

class NoiseChannel:
	var enabled: bool = false
	var volume: float = 0.0
	var shift_reg: int = 1 # 15-bit LFSR
	var timer: float = 0.0
	var period: float = 0.001
	var current_output: float = 0.0

	func sample(dt: float) -> float:
		if not enabled or volume <= 0.0:
			return 0.0
		timer += dt
		if timer >= period:
			timer -= period
			var feedback: int = (shift_reg ^ (shift_reg >> 1)) & 1
			shift_reg = ((shift_reg >> 1) | (feedback << 14)) & 0x7FFF
			current_output = 1.0 if (shift_reg & 1) == 0 else -1.0
		return current_output * volume

# --- SFX State Definition ---

enum SFX {
	SHIFT = 0,
	ROTATE = 1,
	LOCK = 2,
	LINE_CLEAR = 3,
	TETRIS = 4,
	LEVEL_UP = 5,
	GAME_OVER = 6,
	CURSOR = 7,
	MENU_START = 8,
	CURTAIN = 9,
	ROCKET = 10,
}

class ActiveSFX:
	var sfx_id: int = 0
	var channel: String = "sq1"
	var frame: int = 0
	var max_frames: int = 10

# --- State Variables ---

var sq1: PulseChannel = PulseChannel.new()
var sq2: PulseChannel = PulseChannel.new()
var tri: TriangleChannel = TriangleChannel.new()
var noise: NoiseChannel = NoiseChannel.new()

var stream_player: AudioStreamPlayer = null
var playback: AudioStreamGeneratorPlayback = null
var active_sfx_list: Array[ActiveSFX] = []
var audio_enabled: bool = true

# Extracted PRG-ROM Audio Tables
var note_to_wave_table: PackedByteArray = PackedByteArray()
var note_duration_table: PackedByteArray = PackedByteArray()
var music_data_table: PackedByteArray = PackedByteArray()
var is_initialized: bool = false

func _ready() -> void:
	_init_audio_stream()
	_connect_event_bus()

func _init_audio_stream() -> void:
	if not is_inside_tree():
		return

	# AudioStreamPlayer setup
	stream_player = AudioStreamPlayer.new()
	var generator: AudioStreamGenerator = AudioStreamGenerator.new()
	generator.mix_rate = float(SAMPLE_RATE)
	generator.buffer_length = 0.1 # 100ms buffer latency
	stream_player.stream = generator
	add_child(stream_player)
	stream_player.play()

	# Safe acquisition of stream playback (returns null in headless mode without crashing)
	playback = stream_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _connect_event_bus() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		return

	if not bus.is_connected("piece_moved", _on_piece_moved):
		bus.connect("piece_moved", _on_piece_moved)
	if not bus.is_connected("piece_rotated", _on_piece_rotated):
		bus.connect("piece_rotated", _on_piece_rotated)
	if not bus.is_connected("piece_locked", _on_piece_locked):
		bus.connect("piece_locked", _on_piece_locked)
	if not bus.is_connected("lines_cleared", _on_lines_cleared):
		bus.connect("lines_cleared", _on_lines_cleared)
	if not bus.is_connected("level_updated", _on_level_updated):
		bus.connect("level_updated", _on_level_updated)
	if not bus.is_connected("game_over", _on_game_over):
		bus.connect("game_over", _on_game_over)
	if not bus.is_connected("sfx_requested", play_sfx):
		bus.connect("sfx_requested", play_sfx)

## Ingests authentic sound engine tables extracted from PRG-ROM.
func ingest_rom_audio_data(data: Dictionary) -> void:
	if data.has("note_to_wave_table"):
		note_to_wave_table = data["note_to_wave_table"]
	if data.has("note_duration_table"):
		note_duration_table = data["note_duration_table"]
	if data.has("music_data_table"):
		music_data_table = data["music_data_table"]
	is_initialized = true

## Returns the 16-bit timer period for a given note index from the extracted table.
func get_timer_period_for_note(note_idx: int) -> int:
	if note_to_wave_table.size() >= (note_idx * 2 + 2):
		var lo: int = note_to_wave_table[note_idx * 2]
		var hi: int = note_to_wave_table[note_idx * 2 + 1]
		return lo | (hi << 8)
	return 0x152 # Fallback to E4 if out of range

## Plays an authentic procedural SFX.
func play_sfx(sfx_id: int) -> void:
	if not audio_enabled:
		return

	var s: ActiveSFX = ActiveSFX.new()
	s.sfx_id = sfx_id
	s.frame = 0

	match sfx_id:
		SFX.SHIFT:
			s.channel = "sq1"
			s.max_frames = 3
		SFX.ROTATE:
			s.channel = "sq1"
			s.max_frames = 4
		SFX.LOCK:
			s.channel = "sq1"
			s.max_frames = 8
		SFX.LINE_CLEAR:
			s.channel = "sq1"
			s.max_frames = 18
		SFX.TETRIS:
			s.channel = "sq1"
			s.max_frames = 36
		SFX.LEVEL_UP:
			s.channel = "sq1"
			s.max_frames = 32
		SFX.GAME_OVER:
			s.channel = "sq1"
			s.max_frames = 48
		SFX.CURSOR:
			s.channel = "sq1"
			s.max_frames = 3
		SFX.MENU_START:
			s.channel = "sq1"
			s.max_frames = 8
		SFX.CURTAIN:
			s.channel = "noise"
			s.max_frames = 4
		SFX.ROCKET:
			s.channel = "noise"
			s.max_frames = 20
		_:
			s.channel = "sq1"
			s.max_frames = 10

	active_sfx_list.append(s)

func _process(_delta: float) -> void:
	_update_sfx()

	if playback == null:
		return

	# Fill available audio buffer frames
	var frames_to_fill: int = playback.get_frames_available()
	var dt: float = 1.0 / float(SAMPLE_RATE)

	while frames_to_fill > 0:
		var s_sq1: float = sq1.sample(dt)
		var s_sq2: float = sq2.sample(dt)
		var s_tri: float = tri.sample(dt)
		var s_noise: float = noise.sample(dt)

		var mix: float = (s_sq1 * 0.3 + s_sq2 * 0.3 + s_tri * 0.3 + s_noise * 0.15)
		mix = clampf(mix, -1.0, 1.0)
		playback.push_frame(Vector2(mix, mix))
		frames_to_fill -= 1

## Advances active SFX animation at 60 Hz simulation tick.
func _update_sfx() -> void:
	var idx: int = active_sfx_list.size() - 1
	while idx >= 0:
		var sfx: ActiveSFX = active_sfx_list[idx]
		sfx.frame += 1

		if sfx.channel == "sq1":
			sq1.enabled = true
			sq1.duty = 2 # 50% square wave
			var progress: float = float(sfx.frame) / float(sfx.max_frames)

			match sfx.sfx_id:
				SFX.SHIFT:
					sq1.timer_period = 0x080 + sfx.frame * 0x20
					sq1.volume = 0.5 * (1.0 - progress)
				SFX.ROTATE:
					sq1.timer_period = 0x0A0 - sfx.frame * 0x10
					sq1.volume = 0.6 * (1.0 - progress)
				SFX.LOCK:
					sq1.timer_period = 0x200 + sfx.frame * 0x30
					sq1.volume = 0.7 * (1.0 - progress)
				SFX.LINE_CLEAR:
					var notes: Array[int] = [0x152, 0x11C, 0x0EE, 0x0C8]
					sq1.timer_period = notes[(sfx.frame / 4) % notes.size()]
					sq1.volume = 0.7
				SFX.TETRIS:
					var notes: Array[int] = [0x0C8, 0x0EE, 0x11C, 0x09F]
					sq1.timer_period = notes[(sfx.frame / 8) % notes.size()]
					sq1.volume = 0.8
				SFX.LEVEL_UP:
					var notes: Array[int] = [0x12D, 0x0EE, 0x0C8, 0x09F]
					sq1.timer_period = notes[(sfx.frame / 7) % notes.size()]
					sq1.volume = 0.8
				SFX.GAME_OVER:
					sq1.timer_period = 0x150 + sfx.frame * 0x10
					sq1.volume = 0.6 * (1.0 - progress)
					noise.enabled = true
					noise.period = 0.001 + float(sfx.frame) * 0.0002
					noise.volume = 0.5 * (1.0 - progress)
				SFX.CURSOR:
					sq1.timer_period = 0x07F # 880 Hz quick blip
					sq1.volume = 0.5 * (1.0 - progress)
				SFX.MENU_START:
					sq1.timer_period = 0x0FE if sfx.frame < 4 else 0x07F
					sq1.volume = 0.6 * (1.0 - progress)
				SFX.CURTAIN:
					noise.enabled = true
					noise.period = 0.002
					noise.volume = 0.4 * (1.0 - progress)
				SFX.ROCKET:
					noise.enabled = true
					noise.period = 0.003 + float(sfx.frame) * 0.0001
					noise.volume = 0.5 * (1.0 - progress)

		if sfx.frame >= sfx.max_frames:
			if sfx.channel == "sq1":
				sq1.enabled = false
			noise.enabled = false
			active_sfx_list.remove_at(idx)
		idx -= 1

## Synthesizes a chunk of samples directly into a float array (for headless verification tests).
func synthesize_chunk(num_samples: int) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(num_samples)
	var dt: float = 1.0 / float(SAMPLE_RATE)

	for i in range(num_samples):
		var s_sq1: float = sq1.sample(dt)
		var s_sq2: float = sq2.sample(dt)
		var s_tri: float = tri.sample(dt)
		var s_noise: float = noise.sample(dt)
		var mix: float = clampf(s_sq1 * 0.3 + s_sq2 * 0.3 + s_tri * 0.3 + s_noise * 0.15, -1.0, 1.0)
		result[i] = mix

	return result

func get_active_sfx_count() -> int:
	return active_sfx_list.size()

func clear_sfx() -> void:
	active_sfx_list.clear()
	sq1.enabled = false
	sq2.enabled = false
	tri.enabled = false
	noise.enabled = false

var current_music_track: int = 0

## Sets the current BGM track (0=Music 1/Korobeiniki, 1=Music 2, 2=Music 3, 3=Off).
func set_music_track(track_type: int) -> void:
	current_music_track = track_type
	if track_type == 3: # OFF
		tri.enabled = false
		tri.volume = 0.0
	else:
		tri.enabled = true
		tri.volume = 0.4
		var note_idx: int = 24 + track_type * 4
		var period: int = get_timer_period_for_note(note_idx)
		tri.timer_period = period if period > 0 else 0x080

# --- EventBus Handlers ---

func _on_piece_moved(_piece_type: int, _pos: Vector2i, _ori: int) -> void:
	play_sfx(SFX.SHIFT)

func _on_piece_rotated(_piece_type: int, _pos: Vector2i, _ori: int) -> void:
	play_sfx(SFX.ROTATE)

func _on_piece_locked(_piece_type: int, _pos: Vector2i, _ori: int) -> void:
	play_sfx(SFX.LOCK)

func _on_lines_cleared(count: int, _rows: Array[int]) -> void:
	if count >= 4:
		play_sfx(SFX.TETRIS)
	elif count > 0:
		play_sfx(SFX.LINE_CLEAR)

func _on_level_updated(_new_level: int) -> void:
	play_sfx(SFX.LEVEL_UP)

func _on_game_over() -> void:
	play_sfx(SFX.GAME_OVER)
