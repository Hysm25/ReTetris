class_name TestHighScores
extends RefCounted

## Unit tests for Phase 3: High Score System & Polish.
## Tests persistence, tie-breaking rules, entry screen navigation,
## curtain wipe animation, ending rocket tiers, and nametable extraction.

const Constants = preload("res://src/core/constants.gd")
const HighScoreManager = preload("res://src/game/high_score_manager.gd")
const MenuController = preload("res://src/game/menu_controller.gd")
const GameStateMachine = preload("res://src/game/game_state_machine.gd")
const CHRExtractor = preload("res://src/importer/chr_extractor.gd")

static func run_all_tests() -> void:
	print(">>> Running Phase 3: High Score System & Polish Tests <<<")
	test_high_score_manager_defaults()
	test_high_score_qualification_and_ties()
	test_high_score_insert_and_shift()
	test_high_score_persistence()
	test_menu_high_score_entry_navigation()
	test_menu_high_score_table_navigation()
	test_curtain_wipe_animation()
	test_rocket_ending_score_tiers()
	test_authentic_nametable_and_defaults_extraction()
	print("  -> TestHighScores: ALL PASSED")

static func test_high_score_manager_defaults() -> void:
	print("  [1/9] Testing HighScoreManager default values...")
	var hsm: HighScoreManager = HighScoreManager.new(false)
	var entries_a: Array[Dictionary] = hsm.get_entries(Constants.GameType.TYPE_A)
	var entries_b: Array[Dictionary] = hsm.get_entries(Constants.GameType.TYPE_B)

	assert(entries_a.size() == 3, "Game A must have exactly 3 high score entries")
	assert(entries_b.size() == 3, "Game B must have exactly 3 high score entries")

	# Check Game A defaults
	assert(entries_a[0]["name"] == "HOWARD", "1st place A must be HOWARD")
	assert(entries_a[0]["score"] == 10000, "1st place A score must be 10000")
	assert(entries_a[0]["level"] == 9, "1st place A level must be 9")

	assert(entries_a[1]["name"] == "OTASAN", "2nd place A must be OTASAN")
	assert(entries_a[1]["score"] == 7500, "2nd place A score must be 7500")

	assert(entries_a[2]["name"] == "LANCE ", "3rd place A must be LANCE ")
	assert(entries_a[2]["score"] == 5000, "3rd place A score must be 5000")

	# Check Game B defaults
	assert(entries_b[0]["name"] == "ALEX  ", "1st place B must be ALEX  ")
	assert(entries_b[0]["score"] == 2000, "1st place B score must be 2000")
	assert(entries_b[1]["name"] == "TONY  ", "2nd place B must be TONY  ")
	assert(entries_b[2]["name"] == "NINTEN", "3rd place B must be NINTEN")
	print("    -> Defaults verified successfully")

static func test_high_score_qualification_and_ties() -> void:
	print("  [2/9] Testing HighScore qualification and tie-breaking...")
	var hsm: HighScoreManager = HighScoreManager.new(false)

	# Type A defaults: 10000, 7500, 5000
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 15000) == 0, "Score > 10000 qualifies for rank 0")
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 10000) == 0, "Score == 10000 must qualify for rank 0 (tie-break prefers newer)")
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 8000) == 1, "Score 8000 qualifies for rank 1")
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 7500) == 1, "Score 7500 must qualify for rank 1")
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 6000) == 2, "Score 6000 qualifies for rank 2")
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 5000) == 2, "Score 5000 must qualify for rank 2")
	assert(hsm.check_qualifies(Constants.GameType.TYPE_A, 4999) == -1, "Score 4999 must NOT qualify")
	print("    -> Qualification & tie-breaking verified")

static func test_high_score_insert_and_shift() -> void:
	print("  [3/9] Testing HighScore insertion and shifting...")
	var hsm: HighScoreManager = HighScoreManager.new(false)

	# Insert rank 1 score (8000 points, level 6)
	var rank: int = hsm.insert_score(Constants.GameType.TYPE_A, "PLAYER", 8000, 6, "user://test_dummy.dat")
	assert(rank == 1, "Score 8000 should insert at rank 1")

	var entries: Array[Dictionary] = hsm.get_entries(Constants.GameType.TYPE_A)
	assert(entries.size() == 3, "Size must remain 3 after insert")
	assert(entries[0]["name"] == "HOWARD", "Rank 0 must remain HOWARD")
	assert(entries[1]["name"] == "PLAYER", "Rank 1 must be PLAYER")
	assert(entries[1]["score"] == 8000, "Rank 1 score must be 8000")
	assert(entries[2]["name"] == "OTASAN", "Rank 2 must now be shifted OTASAN (LANCE dropped)")
	print("    -> Insertion and shifting verified")

static func test_high_score_persistence() -> void:
	print("  [4/9] Testing HighScore disk persistence...")
	var test_path: String = "user://test_hs_save.dat"
	var hsm1: HighScoreManager = HighScoreManager.new(false)
	hsm1.insert_score(Constants.GameType.TYPE_A, "TESTER", 99999, 19, test_path)

	var hsm2: HighScoreManager = HighScoreManager.new(false)
	var load_success: bool = hsm2.load_scores(test_path)
	assert(load_success, "Must successfully load saved scores from disk")

	var entries: Array[Dictionary] = hsm2.get_entries(Constants.GameType.TYPE_A)
	assert(entries[0]["name"] == "TESTER", "Loaded top entry must match saved name")
	assert(entries[0]["score"] == 99999, "Loaded top entry must match saved score")
	assert(entries[0]["level"] == 19, "Loaded top entry must match saved level")

	# Clean up test file
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(test_path)
	print("    -> Persistence verified successfully")

static func test_menu_high_score_entry_navigation() -> void:
	print("  [5/9] Testing MenuController High Score entry navigation...")
	var menu: MenuController = MenuController.new()

	# Trigger high score qualification for rank 0
	menu.handle_game_over(Constants.GameType.TYPE_A, 20000, 10)
	assert(menu.current_mode == Constants.MenuMode.HIGH_SCORE_ENTRY, "Must transition to HIGH_SCORE_ENTRY")
	assert(menu.entry_char_index == 0, "Cursor must start at index 0")
	assert(menu.entry_name_chars[0] == "A", "First char must default to A")

	# Cycle character Up (A -> B)
	menu.step_frame(0, Constants.BUTTON_UP)
	assert(menu.entry_name_chars[0] == "B", "Up button must cycle A to B")

	# Move cursor right
	menu.step_frame(0, Constants.BUTTON_RIGHT)
	assert(menu.entry_char_index == 1, "Right button must advance cursor to index 1")

	# Cycle character Down on index 1 (A -> .)
	menu.step_frame(0, Constants.BUTTON_DOWN)
	assert(menu.entry_name_chars[1] == ".", "Down button from A must cycle to last char .")

	# Press Start to submit
	menu.step_frame(0, Constants.BUTTON_START)
	assert(menu.current_mode == Constants.MenuMode.HIGH_SCORE_TABLE, "Start button must submit and transition to HIGH_SCORE_TABLE")

	var top_score: int = menu.high_score_mgr.get_top_score(Constants.GameType.TYPE_A)
	assert(top_score == 20000, "Submitted score must be recorded in HighScoreManager")
	print("    -> Entry navigation verified")

static func test_menu_high_score_table_navigation() -> void:
	print("  [6/9] Testing MenuController High Score table navigation...")
	var menu: MenuController = MenuController.new()
	menu.current_mode = Constants.MenuMode.HIGH_SCORE_TABLE
	menu.game_type = Constants.GameType.TYPE_A

	# Toggle game type (A -> B)
	menu.step_frame(0, Constants.BUTTON_RIGHT)
	assert(menu.game_type == Constants.GameType.TYPE_B, "Right button must toggle to TYPE_B")

	# Toggle back (B -> A)
	menu.step_frame(0, Constants.BUTTON_LEFT)
	assert(menu.game_type == Constants.GameType.TYPE_A, "Left button must toggle to TYPE_A")

	# Press Start to return to title
	menu.step_frame(0, Constants.BUTTON_START)
	assert(menu.current_mode == Constants.MenuMode.TITLE_SCREEN, "Start button must return to TITLE_SCREEN")
	print("    -> Table navigation verified")

static func test_curtain_wipe_animation() -> void:
	print("  [7/9] Testing Topout Curtain Wipe animation...")
	var gsm: GameStateMachine = GameStateMachine.new()
	gsm.is_headless_testing = true
	gsm.start_game(0)

	gsm.start_curtain_wipe()
	assert(gsm.current_state == GameStateMachine.State.CURTAIN_WIPE, "State must be CURTAIN_WIPE")
	assert(gsm.curtain_row == -16, "Initial curtain_row must be -16")

	# Step 64 frames (16 steps * 4 frames)
	for f in range(64):
		gsm.step_frame(0, 0)

	assert(gsm.curtain_row == 0, "After 64 frames delay, curtain_row must reach 0")

	# Step 80 frames (20 rows * 4 frames) to wipe all 20 rows
	for f in range(80):
		gsm.step_frame(0, 0)

	# All visible rows 2..21 must now be covered with curtain tiles (tile 1)
	for r in range(Constants.HIDDEN_ROWS, Constants.GRID_ROWS):
		for c in range(Constants.GRID_COLUMNS):
			assert(gsm.grid.get_cell(c, r) != Constants.TileType.EMPTY, "Row %d must be filled by curtain" % r)

	assert(gsm.curtain_row == 20, "Curtain row must reach 20 after wipe")

	# Step 4 frames to process @curtainFinished transition
	for f in range(4):
		gsm.step_frame(0, 0)

	assert(gsm.current_state == GameStateMachine.State.GAME_OVER, "Low score must transition to GAME_OVER after curtain")
	gsm.free()
	print("    -> Curtain wipe 148-frame cycle verified")

static func test_rocket_ending_score_tiers() -> void:
	print("  [8/9] Testing Rocket Ending score thresholds and animation...")
	var tiers: Array[Dictionary] = [
		{"score": 35000, "expected_tier": Constants.RocketTier.TIER_0_SMALL},
		{"score": 55000, "expected_tier": Constants.RocketTier.TIER_1_MEDIUM_SMALL},
		{"score": 75000, "expected_tier": Constants.RocketTier.TIER_2_MEDIUM},
		{"score": 105000, "expected_tier": Constants.RocketTier.TIER_3_LARGE},
		{"score": 125000, "expected_tier": Constants.RocketTier.TIER_4_CATHEDRAL},
	]

	for tc in tiers:
		var gsm: GameStateMachine = GameStateMachine.new()
		gsm.is_headless_testing = true
		gsm.start_game(0)
		gsm.score_mgr.score = tc["score"]

		gsm.start_ending_animation()
		assert(gsm.current_state == GameStateMachine.State.ENDING_ANIMATION, "Must transition to ENDING_ANIMATION")
		assert(gsm.ending_tier == tc["expected_tier"], "Score %d must map to tier %d" % [tc["score"], tc["expected_tier"]])

		var initial_y: float = gsm.ending_rocket_y
		# Advance 240 launchpad hold frames
		for f in range(240):
			gsm.step_frame(0, 0)
		assert(gsm.ending_rocket_y == initial_y, "Rocket must stay on pad during initial 240 frames")

		# Advance 60 liftoff frames
		for f in range(60):
			gsm.step_frame(0, 0)
		assert(gsm.ending_rocket_y < initial_y, "Rocket must rise after 240 frames")

		# Press Start to exit ending
		gsm.step_frame(0, Constants.BUTTON_START)
		assert(gsm.current_state == GameStateMachine.State.GAME_OVER, "Start button must exit ending to GAME_OVER")
		gsm.free()

	print("    -> Rocket tiers and animation verified")

static func test_authentic_nametable_and_defaults_extraction() -> void:
	print("  [9/9] Testing authentic nametables and PRG default high scores extraction...")
	if not FileAccess.file_exists("Tetris (USA).nes"):
		print("    -> Skipping ROM extraction test (no local ROM file)")
		return

	var res: Dictionary = CHRExtractor.extract_from_file("Tetris (USA).nes", true)
	assert(res.get("success", false), "ROM extraction must succeed")

	# Verify extracted nametables
	assert(res.has("high_scores_nametable"), "Must extract high_scores_nametable")
	assert(res["high_scores_nametable"].size() == 1024, "high_scores_nametable must be 1024 bytes")

	assert(res.has("enter_high_score_nametable"), "Must extract enter_high_score_nametable")
	assert(res["enter_high_score_nametable"].size() == 1024, "enter_high_score_nametable must be 1024 bytes")

	assert(res.has("type_a_ending_nametable"), "Must extract type_a_ending_nametable")
	assert(res["type_a_ending_nametable"].size() == 1024, "type_a_ending_nametable must be 1024 bytes")

	# Verify rendered textures
	assert(res.has("high_scores_texture"), "Must render high_scores_texture")
	var tex_hs: ImageTexture = res["high_scores_texture"] as ImageTexture
	assert(tex_hs.get_size() == Vector2(256, 240), "high_scores_texture size must be 256x240")

	assert(res.has("enter_high_score_texture"), "Must render enter_high_score_texture")
	var tex_ehs: ImageTexture = res["enter_high_score_texture"] as ImageTexture
	assert(tex_ehs.get_size() == Vector2(256, 240), "enter_high_score_texture size must be 256x240")

	assert(res.has("type_a_ending_texture"), "Must render type_a_ending_texture")
	var tex_end: ImageTexture = res["type_a_ending_texture"] as ImageTexture
	assert(tex_end.get_size() == Vector2(256, 240), "type_a_ending_texture size must be 256x240")

	# Verify PRG default high scores
	assert(res.has("default_high_scores"), "Must extract default_high_scores")
	var defs: Dictionary = res["default_high_scores"] as Dictionary
	var def_a: Array = defs["scores_a"] as Array
	var def_b: Array = defs["scores_b"] as Array

	assert(def_a[0]["name"] == "HOWARD" and def_a[0]["score"] == 10000 and def_a[0]["level"] == 9, "ROM Type A default 1 must be HOWARD")
	assert(def_a[1]["name"] == "OTASAN" and def_a[1]["score"] == 7500, "ROM Type A default 2 must be OTASAN")
	assert(def_a[2]["name"] == "LANCE " and def_a[2]["score"] == 5000, "ROM Type A default 3 must be LANCE ")

	assert(def_b[0]["name"] == "ALEX  " and def_b[0]["score"] == 2000, "ROM Type B default 1 must be ALEX  ")
	assert(def_b[1]["name"] == "TONY  " and def_b[1]["score"] == 1000, "ROM Type B default 2 must be TONY  ")
	assert(def_b[2]["name"] == "NINTEN" and def_b[2]["score"] == 500, "ROM Type B default 3 must be NINTEN")
	print("    -> Authentic nametables and PRG default high scores verified")
