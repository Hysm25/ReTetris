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

var game_state: GameStateMachine = null
var menu_ctrl: MenuController = null
var renderer: PlayfieldRenderer = null
var audio_manager: AudioManager = null

var prev_held_buttons: int = 0

func _ready() -> void:
	# 1. Instantiate Game State Machine (deferred start until menu launches game)
	game_state = GameStateMachine.new()
	game_state.name = "GameStateMachine"
	game_state.is_headless_testing = true
	add_child(game_state)

	# 2. Instantiate Menu Controller
	menu_ctrl = MenuController.new()
	menu_ctrl.game_started.connect(_on_game_started)
	menu_ctrl.sfx_requested.connect(_on_menu_sfx)
	menu_ctrl.music_changed.connect(_on_menu_music)

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

	# 5. Mandatory ROM Ingestion Startup Gate
	var extraction_res: Dictionary = CHRExtractor.auto_ingest_rom()
	if extraction_res.get("success", false):
		CHRExtractor.apply_to_registry_and_audio(extraction_res, get_node_or_null("/root/ContentRegistry"), audio_manager)
		menu_ctrl.reset_to_title()
	else:
		# Refuse to start: transition to ROM_SETUP state and display missing ROM prompt
		game_state.current_state = GameStateMachine.State.ROM_SETUP
		renderer.queue_redraw()

func _physics_process(_delta: float) -> void:
	if game_state == null or game_state.current_state == GameStateMachine.State.ROM_SETUP:
		return

	# Collect controller inputs mapped to NES bitmask
	var held_buttons: int = _poll_controller_input()
	var newly_pressed: int = held_buttons & (~prev_held_buttons)
	prev_held_buttons = held_buttons

	# Dispatch to MenuController or GameStateMachine based on active mode
	if menu_ctrl != null and menu_ctrl.current_mode != Constants.MenuMode.IN_GAME:
		menu_ctrl.step_frame(held_buttons, newly_pressed)
	else:
		game_state.step_frame(held_buttons, newly_pressed)

func _on_game_started(g_type: int, start_level: int, start_height: int, m_type: int) -> void:
	game_state.start_game(start_level, g_type, start_height)
	if audio_manager != null:
		audio_manager.set_music_track(m_type)

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
