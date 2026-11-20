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

	audio._on_piece_moved(0, Vector2i.ZERO, 0)
	assert(audio.get_active_sfx_count() == 1, "piece_moved should trigger 1 SFX (SHIFT)")

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
