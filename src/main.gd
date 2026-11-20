class_name Main
extends Node2D

## Main scene coordinator for ReTetris.
## Instantiates and wires together the simulation GameStateMachine,
## the PlayfieldRenderer canvas, and the procedural AudioManager.

const Constants = preload("res://src/core/constants.gd")
const GameStateMachine = preload("res://src/game/game_state_machine.gd")
const PlayfieldRenderer = preload("res://src/game/playfield_renderer.gd")
const AudioManager = preload("res://src/audio/audio_manager.gd")
const CHRExtractor = preload("res://src/importer/chr_extractor.gd")

var game_state: GameStateMachine = null
var renderer: PlayfieldRenderer = null
var audio_manager: AudioManager = null

var prev_held_buttons: int = 0

func _ready() -> void:
	# 1. Instantiate Game State Machine
	game_state = GameStateMachine.new()
	game_state.name = "GameStateMachine"
	add_child(game_state)

	# 2. Instantiate Playfield & HUD Renderer
	renderer = PlayfieldRenderer.new(game_state)
	renderer.name = "PlayfieldRenderer"
	add_child(renderer)

	# 3. Instantiate APU Audio Manager
	audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)

	# 4. Mandatory ROM Ingestion Startup Gate
	var extraction_res: Dictionary = CHRExtractor.auto_ingest_rom()
	if extraction_res.get("success", false):
		CHRExtractor.apply_to_registry_and_audio(extraction_res, get_node_or_null("/root/ContentRegistry"), audio_manager)
		game_state.start_game(0)
	else:
		# Refuse to start gameplay: transition to ROM_SETUP state and display missing ROM prompt
		game_state.current_state = GameStateMachine.State.ROM_SETUP
		renderer.queue_redraw()

func _physics_process(_delta: float) -> void:
	if game_state == null:
		return

	# Collect controller inputs mapped to NES bitmask
	var held_buttons: int = _poll_controller_input()
	var newly_pressed: int = held_buttons & (~prev_held_buttons)
	prev_held_buttons = held_buttons

	# Advance 60 TPS simulation frame
	game_state.step_frame(held_buttons, newly_pressed)

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
	return mask
