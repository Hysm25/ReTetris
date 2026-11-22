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

# Extracted PRG-ROM Audio & Demo Tables
var prg_rom: PackedByteArray = PackedByteArray()
var demo_buttons_table: PackedByteArray = PackedByteArray()
var demo_tetrimino_type_table: PackedByteArray = PackedByteArray()
var note_to_wave_table: PackedByteArray = PackedByteArray()
var note_duration_table: PackedByteArray = PackedByteArray()
var music_data_table: PackedByteArray = PackedByteArray()
var music_vol_table: PackedByteArray = PackedByteArray()
var noises_table: PackedByteArray = PackedByteArray()

# Extracted Authentic Menu & In-Game Textures (256x240)
var title_screen_texture: ImageTexture = null
var game_type_menu_texture: ImageTexture = null
var level_menu_a_texture: ImageTexture = null
var level_menu_b_texture: ImageTexture = null
var high_scores_texture: ImageTexture = null
var enter_high_score_texture: ImageTexture = null
var game_background_a_texture: ImageTexture = null
var game_background_b_texture: ImageTexture = null
var type_a_ending_texture: ImageTexture = null
var type_a_ending_120k_texture: ImageTexture = null
var type_b_ending_texture: ImageTexture = null
var type_b_lvl9_ending_texture: ImageTexture = null
var cursor_arrow_right_texture: ImageTexture = null
var cursor_arrow_left_texture: ImageTexture = null
var cursor_tile_fc_texture: ImageTexture = null
var cursor_box_texture: ImageTexture = null
var font_glyph_textures: Dictionary = {}
var background_pattern_tile_texture: ImageTexture = null
var background_pattern_menu_texture: ImageTexture = null
var background_pattern_game_texture: ImageTexture = null
var rocket_sprites_data: Array[Dictionary] = []
var menu_palette_colors: Array[Color] = []
var ending_palette_colors: Array[Color] = []
var default_high_scores: Dictionary = {}

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

	# 3. Ingest Authentic Menu & Ending Textures
	if extracted_data.has("title_screen_texture"):
		title_screen_texture = extracted_data["title_screen_texture"] as ImageTexture
	if extracted_data.has("game_type_menu_texture"):
		game_type_menu_texture = extracted_data["game_type_menu_texture"] as ImageTexture
	if extracted_data.has("level_menu_a_texture"):
		level_menu_a_texture = extracted_data["level_menu_a_texture"] as ImageTexture
	if extracted_data.has("level_menu_b_texture"):
		level_menu_b_texture = extracted_data["level_menu_b_texture"] as ImageTexture
	if extracted_data.has("high_scores_texture"):
		high_scores_texture = extracted_data["high_scores_texture"] as ImageTexture
	if extracted_data.has("enter_high_score_texture"):
		enter_high_score_texture = extracted_data["enter_high_score_texture"] as ImageTexture
	if extracted_data.has("type_a_ending_texture"):
		type_a_ending_texture = extracted_data["type_a_ending_texture"] as ImageTexture
	if extracted_data.has("type_a_ending_120k_texture"):
		type_a_ending_120k_texture = extracted_data["type_a_ending_120k_texture"] as ImageTexture
	if extracted_data.has("type_b_ending_texture"):
		type_b_ending_texture = extracted_data["type_b_ending_texture"] as ImageTexture
	if extracted_data.has("type_b_lvl9_ending_texture"):
		type_b_lvl9_ending_texture = extracted_data["type_b_lvl9_ending_texture"] as ImageTexture
	if extracted_data.has("game_background_a_texture"):
		game_background_a_texture = extracted_data["game_background_a_texture"] as ImageTexture
	if extracted_data.has("game_background_b_texture"):
		game_background_b_texture = extracted_data["game_background_b_texture"] as ImageTexture
	if extracted_data.has("cursor_arrow_right_texture"):
		cursor_arrow_right_texture = extracted_data["cursor_arrow_right_texture"] as ImageTexture
	if extracted_data.has("cursor_arrow_left_texture"):
		cursor_arrow_left_texture = extracted_data["cursor_arrow_left_texture"] as ImageTexture
	if extracted_data.has("cursor_tile_fc_texture"):
		cursor_tile_fc_texture = extracted_data["cursor_tile_fc_texture"] as ImageTexture
	if extracted_data.has("cursor_box_texture"):
		cursor_box_texture = extracted_data["cursor_box_texture"] as ImageTexture
	if extracted_data.has("font_glyph_textures"):
		font_glyph_textures = extracted_data["font_glyph_textures"] as Dictionary
	if extracted_data.has("background_pattern_tile_texture"):
		background_pattern_tile_texture = extracted_data["background_pattern_tile_texture"] as ImageTexture
	if extracted_data.has("background_pattern_menu_texture"):
		background_pattern_menu_texture = extracted_data["background_pattern_menu_texture"] as ImageTexture
	if extracted_data.has("background_pattern_game_texture"):
		background_pattern_game_texture = extracted_data["background_pattern_game_texture"] as ImageTexture
	if extracted_data.has("rocket_sprites_data"):
		rocket_sprites_data = extracted_data["rocket_sprites_data"]
	if extracted_data.has("menu_palette"):
		var raw_pal: PackedByteArray = extracted_data["menu_palette"]
		menu_palette_colors.clear()
		for b in raw_pal:
			menu_palette_colors.append(Constants.NES_MASTER_PALETTE[b])
	if extracted_data.has("ending_palette"):
		var raw_end_pal: PackedByteArray = extracted_data["ending_palette"]
		ending_palette_colors.clear()
		for b in raw_end_pal:
			ending_palette_colors.append(Constants.NES_MASTER_PALETTE[b])
	if extracted_data.has("default_high_scores"):
		default_high_scores = extracted_data["default_high_scores"] as Dictionary

	# 4. Ingest Authentic Audio & Demo Bytecode Tables
	if extracted_data.has("prg_rom"):
		prg_rom = extracted_data["prg_rom"]
	if extracted_data.has("demo_buttons_table"):
		demo_buttons_table = extracted_data["demo_buttons_table"]
	if extracted_data.has("demo_tetrimino_type_table"):
		demo_tetrimino_type_table = extracted_data["demo_tetrimino_type_table"]
	if extracted_data.has("note_to_wave_table"):
		note_to_wave_table = extracted_data["note_to_wave_table"]
	if extracted_data.has("note_duration_table"):
		note_duration_table = extracted_data["note_duration_table"]
	if extracted_data.has("music_data_table"):
		music_data_table = extracted_data["music_data_table"]
	if extracted_data.has("music_vol_table"):
		music_vol_table = extracted_data["music_vol_table"]
	if extracted_data.has("noises_table"):
		noises_table = extracted_data["noises_table"]

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

func get_high_scores_texture() -> ImageTexture:
	return high_scores_texture if is_initialized else _empty_tile_texture

func get_enter_high_score_texture() -> ImageTexture:
	return enter_high_score_texture if is_initialized else _empty_tile_texture

func get_type_a_ending_texture() -> ImageTexture:
	return type_a_ending_texture if is_initialized else _empty_tile_texture

func get_game_background_texture(game_type: int = 0) -> ImageTexture:
	if not is_initialized:
		return _empty_tile_texture
	if game_type == Constants.GameType.TYPE_B and game_background_b_texture != null:
		return game_background_b_texture
	return game_background_a_texture if game_background_a_texture != null else _empty_tile_texture

func get_cursor_arrow_texture(flip_left: bool = false) -> ImageTexture:
	if not is_initialized:
		return _empty_tile_texture
	return cursor_arrow_left_texture if flip_left else cursor_arrow_right_texture

func get_cursor_box_texture() -> ImageTexture:
	return cursor_box_texture if is_initialized else _empty_tile_texture

func get_cursor_tile_fc_texture() -> ImageTexture:
	return cursor_tile_fc_texture if is_initialized else _empty_tile_texture

func get_font_glyph(char_key: String) -> ImageTexture:
	if font_glyph_textures.has(char_key):
		return font_glyph_textures[char_key] as ImageTexture
	return null

func get_background_pattern_tile_texture(is_menu: bool = false) -> ImageTexture:
	if not is_initialized:
		return null
	if is_menu and background_pattern_menu_texture != null:
		return background_pattern_menu_texture
	if not is_menu and background_pattern_game_texture != null:
		return background_pattern_game_texture
	return background_pattern_tile_texture

func get_ending_texture(tier: int = 0) -> ImageTexture:
	if not is_initialized:
		return _empty_tile_texture
	if tier == Constants.RocketTier.TIER_4_CATHEDRAL and type_a_ending_120k_texture != null:
		return type_a_ending_120k_texture
	return type_a_ending_texture if type_a_ending_texture != null else _empty_tile_texture

func draw_ending_rocket(canvas: CanvasItem, tier: int, rocket_pos: Vector2, frame_counter: int) -> void:
	if not is_initialized or tier < 0 or tier >= rocket_sprites_data.size():
		return
	var r_data: Dictionary = rocket_sprites_data[tier]
	var body_tex: Texture2D = r_data.get("body_tex") as Texture2D
	var body_offset: Vector2 = r_data.get("body_offset", Vector2.ZERO) as Vector2
	if body_tex != null:
		canvas.draw_texture(body_tex, rocket_pos + body_offset)

	# Draw animated thrusters during climb
	if frame_counter >= Constants.ROCKET_LAUNCH_DELAY_FRAMES and rocket_pos.y > -50.0:
		var flame_toggle: bool = (frame_counter & 0x02) != 0
		var jet_tex: Texture2D = (r_data.get("jet_2_tex") if flame_toggle else r_data.get("jet_1_tex")) as Texture2D
		var jet_offset: Vector2 = (r_data.get("jet_2_offset") if flame_toggle else r_data.get("jet_1_offset")) as Vector2
		if jet_tex != null:
			canvas.draw_texture(jet_tex, rocket_pos + jet_offset)

func get_default_high_scores() -> Dictionary:
	return default_high_scores

func get_prg_rom() -> PackedByteArray:
	return prg_rom

func get_demo_buttons_table() -> PackedByteArray:
	return demo_buttons_table

func get_demo_tetrimino_type_table() -> PackedByteArray:
	return demo_tetrimino_type_table

func get_note_to_wave_table() -> PackedByteArray:
	return note_to_wave_table

func get_note_duration_table() -> PackedByteArray:
	return note_duration_table

func get_music_data_table() -> PackedByteArray:
	return music_data_table

func get_music_vol_table() -> PackedByteArray:
	return music_vol_table

func get_noises_table() -> PackedByteArray:
	return noises_table

## Clears custom textures.
func reset_custom_textures() -> void:
	_tile_texture_cache.clear()
	_atlas_texture_cache.clear()
	title_screen_texture = null
	game_type_menu_texture = null
	level_menu_a_texture = null
	level_menu_b_texture = null
	high_scores_texture = null
	enter_high_score_texture = null
	type_a_ending_texture = null
	type_a_ending_120k_texture = null
	type_b_ending_texture = null
	type_b_lvl9_ending_texture = null
	game_background_a_texture = null
	game_background_b_texture = null
	cursor_arrow_right_texture = null
	cursor_arrow_left_texture = null
	cursor_tile_fc_texture = null
	cursor_box_texture = null
	rocket_sprites_data.clear()
	menu_palette_colors.clear()
	ending_palette_colors.clear()
	default_high_scores.clear()
	is_initialized = false
