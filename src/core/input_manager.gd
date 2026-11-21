extends Node

## Centralized input manager and controller remapping system for ReTetris.
## Manages InputMap action bindings, input profiles, gamepad deadzones,
## SOCD (Simultaneous Opposite Cardinal Direction) cleaning, and mobile virtual gamepad integration.
## Returns authentic 8-bit NES button masks at 60 TPS without frame-jitter.

const Constants = preload("res://src/core/constants.gd")

# Action Name Constants
const ACTION_LEFT: String = "tetris_left"
const ACTION_RIGHT: String = "tetris_right"
const ACTION_DOWN: String = "tetris_down"
const ACTION_UP: String = "tetris_up"
const ACTION_A: String = "tetris_a"
const ACTION_B: String = "tetris_b"
const ACTION_START: String = "tetris_start"
const ACTION_SELECT: String = "tetris_select"
const ACTION_TOGGLE_CRT: String = "tetris_toggle_crt"
const ACTION_RESET: String = "tetris_reset"

# Input Profiles
enum ProfileType {
	DEFAULT_KEYBOARD = 0,
	WASD_KEYBOARD = 1,
	GAMEPAD_STANDARD = 2,
	CUSTOM = 3,
}

# SOCD Cleaning Modes
enum SOCDMode {
	NEUTRAL = 0,    # Opposite directions cancel each other out to neutral (0)
	LAST_INPUT = 1, # Most recently pressed direction takes precedence
	PRIORITY = 2,   # Left overrides Right; Up overrides Down
}

# State & Configuration
var current_profile: int = ProfileType.DEFAULT_KEYBOARD
var socd_mode: int = SOCDMode.NEUTRAL
var joypad_deadzone: float = 0.3
var virtual_gamepad_mask: int = 0
var mock_raw_mask: int = -1 # Used for headless deterministic testing (-1 means disabled)

# SOCD tracking for LAST_INPUT mode
var _last_horizontal_button: int = 0
var _last_vertical_button: int = 0
var _prev_raw_mask: int = 0

# Signal for remapping UI notification
signal bindings_changed()
signal profile_changed(profile_id: int)

func _ready() -> void:
	init_default_mappings()

## Initializes default InputMap actions and populates them if missing
func init_default_mappings() -> void:
	_ensure_actions_exist()
	apply_profile(ProfileType.DEFAULT_KEYBOARD)

func _ensure_actions_exist() -> void:
	var actions: Array[String] = [
		ACTION_LEFT, ACTION_RIGHT, ACTION_DOWN, ACTION_UP,
		ACTION_A, ACTION_B, ACTION_START, ACTION_SELECT,
		ACTION_TOGGLE_CRT, ACTION_RESET
	]
	for act in actions:
		if not InputMap.has_action(act):
			InputMap.add_action(act, joypad_deadzone)

## Clears all event bindings associated with an action
func clear_action_bindings(action_name: String) -> void:
	if InputMap.has_action(action_name):
		InputMap.action_erase_events(action_name)

## Clears bindings for all Tetris actions
func clear_all_tetris_bindings() -> void:
	var actions: Array[String] = [
		ACTION_LEFT, ACTION_RIGHT, ACTION_DOWN, ACTION_UP,
		ACTION_A, ACTION_B, ACTION_START, ACTION_SELECT,
		ACTION_TOGGLE_CRT, ACTION_RESET
	]
	for act in actions:
		clear_action_bindings(act)

## Binds a physical keyboard key to an action
func add_key_binding(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, joypad_deadzone)
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	InputMap.action_add_event(action_name, ev)

## Binds a joypad button to an action
func add_joy_button_binding(action_name: String, button: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, joypad_deadzone)
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)

## Binds a joypad motion axis to an action
func add_joy_axis_binding(action_name: String, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, joypad_deadzone)
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action_name, ev)

## Applies one of the standard predefined input profiles
func apply_profile(profile_type: int) -> void:
	current_profile = profile_type
	clear_all_tetris_bindings()

	match profile_type:
		ProfileType.DEFAULT_KEYBOARD:
			_setup_default_keyboard_profile()
		ProfileType.WASD_KEYBOARD:
			_setup_wasd_keyboard_profile()
		ProfileType.GAMEPAD_STANDARD:
			_setup_gamepad_profile()
		ProfileType.CUSTOM:
			# Custom profile relies on loaded or user-modified bindings
			pass

	# Always attach standard gamepad fallback bindings so controllers work universally
	if profile_type != ProfileType.GAMEPAD_STANDARD and profile_type != ProfileType.CUSTOM:
		_attach_standard_gamepad_bindings()

	# Always register universal shortcut utility keys
	add_key_binding(ACTION_TOGGLE_CRT, KEY_F1)
	add_key_binding(ACTION_TOGGLE_CRT, KEY_C)
	add_key_binding(ACTION_RESET, KEY_F5)
	add_key_binding(ACTION_RESET, KEY_R)

	bindings_changed.emit()
	profile_changed.emit(current_profile)

func _setup_default_keyboard_profile() -> void:
	# Directional Arrows
	add_key_binding(ACTION_LEFT, KEY_LEFT)
	add_key_binding(ACTION_LEFT, KEY_A)
	add_key_binding(ACTION_RIGHT, KEY_RIGHT)
	add_key_binding(ACTION_RIGHT, KEY_D)
	add_key_binding(ACTION_DOWN, KEY_DOWN)
	add_key_binding(ACTION_DOWN, KEY_S)
	add_key_binding(ACTION_UP, KEY_UP)
	add_key_binding(ACTION_UP, KEY_W)

	# NES Buttons: A (Rotate CW), B (Rotate CCW)
	add_key_binding(ACTION_A, KEY_X)
	add_key_binding(ACTION_A, KEY_UP)
	add_key_binding(ACTION_B, KEY_Z)

	# Start & Select
	add_key_binding(ACTION_START, KEY_ENTER)
	add_key_binding(ACTION_START, KEY_SPACE)
	add_key_binding(ACTION_SELECT, KEY_SHIFT)
	add_key_binding(ACTION_SELECT, KEY_TAB)

func _setup_wasd_keyboard_profile() -> void:
	# Pure WASD Directionals
	add_key_binding(ACTION_LEFT, KEY_A)
	add_key_binding(ACTION_RIGHT, KEY_D)
	add_key_binding(ACTION_DOWN, KEY_S)
	add_key_binding(ACTION_UP, KEY_W)

	# Ergonomic Right-Hand Rotations (J/K/L)
	add_key_binding(ACTION_A, KEY_L)
	add_key_binding(ACTION_A, KEY_K)
	add_key_binding(ACTION_B, KEY_J)

	# Start & Select
	add_key_binding(ACTION_START, KEY_ENTER)
	add_key_binding(ACTION_START, KEY_SPACE)
	add_key_binding(ACTION_SELECT, KEY_BACKSPACE)

func _setup_gamepad_profile() -> void:
	_attach_standard_gamepad_bindings()

func _attach_standard_gamepad_bindings() -> void:
	# D-Pad
	add_joy_button_binding(ACTION_LEFT, JOY_BUTTON_DPAD_LEFT)
	add_joy_button_binding(ACTION_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	add_joy_button_binding(ACTION_DOWN, JOY_BUTTON_DPAD_DOWN)
	add_joy_button_binding(ACTION_UP, JOY_BUTTON_DPAD_UP)

	# Left Analog Stick
	add_joy_axis_binding(ACTION_LEFT, JOY_AXIS_LEFT_X, -1.0)
	add_joy_axis_binding(ACTION_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	add_joy_axis_binding(ACTION_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	add_joy_axis_binding(ACTION_UP, JOY_AXIS_LEFT_Y, -1.0)

	# Action Buttons: A (Bottom/Right buttons), B (Left/Top buttons)
	add_joy_button_binding(ACTION_A, JOY_BUTTON_A)
	add_joy_button_binding(ACTION_A, JOY_BUTTON_B)
	add_joy_button_binding(ACTION_B, JOY_BUTTON_X)
	add_joy_button_binding(ACTION_B, JOY_BUTTON_Y)

	# Start & Select (Options / Back / Menu)
	add_joy_button_binding(ACTION_START, JOY_BUTTON_START)
	add_joy_button_binding(ACTION_SELECT, JOY_BUTTON_BACK)

## Sets the virtual touch gamepad bitmask
func set_virtual_gamepad_mask(mask: int) -> void:
	virtual_gamepad_mask = mask

## Updates an individual virtual gamepad button state
func set_virtual_button(button_mask: int, pressed: bool) -> void:
	if pressed:
		virtual_gamepad_mask |= button_mask
	else:
		virtual_gamepad_mask &= ~button_mask

## Sets mock raw mask for headless deterministic testing
func set_mock_raw_mask(mask: int) -> void:
	mock_raw_mask = mask

## Polls the raw hardware controller input without SOCD cleaning
func poll_raw_button_mask() -> int:
	if mock_raw_mask >= 0:
		return mock_raw_mask | virtual_gamepad_mask

	var mask: int = 0
	if Input.is_action_pressed(ACTION_A):
		mask |= Constants.BUTTON_A
	if Input.is_action_pressed(ACTION_B):
		mask |= Constants.BUTTON_B
	if Input.is_action_pressed(ACTION_SELECT):
		mask |= Constants.BUTTON_SELECT
	if Input.is_action_pressed(ACTION_START):
		mask |= Constants.BUTTON_START
	if Input.is_action_pressed(ACTION_UP):
		mask |= Constants.BUTTON_UP
	if Input.is_action_pressed(ACTION_DOWN):
		mask |= Constants.BUTTON_DOWN
	if Input.is_action_pressed(ACTION_LEFT):
		mask |= Constants.BUTTON_LEFT
	if Input.is_action_pressed(ACTION_RIGHT):
		mask |= Constants.BUTTON_RIGHT

	# Merge with virtual touch gamepad
	mask |= virtual_gamepad_mask
	return mask

## Applies SOCD (Simultaneous Opposite Cardinal Direction) cleaning to input bitmask
func clean_socd(raw_mask: int) -> int:
	var cleaned: int = raw_mask
	var has_left: bool = (raw_mask & Constants.BUTTON_LEFT) != 0
	var has_right: bool = (raw_mask & Constants.BUTTON_RIGHT) != 0
	var has_up: bool = (raw_mask & Constants.BUTTON_UP) != 0
	var has_down: bool = (raw_mask & Constants.BUTTON_DOWN) != 0

	var newly_pressed: int = raw_mask & (~_prev_raw_mask)

	# Update last pressed horizontal tracking
	if (newly_pressed & Constants.BUTTON_LEFT) != 0:
		_last_horizontal_button = Constants.BUTTON_LEFT
	elif (newly_pressed & Constants.BUTTON_RIGHT) != 0:
		_last_horizontal_button = Constants.BUTTON_RIGHT
	elif not has_left and not has_right:
		_last_horizontal_button = 0
	elif has_left and not has_right:
		_last_horizontal_button = Constants.BUTTON_LEFT
	elif has_right and not has_left:
		_last_horizontal_button = Constants.BUTTON_RIGHT

	# Update last pressed vertical tracking
	if (newly_pressed & Constants.BUTTON_UP) != 0:
		_last_vertical_button = Constants.BUTTON_UP
	elif (newly_pressed & Constants.BUTTON_DOWN) != 0:
		_last_vertical_button = Constants.BUTTON_DOWN
	elif not has_up and not has_down:
		_last_vertical_button = 0
	elif has_up and not has_down:
		_last_vertical_button = Constants.BUTTON_UP
	elif has_down and not has_up:
		_last_vertical_button = Constants.BUTTON_DOWN

	# 1. Horizontal SOCD resolution (Left vs Right)
	if has_left and has_right:
		match socd_mode:
			SOCDMode.NEUTRAL:
				cleaned &= ~(Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT)
			SOCDMode.PRIORITY:
				# Left takes priority
				cleaned &= ~Constants.BUTTON_RIGHT
			SOCDMode.LAST_INPUT:
				if _last_horizontal_button == Constants.BUTTON_LEFT:
					cleaned &= ~Constants.BUTTON_RIGHT
				elif _last_horizontal_button == Constants.BUTTON_RIGHT:
					cleaned &= ~Constants.BUTTON_LEFT
				else:
					cleaned &= ~(Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT)

	# 2. Vertical SOCD resolution (Up vs Down)
	if has_up and has_down:
		match socd_mode:
			SOCDMode.NEUTRAL:
				cleaned &= ~(Constants.BUTTON_UP | Constants.BUTTON_DOWN)
			SOCDMode.PRIORITY:
				# Up takes priority
				cleaned &= ~Constants.BUTTON_DOWN
			SOCDMode.LAST_INPUT:
				if _last_vertical_button == Constants.BUTTON_UP:
					cleaned &= ~Constants.BUTTON_DOWN
				elif _last_vertical_button == Constants.BUTTON_DOWN:
					cleaned &= ~Constants.BUTTON_UP
				else:
					cleaned &= ~(Constants.BUTTON_UP | Constants.BUTTON_DOWN)

	_prev_raw_mask = raw_mask
	return cleaned

## Main 60 TPS input poll method returning authentic 8-bit NES button mask
func poll_button_mask() -> int:
	var raw: int = poll_raw_button_mask()
	return clean_socd(raw)

## Exports the current configuration to a dictionary for persistence
func export_profile_dictionary() -> Dictionary:
	var data: Dictionary = {
		"profile_type": current_profile,
		"socd_mode": socd_mode,
		"joypad_deadzone": joypad_deadzone,
		"actions": {}
	}

	var actions: Array[String] = [
		ACTION_LEFT, ACTION_RIGHT, ACTION_DOWN, ACTION_UP,
		ACTION_A, ACTION_B, ACTION_START, ACTION_SELECT,
		ACTION_TOGGLE_CRT, ACTION_RESET
	]

	for act in actions:
		var events_data: Array[Dictionary] = []
		if InputMap.has_action(act):
			for ev in InputMap.action_get_events(act):
				if ev is InputEventKey:
					events_data.append({
						"type": "key",
						"keycode": int(ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode)
					})
				elif ev is InputEventJoypadButton:
					events_data.append({
						"type": "joy_button",
						"button_index": int(ev.button_index)
					})
				elif ev is InputEventJoypadMotion:
					events_data.append({
						"type": "joy_axis",
						"axis": int(ev.axis),
						"axis_value": float(ev.axis_value)
					})
		data["actions"][act] = events_data

	return data

## Imports configuration from a dictionary
func import_profile_dictionary(data: Dictionary) -> bool:
	if not data.has("actions") or not (data["actions"] is Dictionary):
		return false

	if data.has("profile_type"):
		current_profile = int(data["profile_type"])
	if data.has("socd_mode"):
		socd_mode = int(data["socd_mode"])
	if data.has("joypad_deadzone"):
		joypad_deadzone = float(data["joypad_deadzone"])

	clear_all_tetris_bindings()

	var actions_dict: Dictionary = data["actions"]
	for act in actions_dict.keys():
		var act_name: String = str(act)
		var events_list = actions_dict[act]
		if not (events_list is Array):
			continue
		for ev_data in events_list:
			if not (ev_data is Dictionary):
				continue
			var ev_type: String = str(ev_data.get("type", ""))
			match ev_type:
				"key":
					var code: int = int(ev_data.get("keycode", KEY_NONE))
					if code != KEY_NONE:
						add_key_binding(act_name, code as Key)
				"joy_button":
					var btn: int = int(ev_data.get("button_index", -1))
					if btn >= 0:
						add_joy_button_binding(act_name, btn as JoyButton)
				"joy_axis":
					var axis: int = int(ev_data.get("axis", -1))
					var val: float = float(ev_data.get("axis_value", 0.0))
					if axis >= 0:
						add_joy_axis_binding(act_name, axis as JoyAxis, val)

	bindings_changed.emit()
	profile_changed.emit(current_profile)
	return true

## Saves input configuration to a JSON file
func save_profile_to_file(path: String = "user://input_config.json") -> bool:
	var dict: Dictionary = export_profile_dictionary()
	var json_str: String = JSON.stringify(dict, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_str)
	file.close()
	return true

## Loads input configuration from a JSON file
func load_profile_from_file(path: String = "user://input_config.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_str: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_err = json.parse(json_str)
	if parse_err != OK or not (json.data is Dictionary):
		return false

	return import_profile_dictionary(json.data)
