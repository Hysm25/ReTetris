class_name GameStateMachine
extends Node

## Comprehensive 1989 NES Tetris simulation coordinator and finite state machine.
## States: SPAWNING, ACTIVE_PLAY, LINE_CLEAR_ANIM, ARE_DELAY, GAME_OVER.
## Operates deterministically in _physics_process at fixed 60 TPS.

const Constants = preload("res://src/core/constants.gd")
const BoardGrid = preload("res://src/game/board_grid.gd")
const DASHandler = preload("res://src/game/das_handler.gd")
const PieceController = preload("res://src/game/piece_controller.gd")
const PieceRandomizer = preload("res://src/game/piece_randomizer.gd")
const ScoreManager = preload("res://src/game/score_manager.gd")

enum State {
	SPAWNING = 0,
	ACTIVE_PLAY = 1,
	LINE_CLEAR_ANIM = 2,
	ARE_DELAY = 3,
	GAME_OVER = 4,
	ROM_SETUP = 5,
	CURTAIN_WIPE = 6,
	ENDING_ANIMATION = 7,
}

var current_state: State = State.SPAWNING
var current_game_type: int = Constants.GameType.TYPE_A
var grid: BoardGrid
var das: DASHandler
var piece: PieceController
var randomizer: PieceRandomizer
var score_mgr: ScoreManager

var next_piece_type: int = Constants.PieceType.T
var are_timer: int = 0
var line_clear_step: int = 0
var line_clear_frame_counter: int = 0
var completed_rows: Array[int] = []

# Optional manual stepping flag (for automated unit testing)
var is_headless_testing: bool = false

# Topout Curtain Wipe and Rocket Ending State
var enable_curtain_wipe: bool = true
var curtain_row: int = -Constants.CURTAIN_INITIAL_DELAY
var curtain_frame_counter: int = 0

var ending_tier: int = Constants.RocketTier.TIER_0_SMALL
var ending_frame_counter: int = 0
var ending_rocket_y: float = 191.0
var ending_rocket_x: float = 84.0
var ending_completed: bool = false

func _init() -> void:
	grid = BoardGrid.new()
	das = DASHandler.new()
	piece = PieceController.new()
	randomizer = PieceRandomizer.new()
	score_mgr = ScoreManager.new()

func _ready() -> void:
	if not is_headless_testing:
		start_game(0)

func start_game(starting_level: int, game_type_or_seed: int = Constants.GameType.TYPE_A, starting_height: int = 0, seed_val: int = -1, is_demo: bool = false) -> void:
	var g_type: int = Constants.GameType.TYPE_A
	var s_val: int = seed_val
	if game_type_or_seed > 1:
		s_val = game_type_or_seed
		g_type = Constants.GameType.TYPE_A
	else:
		g_type = game_type_or_seed

	grid.clear()
	das.reset()
	piece.reset()
	randomizer.reset(s_val)
	if is_demo:
		var main_loop: MainLoop = Engine.get_main_loop()
		var reg: Node = null
		if main_loop is SceneTree and (main_loop as SceneTree).root != null:
			reg = (main_loop as SceneTree).root.get_node_or_null("/root/ContentRegistry")
		var types: PackedByteArray = reg.get_demo_tetrimino_type_table() if reg != null else PackedByteArray()
		randomizer.set_demo_mode(true, types)
	else:
		randomizer.set_demo_mode(false)
	current_game_type = g_type
	score_mgr.init_game(starting_level, g_type, starting_height)

	if g_type == Constants.GameType.TYPE_B:
		grid.setup_type_b_garbage(starting_height, s_val)

	# Initial roll for active and next piece
	var first_piece: int = randomizer.roll_next_piece()
	next_piece_type = randomizer.roll_next_piece()

	current_state = State.SPAWNING
	_spawn_piece(first_piece)

func _spawn_piece(type: int) -> void:
	var success: bool = piece.spawn(type, grid)
	if not success:
		if enable_curtain_wipe and not is_headless_testing:
			start_curtain_wipe()
		else:
			current_state = State.GAME_OVER
			_emit_game_over()
		return

	current_state = State.ACTIVE_PLAY
	_emit_piece_spawned(piece.piece_type, piece.position, piece.orientation)

## Advances one frame of the simulation.
## Reads controller button bitmasks (held and newly pressed).
func step_frame(held_buttons: int, newly_pressed_buttons: int) -> void:
	match current_state:
		State.ACTIVE_PLAY:
			_process_active_play(held_buttons, newly_pressed_buttons)
		State.LINE_CLEAR_ANIM:
			_process_line_clear_anim(held_buttons)
		State.ARE_DELAY:
			_process_are_delay(held_buttons)
		State.SPAWNING:
			var p_type: int = next_piece_type
			next_piece_type = randomizer.roll_next_piece()
			_spawn_piece(p_type)
		State.CURTAIN_WIPE:
			_process_curtain_wipe()
		State.ENDING_ANIMATION:
			_process_ending_animation(held_buttons, newly_pressed_buttons)
		State.GAME_OVER:
			pass
		State.ROM_SETUP:
			pass

func _process_active_play(held_buttons: int, newly_pressed_buttons: int) -> void:
	# 1. Rotations (Button A = Clockwise, Button B = Counter-Clockwise)
	if (newly_pressed_buttons & Constants.BUTTON_A) != 0:
		if piece.rotate_cw(grid):
			_emit_piece_rotated(piece.piece_type, piece.position, piece.orientation)
	elif (newly_pressed_buttons & Constants.BUTTON_B) != 0:
		if piece.rotate_ccw(grid):
			_emit_piece_rotated(piece.piece_type, piece.position, piece.orientation)

	# 2. Horizontal DAS shift
	var shift_dx: int = das.process_input(held_buttons, newly_pressed_buttons)
	if shift_dx != 0:
		if piece.shift(shift_dx, grid):
			_emit_piece_moved(piece.piece_type, piece.position, piece.orientation)

	# 3. Gravity and Soft Drop
	var down_held: bool = (held_buttons & Constants.BUTTON_DOWN) != 0
	var grav_res: Dictionary = piece.tick_gravity(score_mgr.level, down_held, grid)

	if grav_res["soft_drop_point"]:
		var pts: int = score_mgr.add_soft_drop_points(1)
		_emit_score_updated(score_mgr.score, pts)

	if grav_res["moved_down"]:
		_emit_piece_moved(piece.piece_type, piece.position, piece.orientation)

	if grav_res["locked"]:
		_on_piece_locked()

func _on_piece_locked() -> void:
	var locked_rows: Array[int] = grid.lock_piece(piece.piece_type, piece.position, piece.orientation)
	var lock_y: int = piece.position.y
	if not locked_rows.is_empty():
		lock_y = locked_rows.max()

	_emit_piece_locked(piece.piece_type, piece.position, piece.orientation)

	# Check completed rows
	completed_rows = grid.get_completed_rows()
	if not completed_rows.is_empty():
		current_state = State.LINE_CLEAR_ANIM
		line_clear_step = 0
		line_clear_frame_counter = 0
	else:
		# Calculate authentic ARE delay
		are_timer = Constants.get_base_are(lock_y)
		current_state = State.ARE_DELAY

func _process_line_clear_anim(held_buttons: int) -> void:
	# Pre-charge DAS during line clear animation
	das.charge_are(held_buttons)

	# Authentic 5-step center-outward animation (4 frames per step = 20 frames total)
	if line_clear_frame_counter % Constants.ARE_LINE_CLEAR_FRAME_STEP == 0:
		grid.clear_step(completed_rows, line_clear_step)
		_emit_lines_clearing(completed_rows, line_clear_step)
		line_clear_step += 1

	line_clear_frame_counter += 1

	if line_clear_frame_counter >= Constants.ARE_LINE_CLEAR_TOTAL_FRAMES:
		# Animation finished -> Collapse grid and score
		grid.collapse_rows(completed_rows)
		var clear_count: int = completed_rows.size()
		var score_res: Dictionary = score_mgr.add_line_clears(clear_count)

		_emit_lines_cleared(clear_count, completed_rows)
		_emit_score_updated(score_mgr.score, score_res["points_added"])
		_emit_lines_updated(score_mgr.lines)
		if score_res["level_up"]:
			_emit_level_updated(score_mgr.level)

		completed_rows.clear()
		if current_game_type == Constants.GameType.TYPE_B and score_mgr.is_goal_reached:
			if enable_curtain_wipe and not is_headless_testing:
				start_curtain_wipe()
			else:
				current_state = State.GAME_OVER
				_emit_game_over()
			return

		are_timer = Constants.ARE_POST_CLEAR_FRAMES
		current_state = State.ARE_DELAY

func _process_are_delay(held_buttons: int) -> void:
	das.charge_are(held_buttons)
	are_timer -= 1
	if are_timer <= 0:
		current_state = State.SPAWNING
		var p_type: int = next_piece_type
		next_piece_type = randomizer.roll_next_piece()
		_spawn_piece(p_type)

func _physics_process(_delta: float) -> void:
	if is_headless_testing:
		return
	var held: int = _read_input_held()
	var pressed: int = _read_input_just_pressed()
	step_frame(held, pressed)

func _read_input_held() -> int:
	var mask: int = 0
	if Input.is_action_pressed("ui_left"):
		mask |= Constants.BUTTON_LEFT
	if Input.is_action_pressed("ui_right"):
		mask |= Constants.BUTTON_RIGHT
	if Input.is_action_pressed("ui_down"):
		mask |= Constants.BUTTON_DOWN
	if Input.is_action_pressed("ui_up"):
		mask |= Constants.BUTTON_UP
	if Input.is_action_pressed("ui_accept"):
		mask |= Constants.BUTTON_A
	if Input.is_action_pressed("ui_cancel"):
		mask |= Constants.BUTTON_B
	return mask

func _read_input_just_pressed() -> int:
	var mask: int = 0
	if Input.is_action_just_pressed("ui_left"):
		mask |= Constants.BUTTON_LEFT
	if Input.is_action_just_pressed("ui_right"):
		mask |= Constants.BUTTON_RIGHT
	if Input.is_action_just_pressed("ui_down"):
		mask |= Constants.BUTTON_DOWN
	if Input.is_action_just_pressed("ui_up"):
		mask |= Constants.BUTTON_UP
	if Input.is_action_just_pressed("ui_accept"):
		mask |= Constants.BUTTON_A
	if Input.is_action_just_pressed("ui_cancel"):
		mask |= Constants.BUTTON_B
	return mask

# --- EventBus helper dispatchers (safe when running in isolation or tree) ---

func _get_event_bus() -> Node:
	if is_inside_tree() and get_tree().root.has_node("EventBus"):
		return get_tree().root.get_node("EventBus")
	return null

func _emit_piece_spawned(p_type: int, pos: Vector2i, orient: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.piece_spawned.emit(p_type, pos, orient)

func _emit_piece_moved(p_type: int, pos: Vector2i, orient: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.piece_moved.emit(p_type, pos, orient)

func _emit_piece_rotated(p_type: int, pos: Vector2i, orient: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.piece_rotated.emit(p_type, pos, orient)

func _emit_piece_locked(p_type: int, pos: Vector2i, orient: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.piece_locked.emit(p_type, pos, orient)

func _emit_lines_clearing(rows: Array[int], step: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.lines_clearing.emit(rows, step)

func _emit_lines_cleared(count: int, rows: Array[int]) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.lines_cleared.emit(count, rows)

func _emit_score_updated(curr_score: int, added: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.score_updated.emit(curr_score, added)

func _emit_lines_updated(tot_lines: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.lines_updated.emit(tot_lines)

func _emit_level_updated(new_lvl: int) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.level_updated.emit(new_lvl)

func _emit_game_over() -> void:
	var bus = _get_event_bus()
	if bus:
		bus.game_over.emit()

func _emit_sfx_requested(sfx_id: int) -> void:
	var bus = _get_event_bus()
	if bus and bus.has_user_signal("sfx_requested"):
		bus.emit_signal("sfx_requested", sfx_id)

## Initiates the authentic NES 20-row curtain wipe animation.
func start_curtain_wipe() -> void:
	current_state = State.CURTAIN_WIPE
	curtain_row = -Constants.CURTAIN_INITIAL_DELAY
	curtain_frame_counter = 0
	_emit_sfx_requested(Constants.SFX_CURTAIN)

func _process_curtain_wipe() -> void:
	curtain_frame_counter += 1
	if curtain_frame_counter % Constants.CURTAIN_FRAME_STEP == 0:
		if curtain_row < 0:
			curtain_row += 1
		elif curtain_row < Constants.CURTAIN_ROWS:
			# Fill row across all columns with curtain tile
			grid.fill_row(curtain_row + Constants.HIDDEN_ROWS, 1)
			_emit_sfx_requested(Constants.SFX_CURTAIN)
			curtain_row += 1
		else:
			# Curtain wipe completed: check if ending sequence qualifies
			if current_game_type == Constants.GameType.TYPE_A and score_mgr.score >= 30000:
				start_ending_animation()
			elif current_game_type == Constants.GameType.TYPE_B and score_mgr.is_goal_reached:
				start_ending_animation()
			else:
				current_state = State.GAME_OVER
				_emit_game_over()

## Starts the authentic rocket / cathedral launch ending sequence.
func start_ending_animation() -> void:
	current_state = State.ENDING_ANIMATION
	ending_frame_counter = 0
	ending_completed = false
	var sc: int = score_mgr.score
	if sc >= 120000:
		ending_tier = Constants.RocketTier.TIER_4_CATHEDRAL
		ending_rocket_y = 199.0
		ending_rocket_x = 160.0
	elif sc >= 100000:
		ending_tier = Constants.RocketTier.TIER_3_LARGE
		ending_rocket_y = 191.0
		ending_rocket_x = 72.0
	elif sc >= 70000:
		ending_tier = Constants.RocketTier.TIER_2_MEDIUM
		ending_rocket_y = 191.0
		ending_rocket_x = 80.0
	elif sc >= 50000:
		ending_tier = Constants.RocketTier.TIER_1_MEDIUM_SMALL
		ending_rocket_y = 191.0
		ending_rocket_x = 84.0
	else:
		ending_tier = Constants.RocketTier.TIER_0_SMALL
		ending_rocket_y = 191.0
		ending_rocket_x = 84.0
	_emit_sfx_requested(Constants.SFX_ROCKET)

func _process_ending_animation(_held_buttons: int, newly_pressed: int) -> void:
	ending_frame_counter += 1
	if ending_frame_counter > Constants.ROCKET_LAUNCH_DELAY_FRAMES:
		if ending_rocket_y > 176.0:
			if (ending_frame_counter & 1) == 0:
				ending_rocket_y -= 1.0
		elif ending_rocket_y > float(Constants.ROCKET_SPEED_ACCEL_Y):
			ending_rocket_y -= 1.0
		else:
			ending_rocket_y -= 2.0

		if ending_rocket_y < -32.0:
			ending_completed = true

	# Allow player to skip with Start after liftoff has begun, or automatically upon completion
	if ((newly_pressed & Constants.BUTTON_START) != 0 and ending_frame_counter > Constants.ROCKET_LAUNCH_DELAY_FRAMES) or ending_completed:
		current_state = State.GAME_OVER
		_emit_game_over()
