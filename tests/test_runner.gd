# tests/test_runner.gd
extends SceneTree

## Headless test harness runner for ReTetris test suites.
## Executable via: godot --headless -s tests/test_runner.gd

const TestCore = preload("res://tests/test_core.gd")

func _init() -> void:
	print(">>> Starting ReTetris Automated Test Runner <<<")
	var success: bool = TestCore.run_all_tests()
	if success:
		print(">>> All Test Suites Completed Successfully! <<<")
		quit(0)
	else:
		push_error("Test Suite Failed!")
		quit(1)
