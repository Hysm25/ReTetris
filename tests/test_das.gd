class_name TestDAS
extends RefCounted

## Verification test suite for 16-frame initial charge, 6-frame repeat interval,
## direction change reset, and ARE preservation.

const DASHandler = preload("res://src/game/das_handler.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestDAS ---")
	test_initial_tap()
	test_charge_and_repeat()
	test_direction_reversal()
	test_are_preservation()
	test_wall_charge_and_down_inhibit()
	print("  -> TestDAS: PASSED")
	return true

static func test_initial_tap() -> void:
	var das = DASHandler.new()

	# Tap right on frame 0
	var shift: int = das.process_input(Constants.BUTTON_RIGHT, Constants.BUTTON_RIGHT)
	assert(shift == 1, "Initial tap must shift right immediately (+1)")
	assert(das.active_direction == 1, "Active direction must be right (1)")
	assert(das.das_counter == 0, "Counter must be 0 after tap")

	# Frame 1: holding right (not newly pressed)
	shift = das.process_input(Constants.BUTTON_RIGHT, 0)
	assert(shift == 0, "Frame 1 must not shift during charge delay")
	assert(das.das_counter == 1, "Counter must be 1 on frame 1")

static func test_charge_and_repeat() -> void:
	var das = DASHandler.new()
	# Frame 0: Initial press
	das.process_input(Constants.BUTTON_RIGHT, Constants.BUTTON_RIGHT)

	# Frames 1 through 15: Holding without repeat
	for f in range(1, 16):
		var shift: int = das.process_input(Constants.BUTTON_RIGHT, 0)
		assert(shift == 0, "Frame %d should not shift before charge expires" % f)
		assert(das.das_counter == f, "DAS counter on frame %d should equal %d" % [f, f])

	# Frame 16: Charge expires -> triggers repeat shift and reloads counter to 10
	var repeat1: int = das.process_input(Constants.BUTTON_RIGHT, 0)
	assert(repeat1 == 1, "Frame 16 must trigger auto-repeat shift (+1)")
	assert(das.das_counter == Constants.DAS_RELOAD_VALUE, "Counter must reload to 10 on repeat")

	# Next 5 frames (counter 11, 12, 13, 14, 15)
	for f in range(5):
		var shift: int = das.process_input(Constants.BUTTON_RIGHT, 0)
		assert(shift == 0, "Should not shift during 6-frame repeat interval")

	# 6th frame after previous repeat (counter reaches 16) -> triggers second repeat!
	var repeat2: int = das.process_input(Constants.BUTTON_RIGHT, 0)
	assert(repeat2 == 1, "Must trigger second auto-repeat shift after exactly 6 frames")
	assert(das.das_counter == Constants.DAS_RELOAD_VALUE, "Counter must reload to 10 again")

static func test_direction_reversal() -> void:
	var das = DASHandler.new()
	# Hold right for 10 frames
	das.process_input(Constants.BUTTON_RIGHT, Constants.BUTTON_RIGHT)
	for f in range(10):
		das.process_input(Constants.BUTTON_RIGHT, 0)

	# Reversal: press left
	var shift: int = das.process_input(Constants.BUTTON_LEFT, Constants.BUTTON_LEFT)
	assert(shift == -1, "Direction reversal must trigger immediate shift left (-1)")
	assert(das.active_direction == -1, "Active direction must switch to left (-1)")
	assert(das.das_counter == 0, "Counter must reset to 0 upon direction reversal")

static func test_are_preservation() -> void:
	var das = DASHandler.new()

	# Pre-charge DAS during ARE for 16 frames
	for f in range(16):
		das.charge_are(Constants.BUTTON_RIGHT)

	assert(das.das_counter == 16, "DAS should be fully charged to 16 during ARE")
	assert(das.active_direction == 1, "Active direction should be right")

	# Next active frame: holding right triggers immediate repeat on frame 0 of new piece!
	var shift: int = das.process_input(Constants.BUTTON_RIGHT, 0)
	assert(shift == 1, "Pre-charged DAS must shift immediately upon piece entry")

static func test_wall_charge_and_down_inhibit() -> void:
	var das = DASHandler.new()
	# Initial press -> counter = 0
	das.process_input(Constants.BUTTON_LEFT, Constants.BUTTON_LEFT)
	assert(das.das_counter == 0)

	# Simulate wall collision -> authentic wall charge sets counter to DAS_INITIAL_DELAY (16)
	das.on_wall_collision()
	assert(das.das_counter == Constants.DAS_INITIAL_DELAY, "Wall collision must set DAS counter to 16")

	# Holding Down inhibits horizontal shift per main.asm:1619-1621
	var blocked_shift: int = das.process_input(Constants.BUTTON_LEFT | Constants.BUTTON_DOWN, Constants.BUTTON_LEFT)
	assert(blocked_shift == 0, "Holding Down must inhibit horizontal shifting")
