class_name ScoreManager
extends RefCounted

## Manages authentic 1989 NES Tetris BPS scoring, lines cleared tracking,
## and starting level transition thresholds.

const Constants = preload("res://src/core/constants.gd")

var score: int = 0
var lines: int = 0
var level: int = 0
var start_level: int = 0
var first_transition_lines: int = 10

func init_game(starting_level: int) -> void:
	score = 0
	lines = 0
	start_level = maxi(0, starting_level)
	level = start_level
	first_transition_lines = Constants.get_first_level_transition_lines(start_level)

func add_soft_drop_points(cells: int) -> int:
	if cells <= 0:
		return 0
	var points: int = cells * Constants.SCORE_SOFT_DROP_PER_CELL
	score += points
	return points

## Adds line clear score and evaluates level transitions.
## Returns Dictionary { "points_added": int, "level_up": bool }
func add_line_clears(count: int) -> Dictionary:
	var result: Dictionary = {
		"points_added": 0,
		"level_up": false,
	}
	if count < 1 or count > 4:
		return result

	var points: int = Constants.get_line_clear_score(count, level)
	score += points
	lines += count
	result["points_added"] = points

	# Authentic level transition logic
	var target_threshold: int = 0
	if level == start_level:
		target_threshold = first_transition_lines
	else:
		target_threshold = first_transition_lines + (level - start_level) * 10

	if lines >= target_threshold:
		level += 1
		result["level_up"] = true

	return result
