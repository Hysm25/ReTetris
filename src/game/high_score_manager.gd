class_name HighScoreManager
extends RefCounted

## Manages persistent high score tables for 1989 NES Tetris (Game A and Game B).
## Stores Top 3 scores with 6-character initials, 6-digit scores, and level numbers.
## Replicates authentic tie-breaking rules: prefers the newer score on tie.
## Persists data to user://high_scores.dat.

const Constants = preload("res://src/core/constants.gd")

const SAVE_PATH: String = "user://high_scores.dat"

# Authentic default scores from 1989 NES Tetris PRG-ROM (offset 0x002D77)
const DEFAULT_SCORES_A: Array[Dictionary] = [
	{"name": "HOWARD", "score": 10000, "level": 9},
	{"name": "OTASAN", "score": 7500, "level": 5},
	{"name": "LANCE ", "score": 5000, "level": 0},
]

const DEFAULT_SCORES_B: Array[Dictionary] = [
	{"name": "ALEX  ", "score": 2000, "level": 9},
	{"name": "TONY  ", "score": 1000, "level": 5},
	{"name": "NINTEN", "score": 500, "level": 0},
]

var scores_a: Array[Dictionary] = []
var scores_b: Array[Dictionary] = []

func _init(auto_load: bool = true) -> void:
	reset_to_defaults()
	if auto_load:
		load_scores()

## Resets both tables to authentic default values.
func reset_to_defaults() -> void:
	scores_a.clear()
	for entry in DEFAULT_SCORES_A:
		scores_a.append(entry.duplicate())

	scores_b.clear()
	for entry in DEFAULT_SCORES_B:
		scores_b.append(entry.duplicate())

## Checks if a score qualifies for the Top 3 in the given game type.
## Returns the 0-indexed rank (0, 1, or 2) if qualified, or -1 if not.
## Authentic behavior: ties qualify and prefer the new score.
func check_qualifies(game_type: int, score: int) -> int:
	var list: Array[Dictionary] = scores_a if game_type == Constants.GameType.TYPE_A else scores_b
	for i in range(list.size()):
		var existing_score: int = int(list[i].get("score", 0))
		if score >= existing_score:
			return i
	return -1

## Inserts a new high score into the table if qualified, saving to disk.
## Returns the inserted rank (0..2), or -1 if disqualified.
func insert_score(game_type: int, player_name: String, score: int, level: int, file_path: String = SAVE_PATH) -> int:
	var rank: int = check_qualifies(game_type, score)
	if rank < 0:
		return -1

	# Sanitize name to exactly 6 characters padded with spaces
	var formatted_name: String = player_name.to_upper()
	if formatted_name.length() > 6:
		formatted_name = formatted_name.substr(0, 6)
	while formatted_name.length() < 6:
		formatted_name += " "

	var new_entry: Dictionary = {
		"name": formatted_name,
		"score": score,
		"level": level,
	}

	var list: Array[Dictionary] = scores_a if game_type == Constants.GameType.TYPE_A else scores_b
	list.insert(rank, new_entry)
	if list.size() > 3:
		list.resize(3)

	save_scores(file_path)
	return rank

## Retrieves the top score for a given game type.
func get_top_score(game_type: int) -> int:
	var list: Array[Dictionary] = scores_a if game_type == Constants.GameType.TYPE_A else scores_b
	if list.is_empty():
		return 0
	return int(list[0].get("score", 0))

## Retrieves the 3 high score entries for a given game type.
func get_entries(game_type: int) -> Array[Dictionary]:
	var list: Array[Dictionary] = scores_a if game_type == Constants.GameType.TYPE_A else scores_b
	var copy: Array[Dictionary] = []
	for entry in list:
		copy.append(entry.duplicate())
	return copy

## Saves high score tables to disk.
func save_scores(file_path: String = SAVE_PATH) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false

	var data: Dictionary = {
		"scores_a": scores_a,
		"scores_b": scores_b,
	}
	file.store_string(JSON.stringify(data))
	file.close()
	return true

## Loads high score tables from disk. If missing or corrupted, retains defaults.
func load_scores(file_path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(file_path):
		return false

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false

	var content: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return false

	var dict: Dictionary = parsed as Dictionary
	if dict.has("scores_a") and dict["scores_a"] is Array:
		var arr_a: Array = dict["scores_a"] as Array
		if arr_a.size() == 3:
			scores_a.clear()
			for item in arr_a:
				if item is Dictionary:
					scores_a.append({
						"name": String(item.get("name", "      ")),
						"score": int(item.get("score", 0)),
						"level": int(item.get("level", 0)),
					})

	if dict.has("scores_b") and dict["scores_b"] is Array:
		var arr_b: Array = dict["scores_b"] as Array
		if arr_b.size() == 3:
			scores_b.clear()
			for item in arr_b:
				if item is Dictionary:
					scores_b.append({
						"name": String(item.get("name", "      ")),
						"score": int(item.get("score", 0)),
						"level": int(item.get("level", 0)),
					})

	return true
