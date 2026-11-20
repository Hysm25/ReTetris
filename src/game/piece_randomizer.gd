class_name PieceRandomizer
extends RefCounted

## Authentic 1989 NES Tetris piece randomizer (Two-Roll algorithm).
## Sourced from Tetris NES disassembly (main.asm:2964-3004).

const Constants = preload("res://src/core/constants.gd")

var previous_piece_id: int = -1
var rng: RandomNumberGenerator

var is_demo: bool = false
var demo_tetrimino_types: PackedByteArray = PackedByteArray()
var demo_index: int = 0

func _init(seed_val: int = -1) -> void:
	rng = RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	previous_piece_id = -1
	is_demo = false

func reset(seed_val: int = -1) -> void:
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
	previous_piece_id = -1

## Configures or disables deterministic demo piece retrieval.
func set_demo_mode(enabled: bool, types: PackedByteArray = PackedByteArray()) -> void:
	is_demo = enabled
	demo_tetrimino_types = types
	demo_index = 0

## Rolls the next piece according to authentic 1989 two-roll rules:
## Roll 1: Pick integer R1 in [0, 7] uniformly.
## If R1 == previous_piece_id OR R1 == 7:
##     Roll 2: Pick integer R2 in [0, 6] uniformly.
##     piece_id = R2.
## Else:
##     piece_id = R1.
## Update previous_piece_id = piece_id.
## Yields authentic duplicate rate: 2/56 = 1/28 ~= 3.571%.
func roll_next_piece() -> int:
	if is_demo and not demo_tetrimino_types.is_empty():
		var b: int = demo_tetrimino_types[demo_index % demo_tetrimino_types.size()]
		demo_index += 1
		var raw_type: int = (b >> 4) & 0x07
		var piece_id: int = raw_type if raw_type < 7 else 0
		previous_piece_id = piece_id
		return piece_id

	var roll1: int = rng.randi_range(0, 7)
	var piece_id: int = -1

	if roll1 == previous_piece_id or roll1 == 7:
		var roll2: int = rng.randi_range(0, 6)
		piece_id = roll2
	else:
		piece_id = roll1

	previous_piece_id = piece_id
	return piece_id
