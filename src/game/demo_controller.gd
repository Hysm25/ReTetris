class_name DemoController
extends RefCounted

## Coordinates attract-mode demo sequence in authentic 1989 NES Tetris.
## Reads input sequences from demoButtonsTable and piece sequence from demoTetriminoTypeTable.
## Operates deterministically at 60 TPS.

const Constants = preload("res://src/core/constants.gd")

var is_active: bool = false
var buttons_offset: int = 0
var current_held: int = 0
var current_repeats: int = 0
var demo_index: int = 0

var demo_buttons: PackedByteArray = PackedByteArray()
var demo_types: PackedByteArray = PackedByteArray()

## Sets up the extracted demo tables from ROM ingestion.
func setup(buttons: PackedByteArray, types: PackedByteArray) -> void:
	demo_buttons = buttons
	demo_types = types

## Starts the attract demo playback.
func start_demo() -> void:
	is_active = true
	buttons_offset = 0
	current_held = 0
	current_repeats = 0
	demo_index = 0

## Halts demo playback.
func stop_demo() -> void:
	is_active = false
	current_held = 0
	current_repeats = 0

## Advances one frame of the demo.
## Reads physical newly pressed buttons: if BUTTON_START is pressed, requests demo exit.
## Returns Dictionary: {"held": int, "newly": int, "should_exit": bool}
func step_frame(physical_newly_pressed: int) -> Dictionary:
	if not is_active:
		return {"held": 0, "newly": 0, "should_exit": false}

	# In authentic NES Tetris: pressing Start immediately exits demo mode
	if (physical_newly_pressed & Constants.BUTTON_START) != 0:
		stop_demo()
		return {"held": 0, "newly": 0, "should_exit": true}

	var newly_pressed: int = 0

	if current_repeats <= 0:
		if buttons_offset + 1 >= demo_buttons.size():
			# Table exhausted -> exit demo
			stop_demo()
			return {"held": 0, "newly": 0, "should_exit": true}

		current_held = demo_buttons[buttons_offset]
		current_repeats = demo_buttons[buttons_offset + 1]
		buttons_offset += 2
		newly_pressed = current_held

	current_repeats -= 1
	return {"held": current_held, "newly": newly_pressed, "should_exit": false}

## Retrieves the next piece type in the authentic demo sequence.
func get_next_piece_type() -> int:
	if demo_types.is_empty():
		return Constants.PieceType.T
	var b: int = demo_types[demo_index % demo_types.size()]
	demo_index += 1
	var raw_type: int = (b >> 4) & 0x07
	return raw_type if raw_type < 7 else 0
