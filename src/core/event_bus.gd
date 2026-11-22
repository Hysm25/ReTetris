extends Node

## Typed global event bus for decoupled communication across ReTetris subsystems.
## Dispatches simulation lifecycle events, scoring updates, grid clears, and game state transitions.

signal piece_spawned(piece_type: int, position: Vector2i, orientation: int)
signal piece_moved(piece_type: int, position: Vector2i, orientation: int)
signal piece_shifted(piece_type: int, position: Vector2i, orientation: int)
signal piece_rotated(piece_type: int, position: Vector2i, orientation: int)
signal piece_locked(piece_type: int, position: Vector2i, orientation: int)
signal lines_clearing(rows: Array[int], frame_step: int)
signal lines_cleared(count: int, rows: Array[int])
signal score_updated(current_score: int, points_added: int)
signal lines_updated(total_lines: int)
signal level_updated(new_level: int)
signal game_over()
signal game_restarted()
signal sfx_requested(sfx_id: int)

# --- Typed Dispatcher Helpers ---

func emit_piece_spawned(piece_type: int, position: Vector2i, orientation: int) -> void:
	piece_spawned.emit(piece_type, position, orientation)

func emit_piece_moved(piece_type: int, position: Vector2i, orientation: int) -> void:
	piece_moved.emit(piece_type, position, orientation)

func emit_piece_shifted(piece_type: int, position: Vector2i, orientation: int) -> void:
	piece_shifted.emit(piece_type, position, orientation)

func emit_piece_rotated(piece_type: int, position: Vector2i, orientation: int) -> void:
	piece_rotated.emit(piece_type, position, orientation)

func emit_piece_locked(piece_type: int, position: Vector2i, orientation: int) -> void:
	piece_locked.emit(piece_type, position, orientation)

func emit_lines_clearing(rows: Array[int], frame_step: int) -> void:
	lines_clearing.emit(rows, frame_step)

func emit_lines_cleared(count: int, rows: Array[int]) -> void:
	lines_cleared.emit(count, rows)

func emit_score_updated(current_score: int, points_added: int) -> void:
	score_updated.emit(current_score, points_added)

func emit_lines_updated(total_lines: int) -> void:
	lines_updated.emit(total_lines)

func emit_level_updated(new_level: int) -> void:
	level_updated.emit(new_level)

func emit_game_over() -> void:
	game_over.emit()

func emit_game_restarted() -> void:
	game_restarted.emit()
