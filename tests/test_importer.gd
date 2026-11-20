class_name TestImporter
extends RefCounted

## Verification test suite for pure-GDScript iNES header parsing,
## 2bpp planar CHR-ROM tile decoding, palette extraction, and ContentRegistry integration.

const CHRExtractor = preload("res://src/importer/chr_extractor.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestImporter ---")
	test_2bpp_planar_decoder()
	test_tile_0x7b_authentic_decoding()
	test_error_handling()
	test_extract_from_rom_file()
	test_content_registry_injection()
	print("  -> TestImporter: PASSED")
	return true

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
	# Plane 0: 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0x00
	# Plane 1: 0x7E, 0x82, 0x82, 0x82, 0x82, 0x82, 0xFE, 0x00
	var tile_7b_bytes: PackedByteArray = PackedByteArray([
		0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0xFE, 0x00,
		0x7E, 0x82, 0x82, 0x82, 0x82, 0x82, 0xFE, 0x00
	])

	var pixels: PackedByteArray = CHRExtractor.decode_tile_2bpp(tile_7b_bytes)
	assert(pixels.size() == 64, "Decoded pixels size must be 64")

	# Row 0: plane0=0xFE (11111110), plane1=0x7E (01111110)
	# Pixel 0: (1, 0) -> 1 (White)
	# Pixels 1..6: (1, 1) -> 3 (Primary)
	# Pixel 7: (0, 0) -> 0 (Shadow/empty)
	var expected_row_0: Array[int] = [1, 3, 3, 3, 3, 3, 3, 0]
	for x in range(8):
		assert(pixels[x] == expected_row_0[x], "Row 0 pixel %d mismatch: got %d, expected %d" % [x, pixels[x], expected_row_0[x]])

	# Row 1: plane0=0xFE (11111110), plane1=0x82 (10000010)
	# Pixel 0: (1, 1) -> 3 (Primary)
	# Pixels 1..5: (1, 0) -> 1 (White)
	# Pixel 6: (1, 1) -> 3 (Primary)
	# Pixel 7: (0, 0) -> 0 (Shadow/empty)
	var expected_row_1: Array[int] = [3, 1, 1, 1, 1, 1, 3, 0]
	for x in range(8):
		assert(pixels[8 + x] == expected_row_1[x], "Row 1 pixel %d mismatch: got %d, expected %d" % [x, pixels[8 + x], expected_row_1[x]])

static func test_error_handling() -> void:
	# 1. Empty buffer
	var res_empty: Dictionary = CHRExtractor.extract_all_from_rom_bytes(PackedByteArray())
	assert(not res_empty.success, "Empty buffer must fail extraction")

	# 2. Too short (< 16 bytes)
	var short_bytes: PackedByteArray = PackedByteArray([0x4E, 0x45, 0x53])
	var res_short: Dictionary = CHRExtractor.extract_all_from_rom_bytes(short_bytes)
	assert(not res_short.success, "Short buffer must fail extraction")

	# 3. Invalid magic header
	var bad_header: PackedByteArray = PackedByteArray()
	bad_header.resize(100)
	bad_header[0] = 0x00
	var res_bad: Dictionary = CHRExtractor.extract_all_from_rom_bytes(bad_header)
	assert(not res_bad.success, "Bad header magic must fail extraction")

	# 4. Truncated CHR
	var truncated: PackedByteArray = PackedByteArray([
		0x4E, 0x45, 0x53, 0x1A, # NES\x1A
		0x02, 0x02, 0x00, 0x00, # 2 PRG chunks = 32KB
		0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00
	])
	truncated.resize(100) # Far less than 32KB + 16KB
	var res_trunc: Dictionary = CHRExtractor.extract_all_from_rom_bytes(truncated)
	assert(not res_trunc.success, "Truncated ROM must fail extraction")

	# 5. Non-existent file
	var res_missing: Dictionary = CHRExtractor.extract_from_file("res://non_existent_rom.nes")
	assert(not res_missing.success, "Non-existent file must fail extraction")

static func test_extract_from_rom_file() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		print("  [Note] Tetris (USA).nes not present, skipping live ROM parsing assertion.")
		return

	var res: Dictionary = CHRExtractor.extract_from_file(rom_path)
	assert(res.success == true, "ROM extraction from Tetris (USA).nes must succeed")
	assert(res.chr_raw.size() == 16384, "Extracted CHR-ROM size must be 16384 bytes")
	assert(res.chr_bank_3_game.size() == 4096, "Extracted Game Bank 3 size must be 4096 bytes")

	# Verify Color Table
	var color_table: Array = res.color_table
	assert(color_table.size() == 10, "Color table must contain 10 levels")
	# Level 0 palette: [0x0F, 0x30, 0x21, 0x12]
	assert(color_table[0] == [0x0F, 0x30, 0x21, 0x12], "Level 0 color table must match authentic indices")
	# Level 9 palette: [0x0F, 0x30, 0x27, 0x16]
	assert(color_table[9] == [0x0F, 0x30, 0x27, 0x16], "Level 9 color table must match authentic indices")

	# Verify Level Textures
	var level_textures: Array = res.level_textures
	assert(level_textures.size() == 10, "Must generate textures for 10 cycling levels")
	var lvl0_entry: Dictionary = level_textures[0]
	assert(lvl0_entry.sheet is ImageTexture, "Sheet must be an ImageTexture")
	assert(lvl0_entry.tile_1 is ImageTexture, "Tile 1 must be an ImageTexture")
	assert(lvl0_entry.tile_2 is ImageTexture, "Tile 2 must be an ImageTexture")
	assert(lvl0_entry.tile_3 is ImageTexture, "Tile 3 must be an ImageTexture")
	assert(lvl0_entry.tile_curtain is ImageTexture, "Curtain tile must be an ImageTexture")

static func test_content_registry_injection() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		return

	var res: Dictionary = CHRExtractor.extract_from_file(rom_path)
	if not res.success:
		return

	var ContentRegistryScript = preload("res://src/core/content_registry.gd")
	var reg = ContentRegistryScript.new()

	var applied: bool = CHRExtractor.apply_to_content_registry(res, reg)
	assert(applied == true, "Applying extracted textures to ContentRegistry must return true")

	# Check that ContentRegistry returns valid textures
	var tex_pri: Texture2D = reg.get_tile_texture(Constants.TileType.PRIMARY, 0)
	assert(tex_pri != null, "Injected primary texture must not be null")

	# Reset to default procedural textures
	reg.reset_custom_textures()
	reg.free()

