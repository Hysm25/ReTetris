class_name TestScoreManager
extends RefCounted

## Verification test suite for BPS line clear scoring, soft drop points,
## and authentic starting level transition thresholds.

const ScoreManager = preload("res://src/game/score_manager.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestScoreManager ---")
	test_initialization()
	test_soft_drop_accumulation()
	test_bps_line_scoring()
	test_starting_level_transitions()
	print("  -> TestScoreManager: PASSED")
	return true

static func test_initialization() -> void:
	var sm = ScoreManager.new()
	sm.init_game(0)
	assert(sm.score == 0 and sm.lines == 0 and sm.level == 0)
	assert(sm.first_transition_lines == 10)

static func test_soft_drop_accumulation() -> void:
	var sm = ScoreManager.new()
	sm.init_game(0)
	var pts: int = sm.add_soft_drop_points(15)
	assert(pts == 15 and sm.score == 15, "15 soft drop cells must award 15 points")

static func test_bps_line_scoring() -> void:
	var sm = ScoreManager.new()

	# Level 0 scoring: (40, 100, 300, 1200) * 1
	sm.init_game(0)
	var r1: Dictionary = sm.add_line_clears(1)
	assert(r1["points_added"] == 40 and sm.score == 40, "Level 0 Single = 40")

	var r2: Dictionary = sm.add_line_clears(2)
	assert(r2["points_added"] == 100 and sm.score == 140, "Level 0 Double = 100")

	var r3: Dictionary = sm.add_line_clears(3)
	assert(r3["points_added"] == 300 and sm.score == 440, "Level 0 Triple = 300")

	var r4: Dictionary = sm.add_line_clears(4)
	assert(r4["points_added"] == 1200 and sm.score == 1640, "Level 0 Tetris = 1200")

	# Level 9 scoring: (40, 100, 300, 1200) * 10
	sm.init_game(9)
	var r_l9: Dictionary = sm.add_line_clears(4)
	assert(r_l9["points_added"] == 12000, "Level 9 Tetris = 12,000")

	# Level 18 scoring: (40, 100, 300, 1200) * 19
	sm.init_game(18)
	var r_l18: Dictionary = sm.add_line_clears(4)
	assert(r_l18["points_added"] == 22800, "Level 18 Tetris = 22,800")

static func test_starting_level_transitions() -> void:
	# Level 0 starts -> transitions at 10 lines
	var sm0 = ScoreManager.new()
	sm0.init_game(0)
	sm0.add_line_clears(4) # 4 lines
	assert(sm0.level == 0)
	sm0.add_line_clears(4) # 8 lines
	assert(sm0.level == 0)
	var trans0: Dictionary = sm0.add_line_clears(2) # 10 lines
	assert(trans0["level_up"] and sm0.level == 1, "Level 0 should transition to 1 at 10 lines")

	# Subsequent transition: 10 more lines (20 lines total)
	sm0.add_line_clears(4)
	sm0.add_line_clears(4)
	var trans1: Dictionary = sm0.add_line_clears(2)
	assert(trans1["level_up"] and sm0.level == 2, "Level 1 should transition to 2 at 20 lines")

	# Level 9 starts -> transitions at 100 lines
	var sm9 = ScoreManager.new()
	sm9.init_game(9)
	assert(sm9.first_transition_lines == 100)
	# Add 99 lines
	for i in range(24):
		sm9.add_line_clears(4) # 96 lines
	sm9.add_line_clears(3) # 99 lines
	assert(sm9.level == 9, "Should still be level 9 at 99 lines")
	var trans9: Dictionary = sm9.add_line_clears(1) # 100 lines
	assert(trans9["level_up"] and sm9.level == 10, "Level 9 should transition to 10 at 100 lines")

	# Level 18 starts -> transitions at 130 lines
	var sm18 = ScoreManager.new()
	sm18.init_game(18)
	assert(sm18.first_transition_lines == 130)

	# Level 19 starts -> transitions at 140 lines
	var sm19 = ScoreManager.new()
	sm19.init_game(19)
	assert(sm19.first_transition_lines == 140)
