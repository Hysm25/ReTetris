class_name PieceRandomizer
extends RefCounted

## Authentic 1989 NES Tetris piece randomizer (16-bit LFSR + Two-Roll algorithm).
## Sourced from Tetris NES disassembly (main.asm:348-351, 2964-3004, 5468-5483).

const Constants = preload("res://src/core/constants.gd")

var previous_piece_id: int = -1
var rng_seed_hi: int = 0x89 # NES RAM rng_seed ($0017)
var rng_seed_lo: int = 0x88 # NES RAM rng_seed+1 ($0018)
var spawn_count: int = 0
var frames_since_roll: int = 0

var is_demo: bool = false
var demo_tetrimino_types: PackedByteArray = PackedByteArray()
var demo_index: int = 0

func _init(seed_val: int = -1) -> void:
	reset(seed_val)
	is_demo = false

func reset(seed_val: int = -1) -> void:
	if seed_val >= 0:
		rng_seed_hi = ((seed_val >> 8) & 0xFF) ^ 0x89
		rng_seed_lo = (seed_val & 0xFF) ^ 0x88
		if (rng_seed_hi | rng_seed_lo) == 0:
			rng_seed_hi = 0x89
			rng_seed_lo = 0x88
	else:
		rng_seed_hi = 0x89
		rng_seed_lo = 0x88
		var jitter: int = int(Time.get_ticks_usec() & 0xFF)
		for _i in range(jitter):
			step_lfsr()
	spawn_count = 0
	frames_since_roll = 0
	previous_piece_id = -1

## Advances the authentic 16-bit NES LFSR by 1 tick (main.asm:5468-5483).
## Computes bit1(seed_hi) XOR bit1(seed_lo) and rotates right through 16 bits.
func step_lfsr() -> void:
	var tap_hi: int = rng_seed_hi & 0x02
	var tap_lo: int = rng_seed_lo & 0x02
	var carry: int = 1 if (tap_hi ^ tap_lo) != 0 else 0
	var new_hi: int = ((rng_seed_hi >> 1) | (carry << 7)) & 0xFF
	var new_lo: int = ((rng_seed_lo >> 1) | ((rng_seed_hi & 1) << 7)) & 0xFF
	rng_seed_hi = new_hi
	rng_seed_lo = new_lo

## Called once per 60 Hz frame to replicate NMI LFSR progression.
func tick_frame() -> void:
	step_lfsr()
	frames_since_roll += 1

## Configures or disables deterministic demo piece retrieval.
func set_demo_mode(enabled: bool, types: PackedByteArray = PackedByteArray()) -> void:
	is_demo = enabled
	demo_tetrimino_types = types
	demo_index = 0

## Rolls the next piece using the authentic 1989 NES 16-bit LFSR two-roll algorithm:
## 1. Increment spawn_count (8-bit).
## 2. Roll 1: index = (rng_seed_hi + spawn_count) & 0x07.
## 3. If index == 7 OR index == previous_piece_id:
##    Advance LFSR, then Roll 2: index = ((rng_seed_hi & 0x07) + prev_spawn_ori) % 7.
## Yields authentic duplicate rate (~3.57% - 1/28).
func roll_next_piece() -> int:
	if is_demo and not demo_tetrimino_types.is_empty():
		var b: int = demo_tetrimino_types[demo_index % demo_tetrimino_types.size()]
		demo_index += 1
		var raw_type: int = (b >> 4) & 0x07
		var piece_id: int = raw_type if raw_type < 7 else 0
		previous_piece_id = piece_id
		return piece_id

	# Ensure at least 11 LFSR shifts between spawns (matching real >=10-frame ARE + fall)
	while frames_since_roll < 11:
		step_lfsr()
		frames_since_roll += 1
	frames_since_roll = 0

	spawn_count = (spawn_count + 1) & 0xFF
	var roll1: int = (rng_seed_hi + spawn_count) & 0x07
	var piece_id: int = -1

	if roll1 == previous_piece_id or roll1 == 7:
		step_lfsr()
		var prev_ori: int = Constants.SPAWN_ORIENTATIONS[previous_piece_id] if previous_piece_id >= 0 else 0
		piece_id = ((rng_seed_hi & 0x07) + prev_ori) % 7
	else:
		piece_id = roll1

	previous_piece_id = piece_id
	return piece_id
