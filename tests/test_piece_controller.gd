class_name TestPieceController
extends RefCounted

## Verification test suite for PieceController translations, NRS rotation with zero kicks,
## gravity drop rates, soft drop, and instant contact lock.

const PieceController = preload("res://src/game/piece_controller.gd")
const BoardGrid = preload("res://src/game/board_grid.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestPieceController ---")
	test_spawn_and_translation()
	test_nrs_rotation_zero_kicks()
	test_gravity_and_soft_drop()
	test_instant_lock()
	print("  -> TestPieceController: PASSED")
	return true

static func test_spawn_and_translation() -> void:
	var grid = BoardGrid.new()
	var pc = PieceController.new()

	assert(pc.spawn(Constants.PieceType.T, grid), "Spawn T piece should succeed")
	assert(pc.position == Constants.SPAWN_POSITION, "Initial position must be (5, 0)")
	assert(pc.orientation == Constants.Orientation.T_DOWN, "Initial orientation must be T_DOWN")

	# Shift left to (4, 0)
	assert(pc.shift(-1, grid), "Shift left should succeed")
	assert(pc.position == Vector2i(4, 0))

	# Shift right back to (5, 0)
	assert(pc.shift(1, grid), "Shift right should succeed")
	assert(pc.position == Vector2i(5, 0))

static func test_nrs_rotation_zero_kicks() -> void:
	var grid = BoardGrid.new()
	var pc = PieceController.new()

	# Spawn I piece at (5, 5)
	pc.spawn(Constants.PieceType.I, grid, Vector2i(5, 5))
	assert(pc.orientation == Constants.Orientation.I_HORIZ)

	# Rotate CW -> I_VERT
	assert(pc.rotate_cw(grid), "Rotation in open space should succeed")
	assert(pc.orientation == Constants.Orientation.I_VERT)

	# Move I_VERT against left wall (x = 0)
	pc.position = Vector2i(0, 5)
	# Attempting to rotate I_VERT to I_HORIZ at x = 0 requires x=-2 and x=-1 (outside grid!)
	# NRS Rule: Zero wall kicks! The rotation MUST be rejected unconditionally!
	var rotated: bool = pc.rotate_cw(grid)
	assert(not rotated, "Wall kick must be completely rejected under NRS")
	assert(pc.orientation == Constants.Orientation.I_VERT, "Orientation must remain I_VERT")
	assert(pc.position == Vector2i(0, 5), "Position must remain unchanged (no kick)")

	# Floor kick rejection: Place T_DOWN at bottom row
	pc.spawn(Constants.PieceType.T, grid, Vector2i(5, 21))
	# T_DOWN at y=21 has mino at y=22 (which is outside grid!), wait:
	# T_UP at y=21 has mino at y=20 and y=21. Rotating to T_RIGHT would place mino at y=22 (below floor!)
	pc.position = Vector2i(5, 20)
	pc.orientation = Constants.Orientation.T_RIGHT # mino at y=21
	pc.position = Vector2i(5, 21) # mino at y=21+1 = 22 (outside)
	assert(not grid.can_place_piece(Constants.PieceType.T, Vector2i(5, 21), Constants.Orientation.T_RIGHT))
	# Set valid position at y=20, orientation T_LEFT
	pc.position = Vector2i(5, 20)
	pc.orientation = Constants.Orientation.T_UP
	# Rotating to T_DOWN at y=21 would place mino at y=22 -> rejected
	pc.position = Vector2i(5, 21)
	assert(not pc.rotate_cw(grid), "Floor kick must be rejected under NRS")

static func test_gravity_and_soft_drop() -> void:
	var grid = BoardGrid.new()
	var pc = PieceController.new()

	# Level 0 gravity = 48 frames per drop
	pc.spawn(Constants.PieceType.O, grid, Vector2i(5, 0))

	# Frames 1 to 47: should not drop
	for f in range(47):
		var res: Dictionary = pc.tick_gravity(0, false, grid)
		assert(not res["moved_down"] and not res["locked"])
		assert(pc.position.y == 0)

	# Frame 48: should drop 1 cell!
	var drop_res: Dictionary = pc.tick_gravity(0, false, grid)
	assert(drop_res["moved_down"], "Frame 48 at Level 0 must drop piece by 1 cell")
	assert(pc.position.y == 1, "Y position must be 1")

	# Soft drop: 1 drop every 2 frames
	var sd1: Dictionary = pc.tick_gravity(0, true, grid)
	assert(not sd1["moved_down"], "Frame 1 of soft drop should not drop yet")
	var sd2: Dictionary = pc.tick_gravity(0, true, grid)
	assert(sd2["moved_down"], "Frame 2 of soft drop must drop piece by 1 cell")
	assert(sd2["soft_drop_point"], "Soft drop must award a soft drop point")
	assert(pc.position.y == 2, "Y position must be 2")

static func test_instant_lock() -> void:
	var grid = BoardGrid.new()
	var pc = PieceController.new()

	# Place O piece resting directly above floor (y = 20)
	# O piece at y=20 occupies rows 20 and 21. Row 22 is floor!
	pc.spawn(Constants.PieceType.O, grid, Vector2i(5, 20))

	# Force drop tick by setting gravity_timer to 47
	pc.gravity_timer = 47
	var lock_res: Dictionary = pc.tick_gravity(0, false, grid)

	# When contacting floor: instant lock! Zero grace period.
	assert(lock_res["locked"], "Piece must lock instantly upon contacting floor")
	assert(not pc.is_active, "Piece should no longer be active after locking")
