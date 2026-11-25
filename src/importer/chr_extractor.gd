class_name CHRExtractor
extends RefCounted

## Pure GDScript iNES parser, cryptographic validator, and 100% authentic PRG/CHR data extractor.
## Enforces Mandatory ROM Ingestion: extracts 100% of graphics, lookup tables, and APU audio data.
## Zero procedural fallbacks: the engine refuses to run unless valid ROM data is ingested.

const Constants = preload("res://src/core/constants.gd")

const INES_HEADER_SIZE: int = 16
const PRG_BANK_SIZE: int = 16384
const CHR_BANK_SIZE: int = 4096
const TOTAL_PRG_SIZE: int = 32768 # 2 banks of 16KB
const TOTAL_CHR_SIZE: int = 16384 # 4 banks of 4KB
const TOTAL_ROM_SIZE: int = 49168 # 16 header + 32KB PRG + 16KB CHR

# --- Authentic 1989 NTSC NES Tetris (USA) Checksums ---
const EXPECTED_PRG_SHA256: String = "a2de35dfa7333b0458762a1485fb612b6bdc9b5a15269f0fcf5a6be67c0d89de"
const EXPECTED_PRG_CRC32: int = 0x943DFBBE
const EXPECTED_CHR_SHA256: String = "23789834e66947081aa5d34efe092beb69a91273abc62089a8bb7c00f67ff751"
const EXPECTED_CHR_CRC32: int = 0x251AF21C
const EXPECTED_ROM_SHA256: String = "acab10f2dbad4d4ef5d56b31cd4cea208bb6e2e2c5dba5eb339d711ec04e3535"
const EXPECTED_ROM_CRC32: int = 0x6D72C53A

# --- Verified Authentic PRG-ROM Offsets (File Offsets) ---
const COLOR_TABLE_ROM_OFFSET: int = 0x00185C     # CPU $984C (40 bytes: 10 levels * 4 colors)
const GRAVITY_TABLE_ROM_OFFSET: int = 0x00099E   # CPU $898E (30 bytes: levels 0..29+)
const POINTS_TABLE_ROM_OFFSET: int = 0x001CB5    # CPU $9CA5 (10 bytes: 5 16-bit words)
const SPAWN_TABLE_ROM_OFFSET: int = 0x001966     # CPU $9956 (19 bytes: orientation to spawn orientation)
const SPAWN_ORIENTATIONS_OFFSET: int = 0x00195E # CPU $994E (7 bytes: piece spawn orientations)
const NOTE_TO_WAVE_ROM_OFFSET: int = 0x006B23    # CPU $EB13 (156 bytes: 78 pitch period words)
const NOTE_DURATION_ROM_OFFSET: int = 0x006BBF   # CPU $EBAF (126 bytes: note duration table)
const MUSIC_DATA_TABLE_ROM_OFFSET: int = 0x006C3D# CPU $EC2D (100 bytes: 10 track headers * 10 bytes)
const MUSIC_VOL_TABLE_ROM_OFFSET: int = 0x006A5A # CPU $EA4A (44 bytes: 22 16-bit envelope pointers)
const NOISES_TABLE_ROM_OFFSET: int = 0x0065BB    # CPU $E5AB (37 bytes: noise triples)
const DEMO_BUTTONS_ROM_OFFSET: int = 0x005D10    # CPU $DD00 (512 bytes: input recording)
const DEMO_TETRIMINO_TYPE_ROM_OFFSET: int = 0x005F10 # CPU $DF00 (256 bytes: piece types)
const DEFAULT_HIGH_SCORES_ROM_OFFSET: int = 0x002D77   # CPU $976D (default high score table)

# --- Verified Authentic PPU Palettes & Nametables (File Offsets) ---
const GAME_PALETTE_ROM_OFFSET: int = 0x002D03      # CPU $ACF3 (32 bytes + header)
const LEGAL_PALETTE_ROM_OFFSET: int = 0x002D27     # CPU $AD17 (16 bytes + header)
const MENU_PALETTE_ROM_OFFSET: int = 0x002D3B       # CPU $AD2B (20 bytes + header)
const ENDING_PALETTE_ROM_OFFSET: int = 0x002D53     # CPU $AD43 (32 bytes + header)
const LEGAL_NAMETABLE_ROM_OFFSET: int = 0x002DC8   # CPU $ADB8 (legal screen nametable)
const TITLE_NAMETABLE_ROM_OFFSET: int = 0x003229   # CPU $B219 (title screen compressed stream)
const GAME_TYPE_NAMETABLE_ROM_OFFSET: int = 0x00368A # CPU $B67A (game type menu compressed stream)
const LEVEL_MENU_NAMETABLE_ROM_OFFSET: int = 0x003AEB # CPU $BADB (level menu compressed stream)
const GAME_NAMETABLE_ROM_OFFSET: int = 0x003F4C    # CPU $BF3C (in-game HUD & playfield nametable)
const ENTER_HIGH_SCORE_NAMETABLE_ROM_OFFSET: int = 0x0043AD # CPU $C39D (enter high score compressed stream)
const HIGH_SCORE_NAMETABLE_ROM_OFFSET: int = 0x00480E # CPU $C7FE (high scores nametable patch)
const HEIGHT_PATCH_ROM_OFFSET: int = 0x00496D      # CPU $C95D (Type A height blanking patch)
const TYPE_B_LVL9_ENDING_NAMETABLE_ROM_OFFSET: int = 0x0049B6 # CPU $C9A6 (Type B level 9 castle ending)
const TYPE_B_ENDING_NAMETABLE_ROM_OFFSET: int = 0x004E17 # CPU $CE07 (Type B ending nametable)
const TYPE_A_ENDING_NAMETABLE_ROM_OFFSET: int = 0x005278 # CPU $D268 (Type A rocket ending nametable)
const TYPE_A_120K_PATCH_ROM_OFFSET: int = 0x0028DC # CPU $A8CC (Cathedral launchpad erase patch)
const GAME_TYPEB_PATCH_ROM_OFFSET: int = 0x0006C0  # CPU $86B0 (Game Type B HUD patch)

# --- CHR Bank Offsets & Game Tile Indices ---
const CHR_BANK_0_TITLE: int = 0
const CHR_BANK_1_TYPEB: int = 4096
const CHR_BANK_2_TYPEA: int = 8192
const CHR_BANK_3_GAME: int = 12288

const TILE_PRIMARY_INDEX: int = 0x7B   # Tile 1: Bevelled frame block
const TILE_SECONDARY_INDEX: int = 0x7C # Tile 2: Gem / specular block
const TILE_TERTIARY_INDEX: int = 0x7D  # Tile 3: Primary with highlight
const TILE_CURTAIN_INDEX: int = 0x4F   # Curtain wipe block

# Authentic 16x16 tile-aligned puzzle cluster (128x128 pixels)
# Composed of 64 interlocking NES Tetris tetrominoes (12 T, 12 L, 13 J, 11 S, 10 Z, 2 O, 4 I)
# using all 18 authentic CHR Bank 3 puzzle tiles (0x67, 0x70-0x75, 0x77-0x7A, 0x80-0x85, 0x87)
# including genuine inner corner and T-junction tiles.
# Wraps modulo-16 on both X and Y axes with ZERO seam errors, zero mirrored columns, and zero cut edges.
const WIDESCREEN_PUZZLE_CLUSTER_16X16: Array[Array] = [
	[0x72, 0x79, 0x7A, 0x67, 0x67, 0x78, 0x73, 0x78, 0x75, 0x7A, 0x67, 0x78, 0x79, 0x79, 0x7A, 0x67],
	[0x87, 0x72, 0x7A, 0x77, 0x82, 0x73, 0x82, 0x7A, 0x87, 0x67, 0x82, 0x79, 0x7A, 0x67, 0x78, 0x85],
	[0x78, 0x83, 0x78, 0x83, 0x67, 0x87, 0x67, 0x67, 0x72, 0x83, 0x67, 0x78, 0x79, 0x83, 0x67, 0x87],
	[0x7A, 0x67, 0x67, 0x72, 0x83, 0x78, 0x85, 0x77, 0x87, 0x67, 0x82, 0x73, 0x78, 0x73, 0x82, 0x79],
	[0x78, 0x85, 0x77, 0x87, 0x67, 0x67, 0x87, 0x82, 0x7A, 0x77, 0x67, 0x87, 0x67, 0x82, 0x7A, 0x67],
	[0x73, 0x87, 0x82, 0x7A, 0x77, 0x82, 0x73, 0x67, 0x78, 0x83, 0x74, 0x7A, 0x77, 0x78, 0x73, 0x82],
	[0x87, 0x67, 0x67, 0x78, 0x83, 0x67, 0x87, 0x74, 0x7A, 0x67, 0x87, 0x67, 0x82, 0x7A, 0x82, 0x7A],
	[0x79, 0x83, 0x82, 0x73, 0x72, 0x83, 0x67, 0x87, 0x67, 0x82, 0x73, 0x82, 0x79, 0x7A, 0x67, 0x78],
	[0x78, 0x79, 0x73, 0x87, 0x87, 0x67, 0x77, 0x78, 0x84, 0x7A, 0x87, 0x78, 0x73, 0x78, 0x85, 0x67],
	[0x73, 0x67, 0x87, 0x72, 0x7A, 0x77, 0x82, 0x7A, 0x78, 0x73, 0x78, 0x73, 0x82, 0x7A, 0x87, 0x82],
	[0x87, 0x77, 0x78, 0x83, 0x78, 0x83, 0x78, 0x75, 0x7A, 0x82, 0x7A, 0x77, 0x78, 0x79, 0x73, 0x67],
	[0x7A, 0x82, 0x7A, 0x67, 0x67, 0x78, 0x73, 0x87, 0x72, 0x7A, 0x67, 0x87, 0x67, 0x67, 0x87, 0x74],
	[0x72, 0x7A, 0x72, 0x83, 0x82, 0x73, 0x77, 0x67, 0x77, 0x67, 0x77, 0x72, 0x83, 0x82, 0x73, 0x87],
	[0x77, 0x67, 0x87, 0x78, 0x73, 0x87, 0x87, 0x77, 0x87, 0x77, 0x77, 0x87, 0x67, 0x67, 0x87, 0x67],
	[0x87, 0x77, 0x70, 0x71, 0x77, 0x70, 0x71, 0x77, 0x78, 0x83, 0x87, 0x78, 0x85, 0x77, 0x78, 0x85],
	[0x78, 0x83, 0x80, 0x81, 0x87, 0x80, 0x81, 0x87, 0x78, 0x79, 0x79, 0x7A, 0x87, 0x82, 0x7A, 0x87],
]

# Background puzzle tile IDs used in CHR Bank 0 (Title/Menus) and CHR Bank 3 (In-Game) nametables.
# Flood-filled from the 256x240 perimeter to render seamless transparency over the widescreen puzzle grid.
const BANK0_PUZZLE_TILES: Array[int] = [
	0x40, 0x41, 0x42, 0x43,
	0x60, 0x61, 0x62,
	0x70, 0x71, 0x72, 0x73,
	0x80, 0x81, 0x82, 0x83,
	0x90, 0x91,
	0xA0, 0xA1,
]
const BANK3_PUZZLE_TILES: Array[int] = [
	0x67, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75,
	0x77, 0x78, 0x79, 0x7A,
	0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x87,
]

# --- Cryptographic Helpers ---

static func compute_crc32(bytes: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	for b in bytes:
		crc ^= b
		for j in range(8):
			if (crc & 1) != 0:
				crc = ((crc >> 1) & 0x7FFFFFFF) ^ 0xEDB88320
			else:
				crc = (crc >> 1) & 0x7FFFFFFF
	return (~crc) & 0xFFFFFFFF

static func compute_sha256(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	var err: Error = ctx.start(HashingContext.HASH_SHA256)
	if err != OK:
		return ""
	if bytes.size() > 0:
		ctx.update(bytes)
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode()

## Verifies cryptographic SHA-256 and CRC32 checksums of PRG-ROM and CHR-ROM.
static func verify_rom_checksums(rom_bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {
		"valid": false,
		"prg_sha256": "",
		"prg_crc32": 0,
		"chr_sha256": "",
		"chr_crc32": 0,
		"is_prg_match": false,
		"is_chr_match": false,
		"error_message": "",
	}

	if rom_bytes.size() < INES_HEADER_SIZE:
		result["error_message"] = "ROM buffer too small (< 16 bytes)"
		return result

	if rom_bytes[0] != 0x4E or rom_bytes[1] != 0x45 or rom_bytes[2] != 0x53 or rom_bytes[3] != 0x1A:
		result["error_message"] = "Invalid iNES header magic"
		return result

	var prg_chunks: int = rom_bytes[4]
	var chr_chunks: int = rom_bytes[5]
	var prg_bytes_size: int = prg_chunks * PRG_BANK_SIZE
	var chr_offset: int = INES_HEADER_SIZE + prg_bytes_size

	if rom_bytes.size() < chr_offset + TOTAL_CHR_SIZE:
		result["error_message"] = "ROM truncated: expected at least %d bytes, got %d" % [chr_offset + TOTAL_CHR_SIZE, rom_bytes.size()]
		return result

	var prg_bytes: PackedByteArray = rom_bytes.slice(INES_HEADER_SIZE, chr_offset)
	var chr_bytes: PackedByteArray = rom_bytes.slice(chr_offset, chr_offset + TOTAL_CHR_SIZE)

	var prg_sha: String = compute_sha256(prg_bytes)
	var prg_crc: int = compute_crc32(prg_bytes)
	var chr_sha: String = compute_sha256(chr_bytes)
	var chr_crc: int = compute_crc32(chr_bytes)

	result["prg_sha256"] = prg_sha
	result["prg_crc32"] = prg_crc
	result["chr_sha256"] = chr_sha
	result["chr_crc32"] = chr_crc

	var is_prg_ok: bool = (prg_sha == EXPECTED_PRG_SHA256) or (prg_crc == EXPECTED_PRG_CRC32)
	var is_chr_ok: bool = (chr_sha == EXPECTED_CHR_SHA256) or (chr_crc == EXPECTED_CHR_CRC32)

	result["is_prg_match"] = is_prg_ok
	result["is_chr_match"] = is_chr_ok
	result["valid"] = is_prg_ok and is_chr_ok

	if not result["valid"]:
		result["error_message"] = "ROM checksum verification failed: non-authentic or modified ROM dump"

	return result

# --- 2bpp Planar Tile Decoder ---

## Decodes a 16-byte NES 2bpp planar tile into an array of 64 pixel color indices (0..3).
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
			pixels[y * 8 + x] = p0 | (p1 << 1)

	return pixels

## Extracts an 8x8 Image from raw CHR bytes.
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

## Converts a 4096-byte CHR bank (256 tiles) into a 128x128 pixel Image (16x16 tiles).
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

## Decodes authentic run-length compressed NES PPU nametable streams.
static func decode_ppu_nametable_stream(stream: PackedByteArray, initial_ppu: PackedByteArray = PackedByteArray()) -> PackedByteArray:
	var ppu: PackedByteArray = PackedByteArray()
	if initial_ppu.size() >= 0x4000:
		ppu = initial_ppu.duplicate()
	else:
		ppu.resize(0x4000)
		for i in range(0x4000):
			ppu[i] = 0xFF

	var pos: int = 0
	while pos < stream.size():
		var b0: int = stream[pos]
		if (b0 & 0x80) != 0:
			break
		var hi: int = stream[pos]
		var lo: int = stream[pos + 1]
		var addr: int = (hi << 8) | lo
		var header: int = stream[pos + 2]
		pos += 3
		var inc: int = 32 if (header & 0x80) != 0 else 1
		var is_rle: bool = (header & 0x40) != 0
		var length: int = header & 0x3F
		if is_rle:
			var val: int = stream[pos]
			pos += 1
			for _i in range(length):
				if addr < 0x4000:
					ppu[addr] = val
				addr += inc
		else:
			for _i in range(length):
				var val: int = stream[pos]
				pos += 1
				if addr < 0x4000:
					ppu[addr] = val
				addr += inc
	return ppu

## Decodes NES Tetris charmap byte array to String.
static func decode_charmap_name(raw_bytes: PackedByteArray) -> String:
	var result: String = ""
	for b in raw_bytes:
		if b >= 0x01 and b <= 0x1A:
			result += char(65 + b - 1)
		elif b == 0x2B or b == 0x00:
			result += " "
		elif b == 0x2A:
			result += "."
		elif b == 0x2C:
			result += "-"
		else:
			result += " "
	return result

## Decodes a 3-byte BCD score to integer.
static func decode_bcd_score(b0: int, b1: int, b2: int) -> int:
	var s0: int = (((b0 >> 4) * 10) + (b0 & 0x0F)) * 10000
	var s1: int = (((b1 >> 4) * 10) + (b1 & 0x0F)) * 100
	var s2: int = ((b2 >> 4) * 10) + (b2 & 0x0F)
	return s0 + s1 + s2

## Applies an uncompressed PPU patch stream (hi, lo, values..., FE=next_record, FD=end).
static func apply_ppu_patch(ppu: PackedByteArray, patch: PackedByteArray) -> void:
	var pos: int = 0
	while pos < patch.size():
		if patch[pos] == 0xFD:
			break
		if pos + 1 >= patch.size():
			break
		var hi: int = patch[pos]
		var lo: int = patch[pos + 1]
		var addr: int = (hi << 8) | lo
		pos += 2
		while pos < patch.size():
			var v: int = patch[pos]
			pos += 1
			if v == 0xFE:
				break
			if v == 0xFD:
				pos -= 1
				break
			if addr < ppu.size():
				ppu[addr] = v
			addr += 1

## Computes a 960-byte (32x30) mask of perimeter-connected background puzzle tiles
## so the underlying continuous widescreen puzzle grid flows seamlessly up to UI boxes and logos.
static func _compute_perimeter_transparent_mask(nametable: PackedByteArray, transparent_tiles: Array[int]) -> PackedByteArray:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(960)
	mask.fill(0)
	if transparent_tiles.is_empty():
		return mask

	var tile_lookup: Dictionary = {}
	for t in transparent_tiles:
		tile_lookup[t] = true

	var queue: Array[Vector2i] = []
	for r in range(30):
		for c in range(32):
			if r == 0 or r == 29 or c == 0 or c == 31:
				var idx: int = r * 32 + c
				if tile_lookup.has(nametable[idx]):
					mask[idx] = 1
					queue.append(Vector2i(c, r))

	var head: int = 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var nc: int = cur.x + d.x
			var nr: int = cur.y + d.y
			if nr >= 0 and nr < 30 and nc >= 0 and nc < 32:
				var n_idx: int = nr * 32 + nc
				if mask[n_idx] == 0 and tile_lookup.has(nametable[n_idx]):
					mask[n_idx] = 1
					queue.append(Vector2i(nc, nr))

	return mask

## Renders a 1024-byte authentic NES nametable (960 tile IDs + 64 attributes)
## into a 256x240 Image using 2bpp tiles from a specified CHR bank and authentic palette.
## If transparent_tiles is provided, perimeter-connected puzzle background tiles render with alpha = 0.
static func render_nametable_image(nametable: PackedByteArray, chr_bank: PackedByteArray, palette_bytes: PackedByteArray, transparent_tiles: Array[int] = []) -> Image:
	var img: Image = Image.create(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, false, Image.FORMAT_RGBA8)
	var universal_bg_idx: int = palette_bytes[0] if palette_bytes.size() > 0 else 0x0F
	var universal_bg: Color = Constants.NES_MASTER_PALETTE[universal_bg_idx]
	img.fill(universal_bg)

	var transparent_mask: PackedByteArray = _compute_perimeter_transparent_mask(nametable, transparent_tiles)

	var bg_palettes: Array[Array] = []
	for p in range(4):
		var pal: Array[Color] = []
		for c in range(4):
			var idx: int = palette_bytes[p * 4 + c] if (p * 4 + c) < palette_bytes.size() else 0x0F
			pal.append(Constants.NES_MASTER_PALETTE[idx])
		bg_palettes.append(pal)

	var tiles_pixels: Array[PackedByteArray] = []
	for t in range(256):
		var tile_data: PackedByteArray = chr_bank.slice(t * 16, (t + 1) * 16)
		tiles_pixels.append(decode_tile_2bpp(tile_data))

	for r in range(30):
		for c in range(32):
			var nt_idx: int = r * 32 + c
			var origin_x: int = c * 8
			var origin_y: int = r * 8
			if transparent_mask[nt_idx] == 1:
				img.fill_rect(Rect2i(origin_x, origin_y, 8, 8), Color(0.0, 0.0, 0.0, 0.0))
				continue

			var tile_id: int = nametable[nt_idx]
			if tile_id == 0xFF:
				continue

			var attr_idx: int = 960 + int(r / 4) * 8 + int(c / 4)
			var attr_byte: int = nametable[attr_idx] if attr_idx < nametable.size() else 0
			var quad_x: int = int(c % 4) / 2
			var quad_y: int = int(r % 4) / 2
			var shift: int = (quad_y * 2 + quad_x) * 2
			var pal_idx: int = (attr_byte >> shift) & 0x03
			var pal: Array[Color] = bg_palettes[pal_idx]
			var pixels: PackedByteArray = tiles_pixels[tile_id]

			for py in range(8):
				for px in range(8):
					var col_val: int = pixels[py * 8 + px]
					if col_val == 0:
						img.set_pixel(origin_x + px, origin_y + py, universal_bg)
					else:
						img.set_pixel(origin_x + px, origin_y + py, pal[col_val])

	return img

# --- Authentic 1989 NES Tetris Rocket OAM Sprite Definitions ---
# Each entry: array of [rel_y, tile_id, attr, rel_x]
# attr: bits 0-1 = pal_idx, bit 6 = flip_h, bit 7 = flip_v
const ROCKET_DEFINITIONS: Array[Dictionary] = [
	# Tier 0: Small Rocket (sprite3E, jet1=sprite3F, jet2=sprite40)
	{
		"body": [[0, 0xA6, 0x23, 0]],
		"jet_1": [[8, 0xA7, 0x23, 0]],
		"jet_2": [[8, 0xF4, 0x23, 0]],
	},
	# Tier 1: Medium-Small Rocket (sprite41, jet1=sprite42, jet2=sprite43)
	{
		"body": [[-8, 0xB4, 0x21, 0], [0, 0xC4, 0x21, 0]],
		"jet_1": [[8, 0xD4, 0x23, 0]],
		"jet_2": [[8, 0xE4, 0x23, 0]],
	},
	# Tier 2: Medium Rocket (sprite44, jet1=sprite45, jet2=sprite46)
	{
		"body": [
			[-24, 0xB5, 0x23, 0], [-24, 0xB6, 0x23, 8],
			[-16, 0xC5, 0x23, 0], [-16, 0xC6, 0x23, 8],
			[-8, 0xD5, 0x23, 0], [-8, 0xD6, 0x23, 8],
			[0, 0xE5, 0x23, 0], [0, 0xE6, 0x23, 8],
		],
		"jet_1": [[8, 0xF5, 0x23, 0], [8, 0xF6, 0x23, 8]],
		"jet_2": [[8, 0xB7, 0x23, 0], [8, 0xB8, 0x23, 8]],
	},
	# Tier 3: Large Buran Rocket (sprite47, jet1=sprite48, jet2=sprite49)
	{
		"body": [
			[-48, 0xC2, 0x21, 8], [-48, 0xC3, 0x21, 16],
			[-40, 0xCB, 0x21, 8], [-40, 0xEB, 0x21, 16],
			[-32, 0xDB, 0x21, 8], [-32, 0xFB, 0x21, 16],
			[-24, 0xC7, 0x21, 0], [-24, 0xC8, 0x21, 8], [-24, 0xC9, 0x21, 16], [-24, 0xCA, 0x21, 24],
			[-16, 0xD7, 0x21, 0], [-16, 0xD8, 0x21, 8], [-16, 0xD9, 0x21, 16], [-16, 0xDA, 0x21, 24],
			[-8, 0xE7, 0x21, 0], [-8, 0xE8, 0x21, 8], [-8, 0xE9, 0x21, 16], [-8, 0xEA, 0x21, 24],
			[0, 0xF7, 0x21, 0], [0, 0xF8, 0x21, 8], [0, 0xF9, 0x21, 16], [0, 0xFA, 0x21, 24],
		],
		"jet_1": [[8, 0x2A, 0x23, 8], [8, 0x2B, 0x23, 16]],
		"jet_2": [[8, 0x2C, 0x23, 8], [8, 0x2D, 0x23, 16], [16, 0x2E, 0x23, 8], [16, 0x2F, 0x23, 16]],
	},
	# Tier 4: Saint Basil's Cathedral Rocket (sprite4A, jet1=sprite23, jet2=sprite24)
	{
		"body": [
			[-56, 0x38, 0x23, 32],
			[-48, 0x39, 0x23, 8], [-48, 0x3B, 0x23, 24], [-48, 0x3C, 0x23, 32], [-48, 0x3E, 0x23, 48], [-48, 0x3F, 0x23, 56],
			[-40, 0x48, 0x23, 0], [-40, 0x49, 0x23, 8], [-40, 0x4A, 0x23, 16], [-40, 0x4B, 0x23, 24], [-40, 0x4C, 0x23, 32], [-40, 0x4D, 0x23, 40], [-40, 0x4E, 0x20, 48], [-40, 0x4F, 0x20, 56],
			[-32, 0x58, 0x23, 0], [-32, 0x59, 0x23, 8], [-32, 0x5A, 0x23, 16], [-32, 0x5B, 0x23, 24], [-32, 0x5C, 0x23, 32], [-32, 0x5D, 0x23, 40], [-32, 0x5E, 0x20, 48], [-32, 0x5F, 0x20, 56],
			[-24, 0x68, 0x23, 0], [-24, 0x69, 0x23, 8], [-24, 0x6A, 0x23, 16], [-24, 0x6B, 0x23, 24], [-24, 0x6C, 0x23, 32], [-24, 0x6D, 0x23, 40], [-24, 0x6E, 0x23, 48], [-24, 0x6F, 0x23, 56],
			[-16, 0x78, 0x23, 0], [-16, 0x79, 0x23, 8], [-16, 0x7A, 0x23, 16], [-16, 0x7B, 0x23, 24], [-16, 0x7C, 0x23, 32], [-16, 0x7D, 0x23, 40], [-16, 0x7E, 0x23, 48], [-16, 0x7F, 0x23, 56],
			[-8, 0x88, 0x20, 0], [-8, 0x89, 0x20, 8], [-8, 0x8A, 0x20, 16], [-8, 0x8B, 0x20, 24], [-8, 0x8C, 0x20, 32], [-8, 0x8D, 0x20, 40], [-8, 0x8E, 0x20, 48], [-8, 0x8F, 0x20, 56],
			[0, 0x98, 0x20, 0], [0, 0x99, 0x20, 8], [0, 0x9A, 0x20, 16], [0, 0x9B, 0x20, 24], [0, 0x9C, 0x20, 32], [0, 0x9D, 0x20, 40], [0, 0x9E, 0x20, 48], [0, 0x9F, 0x20, 56],
		],
		"jet_1": [[8, 0xA8, 0x23, 24], [8, 0xA9, 0x23, 32]],
		"jet_2": [
			[8, 0xAA, 0x23, 16], [8, 0xAB, 0x23, 24], [8, 0xAC, 0x23, 32], [8, 0xAD, 0x23, 40],
			[16, 0xBA, 0x23, 16], [16, 0xBB, 0x23, 24],
		],
	},
]

## Pre-renders an array of OAM sprite definitions [rel_y, tile_id, attr, rel_x] into an ImageTexture.
static func render_sprite_group_image(chr_bank: PackedByteArray, sprite_defs: Array, sprite_palettes: PackedByteArray) -> Dictionary:
	if sprite_defs.is_empty():
		var empty_tex: ImageTexture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
		return {"texture": empty_tex, "offset": Vector2.ZERO}

	var min_x: int = 999
	var max_x: int = -999
	var min_y: int = 999
	var max_y: int = -999
	for s in sprite_defs:
		var sy: int = int(s[0])
		var sx: int = int(s[3])
		min_x = mini(min_x, sx)
		max_x = maxi(max_x, sx + 8)
		min_y = mini(min_y, sy)
		max_y = maxi(max_y, sy + 8)

	var w: int = maxi(1, max_x - min_x)
	var h: int = maxi(1, max_y - min_y)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # Sprites are transparent by default

	# Parse 4 sprite palettes (4 colors each: index 0 transparent, indices 1..3 from NES_MASTER_PALETTE)
	var s_palettes: Array[Array] = []
	for p in range(4):
		var pal: Array[Color] = [Color(0, 0, 0, 0)]
		for c in range(1, 4):
			var idx: int = sprite_palettes[p * 4 + c] if (p * 4 + c) < sprite_palettes.size() else 0x0F
			pal.append(Constants.NES_MASTER_PALETTE[idx])
		s_palettes.append(pal)

	for s in sprite_defs:
		var rel_y: int = int(s[0])
		var tile_id: int = int(s[1])
		var attr: int = int(s[2])
		var rel_x: int = int(s[3])

		var tile_offset: int = tile_id * 16
		var pixels: PackedByteArray = decode_tile_2bpp(chr_bank, tile_offset)
		var flip_h: bool = (attr & 0x40) != 0
		var flip_v: bool = (attr & 0x80) != 0
		var pal_idx: int = attr & 0x03
		var pal: Array[Color] = s_palettes[pal_idx]

		var dest_origin_x: int = rel_x - min_x
		var dest_origin_y: int = rel_y - min_y

		for py in range(8):
			var src_y: int = (7 - py) if flip_v else py
			for px in range(8):
				var src_x: int = (7 - px) if flip_h else px
				var col_val: int = pixels[src_y * 8 + src_x]
				if col_val != 0:
					var dx: int = dest_origin_x + px
					var dy: int = dest_origin_y + py
					if dx >= 0 and dx < w and dy >= 0 and dy < h:
						img.set_pixel(dx, dy, pal[col_val])

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return {"texture": tex, "offset": Vector2(float(min_x), float(min_y))}

# --- Comprehensive 100% Extraction Pipeline ---

## Extracts 100% of authentic game data (CHR pattern tables, PRG lookup tables, PRG audio tables) from ROM bytes.
static func extract_all_from_rom_bytes(rom_bytes: PackedByteArray, enforce_checksum: bool = true) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error_message": "",
	}

	# 1. Verify Checksums
	var chk: Dictionary = verify_rom_checksums(rom_bytes)
	result["checksum_info"] = chk
	if enforce_checksum and not chk["valid"]:
		result["error_message"] = chk["error_message"]
		return result

	var prg_chunks: int = rom_bytes[4]
	var prg_bytes_size: int = prg_chunks * PRG_BANK_SIZE
	var chr_offset: int = INES_HEADER_SIZE + prg_bytes_size
	var prg_bytes: PackedByteArray = rom_bytes.slice(INES_HEADER_SIZE, chr_offset)

	# 2. Extract 16KB CHR-ROM across all 4 banks
	var chr_data: PackedByteArray = rom_bytes.slice(chr_offset, chr_offset + TOTAL_CHR_SIZE)
	var chr_bank_0: PackedByteArray = chr_data.slice(CHR_BANK_0_TITLE, CHR_BANK_0_TITLE + CHR_BANK_SIZE)
	var chr_bank_1: PackedByteArray = chr_data.slice(CHR_BANK_1_TYPEB, CHR_BANK_1_TYPEB + CHR_BANK_SIZE)
	var chr_bank_2: PackedByteArray = chr_data.slice(CHR_BANK_2_TYPEA, CHR_BANK_2_TYPEA + CHR_BANK_SIZE)
	var chr_bank_3: PackedByteArray = chr_data.slice(CHR_BANK_3_GAME, CHR_BANK_3_GAME + CHR_BANK_SIZE)

	result["chr_raw"] = chr_data
	result["chr_bank_0_title"] = chr_bank_0
	result["chr_bank_1_typeb"] = chr_bank_1
	result["chr_bank_2_typea"] = chr_bank_2
	result["chr_bank_3_game"] = chr_bank_3

	# 3. Extract PRG-ROM Level Palettes (CPU $984C)
	var color_table: Array[Array] = []
	for lvl in range(10):
		var pal: Array[int] = []
		for c in range(4):
			pal.append(rom_bytes[COLOR_TABLE_ROM_OFFSET + lvl * 4 + c])
		color_table.append(pal)
	result["color_table"] = color_table

	# 4. Extract PRG-ROM Gravity Drop Table (CPU $898E, 30 bytes)
	var gravity_table: Array[int] = []
	for i in range(30):
		gravity_table.append(rom_bytes[GRAVITY_TABLE_ROM_OFFSET + i])
	result["gravity_table"] = gravity_table

	# 5. Extract PRG-ROM Points Scoring Table (CPU $9CA5, 5 words)
	var points_table: Array[int] = []
	for i in range(5):
		var lo: int = rom_bytes[POINTS_TABLE_ROM_OFFSET + i * 2]
		var hi: int = rom_bytes[POINTS_TABLE_ROM_OFFSET + i * 2 + 1]
		# In NES Tetris, pointsTable stores BCD representation ($0000, $0040, $0100, $0300, $1200)
		var bcd_lo: int = ((lo >> 4) * 10) + (lo & 0x0F)
		var bcd_hi: int = ((hi >> 4) * 10) + (hi & 0x0F)
		var val: int = bcd_lo + (bcd_hi * 100)
		points_table.append(val)
	result["points_table"] = points_table

	# 6. Extract PRG-ROM Piece Spawn Orientations (CPU $994F, 7 bytes)
	var spawn_orientations: Array[int] = []
	for i in range(7):
		spawn_orientations.append(rom_bytes[SPAWN_ORIENTATIONS_OFFSET + i])
	result["spawn_orientations"] = spawn_orientations

	# 7. Extract PRG-ROM Audio Tables and Sound Bank
	result["prg_rom"] = prg_bytes
	result["note_to_wave_table"] = rom_bytes.slice(NOTE_TO_WAVE_ROM_OFFSET, NOTE_TO_WAVE_ROM_OFFSET + 156)
	result["note_duration_table"] = rom_bytes.slice(NOTE_DURATION_ROM_OFFSET, NOTE_DURATION_ROM_OFFSET + 126)
	result["music_data_table"] = rom_bytes.slice(MUSIC_DATA_TABLE_ROM_OFFSET, MUSIC_DATA_TABLE_ROM_OFFSET + 100)
	result["music_vol_table"] = rom_bytes.slice(MUSIC_VOL_TABLE_ROM_OFFSET, MUSIC_VOL_TABLE_ROM_OFFSET + 44)
	result["noises_table"] = rom_bytes.slice(NOISES_TABLE_ROM_OFFSET, NOISES_TABLE_ROM_OFFSET + 37)
	result["demo_buttons_table"] = rom_bytes.slice(DEMO_BUTTONS_ROM_OFFSET, DEMO_BUTTONS_ROM_OFFSET + 512)
	result["demo_tetrimino_type_table"] = rom_bytes.slice(DEMO_TETRIMINO_TYPE_ROM_OFFSET, DEMO_TETRIMINO_TYPE_ROM_OFFSET + 256)

	# 8. Generate Level Textures for all 10 cycling levels (Bank 3)
	var level_textures: Array[Dictionary] = []
	for lvl in range(10):
		var nes_indices: Array = color_table[lvl]
		var rgb_pal: Array[Color] = [
			Color(0.0, 0.0, 0.0, 0.0), # Index 0 transparent
			Constants.NES_MASTER_PALETTE[nes_indices[1]],
			Constants.NES_MASTER_PALETTE[nes_indices[2]],
			Constants.NES_MASTER_PALETTE[nes_indices[3]],
		]

		var sheet_img: Image = chr_bank_to_image(chr_bank_3, 0, rgb_pal)
		var sheet_tex: ImageTexture = ImageTexture.create_from_image(sheet_img)

		var t1_img: Image = extract_tile_image(chr_bank_3, TILE_PRIMARY_INDEX, rgb_pal)
		var t2_img: Image = extract_tile_image(chr_bank_3, TILE_SECONDARY_INDEX, rgb_pal)
		var t3_img: Image = extract_tile_image(chr_bank_3, TILE_TERTIARY_INDEX, rgb_pal)
		var curtain_img: Image = extract_tile_image(chr_bank_3, TILE_CURTAIN_INDEX, rgb_pal)

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

	# 9. Extract PRG-ROM Menu Palettes & Nametables
	var game_palette: PackedByteArray = rom_bytes.slice(GAME_PALETTE_ROM_OFFSET + 3, GAME_PALETTE_ROM_OFFSET + 35)
	result["game_palette"] = game_palette

	var legal_palette: PackedByteArray = rom_bytes.slice(LEGAL_PALETTE_ROM_OFFSET + 3, LEGAL_PALETTE_ROM_OFFSET + 19)
	result["legal_palette"] = legal_palette

	var menu_palette: PackedByteArray = rom_bytes.slice(MENU_PALETTE_ROM_OFFSET + 3, MENU_PALETTE_ROM_OFFSET + 23)
	result["menu_palette"] = menu_palette

	var ending_palette: PackedByteArray = rom_bytes.slice(ENDING_PALETTE_ROM_OFFSET + 3, ENDING_PALETTE_ROM_OFFSET + 35)
	result["ending_palette"] = ending_palette

	# Authentic Nametable Streams Decoding
	var ppu_title: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(TITLE_NAMETABLE_ROM_OFFSET))
	var nt_title: PackedByteArray = ppu_title.slice(0x2000, 0x2400)
	result["title_nametable"] = nt_title

	var ppu_type: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(GAME_TYPE_NAMETABLE_ROM_OFFSET))
	var nt_type: PackedByteArray = ppu_type.slice(0x2000, 0x2400)
	result["game_type_nametable"] = nt_type

	# Level Menu B: level menu stream + high scores table overlay
	var ppu_lvl_b: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(LEVEL_MENU_NAMETABLE_ROM_OFFSET))
	ppu_lvl_b = decode_ppu_nametable_stream(rom_bytes.slice(HIGH_SCORE_NAMETABLE_ROM_OFFSET), ppu_lvl_b)
	var nt_lvl_b: PackedByteArray = ppu_lvl_b.slice(0x2000, 0x2400)
	result["level_menu_nametable_b"] = nt_lvl_b

	# Level Menu A: level menu stream + height patch + high scores table overlay
	var ppu_lvl_a: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(LEVEL_MENU_NAMETABLE_ROM_OFFSET))
	ppu_lvl_a = decode_ppu_nametable_stream(rom_bytes.slice(HEIGHT_PATCH_ROM_OFFSET), ppu_lvl_a)
	ppu_lvl_a = decode_ppu_nametable_stream(rom_bytes.slice(HIGH_SCORE_NAMETABLE_ROM_OFFSET), ppu_lvl_a)
	var nt_lvl_a: PackedByteArray = ppu_lvl_a.slice(0x2000, 0x2400)
	result["level_menu_nametable_a"] = nt_lvl_a

	# High Scores Screen & Enter High Score Screen
	var ppu_enter: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(ENTER_HIGH_SCORE_NAMETABLE_ROM_OFFSET))
	ppu_enter = decode_ppu_nametable_stream(rom_bytes.slice(HIGH_SCORE_NAMETABLE_ROM_OFFSET), ppu_enter)
	var nt_enter: PackedByteArray = ppu_enter.slice(0x2000, 0x2400)
	result["enter_high_score_nametable"] = nt_enter

	var ppu_high: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(ENTER_HIGH_SCORE_NAMETABLE_ROM_OFFSET))
	ppu_high = decode_ppu_nametable_stream(rom_bytes.slice(HIGH_SCORE_NAMETABLE_ROM_OFFSET), ppu_high)
	var nt_high: PackedByteArray = ppu_high.slice(0x2000, 0x2400)
	result["high_scores_nametable"] = nt_high

	# In-game Background Nametables (HUD, Borders, Stats)
	var ppu_game_a: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(GAME_NAMETABLE_ROM_OFFSET))
	ppu_game_a[0x2083] = 0x0A # 'A' tile for A-TYPE
	var nt_game_a: PackedByteArray = ppu_game_a.slice(0x2000, 0x2400)

	var ppu_game_b: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(GAME_NAMETABLE_ROM_OFFSET))
	ppu_game_b[0x2083] = 0x0B # 'B' tile for B-TYPE
	var patch_b_data: PackedByteArray = rom_bytes.slice(GAME_TYPEB_PATCH_ROM_OFFSET, GAME_TYPEB_PATCH_ROM_OFFSET + 64)
	apply_ppu_patch(ppu_game_b, patch_b_data)
	var nt_game_b: PackedByteArray = ppu_game_b.slice(0x2000, 0x2400)

	# Blank out baked-in 000000 placeholder tiles under TOP, SCORE, and Statistics so dynamic font glyphs don't double-draw
	# TOP score: Row 5, Col 24..29
	for c in range(24, 30):
		nt_game_a[5 * 32 + c] = 0xFF
		nt_game_b[5 * 32 + c] = 0xFF
	# SCORE: Row 8, Col 24..29
	for c in range(24, 30):
		nt_game_a[8 * 32 + c] = 0xFF
		nt_game_b[8 * 32 + c] = 0xFF
	# Statistics counts: Rows 12, 14, 16, 18, 20, 22, 24, Col 6..8
	for i in range(7):
		var r: int = 12 + i * 2
		for c in range(6, 9):
			nt_game_a[r * 32 + c] = 0xFF
			nt_game_b[r * 32 + c] = 0xFF

	result["game_nametable_a"] = nt_game_a
	result["game_nametable_b"] = nt_game_b

	# Ending Nametables
	var ppu_ending_a: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(TYPE_A_ENDING_NAMETABLE_ROM_OFFSET))
	var nt_ending_a: PackedByteArray = ppu_ending_a.slice(0x2000, 0x2400)
	result["type_a_ending_nametable"] = nt_ending_a

	var ppu_ending_120k: PackedByteArray = ppu_ending_a.duplicate()
	var patch_120k_data: PackedByteArray = rom_bytes.slice(TYPE_A_120K_PATCH_ROM_OFFSET, TYPE_A_120K_PATCH_ROM_OFFSET + 96)
	apply_ppu_patch(ppu_ending_120k, patch_120k_data)
	var nt_ending_120k: PackedByteArray = ppu_ending_120k.slice(0x2000, 0x2400)
	result["type_a_ending_120k_nametable"] = nt_ending_120k

	var ppu_ending_b: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(TYPE_B_ENDING_NAMETABLE_ROM_OFFSET))
	var nt_ending_b: PackedByteArray = ppu_ending_b.slice(0x2000, 0x2400)
	result["type_b_ending_nametable"] = nt_ending_b

	var ppu_ending_b_lvl9: PackedByteArray = decode_ppu_nametable_stream(rom_bytes.slice(TYPE_B_LVL9_ENDING_NAMETABLE_ROM_OFFSET))
	var nt_ending_b_lvl9: PackedByteArray = ppu_ending_b_lvl9.slice(0x2000, 0x2400)
	result["type_b_lvl9_ending_nametable"] = nt_ending_b_lvl9

	# 10. Generate 256x240 Authentic Menu, In-game HUD, and Ending Textures
	var title_img: Image = render_nametable_image(nt_title, chr_bank_0, menu_palette, BANK0_PUZZLE_TILES)
	var type_img: Image = render_nametable_image(nt_type, chr_bank_0, menu_palette, BANK0_PUZZLE_TILES)
	var lvl_a_img: Image = render_nametable_image(nt_lvl_a, chr_bank_0, menu_palette, BANK0_PUZZLE_TILES)
	var lvl_b_img: Image = render_nametable_image(nt_lvl_b, chr_bank_0, menu_palette, BANK0_PUZZLE_TILES)
	var high_img: Image = render_nametable_image(nt_high, chr_bank_0, menu_palette, BANK0_PUZZLE_TILES)
	var enter_img: Image = render_nametable_image(nt_enter, chr_bank_0, menu_palette, BANK0_PUZZLE_TILES)

	var game_a_img: Image = render_nametable_image(nt_game_a, chr_bank_3, game_palette, BANK3_PUZZLE_TILES)
	var game_b_img: Image = render_nametable_image(nt_game_b, chr_bank_3, game_palette, BANK3_PUZZLE_TILES)

	var ending_a_img: Image = render_nametable_image(nt_ending_a, chr_bank_2, ending_palette)
	var ending_120k_img: Image = render_nametable_image(nt_ending_120k, chr_bank_2, ending_palette)
	var ending_b_img: Image = render_nametable_image(nt_ending_b, chr_bank_2, ending_palette)
	var ending_b_lvl9_img: Image = render_nametable_image(nt_ending_b_lvl9, chr_bank_1, ending_palette)

	result["title_screen_texture"] = ImageTexture.create_from_image(title_img)
	result["game_type_menu_texture"] = ImageTexture.create_from_image(type_img)
	result["level_menu_a_texture"] = ImageTexture.create_from_image(lvl_a_img)
	result["level_menu_b_texture"] = ImageTexture.create_from_image(lvl_b_img)
	result["high_scores_texture"] = ImageTexture.create_from_image(high_img)
	result["enter_high_score_texture"] = ImageTexture.create_from_image(enter_img)
	result["game_background_a_texture"] = ImageTexture.create_from_image(game_a_img)
	result["game_background_b_texture"] = ImageTexture.create_from_image(game_b_img)
	result["type_a_ending_texture"] = ImageTexture.create_from_image(ending_a_img)
	result["type_a_ending_120k_texture"] = ImageTexture.create_from_image(ending_120k_img)
	result["type_b_ending_texture"] = ImageTexture.create_from_image(ending_b_img)
	result["type_b_lvl9_ending_texture"] = ImageTexture.create_from_image(ending_b_lvl9_img)

	result["title_img"] = title_img
	result["type_img"] = type_img
	result["lvl_a_img"] = lvl_a_img
	result["lvl_b_img"] = lvl_b_img
	result["high_img"] = high_img
	result["enter_img"] = enter_img
	result["game_a_img"] = game_a_img
	result["game_b_img"] = game_b_img
	result["ending_img"] = ending_a_img
	result["ending_120k_img"] = ending_120k_img

	# 10b. Extract Authentic Menu Cursor Sprites (CHR Bank 0 Tile 0x27 arrow, Tile 0xFC box)
	var cursor_pal: Array[Color] = [
		Color(0.0, 0.0, 0.0, 0.0),
		Constants.NES_MASTER_PALETTE[menu_palette[1] if menu_palette.size() > 1 else 0x30],
		Constants.NES_MASTER_PALETTE[menu_palette[2] if menu_palette.size() > 2 else 0x16],
		Constants.NES_MASTER_PALETTE[menu_palette[3] if menu_palette.size() > 3 else 0x27],
	]
	var arrow_img: Image = extract_tile_image(chr_bank_0, 0x27, cursor_pal)
	var arrow_flip_img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	arrow_flip_img.copy_from(arrow_img)
	arrow_flip_img.flip_x()
	result["cursor_arrow_right_texture"] = ImageTexture.create_from_image(arrow_img)
	result["cursor_arrow_left_texture"] = ImageTexture.create_from_image(arrow_flip_img)

	var tile_fc_img: Image = extract_tile_image(chr_bank_0, 0xFC, cursor_pal)
	result["cursor_tile_fc_texture"] = ImageTexture.create_from_image(tile_fc_img)

	var box_16_img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	box_16_img.fill(Color(0, 0, 0, 0))
	box_16_img.blit_rect(tile_fc_img, Rect2i(0, 0, 8, 8), Vector2i(0, 0))
	box_16_img.blit_rect(tile_fc_img, Rect2i(0, 0, 8, 8), Vector2i(8, 0))
	box_16_img.blit_rect(tile_fc_img, Rect2i(0, 0, 8, 8), Vector2i(0, 8))
	box_16_img.blit_rect(tile_fc_img, Rect2i(0, 0, 8, 8), Vector2i(8, 8))
	result["cursor_box_texture"] = ImageTexture.create_from_image(box_16_img)

	# 10d. Extract Authentic CHR Bank 3 Font Glyphs (0..9, A..Z, punctuation)
	var font_pal: Array[Color] = [
		Color(0.0, 0.0, 0.0, 0.0), # Background is transparent
		Color(1.0, 1.0, 1.0, 1.0), # Foreground is white for modulate tinting
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
	]
	var font_glyphs: Dictionary = {}
	# Digits 0..9 (Tiles 0x00..0x09)
	for d in range(10):
		var ch_str: String = str(d)
		var img: Image = extract_tile_image(chr_bank_3, d, font_pal)
		font_glyphs[ch_str] = ImageTexture.create_from_image(img)
	# Letters A..Z (Tiles 0x0A..0x23)
	var letters: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	for l_i in range(letters.length()):
		var ch_str: String = letters[l_i]
		var img: Image = extract_tile_image(chr_bank_3, 0x0A + l_i, font_pal)
		font_glyphs[ch_str] = ImageTexture.create_from_image(img)
	# Punctuation
	var dash_img: Image = extract_tile_image(chr_bank_3, 0x24, font_pal)
	font_glyphs["-"] = ImageTexture.create_from_image(dash_img)
	var dot_img: Image = extract_tile_image(chr_bank_3, 0x25, font_pal)
	font_glyphs["."] = ImageTexture.create_from_image(dot_img)
	font_glyphs[","] = ImageTexture.create_from_image(dot_img)
	var bang_img: Image = extract_tile_image(chr_bank_3, 0x28, font_pal)
	font_glyphs["!"] = ImageTexture.create_from_image(bang_img)
	var slash_img: Image = extract_tile_image(chr_bank_3, 0x2F, font_pal)
	font_glyphs["/"] = ImageTexture.create_from_image(slash_img)
	var space_img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	space_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	font_glyphs[" "] = ImageTexture.create_from_image(space_img)
	result["font_glyph_textures"] = font_glyphs

	# 10e. Generate 128x128 Non-Mirrored Seamlessly Wrapping Puzzle Cluster Backgrounds
	# Uses authentic interlocking NES Tetris border tiles from CHR Bank 3 (0x66-0x89)
	# rendered in two exact color variants:
	# - background_pattern_menu_texture: rendered with menu_palette Palette 2 (grey & white highlights)
	# - background_pattern_game_texture: rendered with game_palette Palette 3 (grey & cyan/blue highlights)
	var pattern_menu_img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var pattern_game_img: Image = Image.create(128, 128, false, Image.FORMAT_RGBA8)

	var universal_bg_menu: Color = Constants.NES_MASTER_PALETTE[menu_palette[0] if menu_palette.size() > 0 else 0x16]
	var universal_bg_game: Color = Constants.NES_MASTER_PALETTE[game_palette[0] if game_palette.size() > 0 else 0x3C]

	var menu_pal_2: Array[Color] = [
		universal_bg_menu,
		Constants.NES_MASTER_PALETTE[menu_palette[9] if menu_palette.size() > 9 else 0x30],
		Constants.NES_MASTER_PALETTE[menu_palette[11] if menu_palette.size() > 11 else 0x00],
		Constants.NES_MASTER_PALETTE[menu_palette[9] if menu_palette.size() > 9 else 0x30],
	]

	var game_pal_3: Array[Color] = [
		universal_bg_game,
		Constants.NES_MASTER_PALETTE[game_palette[13] if game_palette.size() > 13 else 0x3C],
		Constants.NES_MASTER_PALETTE[game_palette[14] if game_palette.size() > 14 else 0x00],
		Constants.NES_MASTER_PALETTE[game_palette[15] if game_palette.size() > 15 else 0x30],
	]

	pattern_menu_img.fill(universal_bg_menu)
	pattern_game_img.fill(universal_bg_game)

	# Pre-decode all CHR Bank 3 tiles
	var chr_b3_tiles: Array[PackedByteArray] = []
	for t in range(256):
		chr_b3_tiles.append(decode_tile_2bpp(chr_bank_3.slice(t * 16, (t + 1) * 16)))

	for r in range(16):
		for c in range(16):
			var tile_id: int = WIDESCREEN_PUZZLE_CLUSTER_16X16[r][c]
			var pixels: PackedByteArray = chr_b3_tiles[tile_id]
			var origin_x: int = c * 8
			var origin_y: int = r * 8

			for py in range(8):
				for px in range(8):
					var col_val: int = pixels[py * 8 + px]
					if col_val == 0:
						pattern_menu_img.set_pixel(origin_x + px, origin_y + py, universal_bg_menu)
						pattern_game_img.set_pixel(origin_x + px, origin_y + py, universal_bg_game)
					else:
						pattern_menu_img.set_pixel(origin_x + px, origin_y + py, menu_pal_2[col_val])
						pattern_game_img.set_pixel(origin_x + px, origin_y + py, game_pal_3[col_val])

	result["background_pattern_menu_texture"] = ImageTexture.create_from_image(pattern_menu_img)
	result["background_pattern_game_texture"] = ImageTexture.create_from_image(pattern_game_img)
	result["background_pattern_tile_texture"] = ImageTexture.create_from_image(pattern_game_img)

	# 10c. Pre-render Authentic OAM Rocket Ending Sprites (CHR Bank 2 with ending_palette)
	var ending_sprite_pal: PackedByteArray = ending_palette.slice(16, 32)
	var rocket_sprites_data: Array[Dictionary] = []
	for tier_idx in range(ROCKET_DEFINITIONS.size()):
		var r_def: Dictionary = ROCKET_DEFINITIONS[tier_idx]
		var body_data: Dictionary = render_sprite_group_image(chr_bank_2, r_def["body"], ending_sprite_pal)
		var j1_data: Dictionary = render_sprite_group_image(chr_bank_2, r_def["jet_1"], ending_sprite_pal)
		var j2_data: Dictionary = render_sprite_group_image(chr_bank_2, r_def["jet_2"], ending_sprite_pal)
		rocket_sprites_data.append({
			"body_tex": body_data["texture"],
			"body_offset": body_data["offset"],
			"jet_1_tex": j1_data["texture"],
			"jet_1_offset": j1_data["offset"],
			"jet_2_tex": j2_data["texture"],
			"jet_2_offset": j2_data["offset"],
		})
	result["rocket_sprites_data"] = rocket_sprites_data

	# 11. Extract Authentic Default High Score Table from PRG-ROM
	var def_scores_a: Array[Dictionary] = []
	var def_scores_b: Array[Dictionary] = []
	var hs_offset: int = DEFAULT_HIGH_SCORES_ROM_OFFSET
	for i in range(3):
		var name_a: String = decode_charmap_name(rom_bytes.slice(hs_offset + i * 6, hs_offset + (i + 1) * 6))
		var sc_off_a: int = hs_offset + 48 + i * 3
		var score_a: int = decode_bcd_score(rom_bytes[sc_off_a], rom_bytes[sc_off_a + 1], rom_bytes[sc_off_a + 2])
		var level_a: int = rom_bytes[hs_offset + 72 + i]
		def_scores_a.append({"name": name_a, "score": score_a, "level": level_a})

	for i in range(4, 7):
		var name_b: String = decode_charmap_name(rom_bytes.slice(hs_offset + i * 6, hs_offset + (i + 1) * 6))
		var sc_off_b: int = hs_offset + 48 + i * 3
		var score_b: int = decode_bcd_score(rom_bytes[sc_off_b], rom_bytes[sc_off_b + 1], rom_bytes[sc_off_b + 2])
		var level_b: int = rom_bytes[hs_offset + 72 + i]
		def_scores_b.append({"name": name_b, "score": score_b, "level": level_b})

	result["default_high_scores"] = {
		"scores_a": def_scores_a,
		"scores_b": def_scores_b,
	}

	result["success"] = true
	return result

## Extracts from a ROM file path.
static func extract_from_file(file_path: String, enforce_checksum: bool = true) -> Dictionary:
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

	return extract_all_from_rom_bytes(bytes, enforce_checksum)

# --- Persistence and Auto-Ingestion ---

## Checks if extracted assets already exist in user_dir.
static func is_rom_extracted(user_dir: String = "user://nes_data/") -> bool:
	var check_file: String = user_dir.path_join("manifest.dat")
	return FileAccess.file_exists(check_file)

## Saves extracted assets and manifest into user://nes_data/.
static func save_extracted_assets(extraction_result: Dictionary, output_dir: String = "user://nes_data/") -> bool:
	if not extraction_result.get("success", false):
		return false

	var err: Error = DirAccess.make_dir_recursive_absolute(output_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return false

	var manifest_path: String = output_dir.path_join("manifest.dat")
	var manifest_file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file != null:
		manifest_file.store_string("ReTetris Extracted ROM Data v1.0\n")
		manifest_file.close()

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

	var high_img: Image = extraction_result.get("high_img") as Image
	if high_img != null:
		high_img.save_png(output_dir.path_join("high_scores.png"))

	var enter_img: Image = extraction_result.get("enter_img") as Image
	if enter_img != null:
		enter_img.save_png(output_dir.path_join("enter_high_score.png"))

	var ending_img: Image = extraction_result.get("ending_img") as Image
	if ending_img != null:
		ending_img.save_png(output_dir.path_join("type_a_ending.png"))

	return true

## Auto-discovers and ingests a valid 1989 NES Tetris ROM from standard locations.
static func auto_ingest_rom(user_dir: String = "user://nes_data/") -> Dictionary:
	var search_paths: Array[String] = [
		user_dir.path_join("tetris.nes"),
		"user://tetris.nes",
		"res://tetris.nes",
		"Tetris (USA).nes",
		"tetris.nes",
	]

	for path in search_paths:
		if FileAccess.file_exists(path):
			var res: Dictionary = extract_from_file(path, true)
			if res.get("success", false):
				save_extracted_assets(res, user_dir)
				return res

	return {
		"success": false,
		"error_message": "No valid 1989 NES Tetris ROM found in standard locations.",
	}

## Applies extracted textures and tables directly to ContentRegistry and AudioManager.
static func apply_to_registry_and_audio(extraction_result: Dictionary, registry: Node = null, audio: Node = null) -> bool:
	if not extraction_result.get("success", false):
		return false

	var reg: Node = registry
	if reg == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			var tree: SceneTree = main_loop as SceneTree
			if tree.root != null:
				reg = tree.root.get_node_or_null("/root/ContentRegistry")

	if reg != null and reg.has_method("ingest_rom_data"):
		reg.ingest_rom_data(extraction_result)

	var aud: Node = audio
	if aud == null:
		var main_loop_a: MainLoop = Engine.get_main_loop()
		if main_loop_a is SceneTree:
			var tree_a: SceneTree = main_loop_a as SceneTree
			if tree_a.root != null:
				aud = tree_a.root.get_node_or_null("/root/AudioManager")

	if aud != null and aud.has_method("ingest_rom_audio_data"):
		aud.ingest_rom_audio_data(extraction_result)

	return true
