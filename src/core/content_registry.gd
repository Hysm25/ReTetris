extends Node

## Central registry for NES Tetris tables, tetromino geometries, palettes, and textures.

const NES_PALETTES: Array[Array] = [
	[Color("#0058F8"), Color("#3CBCFC"), Color("#FCFCFC")], # Level 0
	[Color("#00A800"), Color("#80D010"), Color("#FCFCFC")], # Level 1
	[Color("#880070"), Color("#F878F8"), Color("#FCFCFC")], # Level 2
	[Color("#0058F8"), Color("#58F898"), Color("#FCFCFC")], # Level 3
	[Color("#D80058"), Color("#00E800"), Color("#FCFCFC")], # Level 4
	[Color("#58F898"), Color("#6888FC"), Color("#FCFCFC")], # Level 5
	[Color("#E40058"), Color("#F83800"), Color("#FCFCFC")], # Level 6
	[Color("#6844FC"), Color("#9878F8"), Color("#FCFCFC")], # Level 7
	[Color("#0058F8"), Color("#F85800"), Color("#FCFCFC")], # Level 8
	[Color("#F83800"), Color("#FFA044"), Color("#FCFCFC")], # Level 9
]

# Gravities in frames per drop (Levels 0 through 29+)
const GRAVITY_TABLE: Array[int] = [
	48, 43, 38, 33, 28, 23, 18, 13, 8, 6,
	5, 5, 5, 4, 4, 4, 3, 3, 3, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 1
]

func get_gravity_frames(level: int) -> int:
	if level < 0:
		return GRAVITY_TABLE[0]
	if level >= GRAVITY_TABLE.size():
		return 1
	return GRAVITY_TABLE[level]

func get_level_palette(level: int) -> Array:
	var idx: int = absi(level) % 10
	return NES_PALETTES[idx]
