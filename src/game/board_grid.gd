class_name BoardGrid
extends RefCounted

## 10x22 Logical Playfield storage, bounds checking, cell occupancy queries,
## piece locking, full-row detection, 5-step center-outward line clearing, and row collapse.

const Constants = preload("res://src/core/constants.gd")
const ContentRegistry = preload("res://src/core/content_registry.gd")

# 10 columns x 22 rows flattened 1D array of cell values (0 = empty, 1..3 = tile styles)
# Index = y * GRID_COLUMNS + x
var cells: Array[int] = []

func _init() -> void:
	cells.resize(Constants.GRID_COLUMNS * Constants.GRID_ROWS)
	clear()

func clear() -> void:
	for i in range(cells.size()):
		cells[i] = Constants.TileType.EMPTY

func is_valid_cell(x: int, y: int) -> bool:
	return x >= 0 and x < Constants.GRID_COLUMNS and y >= 0 and y < Constants.GRID_ROWS

func get_cell(x: int, y: int) -> int:
	if not is_valid_cell(x, y):
		return -1
	return cells[y * Constants.GRID_COLUMNS + x]

func set_cell(x: int, y: int, value: int) -> void:
	if is_valid_cell(x, y):
		cells[y * Constants.GRID_COLUMNS + x] = value

func is_occupied(x: int, y: int) -> bool:
	# Outside left, right, or bottom is considered occupied
	if x < 0 or x >= Constants.GRID_COLUMNS or y >= Constants.GRID_ROWS:
		return true
	# Above playfield (y < 0) is not occupied (allow piece above buffer if needed)
	if y < 0:
		return false
	return cells[y * Constants.GRID_COLUMNS + x] != Constants.TileType.EMPTY

## Checks whether a piece in a given orientation can be placed at grid position (x, y).
## Sourced from authentic NRS: zero wall kicks, zero floor kicks.
func can_place_piece(piece_type: int, position: Vector2i, orientation: int) -> bool:
	if orientation < 0 or orientation >= ContentRegistry.ORIENTATION_MINO_OFFSETS.size():
		return false

	var offsets: Array = ContentRegistry.ORIENTATION_MINO_OFFSETS[orientation]
	for offset in offsets:
		var vec: Vector2i = offset as Vector2i
		var cell_x: int = position.x + vec.x
		var cell_y: int = position.y + vec.y

		# Out of bounds left, right, or below floor
		if cell_x < 0 or cell_x >= Constants.GRID_COLUMNS or cell_y >= Constants.GRID_ROWS:
			return false
		# Check cell occupancy within grid
		if cell_y >= 0:
			if cells[cell_y * Constants.GRID_COLUMNS + cell_x] != Constants.TileType.EMPTY:
				return false

	return true

## Locks a tetromino into the grid and returns an array of occupied row indices affected.
func lock_piece(piece_type: int, position: Vector2i, orientation: int) -> Array[int]:
	var tile_style: int = Constants.TILE_TYPE_FROM_PIECE[piece_type]
	var offsets: Array = ContentRegistry.ORIENTATION_MINO_OFFSETS[orientation]
	var affected_rows_dict: Dictionary = {}

	for offset in offsets:
		var vec: Vector2i = offset as Vector2i
		var cell_x: int = position.x + vec.x
		var cell_y: int = position.y + vec.y

		if is_valid_cell(cell_x, cell_y):
			set_cell(cell_x, cell_y, tile_style)
			affected_rows_dict[cell_y] = true

	var rows: Array[int] = []
	for r in affected_rows_dict.keys():
		rows.append(r as int)
	rows.sort()
	return rows

## Returns array of row indices that are completely filled (from top to bottom).
func get_completed_rows() -> Array[int]:
	var completed: Array[int] = []
	for y in range(Constants.GRID_ROWS):
		var full: bool = true
		for x in range(Constants.GRID_COLUMNS):
			if cells[y * Constants.GRID_COLUMNS + x] == Constants.TileType.EMPTY:
				full = false
				break
		if full:
			completed.append(y)
	return completed

## Performs one step (0..4) of authentic 5-step center-outward line clearing on specified rows:
## Step 0: cols 4 & 5
## Step 1: cols 3 & 6
## Step 2: cols 2 & 7
## Step 3: cols 1 & 8
## Step 4: cols 0 & 9
func clear_step(completed_rows: Array[int], step: int) -> void:
	if step < 0 or step >= Constants.ARE_LINE_CLEAR_STEPS:
		return
	var left_col: int = Constants.LINE_CLEAR_LEFT_COLS[step]
	var right_col: int = Constants.LINE_CLEAR_RIGHT_COLS[step]

	for y in completed_rows:
		if is_valid_cell(left_col, y):
			set_cell(left_col, y, Constants.TileType.EMPTY)
		if is_valid_cell(right_col, y):
			set_cell(right_col, y, Constants.TileType.EMPTY)

## Collapses completed rows downward.
func collapse_rows(completed_rows: Array[int]) -> void:
	if completed_rows.is_empty():
		return

	var is_cleared_row: Dictionary = {}
	for r in completed_rows:
		is_cleared_row[r] = true

	var write_y: int = Constants.GRID_ROWS - 1
	for read_y in range(Constants.GRID_ROWS - 1, -1, -1):
		if not is_cleared_row.has(read_y):
			if write_y != read_y:
				for x in range(Constants.GRID_COLUMNS):
					cells[write_y * Constants.GRID_COLUMNS + x] = cells[read_y * Constants.GRID_COLUMNS + x]
			write_y -= 1

	# Clear remaining top rows
	while write_y >= 0:
		for x in range(Constants.GRID_COLUMNS):
			cells[write_y * Constants.GRID_COLUMNS + x] = Constants.TileType.EMPTY
		write_y -= 1

## Populates Type B starting garbage based on selected height (0 to 5).
## Replicates authentic 1989 NES Tetris logic from typeBRows / typeBGarbageInRow.
func setup_type_b_garbage(height: int, seed_val: int = -1) -> void:
	clear()
	var h: int = clampi(height, 0, 5)
	if h <= 0:
		return

	var num_rows: int = Constants.TYPE_B_GARBAGE_ROWS[h]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()

	# Authentic row filling from bottom (row 21) up to row (22 - num_rows)
	for r_offset in range(num_rows):
		var r: int = Constants.GRID_ROWS - 1 - r_offset
		# Guarantee at least one blank column (typeBGuaranteeBlank)
		var blank_col: int = rng.randi_range(0, Constants.GRID_COLUMNS - 1)
		for c in range(Constants.GRID_COLUMNS):
			if c == blank_col:
				set_cell(c, r, Constants.TileType.EMPTY)
			else:
				var roll: int = rng.randi() & 0x07
				set_cell(c, r, Constants.TYPE_B_RNG_TABLE[roll])
