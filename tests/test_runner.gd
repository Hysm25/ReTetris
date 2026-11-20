# tests/test_runner.gd
extends SceneTree

## Comprehensive headless test harness runner for all ReTetris test suites.
## Executable via: godot --headless -s tests/test_runner.gd

const TestCore = preload("res://tests/test_core.gd")
const TestRandomizer = preload("res://tests/test_randomizer.gd")
const TestBoardGrid = preload("res://tests/test_board_grid.gd")
const TestDAS = preload("res://tests/test_das.gd")
const TestPieceController = preload("res://tests/test_piece_controller.gd")
const TestScoreManager = preload("res://tests/test_score_manager.gd")
const TestGameSimulation = preload("res://tests/test_game_simulation.gd")
const TestRenderer = preload("res://tests/test_renderer.gd")
const TestAudio = preload("res://tests/test_audio.gd")
const TestImporter = preload("res://tests/test_importer.gd")

func _init() -> void:
	print("==================================================")
	print(">>> Starting ReTetris Automated Test Runner <<<")
	print("==================================================")

	var success: bool = true

	# 1. Milestone 1: Core Enums, Constants, Events & Content Registry
	success = TestCore.run_all_tests() and success

	# 2. Milestone 2: Simulation Components
	print("\n>>> Running Milestone 2: Gameplay Simulation Tests <<<")
	success = TestRandomizer.run_tests() and success
	success = TestBoardGrid.run_tests() and success
	success = TestDAS.run_tests() and success
	success = TestPieceController.run_tests() and success
	success = TestScoreManager.run_tests() and success
	success = TestGameSimulation.run_tests() and success

	# 3. Milestone 3: Rendering, Audio & Importer
	print("\n>>> Running Milestone 3: Rendering, Audio & Importer Tests <<<")
	success = TestRenderer.run_tests() and success
	success = TestAudio.run_tests() and success
	success = TestImporter.run_tests() and success

	print("\n==================================================")
	if success:
		print(">>> ALL TEST SUITES PASSED CLEANLY! (10/10 Suites) <<<")
		print("==================================================")
		quit(0)
	else:
		push_error("One or more test suites failed!")
		quit(1)
