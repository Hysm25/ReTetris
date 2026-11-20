class_name DASHandler
extends RefCounted

## Frame-accurate Delayed Auto-Shift (DAS) handler for 1989 NES Tetris.
## Sourced from Tetris NES disassembly (main.asm:1530-1550).
## 16-frame initial charge counter, 6-frame repeat interval (counter reloaded to 10).
## Preserves DAS charge across piece locks, ARE delays, and line clear animations.

const Constants = preload("res://src/core/constants.gd")

var das_counter: int = 0
var active_direction: int = 0 # -1 for Left, +1 for Right, 0 for None

func reset() -> void:
	das_counter = 0
	active_direction = 0

## Updates DAS state given current controller buttons bitmask.
## Returns column movement delta: -1 (shift left), +1 (shift right), or 0 (no shift).
func process_input(held_buttons: int, newly_pressed_buttons: int) -> int:
	var left_pressed: bool = (newly_pressed_buttons & Constants.BUTTON_LEFT) != 0
	var right_pressed: bool = (newly_pressed_buttons & Constants.BUTTON_RIGHT) != 0
	var left_held: bool = (held_buttons & Constants.BUTTON_LEFT) != 0
	var right_held: bool = (held_buttons & Constants.BUTTON_RIGHT) != 0

	# 1. New directional press takes immediate precedence and triggers instant shift on frame 0
	if left_pressed and not right_pressed:
		active_direction = -1
		das_counter = 0
		return -1
	elif right_pressed and not left_pressed:
		active_direction = 1
		das_counter = 0
		return 1

	# 2. Continuous hold in active direction
	if active_direction == -1:
		if left_held:
			das_counter += 1
			if das_counter >= Constants.DAS_INITIAL_DELAY:
				das_counter = Constants.DAS_RELOAD_VALUE # 10 frames reload (16 - 10 = 6 frame repeat)
				return -1
		else:
			# Left was released
			if right_held:
				# Immediate reversal if right is already held
				active_direction = 1
				das_counter = 0
				return 1
			else:
				active_direction = 0
				das_counter = 0
	elif active_direction == 1:
		if right_held:
			das_counter += 1
			if das_counter >= Constants.DAS_INITIAL_DELAY:
				das_counter = Constants.DAS_RELOAD_VALUE
				return 1
		else:
			# Right was released
			if left_held:
				active_direction = -1
				das_counter = 0
				return -1
			else:
				active_direction = 0
				das_counter = 0
	else:
		# No active direction currently, check if held without newly_pressed (e.g. continuing from prior state)
		if left_held and not right_held:
			active_direction = -1
			das_counter = 0
			return -1
		elif right_held and not left_held:
			active_direction = 1
			das_counter = 0
			return 1

	return 0

## Updates DAS charge during ARE or line clear animation without shifting the piece.
## Maintains authentic pre-charging behavior.
func charge_are(held_buttons: int) -> void:
	var left_held: bool = (held_buttons & Constants.BUTTON_LEFT) != 0
	var right_held: bool = (held_buttons & Constants.BUTTON_RIGHT) != 0

	if left_held and not right_held:
		if active_direction != -1:
			active_direction = -1
			das_counter = 1
		else:
			das_counter = mini(Constants.DAS_INITIAL_DELAY, das_counter + 1)
	elif right_held and not left_held:
		if active_direction != 1:
			active_direction = 1
			das_counter = 1
		else:
			das_counter = mini(Constants.DAS_INITIAL_DELAY, das_counter + 1)
	else:
		active_direction = 0
		das_counter = 0
