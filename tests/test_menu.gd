class_name TestMenu
extends RefCounted

## Verification test suite for Phase 2: Menu Flow & Game Modes.
## Covers: Title Screen, Game Type Menu (A/B), Music Track Selection,
## Level Menu (0..9 and 10..19 A+Start cheat), Type B Height Selection,
## Type B starting garbage generation, and Type B 25-line goal condition.

const Constants = preload("res://src/core/constants.gd")
const MenuController = preload("res://src/game/menu_controller.gd")
const BoardGrid = preload("res://src/game/board_grid.gd")
const ScoreManager = preload("res://src/game/score_manager.gd")
const GameStateMachine = preload("res://src/game/game_state_machine.gd")
const CHRExtractor = preload("res://src/importer/chr_extractor.gd")

static func run_tests() -> bool:
	print("--- Running TestMenu (Phase 2) ---")
	test_menu_controller_initialization()
	test_title_screen_start_transition()
	test_game_type_menu_navigation()
	test_level_menu_navigation_type_a()
	test_authentic_a_plus_start_level_10_to_19()
	test_level_menu_type_b_height_selection()
	test_type_b_starting_garbage_generation()
	test_type_b_score_manager_goal_and_bonus()
	test_menu_nametables_extraction_and_textures()
	print("  -> TestMenu: PASSED")
	return true

static func test_menu_controller_initialization() -> void:
	var menu = MenuController.new()
	assert(menu.current_mode == Constants.MenuMode.TITLE_SCREEN, "Must initialize in TITLE_SCREEN")
	assert(menu.game_type == Constants.GameType.TYPE_A, "Default game type must be TYPE_A")
	assert(menu.music_type == Constants.MusicType.MUSIC_1, "Default music must be MUSIC_1")
	assert(menu.selected_level == 0, "Default level must be 0")
	assert(menu.selected_height == 0, "Default height must be 0")
	assert(not menu.selecting_height, "Must not be selecting height initially")

static func test_title_screen_start_transition() -> void:
	var menu = MenuController.new()
	var sfx_heard: Array[int] = [-1]
	menu.sfx_requested.connect(func(s_id: int): sfx_heard[0] = s_id)

	# Simulate pressing Start on Title Screen
	menu.step_frame(0, Constants.BUTTON_START)
	assert(menu.current_mode == Constants.MenuMode.GAME_TYPE_MENU, "Pressing Start must advance to GAME_TYPE_MENU")
	assert(sfx_heard[0] == Constants.SFX_MENU_START, "Pressing Start must play SFX_MENU_START")

static func test_game_type_menu_navigation() -> void:
	var menu = MenuController.new()
	menu.current_mode = Constants.MenuMode.GAME_TYPE_MENU

	# Toggle Game Type: Right -> TYPE_B, Left -> TYPE_A
	menu.step_frame(0, Constants.BUTTON_RIGHT)
	assert(menu.game_type == Constants.GameType.TYPE_B, "Right must select TYPE_B")

	menu.step_frame(0, Constants.BUTTON_LEFT)
	assert(menu.game_type == Constants.GameType.TYPE_A, "Left must select TYPE_A")

	# Music Type: Down -> 1, 2, 3 (OFF), Up -> 2, 1, 0
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.music_type == Constants.MusicType.MUSIC_2, "Down must advance to MUSIC_2")
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.music_type == Constants.MusicType.MUSIC_3, "Down must advance to MUSIC_3")
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.music_type == Constants.MusicType.OFF, "Down must advance to OFF")
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.music_type == Constants.MusicType.OFF, "Down at OFF must clamp to OFF")

	menu.step_frame(0, Constants.BUTTON_UP)
	assert(menu.music_type == Constants.MusicType.MUSIC_3, "Up must return to MUSIC_3")

	# Button B returns to Title Screen
	menu.step_frame(0, Constants.BUTTON_B)
	assert(menu.current_mode == Constants.MenuMode.TITLE_SCREEN, "B must return to TITLE_SCREEN")

	# Back to Type Menu and advance to Level Menu with Start
	menu.step_frame(0, Constants.BUTTON_START)
	assert(menu.current_mode == Constants.MenuMode.GAME_TYPE_MENU)
	menu.step_frame(0, Constants.BUTTON_START)
	assert(menu.current_mode == Constants.MenuMode.LEVEL_MENU, "Start must advance to LEVEL_MENU")

static func test_level_menu_navigation_type_a() -> void:
	var menu = MenuController.new()
	menu.current_mode = Constants.MenuMode.LEVEL_MENU
	assert(menu.selected_level == 0)

	# Right increments level
	menu.step_frame(0, Constants.BUTTON_RIGHT)
	assert(menu.selected_level == 1, "Level must be 1")

	# Down jumps +5 to row 1 (Level 1 + 5 = 6)
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.selected_level == 6, "Down must jump +5 to Level 6")

	# Up jumps -5 back to row 0 (Level 6 - 5 = 1)
	menu.step_frame(0, Constants.BUTTON_UP)
	assert(menu.selected_level == 1, "Up must jump -5 to Level 1")

	# Test bounds: Left at 0 clamps to 0; Right at 9 clamps to 9
	menu.step_frame(0, Constants.BUTTON_LEFT)
	assert(menu.selected_level == 0)
	menu.step_frame(0, Constants.BUTTON_LEFT)
	assert(menu.selected_level == 0, "Left at 0 must clamp to 0")

	# Start game
	var game_started_data: Dictionary = {}
	menu.game_started.connect(func(gt: int, lvl: int, h: int, m: int):
		game_started_data["type"] = gt
		game_started_data["level"] = lvl
		game_started_data["height"] = h
		game_started_data["music"] = m
	)

	menu.step_frame(0, Constants.BUTTON_START)
	assert(menu.current_mode == Constants.MenuMode.IN_GAME, "Start must enter IN_GAME mode")
	assert(game_started_data["type"] == Constants.GameType.TYPE_A)
	assert(game_started_data["level"] == 0)

static func test_authentic_a_plus_start_level_10_to_19() -> void:
	var menu = MenuController.new()
	menu.current_mode = Constants.MenuMode.LEVEL_MENU
	menu.selected_level = 9 # Cursor on 9

	var launched_level: Array[int] = [-1]
	menu.game_started.connect(func(_gt: int, lvl: int, _h: int, _m: int):
		launched_level[0] = lvl
	)

	# Hold Button A while pressing Start
	var held: int = Constants.BUTTON_A
	var pressed: int = Constants.BUTTON_START
	menu.step_frame(held, pressed)

	assert(launched_level[0] == 19, "Holding Button A + Start on Level 9 must launch Level 19! Got: %d" % launched_level[0])

	# Also test Level 0 with A+Start -> Level 10
	var menu2 = MenuController.new()
	menu2.current_mode = Constants.MenuMode.LEVEL_MENU
	menu2.selected_level = 0
	var launched_level2: Array[int] = [-1]
	menu2.game_started.connect(func(_gt: int, lvl: int, _h: int, _m: int):
		launched_level2[0] = lvl
	)
	menu2.step_frame(Constants.BUTTON_A, Constants.BUTTON_START)
	assert(launched_level2[0] == 10, "Holding Button A + Start on Level 0 must launch Level 10! Got: %d" % launched_level2[0])

static func test_level_menu_type_b_height_selection() -> void:
	var menu = MenuController.new()
	menu.current_mode = Constants.MenuMode.LEVEL_MENU
	menu.game_type = Constants.GameType.TYPE_B
	assert(not menu.selecting_height)

	# Press Button A to toggle into Height selection
	menu.step_frame(0, Constants.BUTTON_A)
	assert(menu.selecting_height == true, "Button A must toggle into Height selection")

	# Right increments height 0..5
	menu.step_frame(0, Constants.BUTTON_RIGHT)
	assert(menu.selected_height == 1, "Height must be 1")

	# Down jumps +3 to bottom row (1 + 3 = 4)
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.selected_height == 4, "Down must jump +3 to Height 4")

	# Toggle back to level selection
	menu.step_frame(0, Constants.BUTTON_A)
	assert(menu.selecting_height == false, "Button A must toggle back to Level selection")

	var started_data: Dictionary = {}
	menu.game_started.connect(func(gt: int, lvl: int, h: int, m: int):
		started_data["type"] = gt
		started_data["level"] = lvl
		started_data["height"] = h
		started_data["music"] = m
	)
	menu.step_frame(0, Constants.BUTTON_START)
	assert(started_data["type"] == Constants.GameType.TYPE_B)
	assert(started_data["height"] == 4, "Launched game must receive Height 4")

static func test_type_b_starting_garbage_generation() -> void:
	var grid = BoardGrid.new()

	# Height 0: 0 rows
	grid.setup_type_b_garbage(0, 1234)
	for r in range(Constants.GRID_ROWS):
		for c in range(Constants.GRID_COLUMNS):
			assert(grid.get_cell(c, r) == Constants.TileType.EMPTY, "Height 0 must have empty grid")

	# Height 1: 3 rows (Rows 19, 20, 21)
	grid.setup_type_b_garbage(1, 1234)
	for r in range(0, 19):
		for c in range(Constants.GRID_COLUMNS):
			assert(grid.get_cell(c, r) == Constants.TileType.EMPTY, "Rows 0..18 must be empty for Height 1")

	# Check rows 19..21: each must have at least one empty hole (typeBGuaranteeBlank)
	for r in range(19, 22):
		var has_hole: bool = false
		for c in range(Constants.GRID_COLUMNS):
			if grid.get_cell(c, r) == Constants.TileType.EMPTY:
				has_hole = true
		assert(has_hole, "Row %d must guarantee at least one blank hole" % r)

	# Height 5: 12 rows (Rows 10..21)
	grid.setup_type_b_garbage(5, 5678)
	for r in range(0, 10):
		for c in range(Constants.GRID_COLUMNS):
			assert(grid.get_cell(c, r) == Constants.TileType.EMPTY, "Rows 0..9 must be empty for Height 5")

	for r in range(10, 22):
		var has_hole: bool = false
		for c in range(Constants.GRID_COLUMNS):
			if grid.get_cell(c, r) == Constants.TileType.EMPTY:
				has_hole = true
		assert(has_hole, "Row %d must guarantee at least one blank hole" % r)

static func test_type_b_score_manager_goal_and_bonus() -> void:
	var sm = ScoreManager.new()
	sm.init_game(5, Constants.GameType.TYPE_B, 3) # Level 5, Type B, Height 3

	assert(sm.game_type == Constants.GameType.TYPE_B)
	assert(sm.lines == 25, "Type B lines must initialize to 25")
	assert(sm.lines_remaining == 25, "Type B lines_remaining must initialize to 25")
	assert(not sm.is_goal_reached, "is_goal_reached must start false")

	# Clear a Double (2 lines)
	var res1: Dictionary = sm.add_line_clears(2)
	assert(sm.lines_remaining == 23, "Lines remaining must decrease to 23")
	assert(sm.lines == 23, "Lines display must sync to 23")
	assert(res1["points_added"] == Constants.get_line_clear_score(2, 5))
	assert(not sm.is_goal_reached)

	# Clear a Tetris (4 lines)
	sm.add_line_clears(4)
	assert(sm.lines_remaining == 19)

	# Clear remaining 19 lines: 4 Tetrises (16 lines) + 1 Triple (3 lines) = 19 lines
	sm.add_line_clears(4) # 15
	sm.add_line_clears(4) # 11
	sm.add_line_clears(4) # 7
	sm.add_line_clears(4) # 3
	var res_final: Dictionary = sm.add_line_clears(3) # 0 -> Goal achieved!

	assert(sm.lines_remaining == 0, "Lines remaining must reach 0")
	assert(sm.is_goal_reached == true, "is_goal_reached must be true upon clearing 25 lines")
	# Victory bonus formula: (Level + 1) * 1000 + Height * 1000 = (5 + 1)*1000 + 3*1000 = 9000
	var expected_bonus: int = (5 + 1) * 1000 + 3 * 1000
	var expected_triple_score: int = Constants.get_line_clear_score(3, 5)
	assert(res_final["points_added"] == expected_triple_score + expected_bonus, "Final points must include Type B completion bonus")

static func test_menu_nametables_extraction_and_textures() -> void:
	var rom_path: String = "Tetris (USA).nes"
	if not FileAccess.file_exists(rom_path):
		return

	var res: Dictionary = CHRExtractor.extract_from_file(rom_path, true)
	assert(res.success == true, "ROM extraction must succeed")

	# Nametables must all be authentic 1024-byte PPU nametables
	assert(res.has("title_nametable") and res.title_nametable.size() == 1024, "Title nametable must be 1024 bytes")
	assert(res.has("game_type_nametable") and res.game_type_nametable.size() == 1024, "Game type nametable must be 1024 bytes")
	assert(res.has("level_menu_nametable_b") and res.level_menu_nametable_b.size() == 1024, "Level menu B nametable must be 1024 bytes")
	assert(res.has("level_menu_nametable_a") and res.level_menu_nametable_a.size() == 1024, "Level menu A nametable must be 1024 bytes")

	# Rendered textures must be 256x240 ImageTextures
	assert(res.title_screen_texture is ImageTexture and res.title_screen_texture.get_size() == Vector2(256, 240), "Title screen texture must be 256x240")
	assert(res.game_type_menu_texture is ImageTexture and res.game_type_menu_texture.get_size() == Vector2(256, 240), "Game type menu texture must be 256x240")
	assert(res.level_menu_a_texture is ImageTexture and res.level_menu_a_texture.get_size() == Vector2(256, 240), "Level menu A texture must be 256x240")
	assert(res.level_menu_b_texture is ImageTexture and res.level_menu_b_texture.get_size() == Vector2(256, 240), "Level menu B texture must be 256x240")
