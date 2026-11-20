class_name TestImporter
extends RefCounted

## Verification test suite for pure-GDScript iNES header parsing, cryptographic validation (SHA-256 / CRC32),
## 2bpp planar CHR-ROM tile decoding, 100% PRG data extraction, and ContentRegistry / AudioManager integration.

const CHRExtractor = preload("res://src/importer/chr_extractor.gd")
const Constants = preload("res://src/core/constants.gd")
const ContentRegistryScript = preload("res://src/core/content_registry.gd")
const AudioManager = preload("res://src/audio/audio_manager.gd")

static func run_tests() -> bool:
	print("--- Running TestImporter ---")
	test_crc32_and_sha256_algorithms()
	test_2bpp_planar_decoder()
	test_tile_0x7b_authentic_decoding()
	test_error_handling()
	test_rom_checksum_validation()
	test_100_percent_data_extraction()
	test_content_registry_and_audio_injection()
	test_persistence_and_auto_ingestion()
	print("  -> TestImporter: PASSED")
	return true

static func test_crc32_and_sha256_algorithms() -> void:
	# Test CRC32 of 'NES\x1A'
	var nes_magic: PackedByteArray = PackedByteArray([0x4E, 0x45, 0x53, 0x1A])
	var crc: int = CHRExtractor.compute_crc32(nes_magic)
	assert(crc == 0x402A48D4, "CRC32 of NES\\x1A must be 0x402A48D4, got %x" % crc)

	# Test SHA256 of empty bytes
	var empty_sha: String = CHRExtractor.compute_sha256(PackedByteArray())
	assert(empty_sha == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA256 of empty bytes must match standard digest")

static func test_2bpp_planar_decoder() -> void:
	# 1. All zeros -> 64 zeros
	var zero_bytes: PackedByteArray = PackedByteArray()
	zero_bytes.resize(16)
	var pixels_zero: PackedByteArray = CHRExtractor.decode_tile_2bpp(zero_bytes)
	assert(pixels_zero.size() == 64, "Decoded pixels must have size 64")
	for p in pixels_zero:
		assert(p == 0, "All-zero tile bytes must yield color 0")

	# 2. All 0xFF -> 64 threes (color 3)
	var ff_bytes: PackedByteArray = PackedByteArray()
	for i in range(16):
		ff_bytes.append(0xFF)
	var pixels_three: PackedByteArray = CHRExtractor.decode_tile_2bpp(ff_bytes)
	for p in pixels_three:
		assert(p == 3, "All-0xFF tile bytes must yield color 3")

	# 3. Plane 0 = 0xFF, Plane 1 = 0x00 -> 64 ones (color 1)
	var plane0_only: PackedByteArray = PackedByteArray()
	for i in range(8):
		plane0_only.append(0xFF)
	for i in range(8):
		plane0_only.append(0x00)
	var pixels_one: PackedByteArray = CHRExtractor.decode_tile_2bpp(plane0_only)
	for p in pixels_one:
		assert(p == 1, "Plane0=0xFF, Plane1=0x00 must yield color 1")

	# 4. Plane 0 = 0x00, Plane 1 = 0xFF -> 64 twos (color 2)
	var plane1_only: PackedByteArray = PackedByteArray()
	for i in range(8):
		plane1_only.append(0x00)
	for i in range(8):
		plane1_only.append(0xFF)
	var pixels_two: PackedByteArray = CHRExtractor.decode_tile_2bpp(plane1_only)
	for p in pixels_two:
		assert(p == 2, "Plane0=0x00, Plane1=0xFF must yield color 2")

static func test_tile_0x7b_authentic_decoding() -> void:
	# Authentic NES Tetris Tile 0x7B (Primary Bevel Block)
	var tile_7b_bytes: PackedByteArray = PackedByteArray([
		0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0x00,
		0x7E, 0x82, 0x82, 0x82, 0x82, 0x82, 0xFE, 0x00
	])

	var pixels: PackedByteArray = CHRExtractor.decode_tile_2bpp(tile_7b_bytes)
	assert(pixels.size() == 64, "Decoded pixels size must be 64")

	var expected_row_0: Array[int] = [1, 3, 3, 3, 3, 3, 3, 0]
	for x in range(8):
		assert(pixels[x] == expected_row_0[x], "Row 0 pixel %d mismatch" % x)

	var expected_row_1: Array[int] = [3, 1, 1, 1, 1, 1, 3, 0]
	for x in range(8):
		assert(pixels[8 + x] == expected_row_1[x], "Row 1 pixel %d mismatch" % x)

static func test_error_handling() -> void:
	# 1. Empty buffer
	var res_empty: Dictionary = CHRExtractor.extract_all_from_rom_bytes(PackedByteArray(), true)
	assert(not res_empty.success, "Empty buffer must fail extraction")

	# 2. Too short (< 16 bytes)
	var short_bytes: PackedByteArray = PackedByteArray([0x4E, 0x45, 0x53])
	var res_short: Dictionary = CHRExtractor.extract_all_from_rom_bytes(short_bytes, true)
	assert(not res_short.success, "Short buffer must fail extraction")

	# 3. Invalid magic header
	var bad_header: PackedByteArray = PackedByteArray()
	bad_header.resize(100)
	bad_header[0] = 0x00
	var res_bad: Dictionary = CHRExtractor.extract_all_from_rom_bytes(bad_header, true)
	assert(not res_bad.success, "Bad header magic must fail extraction")

	# 4. Truncated CHR
	var truncated: PackedByteArray = PackedByteArray([
		0x4E, 0x45, 0x53, 0x1A,
		0x02, 0x02, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00
	])
	truncated.resize(100)
	var res_trunc: Dictionary = CHRExtractor.extract_all_from_rom_bytes(truncated, true)
	assert(not res_trunc.success, "Truncated ROM must fail extraction")

	# 5. Non-existent file
	var res_missing: Dictionary = CHRExtractor.extract_from_file("res://non_existent_rom.nes")
	assert(not res_missing.success, "Non-existent file must fail extraction")

static func test_rom_checksum_validation() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		return

	var rom_bytes: PackedByteArray = FileAccess.get_file_as_bytes(rom_path)
	var chk: Dictionary = CHRExtractor.verify_rom_checksums(rom_bytes)

	assert(chk.valid == true, "Authentic ROM checksum validation must pass")
	assert(chk.is_prg_match == true, "PRG checksum must match authentic NES release")
	assert(chk.is_chr_match == true, "CHR checksum must match authentic NES release")
	assert(chk.prg_sha256 == CHRExtractor.EXPECTED_PRG_SHA256, "PRG SHA-256 must match authentic value")
	assert(chk.prg_crc32 == CHRExtractor.EXPECTED_PRG_CRC32, "PRG CRC32 must match authentic value")
	assert(chk.chr_sha256 == CHRExtractor.EXPECTED_CHR_SHA256, "CHR SHA-256 must match authentic value")
	assert(chk.chr_crc32 == CHRExtractor.EXPECTED_CHR_CRC32, "CHR CRC32 must match authentic value")

static func test_100_percent_data_extraction() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		return

	var res: Dictionary = CHRExtractor.extract_from_file(rom_path, true)
	assert(res.success == true, "ROM extraction must succeed")

	# 1. 16KB CHR-ROM & 4 Banks
	assert(res.chr_raw.size() == 16384, "Total CHR raw must be 16384 bytes")
	assert(res.chr_bank_0_title.size() == 4096, "Bank 0 Title must be 4096 bytes")
	assert(res.chr_bank_1_typeb.size() == 4096, "Bank 1 Type B must be 4096 bytes")
	assert(res.chr_bank_2_typea.size() == 4096, "Bank 2 Type A must be 4096 bytes")
	assert(res.chr_bank_3_game.size() == 4096, "Bank 3 Game must be 4096 bytes")

	# 2. PRG-ROM Level Palettes ($984C)
	var color_table: Array = res.color_table
	assert(color_table.size() == 10, "Color table must contain 10 levels")
	assert(color_table[0] == [0x0F, 0x30, 0x21, 0x12], "Level 0 palette must match authentic indices")
	assert(color_table[9] == [0x0F, 0x30, 0x27, 0x16], "Level 9 palette must match authentic indices")

	# 3. PRG-ROM Gravity Table ($898E)
	var grav: Array = res.gravity_table
	assert(grav.size() == 30, "Gravity table must have 30 entries")
	assert(grav[0] == 48, "Level 0 gravity must be 48 frames")
	assert(grav[9] == 6, "Level 9 gravity must be 6 frames")
	assert(grav[19] == 2, "Level 19 gravity must be 2 frames")
	assert(grav[29] == 1, "Level 29 gravity must be 1 frame")

	# 4. PRG-ROM Points Scoring Table ($9CA5)
	var pts: Array = res.points_table
	assert(pts.size() == 5, "Points table must have 5 entries")
	assert(pts[0] == 0 and pts[1] == 40 and pts[2] == 100 and pts[3] == 300 and pts[4] == 1200, "Points table must match 0, 40, 100, 300, 1200")

	# 5. PRG-ROM Spawn Orientations ($994F)
	var spawn: Array = res.spawn_orientations
	assert(spawn.size() == 7, "Spawn orientations must have 7 entries")
	assert(spawn == [2, 7, 8, 10, 11, 14, 18], "Spawn orientations must match [2, 7, 8, 10, 11, 14, 18]")

	# 6. PRG-ROM Audio Tables
	assert(res.note_to_wave_table.size() == 134, "Note-to-wave table must be 134 bytes")
	assert(res.note_duration_table.size() == 77, "Note duration table must be 77 bytes")
	assert(res.music_data_table.size() == 100, "Music data table must be 100 bytes")

	# 7. Level Textures
	var level_textures: Array = res.level_textures
	assert(level_textures.size() == 10, "Must generate textures for 10 cycling levels")
	assert(level_textures[0].tile_1 is ImageTexture, "Tile 1 must be ImageTexture")
	assert(level_textures[0].tile_2 is ImageTexture, "Tile 2 must be ImageTexture")
	assert(level_textures[0].tile_3 is ImageTexture, "Tile 3 must be ImageTexture")

static func test_content_registry_and_audio_injection() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		return

	var res: Dictionary = CHRExtractor.extract_from_file(rom_path, true)
	assert(res.success == true)

	var reg = ContentRegistryScript.new()
	var aud = AudioManager.new()

	var applied: bool = CHRExtractor.apply_to_registry_and_audio(res, reg, aud)
	assert(applied == true, "apply_to_registry_and_audio must succeed")
	assert(reg.is_ready() == true, "ContentRegistry must be ready after ROM injection")
	assert(aud.is_initialized == true, "AudioManager must be initialized after ROM injection")

	# Verify table lookups on registry
	assert(reg.get_gravity_frames(0) == 48, "Registry gravity level 0 must be 48")
	assert(reg.get_score_points(4) == 1200, "Registry score for 4 lines must be 1200")
	assert(reg.get_tile_texture(Constants.TileType.PRIMARY, 0) != null, "Primary tile texture must not be null")

	reg.reset_custom_textures()
	reg.free()
	aud.free()

static func test_persistence_and_auto_ingestion() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		return

	var res: Dictionary = CHRExtractor.auto_ingest_rom("user://test_nes_data/")
	assert(res.success == true, "auto_ingest_rom must locate and extract authentic ROM")
	assert(CHRExtractor.is_rom_extracted("user://test_nes_data/"), "is_rom_extracted must report true after saving")
