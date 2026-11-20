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
	print("  -> TestRenderer: PASSED")
	return true

static func test_coordinate_mapping() -> void:
	# Visible origin (col 0, row 2) -> (96, 40)
	var screen_origin: Vector2 = PlayfieldRenderer.grid_to_screen(Vector2i(0, 2))
	assert(screen_origin == Vector2(96.0, 40.0), "Grid (0, 2) must map to screen (96, 40)")

	# Bottom-right visible cell (col 9, row 21) -> (96 + 9*8, 40 + 19*8) = (168, 192)
	var screen_br: Vector2 = PlayfieldRenderer.grid_to_screen(Vector2i(9, 21))
	assert(screen_br == Vector2(168.0, 192.0), "Grid (9, 21) must map to screen (168, 192)")

	# Center cell (col 5, row 10) -> (96 + 5*8, 40 + 8*8) = (136, 104)
	var screen_center: Vector2 = PlayfieldRenderer.grid_to_screen(Vector2i(5, 10))
	assert(screen_center == Vector2(136.0, 104.0), "Grid (5, 10) must map to screen (136, 104)")

static func test_preview_anchor_calculation() -> void:
	# Preview origin is (192, 112)
	var anchor_t: Vector2 = PlayfieldRenderer.get_preview_anchor(Constants.PieceType.T)
	assert(anchor_t == Vector2(208.0, 124.0), "T piece preview anchor must be (208, 124)")

	var anchor_o: Vector2 = PlayfieldRenderer.get_preview_anchor(Constants.PieceType.O)
	assert(anchor_o == Vector2(212.0, 124.0), "O piece preview anchor must be (212, 124)")

	var anchor_i: Vector2 = PlayfieldRenderer.get_preview_anchor(Constants.PieceType.I)
	assert(anchor_i == Vector2(212.0, 128.0), "I piece preview anchor must be (212, 128)")

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
	assert(renderer.top_score == 1200, "Top score must track to 1200")

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
