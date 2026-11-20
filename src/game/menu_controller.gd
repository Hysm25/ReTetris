class_name MenuController
extends RefCounted

## Coordinates authentic 1989 NES Tetris menu navigation, game mode selection,
## music selection, and starting level / height configuration.
## States: TITLE_SCREEN, GAME_TYPE_MENU, LEVEL_MENU, IN_GAME.
## Operates deterministically at fixed 60 TPS.

const Constants = preload("res://src/core/constants.gd")
const HighScoreManager = preload("res://src/game/high_score_manager.gd")

signal mode_changed(new_mode: int)
signal game_started(game_type: int, start_level: int, start_height: int, music_type: int)
signal sfx_requested(sfx_id: int)
signal music_changed(track_type: int)

var current_mode: int = Constants.MenuMode.TITLE_SCREEN
var game_type: int = Constants.GameType.TYPE_A
var music_type: int = Constants.MusicType.MUSIC_1
var selected_level: int = 0
var selected_height: int = 0
var selecting_height: bool = false

var cursor_timer: int = 0
var title_timer: int = 0

# High Score Management
var high_score_mgr: HighScoreManager = null
var entry_game_type: int = Constants.GameType.TYPE_A
var entry_score: int = 0
var entry_level: int = 0
var entry_rank: int = -1
var entry_name_chars: Array[String] = ["A", "A", "A", " ", " ", " "]
var entry_char_index: int = 0

const ENTRY_CHAR_TABLE: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ -."

func _init() -> void:
	high_score_mgr = HighScoreManager.new()

func reset_to_title() -> void:
	current_mode = Constants.MenuMode.TITLE_SCREEN
	cursor_timer = 0
	title_timer = 0
	selecting_height = false
	mode_changed.emit(current_mode)

func step_frame(held_buttons: int, newly_pressed_buttons: int) -> void:
	cursor_timer = (cursor_timer + 1) & 0xFF

	match current_mode:
		Constants.MenuMode.TITLE_SCREEN:
			_step_title_screen(held_buttons, newly_pressed_buttons)
		Constants.MenuMode.GAME_TYPE_MENU:
			_step_game_type_menu(held_buttons, newly_pressed_buttons)
		Constants.MenuMode.LEVEL_MENU:
			_step_level_menu(held_buttons, newly_pressed_buttons)
		Constants.MenuMode.HIGH_SCORE_ENTRY:
			_step_high_score_entry(held_buttons, newly_pressed_buttons)
		Constants.MenuMode.HIGH_SCORE_TABLE:
			_step_high_score_table(held_buttons, newly_pressed_buttons)
		Constants.MenuMode.IN_GAME:
			pass

func _step_title_screen(_held_buttons: int, newly_pressed: int) -> void:
	title_timer += 1
	if (newly_pressed & Constants.BUTTON_START) != 0:
		sfx_requested.emit(Constants.SFX_MENU_START)
		current_mode = Constants.MenuMode.GAME_TYPE_MENU
		mode_changed.emit(current_mode)
		music_changed.emit(music_type)

func _step_game_type_menu(_held_buttons: int, newly_pressed: int) -> void:
	if (newly_pressed & Constants.BUTTON_LEFT) != 0:
		if game_type != Constants.GameType.TYPE_A:
			game_type = Constants.GameType.TYPE_A
			sfx_requested.emit(Constants.SFX_CURSOR)
	elif (newly_pressed & Constants.BUTTON_RIGHT) != 0:
		if game_type != Constants.GameType.TYPE_B:
			game_type = Constants.GameType.TYPE_B
			sfx_requested.emit(Constants.SFX_CURSOR)

	if (newly_pressed & Constants.BUTTON_DOWN) != 0:
		if music_type < Constants.MusicType.OFF:
			music_type += 1
			sfx_requested.emit(Constants.SFX_CURSOR)
			music_changed.emit(music_type)
	elif (newly_pressed & Constants.BUTTON_UP) != 0:
		if music_type > Constants.MusicType.MUSIC_1:
			music_type -= 1
			sfx_requested.emit(Constants.SFX_CURSOR)
			music_changed.emit(music_type)

	if (newly_pressed & Constants.BUTTON_START) != 0:
		sfx_requested.emit(Constants.SFX_MENU_START)
		current_mode = Constants.MenuMode.LEVEL_MENU
		selecting_height = false
		mode_changed.emit(current_mode)
	elif (newly_pressed & Constants.BUTTON_B) != 0:
		sfx_requested.emit(Constants.SFX_MENU_START)
		current_mode = Constants.MenuMode.TITLE_SCREEN
		title_timer = 0
		mode_changed.emit(current_mode)

func _step_level_menu(held_buttons: int, newly_pressed: int) -> void:
	if game_type == Constants.GameType.TYPE_B and (newly_pressed & Constants.BUTTON_A) != 0:
		selecting_height = not selecting_height
		sfx_requested.emit(Constants.SFX_CURSOR)
		return

	if not selecting_height:
		if (newly_pressed & Constants.BUTTON_RIGHT) != 0:
			if selected_level < 9:
				selected_level += 1
				sfx_requested.emit(Constants.SFX_CURSOR)
		elif (newly_pressed & Constants.BUTTON_LEFT) != 0:
			if selected_level > 0:
				selected_level -= 1
				sfx_requested.emit(Constants.SFX_CURSOR)
		elif (newly_pressed & Constants.BUTTON_DOWN) != 0:
			if selected_level < 5:
				selected_level += 5
				sfx_requested.emit(Constants.SFX_CURSOR)
		elif (newly_pressed & Constants.BUTTON_UP) != 0:
			if selected_level >= 5:
				selected_level -= 5
				sfx_requested.emit(Constants.SFX_CURSOR)
	else:
		if (newly_pressed & Constants.BUTTON_RIGHT) != 0:
			if selected_height < 5:
				selected_height += 1
				sfx_requested.emit(Constants.SFX_CURSOR)
		elif (newly_pressed & Constants.BUTTON_LEFT) != 0:
			if selected_height > 0:
				selected_height -= 1
				sfx_requested.emit(Constants.SFX_CURSOR)
		elif (newly_pressed & Constants.BUTTON_DOWN) != 0:
			if selected_height < 3:
				selected_height += 3
				sfx_requested.emit(Constants.SFX_CURSOR)
		elif (newly_pressed & Constants.BUTTON_UP) != 0:
			if selected_height >= 3:
				selected_height -= 3
				sfx_requested.emit(Constants.SFX_CURSOR)

	if (newly_pressed & Constants.BUTTON_START) != 0:
		var effective_level: int = selected_level
		# Authentic NES Tetris A+Start Level 10..19 secret
		if (held_buttons & Constants.BUTTON_A) != 0:
			effective_level += 10

		sfx_requested.emit(Constants.SFX_MENU_START)
		current_mode = Constants.MenuMode.IN_GAME
		mode_changed.emit(current_mode)
		game_started.emit(game_type, effective_level, selected_height, music_type)
	elif (newly_pressed & Constants.BUTTON_B) != 0:
		sfx_requested.emit(Constants.SFX_MENU_START)
		current_mode = Constants.MenuMode.GAME_TYPE_MENU
		mode_changed.emit(current_mode)

## Called when a game finishes to verify high score qualification.
func handle_game_over(g_type: int, final_score: int, final_level: int) -> void:
	entry_game_type = g_type
	entry_score = final_score
	entry_level = final_level
	entry_rank = high_score_mgr.check_qualifies(g_type, final_score)
	if entry_rank >= 0:
		current_mode = Constants.MenuMode.HIGH_SCORE_ENTRY
		entry_char_index = 0
		entry_name_chars = ["A", "A", "A", " ", " ", " "]
		mode_changed.emit(current_mode)
	else:
		current_mode = Constants.MenuMode.HIGH_SCORE_TABLE
		mode_changed.emit(current_mode)

func _step_high_score_entry(held_buttons: int, newly_pressed: int) -> void:
	# 1. Advance / retreat cursor position (Right/A = advance, Left/B = retreat)
	if (newly_pressed & (Constants.BUTTON_RIGHT | Constants.BUTTON_A)) != 0:
		entry_char_index = (entry_char_index + 1) % 6
		sfx_requested.emit(Constants.SFX_CURSOR)
	elif (newly_pressed & (Constants.BUTTON_LEFT | Constants.BUTTON_B)) != 0:
		entry_char_index = (entry_char_index + 5) % 6
		sfx_requested.emit(Constants.SFX_CURSOR)

	# 2. Cycle characters (Up = next char, Down = previous char)
	var curr_char: String = entry_name_chars[entry_char_index]
	var char_pos: int = ENTRY_CHAR_TABLE.find(curr_char)
	if char_pos < 0:
		char_pos = 0

	var changed_char: bool = false
	if (newly_pressed & Constants.BUTTON_UP) != 0:
		char_pos = (char_pos + 1) % ENTRY_CHAR_TABLE.length()
		changed_char = true
	elif (newly_pressed & Constants.BUTTON_DOWN) != 0:
		char_pos = (char_pos + ENTRY_CHAR_TABLE.length() - 1) % ENTRY_CHAR_TABLE.length()
		changed_char = true
	elif (held_buttons & (Constants.BUTTON_UP | Constants.BUTTON_DOWN)) != 0 and (cursor_timer & 0x07) == 0:
		if (held_buttons & Constants.BUTTON_UP) != 0:
			char_pos = (char_pos + 1) % ENTRY_CHAR_TABLE.length()
			changed_char = true
		elif (held_buttons & Constants.BUTTON_DOWN) != 0:
			char_pos = (char_pos + ENTRY_CHAR_TABLE.length() - 1) % ENTRY_CHAR_TABLE.length()
			changed_char = true

	if changed_char:
		entry_name_chars[entry_char_index] = ENTRY_CHAR_TABLE[char_pos]
		sfx_requested.emit(Constants.SFX_CURSOR)

	# 3. Confirm entry with Start
	if (newly_pressed & Constants.BUTTON_START) != 0:
		var full_name: String = "".join(entry_name_chars)
		high_score_mgr.insert_score(entry_game_type, full_name, entry_score, entry_level)
		sfx_requested.emit(Constants.SFX_MENU_START)
		current_mode = Constants.MenuMode.HIGH_SCORE_TABLE
		mode_changed.emit(current_mode)

func _step_high_score_table(_held_buttons: int, newly_pressed: int) -> void:
	# Toggle between A-TYPE and B-TYPE high score tables
	if (newly_pressed & (Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT)) != 0:
		game_type = Constants.GameType.TYPE_B if game_type == Constants.GameType.TYPE_A else Constants.GameType.TYPE_A
		sfx_requested.emit(Constants.SFX_CURSOR)

	# Return to Title Screen on Start or B
	if (newly_pressed & (Constants.BUTTON_START | Constants.BUTTON_B)) != 0:
		sfx_requested.emit(Constants.SFX_MENU_START)
		reset_to_title()
