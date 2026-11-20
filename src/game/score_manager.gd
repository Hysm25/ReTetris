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
var game_type: int = Constants.GameType.TYPE_A
var start_height: int = 0
var lines_remaining: int = 25
var is_goal_reached: bool = false

func init_game(starting_level: int, type: int = Constants.GameType.TYPE_A, height: int = 0) -> void:
	score = 0
	start_level = maxi(0, starting_level)
	level = start_level
	game_type = type
	start_height = clampi(height, 0, 5)
	first_transition_lines = Constants.get_first_level_transition_lines(start_level)
	if game_type == Constants.GameType.TYPE_B:
		lines = Constants.TYPE_B_GOAL_LINES
		lines_remaining = Constants.TYPE_B_GOAL_LINES
		is_goal_reached = false
	else:
		lines = 0
		lines_remaining = 0
		is_goal_reached = false

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
	result["points_added"] = points

	if game_type == Constants.GameType.TYPE_B:
		lines_remaining = maxi(0, lines_remaining - count)
		lines = lines_remaining
		if lines_remaining == 0 and not is_goal_reached:
			is_goal_reached = true
			# Authentic Type B victory bonus: (level + 1) * 1000 + height * 1000
			var bonus: int = (level + 1) * 1000 + start_height * 1000
			score += bonus
			result["points_added"] += bonus
	else:
		lines += count
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
