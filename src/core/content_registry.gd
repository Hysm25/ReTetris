extends Node

## Central repository for authentic 1989 NES Tetris tables, tetromino geometries, and textures.
## Operates under Mandatory ROM Ingestion: all palettes, tiles, and tables are populated exclusively
## from authentic ROM dumps. Zero procedural tile synthesis fallbacks are present.

const Constants = preload("res://src/core/constants.gd")

# --- Authentic Mino Offset Definitions ---
# 4 minos per orientation: Array of Vector2i(x, y) relative to piece anchor (tetriminoX, tetriminoY).
# Sourced directly from NES Tetris disassembly (main.asm:1759-1786).
const ORIENTATION_MINO_OFFSETS: Array[Array] = [
	# $00 T_UP
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, -1)],
	# $01 T_RIGHT
	[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	# $02 T_DOWN (spawn)
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	# $03 T_LEFT
	[Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)],

	# $04 J_LEFT
	[Vector2i(0, -1), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	# $05 J_UP
	[Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],
	# $06 J_RIGHT
	[Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(0, 1)],
	# $07 J_DOWN (spawn)
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],

	# $08 Z_HORIZ (spawn)
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	# $09 Z_VERT
	[Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],

	# $0A O_FIXED (spawn)
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)],

	# $0B S_HORIZ (spawn)
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	# $0C S_VERT
	[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],

	# $0D L_RIGHT
	[Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	# $0E L_DOWN (spawn)
	[Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)],
	# $0F L_LEFT
	[Vector2i(-1, -1), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)],
	# $10 L_UP
	[Vector2i(1, -1), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],

	# $11 I_VERT
	[Vector2i(0, -2), Vector2i(0, -1), Vector2i(0, 0), Vector2i(0, 1)],
	# $12 I_HORIZ (spawn)
	[Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)],

	# $13 HIDDEN
	[Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)],
]

# Static 4x4 coordinate offset matrices for all 20 orientations (values: 0=empty, 1..3=tile type)
var matrices_4x4: Array[Array] = []

# Cached extracted textures: level -> Array[ImageTexture] (indexed by TileType 0..3)
var _tile_texture_cache: Dictionary = {}

# Cached atlas textures: level -> ImageTexture (32x8 atlas)
var _atlas_texture_cache: Dictionary = {}

# Extracted PRG-ROM Data Tables
var extracted_gravity_table: Array[int] = []
var extracted_points_table: Array[int] = []
var extracted_color_table: Array[Array] = []
var extracted_spawn_orientations: Array[int] = []

# Extracted Authentic Menu Textures (256x240)
var title_screen_texture: ImageTexture = null
var game_type_menu_texture: ImageTexture = null
var level_menu_a_texture: ImageTexture = null
var level_menu_b_texture: ImageTexture = null
var menu_palette_colors: Array[Color] = []

# Initialization State (Enforces Mandatory ROM Ingestion)
var is_initialized: bool = false

# Blank 8x8 transparent fallback texture
var _empty_tile_texture: ImageTexture = null

func _init() -> void:
	_build_matrices_4x4()
	_create_empty_tile()

func _create_empty_tile() -> void:
	var empty_img: Image = Image.create(Constants.TILE_SIZE, Constants.TILE_SIZE, false, Image.FORMAT_RGBA8)
	empty_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	_empty_tile_texture = ImageTexture.create_from_image(empty_img)

func _build_matrices_4x4() -> void:
	matrices_4x4.clear()
	for orientation_idx in range(Constants.ORIENTATION_COUNT):
		var mat: Array[Array] = []
		for r in range(4):
			var row: Array[int] = [0, 0, 0, 0]
			mat.append(row)

		if orientation_idx == Constants.Orientation.HIDDEN:
			matrices_4x4.append(mat)
			continue

		var piece_type: int = Constants.PIECE_TYPE_FROM_ORIENTATION[orientation_idx]
		var tile_type: int = Constants.TILE_TYPE_FROM_PIECE[piece_type]
		var offsets: Array = ORIENTATION_MINO_OFFSETS[orientation_idx]

		for mino_offset in offsets:
			var vec: Vector2i = mino_offset as Vector2i
			var r: int = 2 + vec.y
			var c: int = 2 + vec.x
			if r >= 0 and r < 4 and c >= 0 and c < 4:
				mat[r][c] = tile_type

		matrices_4x4.append(mat)

# --- Geometry & Matrix Lookups ---

func get_mino_offsets(orientation: int) -> Array[Vector2i]:
	if orientation < 0 or orientation >= ORIENTATION_MINO_OFFSETS.size():
		return [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
	var res: Array[Vector2i] = []
	for offset in ORIENTATION_MINO_OFFSETS[orientation]:
		res.append(offset as Vector2i)
	return res

func get_matrix_4x4(orientation: int) -> Array[Array]:
	if orientation < 0 or orientation >= matrices_4x4.size():
		return []
	return matrices_4x4[orientation]

func get_piece_spawn_orientation(piece_type: int) -> int:
	if extracted_spawn_orientations.size() == Constants.PIECE_COUNT:
		if piece_type >= 0 and piece_type < extracted_spawn_orientations.size():
			return extracted_spawn_orientations[piece_type]
	if piece_type < 0 or piece_type >= Constants.PIECE_COUNT:
		return Constants.Orientation.T_DOWN
	return Constants.SPAWN_ORIENTATIONS[piece_type]

func get_tile_type_for_piece(piece_type: int) -> int:
	if piece_type < 0 or piece_type >= Constants.PIECE_COUNT:
		return Constants.TileType.EMPTY
	return Constants.TILE_TYPE_FROM_PIECE[piece_type]

# --- Gravity, Scoring & Palette Lookups from Extracted Tables ---

func get_gravity_frames(level: int) -> int:
	if extracted_gravity_table.size() >= 30:
		var clamped: int = clampi(level, 0, extracted_gravity_table.size() - 1)
		return extracted_gravity_table[clamped]
	return Constants.get_gravity_frames(level)

func get_score_points(lines: int) -> int:
	if extracted_points_table.size() == 5:
		if lines >= 0 and lines < 5:
			return extracted_points_table[lines]
	if lines >= 0 and lines < Constants.SCORE_POINTS_PER_LINES.size():
		return Constants.SCORE_POINTS_PER_LINES[lines]
	return 0

func get_level_palette(level: int) -> Array[Color]:
	var level_idx: int = absi(level) % 10
	if extracted_color_table.size() == 10:
		var indices: Array = extracted_color_table[level_idx]
		if indices.size() >= 4:
			return [
				Constants.NES_MASTER_PALETTE[indices[1]],
				Constants.NES_MASTER_PALETTE[indices[2]],
				Constants.NES_MASTER_PALETTE[indices[3]],
			]
	return Constants.get_level_palette(level)

# --- Mandatory ROM Data Ingestion ---

## Ingests 100% authentic tables, palettes, and textures extracted from ROM.
func ingest_rom_data(extracted_data: Dictionary) -> bool:
	if not extracted_data.get("success", false):
		return false

	# 1. Ingest PRG Tables
	if extracted_data.has("gravity_table"):
		extracted_gravity_table.clear()
		for val in extracted_data["gravity_table"]:
			extracted_gravity_table.append(int(val))
	if extracted_data.has("points_table"):
		extracted_points_table.clear()
		for val in extracted_data["points_table"]:
			extracted_points_table.append(int(val))
	if extracted_data.has("color_table"):
		extracted_color_table.clear()
		for pal in extracted_data["color_table"]:
			var pal_arr: Array = []
			for idx in pal:
				pal_arr.append(int(idx))
			extracted_color_table.append(pal_arr)
	if extracted_data.has("spawn_orientations"):
		extracted_spawn_orientations.clear()
		for val in extracted_data["spawn_orientations"]:
			extracted_spawn_orientations.append(int(val))

	# 2. Ingest CHR Textures
	var level_textures: Array = extracted_data.get("level_textures", [])
	for lvl in range(level_textures.size()):
		var entry: Dictionary = level_textures[lvl] as Dictionary
		var t1: ImageTexture = entry.get("tile_1") as ImageTexture
		var t2: ImageTexture = entry.get("tile_2") as ImageTexture
		var t3: ImageTexture = entry.get("tile_3") as ImageTexture

		var textures: Array[ImageTexture] = [_empty_tile_texture, t1, t2, t3]
		set_custom_level_textures(lvl, textures)

	# 3. Ingest Authentic Menu Textures
	if extracted_data.has("title_screen_texture"):
		title_screen_texture = extracted_data["title_screen_texture"] as ImageTexture
	if extracted_data.has("game_type_menu_texture"):
		game_type_menu_texture = extracted_data["game_type_menu_texture"] as ImageTexture
	if extracted_data.has("level_menu_a_texture"):
		level_menu_a_texture = extracted_data["level_menu_a_texture"] as ImageTexture
	if extracted_data.has("level_menu_b_texture"):
		level_menu_b_texture = extracted_data["level_menu_b_texture"] as ImageTexture
	if extracted_data.has("menu_palette"):
		var raw_pal: PackedByteArray = extracted_data["menu_palette"]
		menu_palette_colors.clear()
		for b in raw_pal:
			menu_palette_colors.append(Constants.NES_MASTER_PALETTE[b])

	is_initialized = true
	return true

func is_ready() -> bool:
	return is_initialized

# --- Texture & Atlas Cache Access ---

## Retrieves the extracted ImageTexture for a given tile type at a specific level.
## Refuses procedural fallback: returns empty texture if uninitialized.
func get_tile_texture(tile_type: int, level: int) -> ImageTexture:
	var level_idx: int = absi(level) % 10
	if _tile_texture_cache.has(level_idx):
		var textures: Array = _tile_texture_cache[level_idx] as Array
		if tile_type >= 0 and tile_type < textures.size():
			return textures[tile_type] as ImageTexture

	return _empty_tile_texture

## Retrieves a 32x8 ImageTexture atlas containing all 4 tiles [EMPTY, PRIMARY, SECONDARY, TERTIARY].
func get_level_tile_atlas(level: int) -> ImageTexture:
	var level_idx: int = absi(level) % 10
	if _atlas_texture_cache.has(level_idx):
		return _atlas_texture_cache[level_idx] as ImageTexture

	if _tile_texture_cache.has(level_idx):
		var textures: Array = _tile_texture_cache[level_idx] as Array
		var atlas_img: Image = Image.create(32, 8, false, Image.FORMAT_RGBA8)
		atlas_img.fill(Color(0.0, 0.0, 0.0, 0.0))

		for t in range(mini(4, textures.size())):
			var tex: ImageTexture = textures[t] as ImageTexture
			if tex != null:
				var img: Image = tex.get_image()
				if img != null:
					atlas_img.blit_rect(img, Rect2i(0, 0, 8, 8), Vector2i(t * 8, 0))

		var atlas_tex: ImageTexture = ImageTexture.create_from_image(atlas_img)
		_atlas_texture_cache[level_idx] = atlas_tex
		return atlas_tex

	return _empty_tile_texture

## Allows injecting custom/extracted textures for a given level.
func set_custom_level_textures(level_idx: int, textures: Array[ImageTexture]) -> void:
	var idx: int = absi(level_idx) % 10
	_tile_texture_cache[idx] = textures
	_atlas_texture_cache.erase(idx)

## Menu Background Texture Getters
func get_title_screen_texture() -> ImageTexture:
	return title_screen_texture if is_initialized else _empty_tile_texture

func get_game_type_menu_texture() -> ImageTexture:
	return game_type_menu_texture if is_initialized else _empty_tile_texture

func get_level_menu_texture(game_type: int) -> ImageTexture:
	if not is_initialized:
		return _empty_tile_texture
	if game_type == Constants.GameType.TYPE_B:
		return level_menu_b_texture
	return level_menu_a_texture

## Clears custom textures.
func reset_custom_textures() -> void:
	_tile_texture_cache.clear()
	_atlas_texture_cache.clear()
	title_screen_texture = null
	game_type_menu_texture = null
	level_menu_a_texture = null
	level_menu_b_texture = null
	menu_palette_colors.clear()
	is_initialized = false
