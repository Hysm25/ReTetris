extends Node

## Central registry for NES Tetris tables, tetromino geometries, palettes, and textures.
## Manages static tetromino matrices, procedural 8x8 tile generation, and palette banks.

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

# Cached textures: level -> Array[ImageTexture] (indexed by TileType 0..3)
var _tile_texture_cache: Dictionary = {}

# Cached atlas textures: level -> ImageTexture (32x8 atlas)
var _atlas_texture_cache: Dictionary = {}

func _init() -> void:
	_build_matrices_4x4()

func _build_matrices_4x4() -> void:
	matrices_4x4.clear()
	for orientation_idx in range(Constants.ORIENTATION_COUNT):
		# Create empty 4x4 matrix
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
	if piece_type < 0 or piece_type >= Constants.PIECE_COUNT:
		return Constants.Orientation.T_DOWN
	return Constants.SPAWN_ORIENTATIONS[piece_type]

func get_tile_type_for_piece(piece_type: int) -> int:
	if piece_type < 0 or piece_type >= Constants.PIECE_COUNT:
		return Constants.TileType.EMPTY
	return Constants.TILE_TYPE_FROM_PIECE[piece_type]

# --- Gravity & Timing Lookups ---

func get_gravity_frames(level: int) -> int:
	return Constants.get_gravity_frames(level)

func get_level_palette(level: int) -> Array[Color]:
	return Constants.get_level_palette(level)

# --- Procedural 8x8 Tile Generation ---

## Generates a procedural 8x8 Image matching authentic NES Tetris pixel styles:
## TileType.PRIMARY (1): Bevelled / Frame style (tile 1)
## TileType.SECONDARY (2): Specular Gem style (tile 2)
## TileType.TERTIARY (3): Primary with top-left highlight (tile 3)
## TileType.EMPTY (0): Fully transparent
func generate_procedural_tile_image(tile_type: int, palette: Array[Color]) -> Image:
	var img: Image = Image.create(Constants.TILE_SIZE, Constants.TILE_SIZE, false, Image.FORMAT_RGBA8)
	
	if tile_type == Constants.TileType.EMPTY or palette.size() < 3:
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		return img

	var color_pri: Color = palette[0]
	var color_sec: Color = palette[1]
	var color_white: Color = palette[2]
	var color_shadow: Color = Color(0.0, 0.0, 0.0, 1.0)

	# Raw 8x8 pixel index mapping (0=Shadow/Border, 1=White, 2=Secondary, 3=Primary)
	# Directly reproduced from authentic NES Tetris CHR-ROM Game Bank 3 ($7B, $7C, $7D)
	var pattern: Array[int] = []

	match tile_type:
		Constants.TileType.PRIMARY:
			# Tile $7B: Bevelled frame block
			pattern = [
				1, 3, 3, 3, 3, 3, 3, 0,
				3, 1, 1, 1, 1, 1, 3, 0,
				3, 1, 1, 1, 1, 1, 3, 0,
				3, 1, 1, 1, 1, 1, 3, 0,
				3, 1, 1, 1, 1, 1, 3, 0,
				3, 1, 1, 1, 1, 1, 3, 0,
				3, 3, 3, 3, 3, 3, 3, 0,
				0, 0, 0, 0, 0, 0, 0, 0,
			]
		Constants.TileType.SECONDARY:
			# Tile $7C: Gem / Specular block
			pattern = [
				1, 2, 2, 2, 2, 2, 2, 0,
				2, 1, 1, 2, 2, 2, 2, 0,
				2, 1, 2, 2, 2, 2, 2, 0,
				2, 2, 2, 2, 2, 2, 2, 0,
				2, 2, 2, 2, 2, 2, 2, 0,
				2, 2, 2, 2, 2, 2, 2, 0,
				2, 2, 2, 2, 2, 2, 2, 0,
				0, 0, 0, 0, 0, 0, 0, 0,
			]
		Constants.TileType.TERTIARY:
			# Tile $7D: Primary with specular highlight
			pattern = [
				1, 3, 3, 3, 3, 3, 3, 0,
				3, 1, 1, 3, 3, 3, 3, 0,
				3, 1, 3, 3, 3, 3, 3, 0,
				3, 3, 3, 3, 3, 3, 3, 0,
				3, 3, 3, 3, 3, 3, 3, 0,
				3, 3, 3, 3, 3, 3, 3, 0,
				3, 3, 3, 3, 3, 3, 3, 0,
				0, 0, 0, 0, 0, 0, 0, 0,
			]
		_:
			img.fill(Color(0.0, 0.0, 0.0, 0.0))
			return img

	for y in range(8):
		for x in range(8):
			var idx: int = pattern[y * 8 + x]
			var c: Color
			match idx:
				0:
					c = color_shadow
				1:
					c = color_white
				2:
					c = color_sec
				3:
					c = color_pri
				_:
					c = color_shadow
			img.set_pixel(x, y, c)

	return img

# --- Texture & Atlas Cache ---

## Retrieves or generates the cached ImageTexture for a given tile type at a specific level.
func get_tile_texture(tile_type: int, level: int) -> ImageTexture:
	var level_idx: int = absi(level) % 10
	if not _tile_texture_cache.has(level_idx):
		_generate_level_textures(level_idx)
	
	var textures: Array = _tile_texture_cache[level_idx] as Array
	if tile_type >= 0 and tile_type < textures.size():
		return textures[tile_type] as ImageTexture
	return textures[0] as ImageTexture

## Retrieves or generates a 32x8 ImageTexture atlas containing all 4 tiles [EMPTY, PRIMARY, SECONDARY, TERTIARY]
func get_level_tile_atlas(level: int) -> ImageTexture:
	var level_idx: int = absi(level) % 10
	if not _atlas_texture_cache.has(level_idx):
		_generate_level_atlas(level_idx)
	return _atlas_texture_cache[level_idx] as ImageTexture

func _generate_level_textures(level_idx: int) -> void:
	var palette: Array[Color] = Constants.get_level_palette(level_idx)
	var textures: Array[ImageTexture] = []

	for t in range(4):
		var img: Image = generate_procedural_tile_image(t, palette)
		var tex: ImageTexture = ImageTexture.create_from_image(img)
		textures.append(tex)

	_tile_texture_cache[level_idx] = textures

func _generate_level_atlas(level_idx: int) -> void:
	var palette: Array[Color] = Constants.get_level_palette(level_idx)
	# Atlas contains 4 tiles side-by-side: 4 * 8 = 32 width, 8 height
	var atlas_img: Image = Image.create(32, 8, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0.0, 0.0, 0.0, 0.0))

	for t in range(4):
		var tile_img: Image = generate_procedural_tile_image(t, palette)
		atlas_img.blit_rect(tile_img, Rect2i(0, 0, 8, 8), Vector2i(t * 8, 0))

	var atlas_tex: ImageTexture = ImageTexture.create_from_image(atlas_img)
	_atlas_texture_cache[level_idx] = atlas_tex
