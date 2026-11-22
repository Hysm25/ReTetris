class_name VirtualGamepad
extends CanvasLayer

## Mobile touch-screen on-screen virtual controller for ReTetris.
## Emulates the classic 1989 NES controller layout with multi-touch support:
## - 4-way Directional Pad (Left, Right, Down, Up) on bottom-left
## - Authentic Button B and Button A on bottom-right
## - Select and Start pill buttons in bottom-center
## Directly updates InputManager's virtual gamepad bitmask.

const Constants = preload("res://src/core/constants.gd")

# Button bounding rectangles in viewport coordinates
# D-pad cross centered at bottom-left margin
const DEFAULT_DPAD_CENTER: Vector2 = Vector2(36, 196)
const DPAD_BUTTON_SIZE: Vector2 = Vector2(18, 18)

var dpad_center: Vector2 = DEFAULT_DPAD_CENTER
var rect_dpad_left: Rect2 = Rect2(DEFAULT_DPAD_CENTER.x - 28, DEFAULT_DPAD_CENTER.y - 9, 18, 18)
var rect_dpad_right: Rect2 = Rect2(DEFAULT_DPAD_CENTER.x + 10, DEFAULT_DPAD_CENTER.y - 9, 18, 18)
var rect_dpad_up: Rect2 = Rect2(DEFAULT_DPAD_CENTER.x - 9, DEFAULT_DPAD_CENTER.y - 28, 18, 18)
var rect_dpad_down: Rect2 = Rect2(DEFAULT_DPAD_CENTER.x - 9, DEFAULT_DPAD_CENTER.y + 10, 18, 18)

# Center pill buttons: Select and Start
var rect_select: Rect2 = Rect2(96, 218, 26, 12)
var rect_start: Rect2 = Rect2(134, 218, 26, 12)

# Action buttons: B and A on right side
var rect_btn_b: Rect2 = Rect2(186, 194, 22, 22)
var rect_btn_a: Rect2 = Rect2(220, 182, 22, 22)

# Visual Colors (Authentic NES controller grey / red palette)
const COLOR_PAD_BODY: Color = Color(0.2, 0.2, 0.2, 0.6)
const COLOR_PAD_ACTIVE: Color = Color(0.8, 0.1, 0.1, 0.85)
const COLOR_BUTTON_RED: Color = Color("#B53120")
const COLOR_BUTTON_RED_PRESSED: Color = Color("#FE8176")
const COLOR_PILL_GREY: Color = Color(0.4, 0.4, 0.4, 0.7)
const COLOR_PILL_PRESSED: Color = Color(0.8, 0.8, 0.8, 0.9)
const COLOR_BORDER: Color = Color(1.0, 1.0, 1.0, 0.5)

# State
var is_active: bool = false
var touch_points: Dictionary = {} # Touch ID -> Bitmask of buttons pressed by this touch
var current_mask: int = 0
var input_manager: Node = null

# CanvasItem overlay node for custom drawing
var _draw_node: Node2D = null

func _init(p_input_manager: Node = null) -> void:
	input_manager = p_input_manager
	layer = 10 # Sit above gameplay canvas
	update_layout(Vector2(float(Constants.SCREEN_WIDTH), float(Constants.SCREEN_HEIGHT)))

func _ready() -> void:
	if input_manager == null:
		input_manager = get_node_or_null("/root/InputManager")

	_draw_node = Node2D.new()
	_draw_node.name = "VirtualPadDraw"
	_draw_node.draw.connect(_on_draw_overlay)
	add_child(_draw_node)

	var vp: Viewport = get_viewport()
	if vp != null:
		if not vp.size_changed.is_connected(_on_viewport_size_changed):
			vp.size_changed.connect(_on_viewport_size_changed)
	update_layout()

	# Auto-enable on mobile platforms
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		set_active(true)
	else:
		set_active(false)

func _on_viewport_size_changed() -> void:
	update_layout()
	if _draw_node != null:
		_draw_node.queue_redraw()

## Dynamically anchors virtual controls relative to the visible viewport boundaries
func update_layout(custom_size: Vector2 = Vector2.ZERO) -> void:
	var vp_size: Vector2 = custom_size
	if vp_size == Vector2.ZERO:
		var vp: Viewport = get_viewport()
		if vp != null:
			vp_size = vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(float(Constants.SCREEN_WIDTH), float(Constants.SCREEN_HEIGHT))

	# D-pad center anchored to bottom-left margin
	dpad_center = Vector2(36.0, vp_size.y - 44.0)
	rect_dpad_left = Rect2(dpad_center.x - 28.0, dpad_center.y - 9.0, 18.0, 18.0)
	rect_dpad_right = Rect2(dpad_center.x + 10.0, dpad_center.y - 9.0, 18.0, 18.0)
	rect_dpad_up = Rect2(dpad_center.x - 9.0, dpad_center.y - 28.0, 18.0, 18.0)
	rect_dpad_down = Rect2(dpad_center.x - 9.0, dpad_center.y + 10.0, 18.0, 18.0)

	# Action buttons anchored to far bottom-right margin
	rect_btn_b = Rect2(vp_size.x - 70.0, vp_size.y - 46.0, 22.0, 22.0)
	rect_btn_a = Rect2(vp_size.x - 36.0, vp_size.y - 58.0, 22.0, 22.0)

	# Center pill buttons: Select and Start anchored to bottom center
	var center_x: float = vp_size.x * 0.5
	var bottom_y: float = vp_size.y - 22.0
	rect_select = Rect2(center_x - 32.0, bottom_y, 26.0, 12.0)
	rect_start = Rect2(center_x + 6.0, bottom_y, 26.0, 12.0)

func set_active(active: bool) -> void:
	is_active = active
	visible = active
	if is_active:
		update_layout()
	else:
		current_mask = 0
		touch_points.clear()
		_sync_with_input_manager()
	if _draw_node != null:
		_draw_node.queue_redraw()

func toggle_active() -> void:
	set_active(not is_active)

func _input(event: InputEvent) -> void:
	# Auto-show on touch screen event
	if event is InputEventScreenTouch and event.pressed:
		if not is_active:
			set_active(true)

	# Auto-hide on physical keyboard or hardware gamepad input
	if is_active:
		if event is InputEventKey and event.pressed and not event.echo:
			set_active(false)
			return
		elif event is InputEventJoypadButton and event.pressed:
			set_active(false)
			return
		elif event is InputEventJoypadMotion:
			var deadzone: float = input_manager.joypad_deadzone if (input_manager != null and "joypad_deadzone" in input_manager) else 0.3
			if absf(event.axis_value) > deadzone:
				set_active(false)
				return

	if not is_active:
		return

	if event is InputEventScreenTouch:
		_handle_touch_event(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_touch_event(event.index, event.position, true)
	elif event is InputEventMouseButton:
		# Also support mouse clicks for testing on desktop
		_handle_touch_event(0, event.position, event.pressed)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_handle_touch_event(0, event.position, true)

func _handle_touch_event(touch_id: int, screen_pos: Vector2, pressed: bool) -> void:
	if not pressed:
		touch_points.erase(touch_id)
	else:
		var vp_pos: Vector2 = _screen_to_viewport(screen_pos)
		var mask: int = _hit_test(vp_pos)
		touch_points[touch_id] = mask

	# Recalculate combined mask from all active touches
	var new_mask: int = 0
	for m in touch_points.values():
		new_mask |= int(m)

	if new_mask != current_mask:
		current_mask = new_mask
		_sync_with_input_manager()
		if _draw_node != null:
			_draw_node.queue_redraw()

func _screen_to_viewport(pos: Vector2) -> Vector2:
	return pos

func _hit_test(pos: Vector2) -> int:
	var mask: int = 0
	if rect_dpad_left.has_point(pos):
		mask |= Constants.BUTTON_LEFT
	if rect_dpad_right.has_point(pos):
		mask |= Constants.BUTTON_RIGHT
	if rect_dpad_up.has_point(pos):
		mask |= Constants.BUTTON_UP
	if rect_dpad_down.has_point(pos):
		mask |= Constants.BUTTON_DOWN
	if rect_btn_a.has_point(pos):
		mask |= Constants.BUTTON_A
	if rect_btn_b.has_point(pos):
		mask |= Constants.BUTTON_B
	if rect_start.has_point(pos):
		mask |= Constants.BUTTON_START
	if rect_select.has_point(pos):
		mask |= Constants.BUTTON_SELECT
	return mask

func _sync_with_input_manager() -> void:
	if input_manager != null and input_manager.has_method("set_virtual_gamepad_mask"):
		input_manager.set_virtual_gamepad_mask(current_mask)

func _on_draw_overlay() -> void:
	if not is_active or _draw_node == null:
		return

	# Draw D-pad buttons
	_draw_rect_button(rect_dpad_left, (current_mask & Constants.BUTTON_LEFT) != 0, COLOR_PAD_BODY, COLOR_PAD_ACTIVE, "<")
	_draw_rect_button(rect_dpad_right, (current_mask & Constants.BUTTON_RIGHT) != 0, COLOR_PAD_BODY, COLOR_PAD_ACTIVE, ">")
	_draw_rect_button(rect_dpad_up, (current_mask & Constants.BUTTON_UP) != 0, COLOR_PAD_BODY, COLOR_PAD_ACTIVE, "^")
	_draw_rect_button(rect_dpad_down, (current_mask & Constants.BUTTON_DOWN) != 0, COLOR_PAD_BODY, COLOR_PAD_ACTIVE, "v")

	# Draw Action buttons: B and A
	_draw_round_button(rect_btn_b, (current_mask & Constants.BUTTON_B) != 0, COLOR_BUTTON_RED, COLOR_BUTTON_RED_PRESSED, "B")
	_draw_round_button(rect_btn_a, (current_mask & Constants.BUTTON_A) != 0, COLOR_BUTTON_RED, COLOR_BUTTON_RED_PRESSED, "A")

	# Draw Select and Start pill buttons
	_draw_pill_button(rect_select, (current_mask & Constants.BUTTON_SELECT) != 0, "SEL")
	_draw_pill_button(rect_start, (current_mask & Constants.BUTTON_START) != 0, "START")

func _draw_rect_button(r: Rect2, pressed: bool, normal_col: Color, active_col: Color, _label: String) -> void:
	var col: Color = active_col if pressed else normal_col
	_draw_node.draw_rect(r, col, true)
	_draw_node.draw_rect(r, COLOR_BORDER, false, 1.0)

func _draw_round_button(r: Rect2, pressed: bool, normal_col: Color, active_col: Color, _label: String) -> void:
	var center: Vector2 = r.position + r.size * 0.5
	var radius: float = r.size.x * 0.5
	var col: Color = active_col if pressed else normal_col
	_draw_node.draw_circle(center, radius, col)
	_draw_node.draw_arc(center, radius, 0, TAU, 16, COLOR_BORDER, 1.0)

func _draw_pill_button(r: Rect2, pressed: bool, _label: String) -> void:
	var col: Color = COLOR_PILL_PRESSED if pressed else COLOR_PILL_GREY
	_draw_node.draw_rect(r, col, true)
	_draw_node.draw_rect(r, COLOR_BORDER, false, 1.0)
