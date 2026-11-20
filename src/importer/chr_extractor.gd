class_name CHRExtractor
extends RefCounted

## Pure GDScript iNES header parser and 2bpp planar CHR-ROM decoder.
## Provides an optional extraction pipeline for user-supplied NES Tetris ROM dumps (e.g. user://nes_data/tetris.nes).
## Extracts 16KB CHR-ROM tilesets, PRG-ROM color palettes, and generates native Godot Image and ImageTexture assets.

const Constants = preload("res://src/core/constants.gd")

const INES_HEADER_SIZE: int = 16
const PRG_BANK_SIZE: int = 16384
const CHR_BANK_SIZE: int = 4096
const TOTAL_CHR_SIZE: int = 16384 # 4 banks of 4096 bytes

# Authentic NES Tetris ROM Offsets (verified against disassembly & PRG-ROM)
const COLOR_TABLE_ROM_OFFSET: int = 0x00185C # CPU $984C (40 bytes: 10 levels * 4 colors)
const GAME_BANK_OFFSET: int = 12288          # Bank 3 in 16KB CHR

# Authentic Game Tile Indices in CHR Bank 3
const TILE_PRIMARY_INDEX: int = 0x7B   # Tile 1: Bevelled frame block
const TILE_SECONDARY_INDEX: int = 0x7C # Tile 2: Gem / specular block
const TILE_TERTIARY_INDEX: int = 0x7D  # Tile 3: Primary with highlight
const TILE_CURTAIN_INDEX: int = 0x4F   # Curtain wipe block

## Decodes a 16-byte NES 2bpp planar tile into an array of 64 pixel color indices (0..3).
## NES 2bpp planar format:
## Bytes 0..7: Bitplane 0 (low bit of pixels in rows 0..7)
## Bytes 8..15: Bitplane 1 (high bit of pixels in rows 0..7)
static func decode_tile_2bpp(tile_bytes: PackedByteArray, offset: int = 0) -> PackedByteArray:
	var pixels: PackedByteArray = PackedByteArray()
	pixels.resize(64)

	if tile_bytes.size() < offset + 16:
		return pixels

	for y in range(8):
		var plane0: int = tile_bytes[offset + y]
		var plane1: int = tile_bytes[offset + y + 8]
		for x in range(8):
			var bit: int = 7 - x
			var p0: int = (plane0 >> bit) & 1
			var p1: int = (plane1 >> bit) & 1
			var color_index: int = p0 | (p1 << 1)
			pixels[y * 8 + x] = color_index

	return pixels

## Extracts an individual 8x8 tile Image from raw CHR bytes.
static func extract_tile_image(chr_bytes: PackedByteArray, tile_index: int, palette_rgb: Array[Color] = []) -> Image:
	var tile_offset: int = tile_index * 16
	var pixels: PackedByteArray = decode_tile_2bpp(chr_bytes, tile_offset)
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)

	for y in range(8):
		for x in range(8):
			var c_idx: int = pixels[y * 8 + x]
			if palette_rgb.size() >= 4:
				img.set_pixel(x, y, palette_rgb[c_idx])
			else:
				var gray: float = float(c_idx) / 3.0
				img.set_pixel(x, y, Color(gray, gray, gray, 1.0 if c_idx > 0 else 0.0))

	return img

## Converts a 4096-byte CHR bank (256 tiles) into a 128x128 pixel Image (16x16 tiles of 8x8).
static func chr_bank_to_image(chr_bytes: PackedByteArray, bank_offset: int = 0, palette_rgb: Array[Color] = []) -> Image:
	var width: int = 128
	var height: int = 128
	var img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)

	for tile_idx in range(256):
		var tile_offset: int = bank_offset + tile_idx * 16
		var tile_pixels: PackedByteArray = decode_tile_2bpp(chr_bytes, tile_offset)
		var tile_x: int = (tile_idx % 16) * 8
		var tile_y: int = int(tile_idx / 16) * 8

		for py in range(8):
			for px in range(8):
				var c_idx: int = tile_pixels[py * 8 + px]
				if palette_rgb.size() >= 4:
					var col: Color = palette_rgb[c_idx]
					img.set_pixel(tile_x + px, tile_y + py, col)
				else:
					var gray: float = float(c_idx) / 3.0
					img.set_pixel(tile_x + px, tile_y + py, Color(gray, gray, gray, 1.0 if c_idx > 0 else 0.0))

	return img

## Parses raw ROM bytes and extracts CHR tilesets, level palettes, and generates level textures.
static func extract_all_from_rom_bytes(rom_bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error_message": "",
	}

	if rom_bytes.size() < INES_HEADER_SIZE:
		result["error_message"] = "ROM too small: Header missing"
		return result

	# Verify iNES magic: 'N', 'E', 'S', 0x1A
	if rom_bytes[0] != 0x4E or rom_bytes[1] != 0x45 or rom_bytes[2] != 0x53 or rom_bytes[3] != 0x1A:
		result["error_message"] = "Invalid iNES header magic"
		return result

	var prg_chunks: int = rom_bytes[4]
	var prg_bytes_size: int = prg_chunks * PRG_BANK_SIZE
	var chr_offset: int = INES_HEADER_SIZE + prg_bytes_size

	if rom_bytes.size() < chr_offset + TOTAL_CHR_SIZE:
		result["error_message"] = "ROM truncated: CHR-ROM data incomplete"
		return result

	# Extract CHR data
	var chr_data: PackedByteArray = rom_bytes.slice(chr_offset, chr_offset + TOTAL_CHR_SIZE)
	var chr_bank_3_game: PackedByteArray = chr_data.slice(GAME_BANK_OFFSET, GAME_BANK_OFFSET + CHR_BANK_SIZE)

	result["chr_raw"] = chr_data
	result["chr_bank_3_game"] = chr_bank_3_game

	# Extract Palettes from PRG-ROM (CPU $984C)
	var color_table: Array[Array] = []
	for lvl in range(10):
		var pal: Array[int] = []
		for c in range(4):
			var byte_pos: int = COLOR_TABLE_ROM_OFFSET + lvl * 4 + c
			if byte_pos < rom_bytes.size():
				pal.append(rom_bytes[byte_pos])
			else:
				pal.append(0x0F)
		color_table.append(pal)
	result["color_table"] = color_table

	# Generate level textures for all 10 cycling levels
	var level_textures: Array[Dictionary] = []
	for lvl in range(10):
		var nes_indices: Array = color_table[lvl]
		var rgb_pal: Array[Color] = [
			Color(0.0, 0.0, 0.0, 0.0), # Color index 0 is transparent / playfield background
			Constants.NES_MASTER_PALETTE[nes_indices[1]],
			Constants.NES_MASTER_PALETTE[nes_indices[2]],
			Constants.NES_MASTER_PALETTE[nes_indices[3]],
		]

		# 128x128 full bank sheet
		var sheet_img: Image = chr_bank_to_image(chr_bank_3_game, 0, rgb_pal)
		var sheet_tex: ImageTexture = ImageTexture.create_from_image(sheet_img)

		# Individual 8x8 tile textures
		var t1_img: Image = extract_tile_image(chr_bank_3_game, TILE_PRIMARY_INDEX, rgb_pal)
		var t2_img: Image = extract_tile_image(chr_bank_3_game, TILE_SECONDARY_INDEX, rgb_pal)
		var t3_img: Image = extract_tile_image(chr_bank_3_game, TILE_TERTIARY_INDEX, rgb_pal)
		var curtain_img: Image = extract_tile_image(chr_bank_3_game, TILE_CURTAIN_INDEX, rgb_pal)

		level_textures.append({
			"sheet": sheet_tex,
			"tile_1": ImageTexture.create_from_image(t1_img),
			"tile_2": ImageTexture.create_from_image(t2_img),
			"tile_3": ImageTexture.create_from_image(t3_img),
			"tile_curtain": ImageTexture.create_from_image(curtain_img),
			"tile_1_img": t1_img,
			"tile_2_img": t2_img,
			"tile_3_img": t3_img,
		})

	result["level_textures"] = level_textures
	result["success"] = true
	return result

## Extracts from a ROM file path (e.g. user://nes_data/tetris.nes).
static func extract_from_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {
			"success": false,
			"error_message": "File does not exist: %s" % file_path,
		}

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file_path)
	if bytes.is_empty():
		return {
			"success": false,
			"error_message": "Could not read ROM bytes from: %s" % file_path,
		}

	return extract_all_from_rom_bytes(bytes)

## Saves extracted textures as PNG images to output_dir (e.g. user://nes_data/).
static func save_extracted_assets(extraction_result: Dictionary, output_dir: String = "user://nes_data/") -> bool:
	if not extraction_result.get("success", false):
		return false

	var err: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return false

	var level_textures: Array = extraction_result.get("level_textures", [])
	for lvl in range(level_textures.size()):
		var entry: Dictionary = level_textures[lvl] as Dictionary
		var t1_img: Image = entry.get("tile_1_img") as Image
		var t2_img: Image = entry.get("tile_2_img") as Image
		var t3_img: Image = entry.get("tile_3_img") as Image

		if t1_img != null:
			t1_img.save_png(output_dir.path_join("tile_primary_lvl_%d.png" % lvl))
		if t2_img != null:
			t2_img.save_png(output_dir.path_join("tile_secondary_lvl_%d.png" % lvl))
		if t3_img != null:
			t3_img.save_png(output_dir.path_join("tile_tertiary_lvl_%d.png" % lvl))

	return true

## Applies extracted tile textures directly to the global ContentRegistry autoload or a supplied instance.
static func apply_to_content_registry(extraction_result: Dictionary, registry: Node = null) -> bool:
	if not extraction_result.get("success", false):
		return false

	var level_textures: Array = extraction_result.get("level_textures", [])
	if level_textures.is_empty():
		return false

	var reg: Node = registry
	if reg == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			var tree: SceneTree = main_loop as SceneTree
			if tree.root != null:
				reg = tree.root.get_node_or_null("/root/ContentRegistry")

	if reg == null:
		return false

	# Create empty transparent 8x8 texture for TileType.EMPTY (0)
	var empty_img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	empty_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var empty_tex: ImageTexture = ImageTexture.create_from_image(empty_img)

	for lvl in range(level_textures.size()):
		var entry: Dictionary = level_textures[lvl] as Dictionary
		var t1_tex: ImageTexture = entry.get("tile_1") as ImageTexture
		var t2_tex: ImageTexture = entry.get("tile_2") as ImageTexture
		var t3_tex: ImageTexture = entry.get("tile_3") as ImageTexture

		var textures: Array[ImageTexture] = [empty_tex, t1_tex, t2_tex, t3_tex]
		reg.set_custom_level_textures(lvl, textures)

	return true
