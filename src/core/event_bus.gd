extends Node

## Typed global event bus for decoupled communication across ReTetris subsystems.

signal piece_spawned(piece_type: int, position: Vector2i, orientation: int)
signal piece_moved(piece_type: int, position: Vector2i, orientation: int)
signal piece_rotated(piece_type: int, position: Vector2i, orientation: int)
signal piece_locked(piece_type: int, position: Vector2i, orientation: int)
signal lines_clearing(rows: Array[int], frame_step: int)
signal lines_cleared(count: int, rows: Array[int])
signal score_updated(current_score: int, points_added: int)
signal lines_updated(total_lines: int)
signal level_updated(new_level: int)
signal game_over()
signal game_restarted()
