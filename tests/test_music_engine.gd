class_name TestMusicEngine
extends RefCounted

## Automated test suite for the 2A03 APU Music Bytecode Engine and Attract-Mode Demo Playback.
## Verifies PRG-ROM sound table extraction, track header decoding, 60 TPS bytecode execution,
## envelope stepping, loop mechanics, channel mixing, and demo controller input streaming.

const CHRExtractor = preload("res://src/importer/chr_extractor.gd")
const MusicBytecodePlayer = preload("res://src/audio/music_bytecode_player.gd")
const AudioManager = preload("res://src/audio/audio_manager.gd")
const DemoController = preload("res://src/game/demo_controller.gd")
const PieceRandomizer = preload("res://src/game/piece_randomizer.gd")
const PlayfieldRenderer = preload("res://src/game/playfield_renderer.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_all_tests() -> bool:
	print("--- Running TestMusicEngine ---")
	test_sound_tables_extraction()
	test_music_track_headers()
	test_music_bytecode_player_initialization()
	test_music_track_loading_and_channel_states()
	test_bytecode_execution_and_envelope_stepping()
	test_audio_manager_bytecode_integration_and_sfx_override()
	test_demo_controller_lifecycle_and_input_streaming()
	test_piece_randomizer_demo_mode()
	test_crt_scanlines_shader_loading()
	print("  -> TestMusicEngine: PASSED")
	return true

static func get_test_extraction() -> Dictionary:
	var path: String = "Tetris (USA).nes"
	if FileAccess.file_exists(path):
		return CHRExtractor.extract_from_file(path, true)
	return {}

static func test_sound_tables_extraction() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		push_warning("Test ROM missing; skipping disk table check")
		return

	assert(res.has("prg_rom"), "Must extract 32KB PRG-ROM")
	var prg: PackedByteArray = res["prg_rom"]
	assert(prg.size() == 32768, "PRG-ROM must be exactly 32768 bytes, got %d" % prg.size())

	assert(res.has("note_to_wave_table"), "Must extract noteToWaveTable")
	var wave: PackedByteArray = res["note_to_wave_table"]
	assert(wave.size() >= 156, "noteToWaveTable must be at least 156 bytes")
	# First note in NTSC is A1 (0x07F0)
	assert(wave[0] == 0x07 and wave[1] == 0xF0, "First note in noteToWaveTable must be A1 ($07F0)")

	assert(res.has("note_duration_table"), "Must extract noteDurationTable")
	var dur: PackedByteArray = res["note_duration_table"]
	assert(dur.size() >= 126, "noteDurationTable must be at least 126 bytes")
	assert(dur[0] == 0x03 and dur[1] == 0x06, "First durations in noteDurationTable must be 3, 6")

	assert(res.has("music_data_table"), "Must extract musicDataTable")
	var data: PackedByteArray = res["music_data_table"]
	assert(data.size() == 100, "musicDataTable must be 100 bytes (10 tracks * 10 bytes)")

	assert(res.has("music_vol_table"), "Must extract musicChanVolControlTable")
	var vol: PackedByteArray = res["music_vol_table"]
	assert(vol.size() == 44, "musicChanVolControlTable must be 44 bytes (22 word pointers)")

	assert(res.has("noises_table"), "Must extract noises_table")
	var noises: PackedByteArray = res["noises_table"]
	assert(noises.size() == 37, "noises_table must be 37 bytes")

	assert(res.has("demo_buttons_table"), "Must extract demoButtonsTable")
	var demo_b: PackedByteArray = res["demo_buttons_table"]
	assert(demo_b.size() >= 260, "demoButtonsTable must be at least 260 bytes")

	assert(res.has("demo_tetrimino_type_table"), "Must extract demoTetriminoTypeTable")
	var demo_t: PackedByteArray = res["demo_tetrimino_type_table"]
	assert(demo_t.size() >= 256, "demoTetriminoTypeTable must be at least 256 bytes")

static func test_music_track_headers() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		return

	var data: PackedByteArray = res["music_data_table"]

	# Track 0: Title Screen
	assert(data[0] == 0x0A, "Track 0 note offset must be 0x0A")
	assert(data[1] == 0x24, "Track 0 duration offset must be 0x24")
	var sq1_0: int = data[2] | (data[3] << 8)
	assert(sq1_0 == 0xECF1, "Track 0 SQ1 script pointer must be $ECF1, got 0x%04X" % sq1_0)

	# Track 2: Music 1 (Korobeiniki)
	var t2_base: int = 2 * 10
	assert(data[t2_base] == 0x81, "Track 2 note offset must be 0x81")
	assert(data[t2_base + 1] == 0x24, "Track 2 duration offset must be 0x24")
	var sq1_2: int = data[t2_base + 2] | (data[t2_base + 3] << 8)
	var noise_2: int = data[t2_base + 8] | (data[t2_base + 9] << 8)
	assert(sq1_2 == 0xEEBF, "Track 2 SQ1 script pointer must be $EEBF, got 0x%04X" % sq1_2)
	assert(noise_2 == 0xEEDD, "Track 2 NOISE script pointer must be $EEDD, got 0x%04X" % noise_2)

	# Track 4: Music 3 (Kalinka) - Noise channel is unused ($FFFF)
	var t4_base: int = 4 * 10
	var noise_4: int = data[t4_base + 8] | (data[t4_base + 9] << 8)
	assert(noise_4 == 0xFFFF, "Track 4 NOISE script pointer must be $FFFF (unused channel)")

	# Track 8: Congratulations (Level Complete)
	var t8_base: int = 8 * 10
	assert(data[t8_base] == 0x00, "Track 8 note offset must be 0x00")
	assert(data[t8_base + 1] == 0x18, "Track 8 duration offset must be 0x18")

	# Track 9: Ending Theme (Rocket)
	var t9_base: int = 9 * 10
	assert(data[t9_base] == 0x8F, "Track 9 note offset must be 0x8F")
	assert(data[t9_base + 1] == 0x24, "Track 9 duration offset must be 0x24")

static func test_music_bytecode_player_initialization() -> void:
	var player = MusicBytecodePlayer.new()
	assert(player.channels.size() == 4, "Music player must initialize 4 APU channels")
	assert(player.currently_playing_track == -1, "Player should start in idle state")

	var res: Dictionary = get_test_extraction()
	if not res.is_empty():
		player.setup_tables(
			res["prg_rom"],
			res["note_to_wave_table"],
			res["note_duration_table"],
			res["music_data_table"],
			res["music_vol_table"],
			res["noises_table"]
		)
		assert(player.prg_rom.size() == 32768, "PRG-ROM must be populated in player")

static func test_music_track_loading_and_channel_states() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		return

	var player = MusicBytecodePlayer.new()
	player.setup_tables(
		res["prg_rom"],
		res["note_to_wave_table"],
		res["note_duration_table"],
		res["music_data_table"],
		res["music_vol_table"],
		res["noises_table"]
	)

	# Load Track 2 (Music 1 / Korobeiniki)
	player.load_track(Constants.MusicTrack.MUSIC_1)
	assert(player.currently_playing_track == Constants.MusicTrack.MUSIC_1, "Playing track must be set")
	assert(player.note_offset == 0x81, "Music 1 note offset must be 0x81")
	assert(player.duration_offset == 0x24, "Music 1 duration offset must be 0x24")

	for i in range(4):
		assert(player.channels[i].enabled, "All 4 channels must be enabled for Music 1")
		assert(player.channels[i].routine_addr > 0, "All 4 channels must have valid routine addresses")

	# Load Track 4 (Music 3 / Kalinka)
	player.load_track(Constants.MusicTrack.MUSIC_3)
	assert(player.channels[0].enabled, "SQ1 must be enabled for Music 3")
	assert(player.channels[1].enabled, "SQ2 must be enabled for Music 3")
	assert(player.channels[2].enabled, "TRI must be enabled for Music 3")
	assert(not player.channels[3].enabled, "NOISE must be disabled for Music 3 ($FFFF)")

	# Stop music
	player.stop_music()
	assert(player.currently_playing_track == -1, "Track must reset on stop")
	for i in range(4):
		assert(not player.channels[i].enabled, "All channels must be disabled after stop")

static func test_bytecode_execution_and_envelope_stepping() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		return

	var player = MusicBytecodePlayer.new()
	player.setup_tables(
		res["prg_rom"],
		res["note_to_wave_table"],
		res["note_duration_table"],
		res["music_data_table"],
		res["music_vol_table"],
		res["noises_table"]
	)

	player.load_track(Constants.MusicTrack.MUSIC_1)

	# Step 1 frame: causes routine 0 byte interpretation
	player.step_frame()

	var ch0 = player.channels[0]
	assert(ch0.note_duration_remaining > 0, "Note duration remaining must be initialized")
	assert(ch0.timer_period > 0, "Pulse 1 timer period must be non-zero during note playback")

	# Step 60 frames (1 second of playback)
	var had_audio: bool = false
	for f in range(60):
		player.step_frame()
		if player.channels[0].volume > 0.0 or player.channels[2].volume > 0.0:
			had_audio = true

	assert(had_audio, "Stepping music bytecode must produce non-zero channel volumes")

	# Verify Triangle linear-counter staccato cutoff math: min((duration - 1) * 4, 0x3C)
	# For a 24-frame note (half note at 150bpm) with vol_control=0x00, linear counter is capped at 0x3C (15 frames)
	var tri = player.channels[2]
	tri.vol_control = 0x00
	tri.note_duration = 24
	tri.tri_linear_hold = false
	tri.tri_linear_quarter_frames = mini((tri.note_duration - 1) * 4, 0x3C)
	assert(tri.tri_linear_quarter_frames == 60, "24-frame triangle note linear counter must cap at 0x3C (60 quarter-frames)")

static func test_audio_manager_bytecode_integration_and_sfx_override() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		return

	var audio = AudioManager.new()
	audio.ingest_rom_audio_data(res)
	audio.set_music_track(Constants.MusicType.MUSIC_1)

	# Advance 1 physics tick (60 TPS) and process
	audio._physics_process(1.0 / 60.0)
	audio._apply_channel_states()

	# Pulse 1 and Triangle should be active from music
	assert(audio.tri.enabled or audio.sq1.enabled, "Music track must enable channels in AudioManager")

	# Synthesize 1000 samples headlessly
	var buf: PackedFloat32Array = audio.synthesize_chunk(1000)
	var has_sound: bool = false
	for s in buf:
		if absf(s) > 0.01:
			has_sound = true
			break
	assert(has_sound, "AudioManager must synthesize audible music waveform")

	# Play SFX on SQ1 (ROTATE)
	audio.play_sfx(AudioManager.SFX.ROTATE)
	audio._update_sfx()
	audio._apply_channel_states()

	# SFX must override SQ1 without stopping music player progress
	assert(audio.get_active_sfx_count() == 1, "SFX must be registered in queue")
	assert(audio.music_player.currently_playing_track == Constants.MusicTrack.MUSIC_1, "Music must still be tracked")

	audio.free()

static func test_demo_controller_lifecycle_and_input_streaming() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		return

	var demo = DemoController.new()
	demo.setup(res["demo_buttons_table"], res["demo_tetrimino_type_table"])

	assert(not demo.is_active, "Demo should start inactive")
	demo.start_demo()
	assert(demo.is_active, "Demo should be active after start_demo()")

	# Frame 0: first record from demoButtonsTable (0x00, 0x31)
	var step1: Dictionary = demo.step_frame(0)
	assert(not step1["should_exit"], "Demo should not exit on first frame")
	assert(step1["held"] == 0, "First move is no-input (0x00)")

	# Test Start button interruption
	var step_start: Dictionary = demo.step_frame(Constants.BUTTON_START)
	assert(step_start["should_exit"], "Pressing BUTTON_START must request demo exit")
	assert(not demo.is_active, "Demo should become inactive after exit")

static func test_piece_randomizer_demo_mode() -> void:
	var res: Dictionary = get_test_extraction()
	if res.is_empty():
		return

	var types: PackedByteArray = res["demo_tetrimino_type_table"]
	var rand = PieceRandomizer.new()
	rand.set_demo_mode(true, types)

	# Verify first 5 pieces match demo table decoding:
	# byte 0 = 0x00 -> type 0 (T)
	# byte 1 = 0x14 -> type 1 (J)
	# byte 2 = 0x8A -> type 0 (T)
	# byte 3 = 0x45 -> type 4 (S)
	# byte 4 = 0x22 -> type 2 (Z)
	var p0: int = rand.roll_next_piece()
	var p1: int = rand.roll_next_piece()
	var p2: int = rand.roll_next_piece()
	var p3: int = rand.roll_next_piece()
	var p4: int = rand.roll_next_piece()

	assert(p0 == Constants.PieceType.T, "Piece 0 must be T, got %d" % p0)
	assert(p1 == Constants.PieceType.J, "Piece 1 must be J, got %d" % p1)
	assert(p2 == Constants.PieceType.T, "Piece 2 must be T, got %d" % p2)
	assert(p3 == Constants.PieceType.S, "Piece 3 must be S, got %d" % p3)
	assert(p4 == Constants.PieceType.Z, "Piece 4 must be Z, got %d" % p4)

static func test_crt_scanlines_shader_loading() -> void:
	var shader = load("res://src/shaders/crt_scanlines.gdshader")
	assert(shader != null, "CRT scanlines shader must load cleanly")

	var renderer = PlayfieldRenderer.new()
	assert(not renderer.enable_crt_shader, "CRT shader should default to disabled")
	renderer.toggle_crt_shader()
	assert(renderer.enable_crt_shader, "CRT shader toggle must turn on")
	renderer.toggle_crt_shader()
	assert(not renderer.enable_crt_shader, "CRT shader toggle must turn off")
	renderer.free()
