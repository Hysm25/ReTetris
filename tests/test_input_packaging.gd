class_name TestInputPackaging
extends RefCounted

## Automated test suite for Phase 5: Controller Remapping, Input Profiles & Packaging.
## Validates InputManager mappings, profiles, SOCD cleaning, serialization,
## VirtualGamepad multi-touch hit-testing, and export preset configuration.

const Constants = preload("res://src/core/constants.gd")
const InputManagerClass = preload("res://src/core/input_manager.gd")
const VirtualGamepadClass = preload("res://src/game/virtual_gamepad.gd")

static func run_all_tests() -> bool:
	print(">>> Running Phase 5: Controller Remapping, Input Profiles & Packaging Tests <<<")
	var success: bool = true

	success = test_input_manager_initialization() and success
	success = test_input_profiles() and success
	success = test_socd_cleaner_neutral() and success
	success = test_socd_cleaner_priority() and success
	success = test_socd_cleaner_last_input() and success
	success = test_remapping_and_serialization() and success
	success = test_mock_raw_mask_and_poll() and success
	success = test_virtual_gamepad_simulation() and success
	success = test_export_presets_configuration() and success
	success = test_desktop_packaging_metadata() and success

	if success:
		print("  -> TestInputPackaging: ALL 10 TESTS PASSED")
	else:
		push_error("  -> TestInputPackaging: FAILED")
	return success

static func test_input_manager_initialization() -> bool:
	print("  [1/10] Testing InputManager initialization & action mappings...")
	var mgr = InputManagerClass.new()
	mgr.init_default_mappings()

	var required_actions: Array[String] = [
		InputManagerClass.ACTION_LEFT,
		InputManagerClass.ACTION_RIGHT,
		InputManagerClass.ACTION_DOWN,
		InputManagerClass.ACTION_UP,
		InputManagerClass.ACTION_A,
		InputManagerClass.ACTION_B,
		InputManagerClass.ACTION_START,
		InputManagerClass.ACTION_SELECT,
		InputManagerClass.ACTION_TOGGLE_CRT,
		InputManagerClass.ACTION_RESET
	]

	for act in required_actions:
		if not InputMap.has_action(act):
			push_error("Missing required action in InputMap: " + act)
			mgr.free()
			return false
		var evs: Array[InputEvent] = InputMap.action_get_events(act)
		if evs.is_empty():
			push_error("Action has no bindings: " + act)
			mgr.free()
			return false

	mgr.free()
	print("    -> InputManager action mappings verified")
	return true

static func test_input_profiles() -> bool:
	print("  [2/10] Testing Input Profiles (Default, WASD, Gamepad)...")
	var mgr = InputManagerClass.new()

	# 1. Default Keyboard Profile
	mgr.apply_profile(InputManagerClass.ProfileType.DEFAULT_KEYBOARD)
	if mgr.current_profile != InputManagerClass.ProfileType.DEFAULT_KEYBOARD:
		mgr.free()
		return false

	# 2. WASD Profile
	mgr.apply_profile(InputManagerClass.ProfileType.WASD_KEYBOARD)
	if mgr.current_profile != InputManagerClass.ProfileType.WASD_KEYBOARD:
		mgr.free()
		return false
	var left_evs: Array[InputEvent] = InputMap.action_get_events(InputManagerClass.ACTION_LEFT)
	var has_key_a: bool = false
	for ev in left_evs:
		if ev is InputEventKey and (ev.keycode == KEY_A or ev.physical_keycode == KEY_A):
			has_key_a = true
			break
	if not has_key_a:
		push_error("WASD profile missing Key A on tetris_left")
		mgr.free()
		return false

	# 3. Gamepad Standard Profile
	mgr.apply_profile(InputManagerClass.ProfileType.GAMEPAD_STANDARD)
	if mgr.current_profile != InputManagerClass.ProfileType.GAMEPAD_STANDARD:
		mgr.free()
		return false
	var a_evs: Array[InputEvent] = InputMap.action_get_events(InputManagerClass.ACTION_A)
	var has_joy_btn: bool = false
	for ev in a_evs:
		if ev is InputEventJoypadButton:
			has_joy_btn = true
			break
	if not has_joy_btn:
		push_error("Gamepad profile missing joypad button on tetris_a")
		mgr.free()
		return false

	# Reset back to default
	mgr.apply_profile(InputManagerClass.ProfileType.DEFAULT_KEYBOARD)
	mgr.free()
	print("    -> Profiles verified successfully")
	return true

static func test_socd_cleaner_neutral() -> bool:
	print("  [3/10] Testing SOCD Cleaner in NEUTRAL mode...")
	var mgr = InputManagerClass.new()
	mgr.socd_mode = InputManagerClass.SOCDMode.NEUTRAL

	# Left + Right -> Neutral (both cancelled)
	var raw_lr: int = Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT
	var clean_lr: int = mgr.clean_socd(raw_lr)
	if (clean_lr & (Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT)) != 0:
		push_error("SOCD Neutral failed: Left + Right should result in neutral, got: %X" % clean_lr)
		mgr.free()
		return false

	# Up + Down -> Neutral (both cancelled)
	var raw_ud: int = Constants.BUTTON_UP | Constants.BUTTON_DOWN
	var clean_ud: int = mgr.clean_socd(raw_ud)
	if (clean_ud & (Constants.BUTTON_UP | Constants.BUTTON_DOWN)) != 0:
		push_error("SOCD Neutral failed: Up + Down should result in neutral, got: %X" % clean_ud)
		mgr.free()
		return false

	# Left + Right + Button A -> Button A only
	var raw_lra: int = Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT | Constants.BUTTON_A
	var clean_lra: int = mgr.clean_socd(raw_lra)
	if clean_lra != Constants.BUTTON_A:
		push_error("SOCD Neutral failed: Left + Right + A should be A, got: %X" % clean_lra)
		mgr.free()
		return false

	# Single direction preserved
	if mgr.clean_socd(Constants.BUTTON_LEFT) != Constants.BUTTON_LEFT:
		mgr.free()
		return false
	if mgr.clean_socd(Constants.BUTTON_DOWN) != Constants.BUTTON_DOWN:
		mgr.free()
		return false

	mgr.free()
	print("    -> SOCD Neutral mode verified")
	return true

static func test_socd_cleaner_priority() -> bool:
	print("  [4/10] Testing SOCD Cleaner in PRIORITY mode...")
	var mgr = InputManagerClass.new()
	mgr.socd_mode = InputManagerClass.SOCDMode.PRIORITY

	# Left + Right -> Left has priority
	var raw_lr: int = Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT
	var clean_lr: int = mgr.clean_socd(raw_lr)
	if clean_lr != Constants.BUTTON_LEFT:
		push_error("SOCD Priority failed: Left + Right should yield Left, got: %X" % clean_lr)
		mgr.free()
		return false

	# Up + Down -> Up has priority
	var raw_ud: int = Constants.BUTTON_UP | Constants.BUTTON_DOWN
	var clean_ud: int = mgr.clean_socd(raw_ud)
	if clean_ud != Constants.BUTTON_UP:
		push_error("SOCD Priority failed: Up + Down should yield Up, got: %X" % clean_ud)
		mgr.free()
		return false

	mgr.free()
	print("    -> SOCD Priority mode verified")
	return true

static func test_socd_cleaner_last_input() -> bool:
	print("  [5/10] Testing SOCD Cleaner in LAST_INPUT mode...")
	var mgr = InputManagerClass.new()
	mgr.socd_mode = InputManagerClass.SOCDMode.LAST_INPUT

	# Frame 1: Left is pressed
	var f1: int = mgr.clean_socd(Constants.BUTTON_LEFT)
	if f1 != Constants.BUTTON_LEFT:
		mgr.free()
		return false

	# Frame 2: Right is added while Left is still held -> Right wins (last input)
	var f2: int = mgr.clean_socd(Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT)
	if f2 != Constants.BUTTON_RIGHT:
		push_error("SOCD Last Input failed: Expected Right to win, got: %X" % f2)
		mgr.free()
		return false

	# Frame 3: Right is released, Left is still held
	var f3: int = mgr.clean_socd(Constants.BUTTON_LEFT)
	if f3 != Constants.BUTTON_LEFT:
		push_error("SOCD Last Input failed: Expected Left to resume, got: %X" % f3)
		mgr.free()
		return false

	# Frame 4: Left released
	mgr.clean_socd(0)

	# Frame 5: Down pressed, then Up added -> Up wins
	mgr.clean_socd(Constants.BUTTON_DOWN)
	var f6: int = mgr.clean_socd(Constants.BUTTON_DOWN | Constants.BUTTON_UP)
	if f6 != Constants.BUTTON_UP:
		push_error("SOCD Last Input failed: Expected Up to win, got: %X" % f6)
		mgr.free()
		return false

	mgr.free()
	print("    -> SOCD Last Input mode verified")
	return true

static func test_remapping_and_serialization() -> bool:
	print("  [6/10] Testing Remapping API & JSON Profile Persistence...")
	var mgr = InputManagerClass.new()
	mgr.init_default_mappings()

	# Custom bind Key P to action tetris_a
	mgr.add_key_binding(InputManagerClass.ACTION_A, KEY_P)
	var exported: Dictionary = mgr.export_profile_dictionary()
	if not exported.has("actions") or not exported["actions"].has(InputManagerClass.ACTION_A):
		push_error("Failed to export profile dictionary")
		mgr.free()
		return false

	# Verify serialization to file
	var test_path: String = "user://test_input_config.json"
	var save_ok: bool = mgr.save_profile_to_file(test_path)
	if not save_ok:
		push_error("Failed to save input profile to " + test_path)
		mgr.free()
		return false

	# Clear and reload from file
	mgr.clear_all_tetris_bindings()
	if InputMap.action_get_events(InputManagerClass.ACTION_A).size() != 0:
		push_error("Failed to clear action events")
		mgr.free()
		return false

	var load_ok: bool = mgr.load_profile_from_file(test_path)
	if not load_ok:
		push_error("Failed to load input profile from " + test_path)
		mgr.free()
		return false

	var reloaded_evs: Array[InputEvent] = InputMap.action_get_events(InputManagerClass.ACTION_A)
	var has_key_p: bool = false
	for ev in reloaded_evs:
		if ev is InputEventKey and (ev.keycode == KEY_P or ev.physical_keycode == KEY_P):
			has_key_p = true
			break
	if not has_key_p:
		push_error("Reloaded profile missing custom KEY_P binding")
		mgr.free()
		return false

	# Test resilience against corrupt JSON data
	var bad_import: bool = mgr.import_profile_dictionary({"corrupt": "data"})
	if bad_import:
		push_error("Expected import_profile_dictionary to reject corrupt data")
		mgr.free()
		return false

	# Clean up test file
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	mgr.apply_profile(InputManagerClass.ProfileType.DEFAULT_KEYBOARD)
	mgr.free()
	print("    -> Remapping & serialization verified successfully")
	return true

static func test_mock_raw_mask_and_poll() -> bool:
	print("  [7/10] Testing 60 TPS Input Polling via Mock Mask...")
	var mgr = InputManagerClass.new()
	mgr.socd_mode = InputManagerClass.SOCDMode.NEUTRAL

	# Normal single button
	mgr.set_mock_raw_mask(Constants.BUTTON_START)
	var mask1: int = mgr.poll_button_mask()
	if mask1 != Constants.BUTTON_START:
		push_error("Expected BUTTON_START, got %X" % mask1)
		mgr.free()
		return false

	# Simultaneous Left + Right + A (SOCD neutral cleans Left/Right)
	mgr.set_mock_raw_mask(Constants.BUTTON_LEFT | Constants.BUTTON_RIGHT | Constants.BUTTON_A)
	var mask2: int = mgr.poll_button_mask()
	if mask2 != Constants.BUTTON_A:
		push_error("Expected BUTTON_A after SOCD clean, got %X" % mask2)
		mgr.free()
		return false

	# Reset mock
	mgr.set_mock_raw_mask(-1)
	mgr.free()
	print("    -> Mock mask polling verified")
	return true

static func test_virtual_gamepad_simulation() -> bool:
	print("  [8/10] Testing VirtualGamepad touch simulation & hit-testing...")
	var mgr = InputManagerClass.new()
	var pad = VirtualGamepadClass.new(mgr)
	pad.set_active(true)

	# 1. Hit-test D-pad Left
	var left_pt: Vector2 = pad.rect_dpad_left.position + pad.rect_dpad_left.size * 0.5
	var mask_l: int = pad._hit_test(left_pt)
	if mask_l != Constants.BUTTON_LEFT:
		push_error("VirtualGamepad hit-test failed for D-pad Left: got %X" % mask_l)
		pad.free()
		mgr.free()
		return false

	# 2. Hit-test Button A
	var a_pt: Vector2 = pad.rect_btn_a.position + pad.rect_btn_a.size * 0.5
	var mask_a: int = pad._hit_test(a_pt)
	if mask_a != Constants.BUTTON_A:
		push_error("VirtualGamepad hit-test failed for Button A: got %X" % mask_a)
		pad.free()
		mgr.free()
		return false

	# 3. Hit-test Start & Select
	var start_pt: Vector2 = pad.rect_start.position + pad.rect_start.size * 0.5
	var mask_start: int = pad._hit_test(start_pt)
	if mask_start != Constants.BUTTON_START:
		push_error("VirtualGamepad hit-test failed for Start: got %X" % mask_start)
		pad.free()
		mgr.free()
		return false

	# 4. Multi-touch integration
	pad._handle_touch_event(0, left_pt, true)
	pad._handle_touch_event(1, a_pt, true)
	if pad.current_mask != (Constants.BUTTON_LEFT | Constants.BUTTON_A):
		push_error("VirtualGamepad multi-touch failed: got %X" % pad.current_mask)
		pad.free()
		mgr.free()
		return false

	# Verify sync with InputManager
	if mgr.virtual_gamepad_mask != (Constants.BUTTON_LEFT | Constants.BUTTON_A):
		push_error("InputManager virtual mask desynced: got %X" % mgr.virtual_gamepad_mask)
		pad.free()
		mgr.free()
		return false

	# Release touch 0 (Left), keep touch 1 (A)
	pad._handle_touch_event(0, left_pt, false)
	if pad.current_mask != Constants.BUTTON_A or mgr.virtual_gamepad_mask != Constants.BUTTON_A:
		push_error("VirtualGamepad touch release sync failed")
		pad.free()
		mgr.free()
		return false

	# Deactivate
	pad.set_active(false)
	if mgr.virtual_gamepad_mask != 0:
		push_error("VirtualGamepad deactivate did not clear mask")
		pad.free()
		mgr.free()
		return false

	# 5. Dynamic Layout Anchoring (Widescreen 426x240)
	pad.set_active(true)
	pad.update_layout(Vector2(426.0, 240.0))
	if absf(pad.rect_btn_b.position.x - (426.0 - 70.0)) > 0.01:
		push_error("VirtualGamepad widescreen Button B anchoring failed: %v" % pad.rect_btn_b.position)
		pad.free()
		mgr.free()
		return false
	if absf(pad.rect_btn_a.position.x - (426.0 - 36.0)) > 0.01:
		push_error("VirtualGamepad widescreen Button A anchoring failed: %v" % pad.rect_btn_a.position)
		pad.free()
		mgr.free()
		return false
	if absf(pad.rect_select.position.x - (213.0 - 32.0)) > 0.01:
		push_error("VirtualGamepad widescreen Select anchoring failed: %v" % pad.rect_select.position)
		pad.free()
		mgr.free()
		return false

	# 6. Direct Hit-testing in widescreen space
	var wide_a_pt: Vector2 = pad.rect_btn_a.position + pad.rect_btn_a.size * 0.5
	if pad._hit_test(wide_a_pt) != Constants.BUTTON_A:
		push_error("VirtualGamepad widescreen hit-test failed for Button A")
		pad.free()
		mgr.free()
		return false

	# 7. Auto-hide on physical keyboard event
	var ev_key: InputEventKey = InputEventKey.new()
	ev_key.pressed = true
	ev_key.keycode = KEY_SPACE
	pad._input(ev_key)
	if pad.is_active:
		push_error("VirtualGamepad did not auto-hide on keyboard event")
		pad.free()
		mgr.free()
		return false

	# 8. Auto-show on touch event
	var ev_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	ev_touch.pressed = true
	ev_touch.position = wide_a_pt
	pad._input(ev_touch)
	if not pad.is_active:
		push_error("VirtualGamepad did not auto-show on touch event")
		pad.free()
		mgr.free()
		return false

	# 9. Auto-hide on joypad button event
	var ev_joy: InputEventJoypadButton = InputEventJoypadButton.new()
	ev_joy.pressed = true
	ev_joy.button_index = JOY_BUTTON_A
	pad._input(ev_joy)
	if pad.is_active:
		push_error("VirtualGamepad did not auto-hide on joypad button event")
		pad.free()
		mgr.free()
		return false

	pad.free()
	mgr.free()
	print("    -> VirtualGamepad simulation verified successfully")
	return true

static func test_export_presets_configuration() -> bool:
	print("  [9/10] Testing export_presets.cfg configuration...")
	var path: String = "res://export_presets.cfg"
	if not FileAccess.file_exists(path):
		push_error("export_presets.cfg not found")
		return false

	var cfg: ConfigFile = ConfigFile.new()
	var err = cfg.load(path)
	if err != OK:
		push_error("Failed to parse export_presets.cfg")
		return false

	# Verify preset sections
	var expected_sections: Array[String] = ["preset.0", "preset.1", "preset.2", "preset.3"]
	for sec in expected_sections:
		if not cfg.has_section(sec):
			push_error("Missing export preset section: " + sec)
			return false

	# Verify Linux preset
	var linux_name: String = str(cfg.get_value("preset.0", "name", ""))
	if linux_name != "Linux/X11 Desktop":
		push_error("Unexpected preset 0 name: " + linux_name)
		return false

	# Verify clean-room boundary filter protects copyrighted / disassembly files
	var exclude_filter: String = str(cfg.get_value("preset.0", "exclude_filter", ""))
	if not exclude_filter.contains("TetrisNESDisasm/*") or not exclude_filter.contains("*.nes"):
		push_error("export_presets.cfg exclude_filter does not protect clean-room boundary: " + exclude_filter)
		return false

	print("    -> export_presets.cfg verified successfully")
	return true

static func test_desktop_packaging_metadata() -> bool:
	print("  [10/10] Testing Desktop entry and build script metadata...")
	# 1. Check desktop file
	var desktop_path: String = "res://packaging/retetris.desktop"
	if not FileAccess.file_exists(desktop_path):
		push_error("packaging/retetris.desktop missing")
		return false
	var df = FileAccess.open(desktop_path, FileAccess.READ)
	var content: String = df.get_as_text()
	df.close()
	if not content.contains("[Desktop Entry]") or not content.contains("Exec=retetris"):
		push_error("packaging/retetris.desktop invalid")
		return false

	# 2. Check build script
	var script_path: String = "res://scripts/build_package.sh"
	if not FileAccess.file_exists(script_path):
		push_error("scripts/build_package.sh missing")
		return false
	var sf = FileAccess.open(script_path, FileAccess.READ)
	var s_content: String = sf.get_as_text()
	sf.close()
	if not s_content.contains("#!/usr/bin/env bash") or not s_content.contains("retetris.pck"):
		push_error("scripts/build_package.sh invalid")
		return false

	print("    -> Desktop metadata and packaging runner verified")
	return true
