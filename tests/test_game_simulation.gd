class_name TestGameSimulation
extends RefCounted

## Verification test suite for GameStateMachine lifecycle, ARE delay calculation,
## 20-frame 5-step line clear animation, and lockout game over.

const GameStateMachine = preload("res://src/game/game_state_machine.gd")
const Constants = preload("res://src/core/constants.gd")

static func run_tests() -> bool:
	print("--- Running TestGameSimulation ---")
	test_game_start_and_spawn()
	test_drop_lock_and_are_transition()
	test_line_clear_animation_sequence()
	test_topout_game_over()
	test_soft_drop_scoring_lifecycle()
	print("  -> TestGameSimulation: PASSED")
	return true

static func test_game_start_and_spawn() -> void:
	var gsm = GameStateMachine.new()
	gsm.is_headless_testing = true
	gsm.start_game(0, 100) # Seed 100

	assert(gsm.current_state == GameStateMachine.State.ACTIVE_PLAY, "Should start in ACTIVE_PLAY")
	assert(gsm.piece.is_active, "Active piece must be active")
	assert(gsm.piece.position == Constants.SPAWN_POSITION, "Piece must spawn at (5, 0)")
	assert(gsm.score_mgr.score == 0 and gsm.score_mgr.lines == 0)
	gsm.free()

static func test_drop_lock_and_are_transition() -> void:
	var gsm = GameStateMachine.new()
	gsm.is_headless_testing = true
	gsm.start_game(0, 100)

	# Position piece 1 cell above floor (y = 20 for O or T)
	gsm.piece.position = Vector2i(5, 20)
	# Make sure it contacts floor on next drop
	gsm.piece.gravity_timer = 47

	# Step 1 frame
	gsm.step_frame(0, 0)

	# Piece should have locked and entered ARE_DELAY
	assert(gsm.current_state == GameStateMachine.State.ARE_DELAY, "State must transition to ARE_DELAY after lock")
	# Lock row was ~20 or 21 -> base ARE should be 10 frames
	assert(gsm.are_timer >= 10, "Base ARE timer must be at least 10 frames")

	# Step through ARE frames until it spawns next piece
	while gsm.current_state == GameStateMachine.State.ARE_DELAY:
		gsm.step_frame(0, 0)

	assert(gsm.current_state == GameStateMachine.State.ACTIVE_PLAY, "Must return to ACTIVE_PLAY after ARE")
	gsm.free()

static func test_line_clear_animation_sequence() -> void:
	var gsm = GameStateMachine.new()
	gsm.is_headless_testing = true
	gsm.start_game(0, 100)

	# Manually fill row 21 except for columns occupied by an I piece
	# I_HORIZ occupies (3, 21), (4, 21), (5, 21), (6, 21) when centered at (5, 21)
	for x in range(Constants.GRID_COLUMNS):
		gsm.grid.set_cell(x, 21, Constants.TileType.PRIMARY)
	# Empty out cells where the I piece will drop
	gsm.grid.set_cell(3, 21, Constants.TileType.EMPTY)
	gsm.grid.set_cell(4, 21, Constants.TileType.EMPTY)
	gsm.grid.set_cell(5, 21, Constants.TileType.EMPTY)
	gsm.grid.set_cell(6, 21, Constants.TileType.EMPTY)

	# Configure active piece as I_HORIZ at (5, 21)
	gsm.piece.piece_type = Constants.PieceType.I
	gsm.piece.orientation = Constants.Orientation.I_HORIZ
	gsm.piece.position = Vector2i(5, 21)
	gsm.piece.is_active = true
	gsm.piece.gravity_timer = 47

	# Step 1 frame: piece attempts to drop to y=22 (floor), locks into row 21, completing row 21!
	gsm.step_frame(0, 0)

	assert(gsm.current_state == GameStateMachine.State.LINE_CLEAR_ANIM, "State must transition to LINE_CLEAR_ANIM on line clear")
	assert(gsm.completed_rows == [21], "Completed rows must be [21]")

	# Step through the 20-frame animation (5 steps * 4 frames)
	var frames_stepped: int = 0
	while gsm.current_state == GameStateMachine.State.LINE_CLEAR_ANIM:
		gsm.step_frame(0, 0)
		frames_stepped += 1

	# Animation must last exactly 20 frames (frame 0 to 19 processed, on frame 20 transitions to ARE_DELAY)
	assert(frames_stepped == 20, "Line clear animation must run for exactly 20 frames, ran for %d" % frames_stepped)
	assert(gsm.current_state == GameStateMachine.State.ARE_DELAY, "State must transition to ARE_DELAY after animation")
	assert(gsm.are_timer == Constants.ARE_POST_CLEAR_FRAMES, "Post clear ARE timer must equal 17 frames")
	assert(gsm.score_mgr.score == 40, "Level 0 Single score must be 40 points")
	assert(gsm.score_mgr.lines == 1, "Lines cleared must equal 1")
	gsm.free()

static func test_topout_game_over() -> void:
	var gsm = GameStateMachine.new()
	gsm.is_headless_testing = true
	gsm.start_game(0, 100)

	# Block the spawn position (5, 0) and surrounding cells
	for x in range(Constants.GRID_COLUMNS):
		gsm.grid.set_cell(x, 0, Constants.TileType.PRIMARY)
		gsm.grid.set_cell(x, 1, Constants.TileType.PRIMARY)

	# Trigger spawning next piece
	gsm.current_state = GameStateMachine.State.SPAWNING
	gsm.step_frame(0, 0)

	assert(gsm.current_state == GameStateMachine.State.GAME_OVER, "Blocked spawn must immediately trigger GAME_OVER")
	gsm.free()

static func test_soft_drop_scoring_lifecycle() -> void:
	var gsm = GameStateMachine.new()
	gsm.is_headless_testing = true
	gsm.start_game(0, 100)

	# 1. Spawn piece at (5, 18)
	gsm.piece.position = Vector2i(5, 18)
	assert(gsm.score_mgr.score == 0)

	var shifted_emitted: bool = false
	var bus_script = preload("res://src/core/event_bus.gd")
	var bus: Node = bus_script.new()
	gsm.custom_event_bus = bus
	var shift_callable: Callable = func(_t: int, _p: Vector2i, _o: int) -> void: shifted_emitted = true
	bus.piece_shifted.connect(shift_callable)

	# 2. Hold Down (BUTTON_DOWN)
	# Frame 1: soft drop frame 1 (does not drop yet, score remains 0)
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.piece.position.y == 18)
	assert(gsm.score_mgr.score == 0, "Score must NOT increment on non-drop frames")

	# Frame 2: soft drop frame 2 (drops to y=19, score MUST STILL BE 0 until lock!)
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.piece.position.y == 19)
	assert(gsm.score_mgr.score == 0, "Score must NOT increment during active falling (only upon lock)")

	# Frame 3: soft drop frame 1
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.piece.position.y == 19)
	assert(gsm.score_mgr.score == 0)

	# Frame 4: soft drop frame 2 (drops to y=20)
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.piece.position.y == 20)
	assert(gsm.score_mgr.score == 0, "Score remains 0 while falling")

	# Frame 5: soft drop frame 1
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.piece.position.y == 20)

	# Frame 6: soft drop frame 2 (attempt y=21 -> contacts floor -> LOCKS!)
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.current_state == GameStateMachine.State.ARE_DELAY, "State must transition to ARE_DELAY after lock")
	assert(gsm.score_mgr.score == 2, "2 soft-dropped cells must award exactly 2 points upon piece lock")
	assert(not shifted_emitted, "Vertical soft drop must not emit piece_shifted or trigger shift SFX")
	if bus != null and bus.piece_shifted.is_connected(shift_callable):
		bus.piece_shifted.disconnect(shift_callable)

	# Reset and test Down release before lock
	gsm.start_game(0, 100)
	gsm.piece.position = Vector2i(5, 18)
	# Drop 1 cell with Down held
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	gsm.step_frame(Constants.BUTTON_DOWN, 0)
	assert(gsm.piece.position.y == 19)
	assert(gsm.score_mgr.score == 0)

	# Release Down before locking -> drop points must reset to 0!
	gsm.step_frame(0, 0)
	gsm.piece.gravity_timer = 47
	gsm.step_frame(0, 0) # gravity drops to 20
	gsm.piece.gravity_timer = 47
	gsm.step_frame(0, 0) # gravity locks at floor
	assert(gsm.current_state == GameStateMachine.State.ARE_DELAY)
	assert(gsm.score_mgr.score == 0, "Score must remain 0 if Down was released before piece lock")

	gsm.custom_event_bus = null
	bus.free()
	gsm.free()
