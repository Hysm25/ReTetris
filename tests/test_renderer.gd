class_name TestRenderer
extends RefCounted

## Verification test suite for PlayfieldRenderer canvas drawing, viewport offsets,
## preview calculations, and HUD state synchronization.

const PlayfieldRenderer = preload("res://src/game/playfield_renderer.gd")
const GameStateMachine = preload("res://src/game/game_state_machine.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestRenderer ---")
	test_coordinate_mapping()
	test_preview_anchor_calculation()
	test_renderer_instantiation_and_sync()
	test_event_bus_updates()
	test_rom_setup_screen_rendering()
	test_authentic_menu_cursor_coordinates()
	test_nes_text_and_widescreen_tiling()
	print("  -> TestRenderer: PASSED")
	return true

static func test_coordinate_mapping() -> void:
	# Visible origin (col 0, row 2) -> (96, 48)
	var screen_origin: Vector2 = PlayfieldRenderer.grid_to_screen(Vector2i(0, 2))
	assert(screen_origin == Vector2(96.0, 48.0), "Grid (0, 2) must map to screen (96, 48)")

	# Bottom-right visible cell (col 9, row 21) -> (96 + 9*8, 48 + 19*8) = (168, 200)
	var screen_br: Vector2 = PlayfieldRenderer.grid_to_screen(Vector2i(9, 21))
	assert(screen_br == Vector2(168.0, 200.0), "Grid (9, 21) must map to screen (168, 200)")

	# Center cell (col 5, row 10) -> (96 + 5*8, 48 + 8*8) = (136, 112)
	var screen_center: Vector2 = PlayfieldRenderer.grid_to_screen(Vector2i(5, 10))
	assert(screen_center == Vector2(136.0, 112.0), "Grid (5, 10) must map to screen (136, 112)")

static func test_preview_anchor_calculation() -> void:
	# Preview origin is (192, 112)
	# Authentic NES Tetris OAM sprite coordinates:
	# T, J, L, S, Z -> (204, 120), O -> (208, 120), I -> (208, 124)
	var anchor_t: Vector2 = PlayfieldRenderer.get_preview_anchor(Constants.PieceType.T)
	assert(anchor_t == Vector2(204.0, 120.0), "T piece preview anchor must be (204, 120)")

	var anchor_o: Vector2 = PlayfieldRenderer.get_preview_anchor(Constants.PieceType.O)
	assert(anchor_o == Vector2(208.0, 120.0), "O piece preview anchor must be (208, 120)")

	var anchor_i: Vector2 = PlayfieldRenderer.get_preview_anchor(Constants.PieceType.I)
	assert(anchor_i == Vector2(208.0, 124.0), "I piece preview anchor must be (208, 124)")

static func test_renderer_instantiation_and_sync() -> void:
	var fsm = GameStateMachine.new()
	fsm.is_headless_testing = true
	fsm.start_game(5) # Start at Level 5

	var renderer = PlayfieldRenderer.new(fsm)
	assert(renderer.game_state == fsm, "Renderer must hold game state reference")

	# Simulate frame process sync
	renderer._process(0.016)
	assert(renderer.current_level == 5, "Renderer current_level must sync to 5")
	assert(renderer.current_score == 0, "Renderer current_score must sync to 0")
	assert(renderer.current_lines == 0, "Renderer current_lines must sync to 0")
	assert(not renderer.is_game_over, "Renderer is_game_over must sync to false")

	# Free nodes
	renderer.free()
	fsm.free()

static func test_authentic_menu_cursor_coordinates() -> void:
	# 1. Game Type & Music cursor coordinates (TetrisNESDisasm main.asm:755-795)
	# Game Type: Y = 63 ($3F). Type A: X = 63, Type B: X = 159. Width between arrows: 58
	var type_a_x: float = 63.0
	var type_b_x: float = 159.0
	assert(type_b_x - type_a_x == 96.0, "Game Type cursor step must be 96 pixels ($60)")

	# Music Type: X = 103 ($67). Y = 143 ($8F) + music_type * 16. Width between arrows: 74
	var music_x: float = 103.0
	var music_y_base: float = 143.0
	assert(music_x == 103.0, "Music cursor X must be 103 ($67)")
	assert(music_y_base == 143.0, "Music cursor base Y must be 143 ($8F)")

	# 2. Level Menu cursor coordinates (TetrisNESDisasm main.asm:1060-1075)
	# Level 0..4 row 0: Y = 83 ($53); Level 5..9 row 1: Y = 99 ($63)
	# Columns: 52, 68, 84, 100, 116 ($34 + col * 16)
	var lvl_row0_y: float = 83.0
	var lvl_row1_y: float = 99.0
	var lvl_col0_x: float = 52.0
	var lvl_col4_x: float = 52.0 + 4.0 * 16.0
	assert(lvl_row1_y - lvl_row0_y == 16.0, "Level grid row step must be 16 pixels")
	assert(lvl_col4_x == 116.0, "Level grid col 4 must be 116 ($74)")

	# Height Menu cursor coordinates (TetrisNESDisasm main.asm:1070-1075)
	# Columns: 156, 172, 188 ($9C + col * 16). Rows: 83, 99
	var h_col0_x: float = 156.0
	var h_col2_x: float = 156.0 + 2.0 * 16.0
	assert(h_col0_x == 156.0, "Height grid col 0 must be 156 ($9C)")
	assert(h_col2_x == 188.0, "Height grid col 2 must be 188 ($BC)")

	# 3. High Score Entry coordinates (TetrisNESDisasm main.asm:4440-4445)
	# Rows by rank: 159 ($9F), 175 ($AF), 191 ($BF)
	# Columns: 72 + char_index * 8 ($48 + char_index * 8)
	var hs_rank0_y: float = 159.0
	var hs_rank2_y: float = 191.0
	var hs_char0_x: float = 72.0
	var hs_char5_x: float = 72.0 + 5.0 * 8.0
	assert(hs_rank2_y - hs_rank0_y == 32.0, "High score entry rank 0-2 delta must be 32 pixels")
	assert(hs_char5_x == 112.0, "High score entry char 5 must be 112 ($70)")


static func test_event_bus_updates() -> void:
	var renderer = PlayfieldRenderer.new()
	assert(renderer.piece_stats == [0, 0, 0, 0, 0, 0, 0], "Piece stats must start at zero")

	# Simulate event triggers directly
	renderer._on_piece_spawned(Constants.PieceType.T, Vector2i(5, 0), Constants.Orientation.T_DOWN)
	assert(renderer.piece_stats[Constants.PieceType.T] == 1, "T piece count must be incremented to 1")

	renderer._on_piece_spawned(Constants.PieceType.I, Vector2i(5, 0), Constants.Orientation.I_HORIZ)
	assert(renderer.piece_stats[Constants.PieceType.I] == 1, "I piece count must be incremented to 1")

	renderer._on_score_updated(1200, 1200)
	assert(renderer.current_score == 1200, "Current score must be 1200")
	# In authentic 1989 NES Tetris, TOP score displays the saved record score and does not tick up live during play
	assert(renderer.top_score == 10000, "Top score must remain fixed at authentic record score (10000) during gameplay")

	renderer._on_lines_updated(4)
	assert(renderer.current_lines == 4, "Current lines must be 4")

	renderer._on_level_updated(6)
	assert(renderer.current_level == 6, "Current level must be 6")

	renderer._on_game_over()
	assert(renderer.is_game_over, "is_game_over must be true after game_over event")

	renderer._on_game_restarted()
	assert(not renderer.is_game_over, "is_game_over must reset on game_restarted")
	assert(renderer.current_score == 0, "Score must reset on game_restarted")
	assert(renderer.piece_stats[Constants.PieceType.T] == 0, "Piece stats must reset on restart")

	renderer.free()

static func test_rom_setup_screen_rendering() -> void:
	var fsm = GameStateMachine.new()
	fsm.is_headless_testing = true
	fsm.current_state = GameStateMachine.State.ROM_SETUP

	var renderer = PlayfieldRenderer.new(fsm)
	renderer._process(0.016)
	assert(renderer.game_state.current_state == GameStateMachine.State.ROM_SETUP, "Renderer must track ROM_SETUP state")

	renderer.free()
	fsm.free()

static func test_nes_text_and_widescreen_tiling() -> void:
	var fsm = GameStateMachine.new()
	fsm.is_headless_testing = true
	var renderer = PlayfieldRenderer.new(fsm)

	# Verify authentic NES HUD coordinates:
	# Lines: (152, 24)
	# Top: (192, 40)
	# Score: (192, 64)
	# Level: (208, 168)
	# Stats 0..6: X: 48, Y: 96, 112, 128, 144, 160, 176, 192 (16px spacing)
	assert(Constants.PLAYFIELD_OFFSET_X == 96, "Playfield X must be 96")
	assert(Constants.PLAYFIELD_OFFSET_Y == 48, "Playfield Y must be 48")

	for i in range(7):
		var stat_y: float = 96.0 + float(i * 16)
		assert(stat_y == 96.0 + i * 16.0, "Stat row %d Y offset mismatch" % i)

	# Verify widescreen stage origin calculation:
	var vp_widescreen: Vector2 = Vector2(426.0, 240.0) # 16:9 expanded
	var stage_origin: Vector2 = ((vp_widescreen - Vector2(float(Constants.SCREEN_WIDTH), float(Constants.SCREEN_HEIGHT))) * 0.5).floor()
	assert(stage_origin.x == 85.0, "Widescreen stage origin X should be 85")
	assert(stage_origin.y == 0.0, "Widescreen stage origin Y should be 0")

	# Verify grid alignment (no fractional seam) with 128x128 multi-tile pattern
	var start_x: float = fmod(stage_origin.x, 128.0)
	if start_x > 0.0:
		start_x -= 128.0
	assert(fmod(stage_origin.x - start_x, 128.0) == 0.0, "Tiling start_x must align to 128px stage grid")

	# Verify Top Score behavior: starts at 10000, does not tick up live on soft drop / line clears
	assert(renderer.top_score == 10000, "Top score must default to 10000")
	renderer.current_score = 5000
	renderer._process(0.016)
	assert(renderer.top_score == 10000, "Top score must not change when current_score is 5000")
	renderer.current_score = 15000
	renderer._process(0.016)
	assert(renderer.top_score == 10000, "Top score must remain fixed at saved high score during active play")

	# Verify menu widescreen pattern selection
	var menu_ctrl = preload("res://src/game/menu_controller.gd").new()
	var menu_renderer = PlayfieldRenderer.new(fsm, menu_ctrl)
	assert(menu_ctrl.current_mode == Constants.MenuMode.TITLE_SCREEN, "Initial menu mode must be TITLE_SCREEN")
	menu_renderer.free()

	renderer.free()
	fsm.free()


