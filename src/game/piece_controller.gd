class_name PieceController
extends RefCounted

## Manages active tetromino state, translations, NRS rotations with zero kicks,
## gravity step accumulation, soft-drop handling, and instant contact lock.

const Constants = preload("res://src/core/constants.gd")
const BoardGrid = preload("res://src/game/board_grid.gd")
const ContentRegistry = preload("res://src/core/content_registry.gd")

var piece_type: int = Constants.PieceType.T
var orientation: int = Constants.Orientation.T_DOWN
var position: Vector2i = Constants.SPAWN_POSITION
var is_active: bool = false

var gravity_timer: int = 0
var soft_drop_timer: int = 0
var soft_drop_cells: int = 0
var drop_points: int = 0

func reset() -> void:
	piece_type = Constants.PieceType.T
	orientation = Constants.Orientation.T_DOWN
	position = Constants.SPAWN_POSITION
	is_active = false
	gravity_timer = 0
	soft_drop_timer = 0
	soft_drop_cells = 0
	drop_points = 0

## Spawns a piece at the spawn position (default: (5, 0)) with authentic spawn orientation.
## Returns true if spawned without collision; false if immediately blocked (lockout/topout).
func spawn(type: int, grid: BoardGrid, start_pos: Vector2i = Constants.SPAWN_POSITION) -> bool:
	piece_type = type
	orientation = Constants.SPAWN_ORIENTATIONS[type]
	position = start_pos
	gravity_timer = 0
	soft_drop_timer = 0
	soft_drop_cells = 0
	drop_points = 0
	is_active = true

	var can_spawn: bool = grid.can_place_piece(piece_type, position, orientation)
	return can_spawn

## Moves piece horizontally by dx columns (-1 or +1).
## Returns true if moved, false if blocked.
func shift(dx: int, grid: BoardGrid) -> bool:
	if not is_active or dx == 0:
		return false
	var new_pos: Vector2i = position + Vector2i(dx, 0)
	if grid.can_place_piece(piece_type, new_pos, orientation):
		position = new_pos
		return true
	return false

## Rotates piece clockwise (Button A). Zero kicks allowed.
func rotate_cw(grid: BoardGrid) -> bool:
	if not is_active:
		return false
	var new_orientation: int = Constants.get_rotated_orientation(orientation, true)
	if grid.can_place_piece(piece_type, position, new_orientation):
		orientation = new_orientation
		return true
	return false

## Rotates piece counter-clockwise (Button B). Zero kicks allowed.
func rotate_ccw(grid: BoardGrid) -> bool:
	if not is_active:
		return false
	var new_orientation: int = Constants.get_rotated_orientation(orientation, false)
	if grid.can_place_piece(piece_type, position, new_orientation):
		orientation = new_orientation
		return true
	return false

## Advances gravity by 1 frame.
## If down_held is true: soft drop rate (1 drop every 2 frames).
## Otherwise: normal gravity rate (1 drop every gravity_frames).
## Returns Dictionary with status:
## { "moved_down": bool, "locked": bool, "soft_drop_point": bool, "drop_points_awarded": int }
func tick_gravity(level: int, down_held: bool, grid: BoardGrid) -> Dictionary:
	var result: Dictionary = {
		"moved_down": false,
		"locked": false,
		"soft_drop_point": false,
		"drop_points_awarded": 0,
	}

	if not is_active:
		return result

	var gravity_frames: int = Constants.get_gravity_frames(level)
	var should_drop: bool = false
	var is_soft_drop: bool = false

	if down_held:
		soft_drop_timer += 1
		# Soft drop falls 1 cell every 2 frames
		if soft_drop_timer >= 2:
			soft_drop_timer = 0
			should_drop = true
			is_soft_drop = true
	else:
		soft_drop_timer = 0
		# Authentic 1989 NES Tetris: if Down is released before lock, holdDownPoints resets to 0 (main.asm:1559)
		drop_points = 0
		soft_drop_cells = 0
		gravity_timer += 1
		if gravity_timer >= gravity_frames:
			gravity_timer = 0
			should_drop = true

	if should_drop:
		if is_soft_drop:
			# Increments holdDownPoints on each soft-drop attempt (main.asm:1569)
			drop_points += 1

		var target_pos: Vector2i = position + Vector2i(0, 1)
		if grid.can_place_piece(piece_type, target_pos, orientation):
			position = target_pos
			result["moved_down"] = true
			if is_soft_drop:
				soft_drop_cells += 1
				result["soft_drop_point"] = true
		else:
			# Surface contact -> Instant lock on contact!
			is_active = false
			result["locked"] = true
			# Authentic 1989 NES Tetris addHoldDownPoints (main.asm:3436):
			# cmp #$02; bmi addLineClearPoints; dec score; adc score (awards holdDownPoints - 1)
			if is_soft_drop and drop_points >= 2:
				result["drop_points_awarded"] = drop_points - 1
			else:
				result["drop_points_awarded"] = 0

	return result

## Returns and clears any accumulated soft-drop points to award upon piece lock.
## In authentic 1989 NES Tetris (main.asm:3436):
## If holdDownPoints >= 2, awards (holdDownPoints - 1) points; otherwise 0.
func get_and_clear_drop_points() -> int:
	var pts: int = (drop_points - 1) if drop_points >= 2 else 0
	drop_points = 0
	soft_drop_cells = 0
	return pts

## Returns the array of 4 absolute playfield grid coordinates for the active piece's minos.
func get_mino_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if orientation < 0 or orientation >= ContentRegistry.ORIENTATION_MINO_OFFSETS.size():
		return result
	var offsets: Array = ContentRegistry.ORIENTATION_MINO_OFFSETS[orientation]
	for offset in offsets:
		var vec: Vector2i = offset as Vector2i
		result.append(position + vec)
	return result

