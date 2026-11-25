class_name TestAudio
extends RefCounted

## Verification test suite for 2A03 APU audio channels (Pulse, Triangle, Noise),
## procedural SFX state progression, and audio synthesis.

const AudioManager = preload("res://src/audio/audio_manager.gd")

static func run_tests() -> bool:
	print("--- Running TestAudio ---")
	test_pulse_channel()
	test_triangle_channel()
	test_noise_channel()
	test_sfx_lifecycle_and_queuing()
	test_audio_sample_synthesis()
	test_event_bus_handlers()
	test_big_endian_timer_period_lookup()
	test_non_clipping_gain_staging()
	test_sfx_priority_and_noise_sfx()
	print("  -> TestAudio: PASSED")
	return true

static func test_pulse_channel() -> void:
	var pulse = AudioManager.PulseChannel.new()
	assert(pulse.get_frequency() == 0.0, "Frequency with timer_period 0 must be 0")

	# Timer period 253 (0x0FD) -> A4 ~ 440 Hz
	pulse.timer_period = 253
	var freq: float = pulse.get_frequency()
	assert(freq > 439.0 and freq < 442.0, "Frequency for period 253 should be ~440.4 Hz, got %f" % freq)

	pulse.enabled = true
	pulse.volume = 0.8
	pulse.duty = 2 # 50% square wave

	var dt: float = 1.0 / 44100.0
	var samples: Array[float] = []
	for i in range(100):
		samples.append(pulse.sample(dt))

	# Square wave values should be +0.8 or -0.8
	var has_positive: bool = false
	var has_negative: bool = false
	for s in samples:
		if s > 0.7:
			has_positive = true
		elif s < -0.7:
			has_negative = true
	assert(has_positive and has_negative, "PulseChannel must oscillate between positive and negative levels")

static func test_triangle_channel() -> void:
	var tri = AudioManager.TriangleChannel.new()
	# Timer period 253 -> ~220.2 Hz
	tri.timer_period = 253
	var freq: float = tri.get_frequency()
	assert(freq > 219.0 and freq < 221.5, "Triangle frequency for period 253 should be ~220.2 Hz, got %f" % freq)

	tri.enabled = true
	tri.volume = 1.0
	var dt: float = 1.0 / 44100.0
	var val: float = tri.sample(dt)
	assert(val >= -1.0 and val <= 1.0, "Triangle sample must be in [-1.0, 1.0]")

static func test_noise_channel() -> void:
	var noise = AudioManager.NoiseChannel.new()
	noise.enabled = true
	noise.volume = 0.5
	noise.period = 0.0001 # Fast shift rate

	var dt: float = 1.0 / 44100.0
	var distinct_samples: Dictionary = {}
	for i in range(200):
		var s: float = noise.sample(dt)
		distinct_samples[snappedf(s, 0.01)] = true

	# Noise should produce non-zero outputs
	assert(distinct_samples.size() > 0, "Noise must produce outputs")
	# Output should be zero-centered AC (-0.5 or +0.5)
	assert(distinct_samples.has(0.5) or distinct_samples.has(-0.5), "Noise output must be zero-centered AC")

	# Test periodic mode
	noise.is_periodic = true
	var s_periodic: float = noise.sample(dt)
	assert(absf(s_periodic) == 0.5, "Periodic noise output must be bounded to volume")

static func test_sfx_lifecycle_and_queuing() -> void:
	var audio = AudioManager.new()
	audio.audio_enabled = true
	assert(audio.get_active_sfx_count() == 0, "Active SFX should initially be empty")

	# Test all SFX types can be queued
	for sfx_id in [
		AudioManager.SFX.SHIFT,
		AudioManager.SFX.ROTATE,
		AudioManager.SFX.LOCK,
		AudioManager.SFX.LINE_CLEAR,
		AudioManager.SFX.TETRIS,
		AudioManager.SFX.LEVEL_UP,
		AudioManager.SFX.GAME_OVER
	]:
		audio.play_sfx(sfx_id)

	assert(audio.get_active_sfx_count() == 7, "All 7 SFX types must be queued")

	# Step 50 frames to let all SFX complete their lifecycles
	for f in range(50):
		audio._update_sfx()

	assert(audio.get_active_sfx_count() == 0, "All SFX must complete and be removed from queue")
	audio.free()

static func test_audio_sample_synthesis() -> void:
	var audio = AudioManager.new()
	audio.audio_enabled = true
	audio.play_sfx(AudioManager.SFX.LINE_CLEAR)
	audio._update_sfx() # Advance frame 0 -> 1, activating sq1 channel

	# Generate 1000 audio samples headlessly
	var buffer: PackedFloat32Array = audio.synthesize_chunk(1000)
	assert(buffer.size() == 1000, "Synthesize chunk must return exact requested sample count")

	var non_zero: bool = false
	for s in buffer:
		assert(s >= -1.0 and s <= 1.0, "Audio sample must be clamped within [-1.0, 1.0]")
		if absf(s) > 0.001:
			non_zero = true

	assert(non_zero, "Synthesizer must produce audible non-zero sound samples when SFX is active")
	audio.free()

static func test_event_bus_handlers() -> void:
	var audio = AudioManager.new()
	audio.audio_enabled = true

	# Horizontal shift triggers SHIFT SFX
	audio._on_piece_shifted(0, Vector2i.ZERO, 0)
	assert(audio.get_active_sfx_count() == 1, "piece_shifted should trigger 1 SFX (SHIFT)")

	# Vertical descent (gravity/soft-drop) triggers NO SFX in authentic 1989 NES Tetris
	audio._on_piece_moved(0, Vector2i.ZERO, 0)
	assert(audio.get_active_sfx_count() == 1, "piece_moved (falling) must not trigger any SFX")

	audio._on_piece_rotated(0, Vector2i.ZERO, 0)
	assert(audio.get_active_sfx_count() == 2, "piece_rotated should trigger 1 SFX (ROTATE)")

	audio._on_piece_locked(0, Vector2i.ZERO, 0)
	assert(audio.get_active_sfx_count() == 3, "piece_locked should trigger 1 SFX (LOCK)")

	audio._on_lines_cleared(1, [20])
	assert(audio.get_active_sfx_count() == 4, "lines_cleared (1 line) should trigger LINE_CLEAR")

	audio._on_lines_cleared(4, [18, 19, 20, 21])
	assert(audio.get_active_sfx_count() == 5, "lines_cleared (4 lines) should trigger TETRIS")

	audio._on_level_updated(1)
	assert(audio.get_active_sfx_count() == 6, "level_updated should trigger LEVEL_UP")

	audio._on_game_over()
	assert(audio.get_active_sfx_count() == 7, "game_over should trigger GAME_OVER")

	audio.clear_sfx()
	assert(audio.get_active_sfx_count() == 0, "clear_sfx must empty queue")
	audio.free()

static func test_big_endian_timer_period_lookup() -> void:
	var audio = AudioManager.new()
	# Simulate note_to_wave_table with E4 (0x0152): Big-endian .dbyt byte 0 = 0x01 (hi), byte 1 = 0x52 (lo)
	audio.note_to_wave_table = PackedByteArray([0x01, 0x52, 0x00, 0xBD])
	var period_e4: int = audio.get_timer_period_for_note(0)
	assert(period_e4 == 0x0152, "Note 0 period must be 0x0152 (338), got 0x%X" % period_e4)
	var period_d5: int = audio.get_timer_period_for_note(1)
	assert(period_d5 == 0x00BD, "Note 1 period must be 0x00BD (189), got 0x%X" % period_d5)
	audio.free()

static func test_non_clipping_gain_staging() -> void:
	var audio = AudioManager.new()
	audio.audio_enabled = true
	# Set all 4 channels to maximum volume (1.0)
	audio.sq1.enabled = true
	audio.sq1.volume = 1.0
	audio.sq1.timer_period = 200
	audio.sq2.enabled = true
	audio.sq2.volume = 1.0
	audio.sq2.timer_period = 300
	audio.tri.enabled = true
	audio.tri.volume = 1.0
	audio.tri.timer_period = 400
	audio.noise.enabled = true
	audio.noise.volume = 1.0

	var buffer: PackedFloat32Array = audio.synthesize_chunk(500)
	for s in buffer:
		# With weights 0.25 + 0.25 + 0.28 + 0.08 = 0.86, peak sample should never exceed 0.86
		assert(absf(s) <= 0.87, "Audio gain staging must prevent digital clipping (<= 0.87), got %f" % absf(s))
	audio.free()

static func test_sfx_priority_and_noise_sfx() -> void:
	var audio = AudioManager.new()
	audio.audio_enabled = true

	# High-priority TETRIS suppresses low-priority SHIFT/ROTATE/LOCK (LE33B main.asm:6312)
	audio.play_sfx(AudioManager.SFX.TETRIS)
	assert(audio.get_active_sfx_count() == 1)
	audio.play_sfx(AudioManager.SFX.SHIFT)
	audio.play_sfx(AudioManager.SFX.ROTATE)
	audio.play_sfx(AudioManager.SFX.LOCK)
	assert(audio.get_active_sfx_count() == 1, "Low-priority SQ1 SFX must be suppressed while TETRIS is active")

	# Noise SFX (CURTAIN / ROCKET) must activate noise channel
	audio.clear_sfx()
	audio.play_sfx(AudioManager.SFX.CURTAIN)
	audio._update_sfx()
	assert(audio.noise.enabled, "SFX.CURTAIN must enable noise channel")
	assert(audio.noise.volume > 0.0, "SFX.CURTAIN must set positive noise volume")

	audio.clear_sfx()
	audio.play_sfx(AudioManager.SFX.ROCKET)
	audio._update_sfx()
	assert(audio.noise.enabled, "SFX.ROCKET must enable noise channel")
	assert(audio.noise.volume > 0.0, "SFX.ROCKET must set positive noise volume")
	audio.free()

