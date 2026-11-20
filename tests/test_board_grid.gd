class_name TestBoardGrid
extends RefCounted

## Verification test suite for 10x22 BoardGrid logic, occupancy, NRS collision,
## 5-step center-outward clearing, and row collapse.

const BoardGrid = preload("res://src/game/board_grid.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestBoardGrid ---")
	test_dimensions_and_cells()
	test_piece_placement_and_bounds()
	test_lock_and_row_completion()
	test_5_step_clearing_and_collapse()
	print("  -> TestBoardGrid: PASSED")
	return true

static func test_dimensions_and_cells() -> void:
	var grid = BoardGrid.new()
	assert(grid.cells.size() == 220, "Grid cells must have size 220 (10x22)")
	assert(grid.is_valid_cell(0, 0), "Cell (0, 0) must be valid")
	assert(grid.is_valid_cell(9, 21), "Cell (9, 21) must be valid")
	assert(not grid.is_valid_cell(10, 21), "Cell (10, 21) must be invalid")
	assert(not grid.is_valid_cell(0, 22), "Cell (0, 22) must be invalid")
	assert(not grid.is_valid_cell(-1, 0), "Cell (-1, 0) must be invalid")

	grid.set_cell(5, 10, Constants.TileType.PRIMARY)
	assert(grid.get_cell(5, 10) == Constants.TileType.PRIMARY, "Cell (5, 10) must be PRIMARY")
	assert(grid.is_occupied(5, 10), "Cell (5, 10) must be occupied")
	assert(not grid.is_occupied(5, 11), "Cell (5, 11) must not be occupied")

static func test_piece_placement_and_bounds() -> void:
	var grid = BoardGrid.new()

	# Can place piece at valid spawn position
	assert(grid.can_place_piece(Constants.PieceType.T, Vector2i(5, 0), Constants.Orientation.T_DOWN))

	# Wall collision (Left wall)
	assert(not grid.can_place_piece(Constants.PieceType.I, Vector2i(0, 10), Constants.Orientation.I_HORIZ), "I piece at x=0 horiz overflows left bounds")
	# Wall collision (Right wall)
	assert(not grid.can_place_piece(Constants.PieceType.I, Vector2i(9, 10), Constants.Orientation.I_HORIZ), "I piece at x=9 horiz overflows right bounds")

	# Floor collision
	assert(not grid.can_place_piece(Constants.PieceType.O, Vector2i(5, 21), Constants.Orientation.O_FIXED), "O piece at y=21 overflows floor bounds")

	# Occupancy collision
	grid.set_cell(5, 10, Constants.TileType.PRIMARY)
	assert(not grid.can_place_piece(Constants.PieceType.T, Vector2i(5, 10), Constants.Orientation.T_DOWN), "Piece must collide with occupied cell")

static func test_lock_and_row_completion() -> void:
	var grid = BoardGrid.new()
	# Lock O piece at (5, 20)
	var locked_rows: Array[int] = grid.lock_piece(Constants.PieceType.O, Vector2i(5, 20), Constants.Orientation.O_FIXED)
	assert(locked_rows.has(20) and locked_rows.has(21), "Locked rows must contain rows 20 and 21")
	assert(grid.is_occupied(4, 20) and grid.is_occupied(5, 20), "Minos at (4, 20) and (5, 20) must be occupied")

	# No complete rows yet
	assert(grid.get_completed_rows().is_empty(), "Grid should have no completed rows yet")

	# Fill remaining cells in row 21
	for x in range(Constants.GRID_COLUMNS):
		grid.set_cell(x, 21, Constants.TileType.PRIMARY)

	var completed: Array[int] = grid.get_completed_rows()
	assert(completed.size() == 1 and completed[0] == 21, "Row 21 must be marked completed")

static func test_5_step_clearing_and_collapse() -> void:
	var grid = BoardGrid.new()
	for x in range(Constants.GRID_COLUMNS):
		grid.set_cell(x, 21, Constants.TileType.PRIMARY)
		grid.set_cell(x, 20, Constants.TileType.SECONDARY)

	var completed: Array[int] = grid.get_completed_rows()
	assert(completed.size() == 2, "Rows 20 and 21 must be complete")

	# Step 0: clear cols 4 & 5
	grid.clear_step(completed, 0)
	assert(grid.get_cell(4, 21) == Constants.TileType.EMPTY and grid.get_cell(5, 21) == Constants.TileType.EMPTY)
	assert(grid.get_cell(3, 21) != Constants.TileType.EMPTY)

	# Steps 1 to 4: center outward
	grid.clear_step(completed, 1) # cols 3 & 6
	grid.clear_step(completed, 2) # cols 2 & 7
	grid.clear_step(completed, 3) # cols 1 & 8
	grid.clear_step(completed, 4) # cols 0 & 9

	# Verify all cells in cleared rows are now empty
	for x in range(Constants.GRID_COLUMNS):
		assert(grid.get_cell(x, 21) == Constants.TileType.EMPTY, "Row 21 cell %d must be cleared" % x)
		assert(grid.get_cell(x, 20) == Constants.TileType.EMPTY, "Row 20 cell %d must be cleared" % x)

	# Setup row 19 with a marker block
	grid.set_cell(3, 19, Constants.TileType.TERTIARY)

	# Collapse rows
	grid.collapse_rows(completed)

	# Row 19 marker block should have moved down by 2 rows to row 21!
	assert(grid.get_cell(3, 21) == Constants.TileType.TERTIARY, "Block from row 19 should collapse to row 21")
	assert(grid.get_cell(3, 19) == Constants.TileType.EMPTY, "Original row 19 should now be empty")
