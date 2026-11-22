class_name Main
extends Node2D

## Main scene coordinator for ReTetris.
## Instantiates and wires together the simulation GameStateMachine,
## the MenuController, PlayfieldRenderer canvas, and the procedural AudioManager.

const Constants = preload("res://src/core/constants.gd")
const GameStateMachine = preload("res://src/game/game_state_machine.gd")
const PlayfieldRenderer = preload("res://src/game/playfield_renderer.gd")
const AudioManager = preload("res://src/audio/audio_manager.gd")
const CHRExtractor = preload("res://src/importer/chr_extractor.gd")
const MenuController = preload("res://src/game/menu_controller.gd")
const DemoController = preload("res://src/game/demo_controller.gd")
const InputManagerClass = preload("res://src/core/input_manager.gd")
const VirtualGamepad = preload("res://src/game/virtual_gamepad.gd")

var game_state: GameStateMachine = null
var menu_ctrl: MenuController = null
var renderer: PlayfieldRenderer = null
var audio_manager: AudioManager = null
var demo_ctrl: DemoController = null
var input_mgr: Node = null
var virtual_pad: VirtualGamepad = null

var prev_held_buttons: int = 0

func _ready() -> void:
	# 1. Instantiate Game State Machine (deferred start until menu launches game)
	game_state = GameStateMachine.new()
	game_state.name = "GameStateMachine"
	game_state.is_headless_testing = true
	add_child(game_state)

	# 2. Instantiate Menu Controller & Demo Controller
	menu_ctrl = MenuController.new()
	menu_ctrl.game_started.connect(_on_game_started)
	menu_ctrl.sfx_requested.connect(_on_menu_sfx)
	menu_ctrl.music_changed.connect(_on_menu_music)
	menu_ctrl.demo_started.connect(_on_demo_started)

	demo_ctrl = DemoController.new()

	# 3. Instantiate APU Audio Manager
	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	# 4. Instantiate Playfield & HUD Renderer
	renderer = PlayfieldRenderer.new(game_state, menu_ctrl)
	renderer.name = "PlayfieldRenderer"
	add_child(renderer)

	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.game_over.connect(_on_game_over)

	# 5. Instantiate Input Manager & Virtual Touch Gamepad
	input_mgr = get_node_or_null("/root/InputManager")
	if input_mgr == null:
		input_mgr = InputManagerClass.new()
		input_mgr.name = "InputManager"
		add_child(input_mgr)

	virtual_pad = VirtualGamepad.new(input_mgr)
	virtual_pad.name = "VirtualGamepad"
	add_child(virtual_pad)

	# 6. Mandatory ROM Ingestion Startup Gate
	var extraction_res: Dictionary = CHRExtractor.auto_ingest_rom()
	if extraction_res.get("success", false):
		CHRExtractor.apply_to_registry_and_audio(extraction_res, get_node_or_null("/root/ContentRegistry"), audio_manager)
		var reg: Node = get_node_or_null("/root/ContentRegistry")
		if reg != null:
			demo_ctrl.setup(reg.get_demo_buttons_table(), reg.get_demo_tetrimino_type_table())

		menu_ctrl.reset_to_title()
	else:
		# Refuse to start: transition to ROM_SETUP state and display missing ROM prompt
		game_state.current_state = GameStateMachine.State.ROM_SETUP
		renderer.queue_redraw()

func _physics_process(_delta: float) -> void:
	if game_state == null or game_state.current_state == GameStateMachine.State.ROM_SETUP:
		return

	# Handle runtime shortcuts
	if InputMap.has_action(Constants.ACTION_TOGGLE_CRT) and Input.is_action_just_pressed(Constants.ACTION_TOGGLE_CRT):
		if renderer != null:
			renderer.toggle_crt_shader()
	if InputMap.has_action(Constants.ACTION_TOGGLE_FULLSCREEN) and Input.is_action_just_pressed(Constants.ACTION_TOGGLE_FULLSCREEN):
		toggle_fullscreen()

	# Collect controller inputs mapped to NES bitmask
	var held_buttons: int = _poll_controller_input()
	var newly_pressed: int = held_buttons & (~prev_held_buttons)
	prev_held_buttons = held_buttons

	# Dispatch to MenuController, DemoController, or GameStateMachine based on active mode
	if menu_ctrl != null and menu_ctrl.current_mode == Constants.MenuMode.DEMO:
		var demo_in: Dictionary = demo_ctrl.step_frame(newly_pressed)
		if demo_in.get("should_exit", false) or game_state.current_state == GameStateMachine.State.GAME_OVER:
			demo_ctrl.stop_demo()
			menu_ctrl.reset_to_title()
			game_state.current_state = GameStateMachine.State.ACTIVE_PLAY
		else:
			game_state.step_frame(demo_in["held"], demo_in["newly"])
	elif menu_ctrl != null and menu_ctrl.current_mode != Constants.MenuMode.IN_GAME:
		menu_ctrl.step_frame(held_buttons, newly_pressed)
	else:
		game_state.step_frame(held_buttons, newly_pressed)

func _on_game_started(g_type: int, start_level: int, start_height: int, m_type: int) -> void:
	game_state.start_game(start_level, g_type, start_height)
	if audio_manager != null:
		audio_manager.set_music_track(m_type)

func _on_demo_started() -> void:
	demo_ctrl.start_demo()
	game_state.start_game(0, Constants.GameType.TYPE_A, 0, -1, true)
	if audio_manager != null:
		audio_manager.set_music_track(Constants.MusicType.OFF)

func _on_menu_sfx(sfx_id: int) -> void:
	if audio_manager != null:
		audio_manager.play_sfx(sfx_id)

func _on_menu_music(track_type: int) -> void:
	if audio_manager != null:
		audio_manager.set_music_track(track_type)

func _on_game_over() -> void:
	if menu_ctrl != null and game_state != null:
		menu_ctrl.handle_game_over(game_state.current_game_type, game_state.score_mgr.score, game_state.score_mgr.level)

func _poll_controller_input() -> int:
	if input_mgr != null and input_mgr.has_method("poll_button_mask"):
		return input_mgr.poll_button_mask()

	var mask: int = 0
	if Input.is_action_pressed("ui_left"):
		mask |= Constants.BUTTON_LEFT
	if Input.is_action_pressed("ui_right"):
		mask |= Constants.BUTTON_RIGHT
	if Input.is_action_pressed("ui_down"):
		mask |= Constants.BUTTON_DOWN
	if Input.is_action_pressed("ui_up"):
		mask |= Constants.BUTTON_UP
	if Input.is_action_pressed("ui_accept"): # Button A
		mask |= Constants.BUTTON_A
	if Input.is_action_pressed("ui_cancel"): # Button B
		mask |= Constants.BUTTON_B
	if Input.is_action_pressed("ui_select") or Input.is_key_pressed(KEY_ENTER):
		mask |= Constants.BUTTON_START
	if Input.is_key_pressed(KEY_SHIFT):
		mask |= Constants.BUTTON_SELECT
	return mask

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_F11 or (key_event.keycode == KEY_ENTER and key_event.alt_pressed):
			toggle_fullscreen()

func toggle_fullscreen() -> void:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
