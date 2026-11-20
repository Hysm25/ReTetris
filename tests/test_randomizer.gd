class_name TestRandomizer
extends RefCounted

## Verification test suite for 1989 NES Tetris Two-Roll Randomizer.

const PieceRandomizer = preload("res://src/game/piece_randomizer.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestRandomizer ---")
	test_roll_bounds()
	test_duplicate_probability()
	print("  -> TestRandomizer: PASSED")
	return true

static func test_roll_bounds() -> void:
	var r = PieceRandomizer.new(12345)
	for i in range(1000):
		var p: int = r.roll_next_piece()
		assert(p >= 0 and p <= 6, "Rolled piece must be in range [0, 6], got %d" % p)

static func test_duplicate_probability() -> void:
	# Statistical validation over 100,000 rolls
	# Theoretical duplicate probability: 1/28 ~= 3.571%
	var r = PieceRandomizer.new(42)
	var total_rolls: int = 100000
	var duplicates: int = 0
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]

	var prev: int = r.roll_next_piece()
	counts[prev] += 1

	for i in range(total_rolls - 1):
		var curr: int = r.roll_next_piece()
		counts[curr] += 1
		if curr == prev:
			duplicates += 1
		prev = curr

	var dup_rate: float = float(duplicates) / float(total_rolls - 1)
	print("    Duplicate rate over %d rolls: %.4f (Expected: ~0.0357)" % [total_rolls, dup_rate])

	# Assert duplicate rate is within [3.2%, 3.9%] tolerance
	assert(dup_rate >= 0.032 and dup_rate <= 0.039, "Duplicate rate %.4f outside acceptable tolerance [0.032, 0.039]" % dup_rate)

	# Verify uniform distribution across all 7 pieces (each ~14.28% of total rolls)
	for p in range(Constants.PIECE_COUNT):
		var piece_ratio: float = float(counts[p]) / float(total_rolls)
		assert(piece_ratio >= 0.13 and piece_ratio <= 0.16, "Piece %d distribution %.4f outside acceptable range" % [p, piece_ratio])
