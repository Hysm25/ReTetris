class_name TestRandomizer
extends RefCounted

## Verification test suite for 1989 NES Tetris Two-Roll Randomizer.

const PieceRandomizer = preload("res://src/game/piece_randomizer.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestRandomizer ---")
	test_roll_bounds()
	test_lfsr_initial_seed_and_step()
	test_duplicate_probability()
	print("  -> TestRandomizer: PASSED")
	return true

static func test_lfsr_initial_seed_and_step() -> void:
	# Authentic 1989 NES Tetris cold-boot seed $8988 (main.asm:348-351, 5468-5483)
	var r = PieceRandomizer.new(0)
	r.rng_seed_hi = 0x89
	r.rng_seed_lo = 0x88
	# Step 1: bit1(0x89)=0, bit1(0x88)=0 -> xor=0 -> carry=0
	# new_hi = 0x89 >> 1 = 0x44 (bit 0 was 1 -> shifts into bit 7 of lo)
	# new_lo = (0x88 >> 1) | 0x80 = 0x44 | 0x80 = 0xC4
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x44 and r.rng_seed_lo == 0xC4, "LFSR step 1 from $8988 must yield $44C4, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 2: bit1(0x44)=0, bit1(0xC4)=0 -> xor=0 -> carry=0; new_hi=0x22, new_lo=0x62
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x22 and r.rng_seed_lo == 0x62, "LFSR step 2 from $44C4 must yield $2262, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 3: bit1(0x22)=1, bit1(0x62)=1 -> xor=0 -> carry=0; new_hi=0x11, new_lo=0x31
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x11 and r.rng_seed_lo == 0x31, "LFSR step 3 from $2262 must yield $1131, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 4: bit1(0x11)=0, bit1(0x31)=0 -> xor=0; bit0(0x11)=1 -> new_hi=0x08, new_lo=0x98
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x08 and r.rng_seed_lo == 0x98, "LFSR step 4 from $1131 must yield $0898, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 5: bit1(0x08)=0, bit1(0x98)=0 -> new_hi=0x04, new_lo=0x4C
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x04 and r.rng_seed_lo == 0x4C, "LFSR step 5 from $0898 must yield $044C, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 6: bit1(0x04)=0, bit1(0x4C)=0 -> new_hi=0x02, new_lo=0x26
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x02 and r.rng_seed_lo == 0x26, "LFSR step 6 from $044C must yield $0226, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 7: bit1(0x02)=1, bit1(0x26)=1 -> xor=0 -> new_hi=0x01, new_lo=0x13
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x01 and r.rng_seed_lo == 0x13, "LFSR step 7 from $0226 must yield $0113, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])
	# Step 8: bit1(0x01)=0, bit1(0x13)=1 -> xor=1 -> carry=1! new_hi=0x80, new_lo=0x89
	r.step_lfsr()
	assert(r.rng_seed_hi == 0x80 and r.rng_seed_lo == 0x89, "LFSR step 8 from $0113 must yield $8089, got $%02X%02X" % [r.rng_seed_hi, r.rng_seed_lo])

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
