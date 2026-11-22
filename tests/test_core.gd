# tests/test_core.gd
class_name TestCore
extends RefCounted

## Verification test suite for Milestone 1: Core Autoloads & Enums.

const Constants = preload("res://src/core/constants.gd")
const ContentRegistryScript = preload("res://src/core/content_registry.gd")
const EventBusScript = preload("res://src/core/event_bus.gd")

static func run_all_tests() -> bool:
	print("==================================================")
	print("  Running Milestone 1 Core Verification Tests")
	print("==================================================")

	test_constants_dimensions_and_timing()
	test_constants_rotations()
	test_constants_gravity_and_scoring()
	test_constants_level_transitions()
	test_constants_are_timing()
	test_constants_palettes()
	test_event_bus_signals()
	test_content_registry_matrices_and_offsets()
	test_content_registry_mandatory_rom_ingestion()
	test_content_registry_tile_atlas_and_tables()

	print("==================================================")
	print("  ALL MILESTONE 1 TESTS PASSED SUCCESSFULLY! (10/10)")
	print("==================================================")
	return true

static func test_constants_dimensions_and_timing() -> void:
	print("[1/10] Testing Constants Dimensions and Timings...")
	assert(Constants.SCREEN_WIDTH == 256, "Native width must be 256")
	assert(Constants.SCREEN_HEIGHT == 240, "Native height must be 240")
	assert(Constants.GRID_COLUMNS == 10, "Playfield columns must be 10")
	assert(Constants.GRID_ROWS == 22, "Logical grid rows must be 22")
	assert(Constants.VISIBLE_ROWS == 20, "Visible rows must be 20")
	assert(Constants.HIDDEN_ROWS == 2, "Hidden spawn rows must be 2")
	assert(Constants.TILE_SIZE == 8, "Tile size must be 8x8")
	assert(Constants.SPAWN_X == 5 and Constants.SPAWN_Y == 0, "Spawn coordinates must be (5, 0)")
	assert(Constants.DAS_INITIAL_DELAY == 16, "DAS initial delay must be 16 frames")
	assert(Constants.DAS_REPEAT_INTERVAL == 6, "DAS auto-repeat interval must be 6 frames")
	assert(Constants.DAS_RELOAD_VALUE == 10, "DAS reload value must be 10 frames")
	assert(Constants.ARE_LINE_CLEAR_TOTAL_FRAMES == 20, "Line clear animation must be 20 frames")
	print("  -> PASSED")

static func test_constants_rotations() -> void:
	print("[2/10] Testing Nintendo Rotation System (NRS) Transitions...")
	# Verify T piece CW: T_UP -> T_RIGHT -> T_DOWN -> T_LEFT -> T_UP
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_UP, true) == Constants.Orientation.T_RIGHT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_RIGHT, true) == Constants.Orientation.T_DOWN)
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_DOWN, true) == Constants.Orientation.T_LEFT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_LEFT, true) == Constants.Orientation.T_UP)

	# Verify T piece CCW: T_UP -> T_LEFT -> T_DOWN -> T_RIGHT -> T_UP
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_UP, false) == Constants.Orientation.T_LEFT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_LEFT, false) == Constants.Orientation.T_DOWN)
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_DOWN, false) == Constants.Orientation.T_RIGHT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.T_RIGHT, false) == Constants.Orientation.T_UP)

	# Verify 2-state toggle pieces (I, S, Z)
	assert(Constants.get_rotated_orientation(Constants.Orientation.I_HORIZ, true) == Constants.Orientation.I_VERT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.I_VERT, true) == Constants.Orientation.I_HORIZ)
	assert(Constants.get_rotated_orientation(Constants.Orientation.S_HORIZ, true) == Constants.Orientation.S_VERT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.S_VERT, true) == Constants.Orientation.S_HORIZ)
	assert(Constants.get_rotated_orientation(Constants.Orientation.Z_HORIZ, true) == Constants.Orientation.Z_VERT)
	assert(Constants.get_rotated_orientation(Constants.Orientation.Z_VERT, true) == Constants.Orientation.Z_HORIZ)

	# Verify 1-state invariant piece (O)
	assert(Constants.get_rotated_orientation(Constants.Orientation.O_FIXED, true) == Constants.Orientation.O_FIXED)
	assert(Constants.get_rotated_orientation(Constants.Orientation.O_FIXED, false) == Constants.Orientation.O_FIXED)
	print("  -> PASSED")

static func test_constants_gravity_and_scoring() -> void:
	print("[3/10] Testing Gravity and Scoring Formulas...")
	# Gravity lookup table checks
	assert(Constants.get_gravity_frames(0) == 48, "Level 0 must be 48 frames")
	assert(Constants.get_gravity_frames(1) == 43, "Level 1 must be 43 frames")
	assert(Constants.get_gravity_frames(8) == 8, "Level 8 must be 8 frames")
	assert(Constants.get_gravity_frames(9) == 6, "Level 9 must be 6 frames")
	assert(Constants.get_gravity_frames(18) == 3, "Level 18 must be 3 frames")
	assert(Constants.get_gravity_frames(19) == 2, "Level 19 must be 2 frames")
	assert(Constants.get_gravity_frames(28) == 2, "Level 28 must be 2 frames")
	assert(Constants.get_gravity_frames(29) == 1, "Level 29 must be 1 frame")
	assert(Constants.get_gravity_frames(35) == 1, "Level 35+ must clamp to 1 frame")
	assert(Constants.get_gravity_frames(-5) == 48, "Negative level must clamp to 48 frames")

	# BPS scoring formula checks: (40, 100, 300, 1200) * (level + 1)
	assert(Constants.get_line_clear_score(1, 0) == 40, "Level 0 Single = 40")
	assert(Constants.get_line_clear_score(2, 0) == 100, "Level 0 Double = 100")
	assert(Constants.get_line_clear_score(3, 0) == 300, "Level 0 Triple = 300")
	assert(Constants.get_line_clear_score(4, 0) == 1200, "Level 0 Tetris = 1200")

	assert(Constants.get_line_clear_score(1, 9) == 400, "Level 9 Single = 400")
	assert(Constants.get_line_clear_score(2, 9) == 1000, "Level 9 Double = 1000")
	assert(Constants.get_line_clear_score(3, 9) == 3000, "Level 9 Triple = 3000")
	assert(Constants.get_line_clear_score(4, 9) == 12000, "Level 9 Tetris = 12000")

	assert(Constants.get_line_clear_score(4, 18) == 22800, "Level 18 Tetris = 22800")
	assert(Constants.get_line_clear_score(0, 0) == 0, "0 lines = 0 points")
	print("  -> PASSED")

static func test_constants_level_transitions() -> void:
	print("[4/10] Testing Starting Level Transition Formulas...")
	# Threshold_0 = min(S * 10 + 10, max(100, S * 10 - 50))
	assert(Constants.get_first_level_transition_lines(0) == 10, "Start Level 0 transitions at 10 lines")
	assert(Constants.get_first_level_transition_lines(1) == 20, "Start Level 1 transitions at 20 lines")
	assert(Constants.get_first_level_transition_lines(5) == 60, "Start Level 5 transitions at 60 lines")
	assert(Constants.get_first_level_transition_lines(9) == 100, "Start Level 9 transitions at 100 lines")
	assert(Constants.get_first_level_transition_lines(10) == 100, "Start Level 10 transitions at 100 lines")
	assert(Constants.get_first_level_transition_lines(15) == 100, "Start Level 15 transitions at 100 lines")
	assert(Constants.get_first_level_transition_lines(18) == 130, "Start Level 18 transitions at 130 lines")
	assert(Constants.get_first_level_transition_lines(19) == 140, "Start Level 19 transitions at 140 lines")
	print("  -> PASSED")

static func test_constants_are_timing() -> void:
	print("[5/10] Testing ARE (Entry Delay) Formulas...")
	# Base ARE formula: 10 + 2 * ((21 - Y_lock) / 4)
	assert(Constants.get_base_are(21) == 10, "Row 21 lock ARE = 10 frames")
	assert(Constants.get_base_are(20) == 10, "Row 20 lock ARE = 10 frames")
	assert(Constants.get_base_are(18) == 10, "Row 18 lock ARE = 10 frames")
	assert(Constants.get_base_are(17) == 12, "Row 17 lock ARE = 12 frames")
	assert(Constants.get_base_are(13) == 14, "Row 13 lock ARE = 14 frames")
	assert(Constants.get_base_are(9) == 16, "Row 9 lock ARE = 16 frames")
	assert(Constants.get_base_are(5) == 18, "Row 5 lock ARE = 18 frames")
	assert(Constants.get_base_are(2) == 18, "Row 2 lock ARE = 18 frames")
	print("  -> PASSED")

static func test_constants_palettes() -> void:
	print("[6/10] Testing NES Palettes and Color Tables...")
	assert(Constants.NES_MASTER_PALETTE.size() == 64, "NES master palette must contain 64 colors")
	assert(Constants.LEVEL_PALETTES.size() == 10, "Level palettes must contain 10 schemes (0-9)")
	assert(Constants.LEVEL_COLOR_INDICES.size() == 10, "Level color indices must contain 10 entries")

	# Verify Level 0 palette mapping
	var p0: Array[Color] = Constants.get_level_palette(0)
	assert(p0.size() == 3, "Palette must contain 3 colors")
	assert(p0[0] == Color("#0058F8"), "Level 0 primary must be Blue")
	assert(p0[1] == Color("#3CBCFC"), "Level 0 secondary must be Light Blue")
	assert(p0[2] == Color("#FCFCFC"), "Level 0 tertiary must be White")

	# Verify Level 9 palette mapping
	var p9: Array[Color] = Constants.get_level_palette(9)
	assert(p9[0] == Color("#F83800"), "Level 9 primary must be Orange")
	assert(p9[1] == Color("#FFA044"), "Level 9 secondary must be Light Orange")

	# Verify cycling (Level 10 == Level 0)
	var p10: Array[Color] = Constants.get_level_palette(10)
	assert(p10[0] == p0[0] and p10[1] == p0[1], "Level 10 palette must match Level 0")
	print("  -> PASSED")

static func test_event_bus_signals() -> void:
	print("[7/10] Testing EventBus Signal Dispatching...")
	var bus = EventBusScript.new()
	var signal_received: Dictionary = {
		"spawned": false,
		"moved": false,
		"shifted": false,
		"rotated": false,
		"locked": false,
		"clearing": false,
		"cleared": false,
		"score": false,
		"lines": false,
		"level": false,
		"game_over": false,
		"restarted": false,
	}

	bus.piece_spawned.connect(func(_p: int, _pos: Vector2i, _o: int) -> void: signal_received["spawned"] = true)
	bus.piece_moved.connect(func(_p: int, _pos: Vector2i, _o: int) -> void: signal_received["moved"] = true)
	bus.piece_shifted.connect(func(_p: int, _pos: Vector2i, _o: int) -> void: signal_received["shifted"] = true)
	bus.piece_rotated.connect(func(_p: int, _pos: Vector2i, _o: int) -> void: signal_received["rotated"] = true)
	bus.piece_locked.connect(func(_p: int, _pos: Vector2i, _o: int) -> void: signal_received["locked"] = true)
	bus.lines_clearing.connect(func(_r: Array[int], _s: int) -> void: signal_received["clearing"] = true)
	bus.lines_cleared.connect(func(_c: int, _r: Array[int]) -> void: signal_received["cleared"] = true)
	bus.score_updated.connect(func(_s: int, _a: int) -> void: signal_received["score"] = true)
	bus.lines_updated.connect(func(_l: int) -> void: signal_received["lines"] = true)
	bus.level_updated.connect(func(_lvl: int) -> void: signal_received["level"] = true)
	bus.game_over.connect(func() -> void: signal_received["game_over"] = true)
	bus.game_restarted.connect(func() -> void: signal_received["restarted"] = true)

	bus.emit_piece_spawned(0, Vector2i(5, 0), 2)
	bus.emit_piece_moved(0, Vector2i(6, 0), 2)
	bus.emit_piece_shifted(0, Vector2i(6, 0), 2)
	bus.emit_piece_rotated(0, Vector2i(6, 0), 1)
	bus.emit_piece_locked(0, Vector2i(6, 20), 1)
	bus.emit_lines_clearing([20], 0)
	bus.emit_lines_cleared(1, [20])
	bus.emit_score_updated(40, 40)
	bus.emit_lines_updated(1)
	bus.emit_level_updated(1)
	bus.emit_game_over()
	bus.emit_game_restarted()

	for k in signal_received.keys():
		assert(signal_received[k] == true, "Signal '%s' was not dispatched" % k)
	bus.free()
	print("  -> PASSED")

static func test_content_registry_matrices_and_offsets() -> void:
	print("[8/10] Testing ContentRegistry 4x4 Matrices and Mino Offsets...")
	var reg = ContentRegistryScript.new()
	assert(reg.matrices_4x4.size() == Constants.ORIENTATION_COUNT, "Must build 20 4x4 matrices")

	# Check each non-hidden orientation has exactly 4 active minos in its 4x4 matrix
	for o_idx in range(Constants.ORIENTATION_COUNT - 1):
		var mat: Array[Array] = reg.get_matrix_4x4(o_idx)
		assert(mat.size() == 4, "Matrix must have 4 rows")
		var mino_count: int = 0
		var expected_tile_type: int = Constants.TILE_TYPE_FROM_PIECE[Constants.PIECE_TYPE_FROM_ORIENTATION[o_idx]]

		for r in range(4):
			assert(mat[r].size() == 4, "Row must have 4 columns")
			for c in range(4):
				if mat[r][c] != 0:
					assert(mat[r][c] == expected_tile_type, "Mino tile type mismatch in matrix")
					mino_count += 1
		assert(mino_count == 4, "Orientation %d matrix must have exactly 4 minos, got %d" % [o_idx, mino_count])

		# Check relative offsets
		var offsets: Array[Vector2i] = reg.get_mino_offsets(o_idx)
		assert(offsets.size() == 4, "Offsets array must have 4 elements")

	reg.free()
	print("  -> PASSED")

static func test_content_registry_mandatory_rom_ingestion() -> void:
	print("[9/10] Testing ContentRegistry Mandatory ROM Ingestion...")
	var reg = ContentRegistryScript.new()
	assert(not reg.is_ready(), "ContentRegistry must start uninitialized (zero procedural fallbacks)")

	# Verify uninitialized access returns empty tile texture
	var tex_empty: ImageTexture = reg.get_tile_texture(Constants.TileType.PRIMARY, 0)
	assert(tex_empty != null, "Empty tile texture should be returned when uninitialized")

	# Mock extracted ROM data
	var mock_img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	mock_img.fill(Color("#0058F8"))
	var mock_tex: ImageTexture = ImageTexture.create_from_image(mock_img)

	var mock_data: Dictionary = {
		"success": true,
		"gravity_table": [48, 43, 38, 33, 28, 23, 18, 13, 8, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
		"points_table": [0, 40, 100, 300, 1200],
		"color_table": [[0x0F, 0x30, 0x21, 0x12]],
		"spawn_orientations": [Constants.Orientation.T_DOWN, Constants.Orientation.J_DOWN, Constants.Orientation.Z_HORIZ, Constants.Orientation.O_FIXED, Constants.Orientation.S_HORIZ, Constants.Orientation.L_DOWN, Constants.Orientation.I_HORIZ],
		"level_textures": [{
			"tile_1": mock_tex,
			"tile_2": mock_tex,
			"tile_3": mock_tex,
		}]
	}

	var ok: bool = reg.ingest_rom_data(mock_data)
	assert(ok, "Ingest ROM data must succeed")
	assert(reg.is_ready(), "ContentRegistry must be ready after ROM ingestion")

	var tex_pri: ImageTexture = reg.get_tile_texture(Constants.TileType.PRIMARY, 0)
	assert(tex_pri == mock_tex, "Tile texture must match ingested ROM texture")

	reg.free()
	print("  -> PASSED")

static func test_content_registry_tile_atlas_and_tables() -> void:
	print("[10/10] Testing Ingested Tile Atlas and ROM Tables...")
	var reg = ContentRegistryScript.new()

	var mock_img: Image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	mock_img.fill(Color("#00A800"))
	var mock_tex: ImageTexture = ImageTexture.create_from_image(mock_img)

	var mock_data: Dictionary = {
		"success": true,
		"gravity_table": [48, 43, 38, 33, 28, 23, 18, 13, 8, 6, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
		"points_table": [0, 40, 100, 300, 1200],
		"color_table": [[0x0F, 0x30, 0x29, 0x1A]],
		"spawn_orientations": [Constants.Orientation.T_DOWN, Constants.Orientation.J_DOWN, Constants.Orientation.Z_HORIZ, Constants.Orientation.O_FIXED, Constants.Orientation.S_HORIZ, Constants.Orientation.L_DOWN, Constants.Orientation.I_HORIZ],
		"level_textures": [{
			"tile_1": mock_tex,
			"tile_2": mock_tex,
			"tile_3": mock_tex,
		}]
	}
	reg.ingest_rom_data(mock_data)

	var atlas: ImageTexture = reg.get_level_tile_atlas(0)
	assert(atlas != null, "Atlas texture must not be null")
	assert(atlas.get_size() == Vector2(32, 8), "Atlas texture size must be 32x8")

	# Test table lookups
	assert(reg.get_gravity_frames(0) == 48, "Level 0 gravity must be 48 frames")
	assert(reg.get_gravity_frames(29) == 1, "Level 29 gravity must be 1 frame")
	assert(reg.get_score_points(1) == 40, "1 line clear must be 40 points")
	assert(reg.get_score_points(4) == 1200, "4 lines clear must be 1200 points")

	reg.free()
	print("  -> PASSED")

