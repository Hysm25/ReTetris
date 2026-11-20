class_name PlayfieldRenderer
extends Node2D

## 1989 NES Tetris authentic CanvasItem playfield and HUD renderer.
## Renders the 256x240 native NES viewport:
## - 10x20 visible playfield at authentic screen offsets (X: 96, Y: 40)
## - Locked grid cells using procedural or extracted 8x8 tile textures
## - Active falling tetromino from PieceController
## - Next-piece preview box (X: 192, Y: 112)
## - Center-outward line clear animation
## - Authentic HUD elements (Score, Lines, Level, Piece Statistics)

const Constants = preload("res://src/core/constants.gd")
const BoardGrid = preload("res://src/game/board_grid.gd")
const PieceController = preload("res://src/game/piece_controller.gd")
const GameStateMachine = preload("res://src/game/game_state_machine.gd")

# Optional direct reference to GameStateMachine (for single-node setup)
var game_state: GameStateMachine = null
var menu_ctrl: RefCounted = null

# Cached HUD and Game State
var current_level: int = 0
var current_score: int = 0
var top_score: int = 0
var current_lines: int = 0
var next_piece_type: int = Constants.PieceType.T
var piece_stats: Array[int] = [0, 0, 0, 0, 0, 0, 0] # T, J, Z, O, S, L, I
var is_game_over: bool = false
var clearing_rows: Array[int] = []
var clearing_step: int = -1

# Visual Colors
const COLOR_BLACK: Color = Color(0.0, 0.0, 0.0, 1.0)
const COLOR_WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_BORDER_FRAME: Color = Color("#666666")
const COLOR_BORDER_ACCENT: Color = Color("#ADADAD")
const COLOR_TEXT_RED: Color = Color("#FE8176")

# Font cache (built-in fallback system font)
var _hud_font: Font = null

# Optional low-overhead CRT scanline overlay
var enable_crt_shader: bool = false
var crt_overlay: CanvasLayer = null
var crt_rect: ColorRect = null

func set_crt_shader(enabled: bool) -> void:
	enable_crt_shader = enabled
	_update_crt_overlay()

func toggle_crt_shader() -> void:
	enable_crt_shader = not enable_crt_shader
	_update_crt_overlay()

func _update_crt_overlay() -> void:
	if not is_inside_tree():
		return
	if enable_crt_shader:
		if crt_overlay == null:
			crt_overlay = CanvasLayer.new()
			crt_overlay.name = "CRTOverlay"
			crt_rect = ColorRect.new()
			crt_rect.name = "CRTRect"
			crt_rect.size = Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
			crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mat = ShaderMaterial.new()
			mat.shader = load("res://src/shaders/crt_scanlines.gdshader")
			crt_rect.material = mat
			crt_overlay.add_child(crt_rect)
			add_child(crt_overlay)
		crt_overlay.visible = true
	else:
		if crt_overlay != null:
			crt_overlay.visible = false

func _init(p_game_state: GameStateMachine = null, p_menu_ctrl: RefCounted = null) -> void:
	game_state = p_game_state
	menu_ctrl = p_menu_ctrl

func _ready() -> void:
	_hud_font = ThemeDB.fallback_font
	_connect_event_bus()

func _connect_event_bus() -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null:
		return

	if not bus.is_connected("piece_spawned", _on_piece_spawned):
		bus.connect("piece_spawned", _on_piece_spawned)
	if not bus.is_connected("piece_moved", _on_piece_moved):
		bus.connect("piece_moved", _on_piece_moved)
	if not bus.is_connected("piece_rotated", _on_piece_rotated):
		bus.connect("piece_rotated", _on_piece_rotated)
	if not bus.is_connected("piece_locked", _on_piece_locked):
		bus.connect("piece_locked", _on_piece_locked)
	if not bus.is_connected("lines_clearing", _on_lines_clearing):
		bus.connect("lines_clearing", _on_lines_clearing)
	if not bus.is_connected("lines_cleared", _on_lines_cleared):
		bus.connect("lines_cleared", _on_lines_cleared)
	if not bus.is_connected("score_updated", _on_score_updated):
		bus.connect("score_updated", _on_score_updated)
	if not bus.is_connected("lines_updated", _on_lines_updated):
		bus.connect("lines_updated", _on_lines_updated)
	if not bus.is_connected("level_updated", _on_level_updated):
		bus.connect("level_updated", _on_level_updated)
	if not bus.is_connected("game_over", _on_game_over):
		bus.connect("game_over", _on_game_over)
	if not bus.is_connected("game_restarted", _on_game_restarted):
		bus.connect("game_restarted", _on_game_restarted)

func _process(_delta: float) -> void:
	# Synchronize state from direct GameStateMachine reference if present
	if game_state != null:
		current_level = game_state.score_mgr.level
		current_score = game_state.score_mgr.score
		current_lines = game_state.score_mgr.lines
		next_piece_type = game_state.next_piece_type
		is_game_over = (game_state.current_state == GameStateMachine.State.GAME_OVER)
		if current_score > top_score:
			top_score = current_score
	queue_redraw()

# --- Draw Logic ---

func _draw() -> void:
	if game_state != null and game_state.current_state == GameStateMachine.State.ROM_SETUP:
		_draw_rom_setup_screen()
		return

	if menu_ctrl != null and menu_ctrl.get("current_mode") != Constants.MenuMode.IN_GAME and menu_ctrl.get("current_mode") != Constants.MenuMode.DEMO:
		var mode: int = menu_ctrl.get("current_mode")
		match mode:
			Constants.MenuMode.TITLE_SCREEN:
				_draw_title_screen()
			Constants.MenuMode.GAME_TYPE_MENU:
				_draw_game_type_menu()
			Constants.MenuMode.LEVEL_MENU:
				_draw_level_menu()
			Constants.MenuMode.HIGH_SCORE_ENTRY:
				_draw_high_score_entry()
			Constants.MenuMode.HIGH_SCORE_TABLE:
				_draw_high_score_table()
		return

	if game_state != null and game_state.current_state == GameStateMachine.State.ENDING_ANIMATION:
		_draw_ending_animation()
		return

	_draw_background()
	_draw_playfield_frame()
	_draw_playfield_matrix()
	_draw_active_piece()
	_draw_preview_box()
	_draw_hud()
	if is_game_over:
		_draw_game_over_banner()

func _draw_title_screen() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_title_screen_texture"):
		var tex: ImageTexture = reg.get_title_screen_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			_draw_text("TETRIS", Vector2(104, 70), COLOR_WHITE)
	else:
		_draw_text("TETRIS", Vector2(104, 70), COLOR_WHITE)

	if menu_ctrl != null and (int(menu_ctrl.get("cursor_timer")) & 0x10) != 0:
		_draw_text("PUSH START BUTTON", Vector2(56, 170), COLOR_WHITE)

func _draw_game_type_menu() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_game_type_menu_texture"):
		var tex: ImageTexture = reg.get_game_type_menu_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)

	if menu_ctrl == null:
		return

	var timer: int = int(menu_ctrl.get("cursor_timer"))
	if (timer & 0x08) != 0:
		var g_type: int = int(menu_ctrl.get("game_type"))
		var cursor_x: float = 48.0 if g_type == Constants.GameType.TYPE_A else 144.0
		draw_rect(Rect2(cursor_x, 56, 64, 24), COLOR_BORDER_ACCENT, false, 2.0)

	if (timer & 0x08) != 0:
		var m_type: int = int(menu_ctrl.get("music_type"))
		var music_y: float = 135.0 + float(m_type) * 16.0
		draw_rect(Rect2(88, music_y, 80, 14), COLOR_WHITE, false, 1.0)

func _draw_level_menu() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var g_type: int = int(menu_ctrl.get("game_type")) if menu_ctrl != null else 0
	if reg != null and reg.has_method("get_level_menu_texture"):
		var tex: ImageTexture = reg.get_level_menu_texture(g_type)
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)

	if menu_ctrl == null:
		return

	var timer: int = int(menu_ctrl.get("cursor_timer"))
	var sel_lvl: int = int(menu_ctrl.get("selected_level")) % 10
	var col: int = sel_lvl % 5
	var row: int = sel_lvl / 5
	var lx: float = 48.0 + float(col) * 16.0
	var ly: float = 78.0 + float(row) * 16.0

	var is_sel_height: bool = bool(menu_ctrl.get("selecting_height"))
	var show_lvl: bool = true
	if not is_sel_height:
		show_lvl = ((timer & 0x08) != 0)

	if show_lvl:
		draw_rect(Rect2(lx, ly, 14, 14), COLOR_BORDER_ACCENT, false, 2.0)

	if g_type == Constants.GameType.TYPE_B:
		var sel_h: int = int(menu_ctrl.get("selected_height"))
		var h_col: int = sel_h % 3
		var h_row: int = sel_h / 3
		var hx: float = 152.0 + float(h_col) * 16.0
		var hy: float = 78.0 + float(h_row) * 16.0

		var show_h: bool = true
		if is_sel_height:
			show_h = ((timer & 0x08) != 0)

		if show_h:
			draw_rect(Rect2(hx, hy, 14, 14), COLOR_BORDER_ACCENT, false, 2.0)

func _draw_high_score_table() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_high_scores_texture"):
		var tex: ImageTexture = reg.get_high_scores_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
			_draw_text("TOP - 3", Vector2(104, 50), COLOR_WHITE)
	else:
		draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
		_draw_text("TOP - 3", Vector2(104, 50), COLOR_WHITE)

	if menu_ctrl == null or menu_ctrl.get("high_score_mgr") == null:
		return

	var g_type: int = int(menu_ctrl.get("game_type"))
	var type_label: String = "A-TYPE" if g_type == Constants.GameType.TYPE_A else "B-TYPE"
	_draw_text(type_label, Vector2(108, 120), COLOR_WHITE)

	var hs_mgr: RefCounted = menu_ctrl.get("high_score_mgr")
	var entries: Array = hs_mgr.call("get_entries", g_type)

	var y_offsets: Array[float] = [159.0, 175.0, 191.0]
	for i in range(mini(3, entries.size())):
		var entry: Dictionary = entries[i] as Dictionary
		var y: float = y_offsets[i]
		var name_str: String = String(entry.get("name", "      "))
		var score_val: int = int(entry.get("score", 0))
		var level_val: int = int(entry.get("level", 0))

		_draw_text(name_str, Vector2(72, y), COLOR_WHITE)
		_draw_text("%06d" % score_val, Vector2(136, y), COLOR_WHITE)
		_draw_text("%02d" % level_val, Vector2(192, y), COLOR_WHITE)

func _draw_high_score_entry() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_enter_high_score_texture"):
		var tex: ImageTexture = reg.get_enter_high_score_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
			_draw_text("CONGRATULATIONS", Vector2(72, 50), COLOR_WHITE)
	else:
		draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
		_draw_text("CONGRATULATIONS", Vector2(72, 50), COLOR_WHITE)

	if menu_ctrl == null or menu_ctrl.get("high_score_mgr") == null:
		return

	var g_type: int = int(menu_ctrl.get("entry_game_type"))
	var type_label: String = "A-TYPE" if g_type == Constants.GameType.TYPE_A else "B-TYPE"
	_draw_text(type_label, Vector2(108, 120), COLOR_WHITE)

	var hs_mgr: RefCounted = menu_ctrl.get("high_score_mgr")
	var entries: Array = hs_mgr.call("get_entries", g_type)
	var rank: int = int(menu_ctrl.get("entry_rank"))
	var cursor_idx: int = int(menu_ctrl.get("entry_char_index"))
	var timer: int = int(menu_ctrl.get("cursor_timer"))
	var name_chars: Array = menu_ctrl.get("entry_name_chars") as Array

	var y_offsets: Array[float] = [159.0, 175.0, 191.0]
	for i in range(mini(3, entries.size())):
		var y: float = y_offsets[i]
		if i == rank:
			# Currently edited entry row
			var full_name: String = "".join(name_chars)
			_draw_text(full_name, Vector2(72, y), COLOR_WHITE)
			var sc: int = int(menu_ctrl.get("entry_score"))
			var lvl: int = int(menu_ctrl.get("entry_level"))
			_draw_text("%06d" % sc, Vector2(136, y), COLOR_WHITE)
			_draw_text("%02d" % lvl, Vector2(192, y), COLOR_WHITE)

			# Flashing cursor underline under selected letter
			if (timer & 0x08) != 0:
				var cx: float = 72.0 + cursor_idx * 8.0
				draw_rect(Rect2(cx, y + 1.0, 7.0, 1.0), COLOR_WHITE)
		else:
			# Existing high score entry
			var lookup_idx: int = i if i < rank else i - 1
			if lookup_idx >= 0 and lookup_idx < entries.size():
				var entry: Dictionary = entries[lookup_idx] as Dictionary
				_draw_text(String(entry.get("name", "      ")), Vector2(72, y), COLOR_WHITE)
				_draw_text("%06d" % int(entry.get("score", 0)), Vector2(136, y), COLOR_WHITE)
				_draw_text("%02d" % int(entry.get("level", 0)), Vector2(192, y), COLOR_WHITE)

func _draw_ending_animation() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_type_a_ending_texture"):
		var tex: ImageTexture = reg.get_type_a_ending_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), Color("#000033"))
	else:
		draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), Color("#000033"))

	if game_state == null:
		return

	var rx: float = game_state.ending_rocket_x
	var ry: float = game_state.ending_rocket_y
	var tier: int = game_state.ending_tier
	var fc: int = game_state.ending_frame_counter

	# Render rocket body based on score tier
	var rocket_color: Color = COLOR_WHITE
	match tier:
		Constants.RocketTier.TIER_0_SMALL:
			draw_rect(Rect2(rx, ry, 8.0, 16.0), rocket_color)
			draw_rect(Rect2(rx + 2.0, ry - 4.0, 4.0, 4.0), COLOR_TEXT_RED)
		Constants.RocketTier.TIER_1_MEDIUM_SMALL:
			draw_rect(Rect2(rx - 4.0, ry, 16.0, 24.0), rocket_color)
			draw_rect(Rect2(rx, ry - 6.0, 8.0, 6.0), COLOR_TEXT_RED)
		Constants.RocketTier.TIER_2_MEDIUM:
			draw_rect(Rect2(rx - 8.0, ry, 24.0, 32.0), rocket_color)
			draw_rect(Rect2(rx - 4.0, ry - 8.0, 16.0, 8.0), COLOR_TEXT_RED)
		Constants.RocketTier.TIER_3_LARGE:
			draw_rect(Rect2(rx - 12.0, ry, 32.0, 48.0), rocket_color)
			draw_rect(Rect2(rx - 6.0, ry - 10.0, 20.0, 10.0), COLOR_TEXT_RED)
		Constants.RocketTier.TIER_4_CATHEDRAL:
			draw_rect(Rect2(rx - 24.0, ry, 56.0, 64.0), Color("#CC3333"))
			draw_rect(Rect2(rx - 16.0, ry - 16.0, 40.0, 16.0), Color("#FFD700"))

	# Render animated thruster jet flames during liftoff
	if fc >= Constants.ROCKET_LAUNCH_DELAY_FRAMES and ry > -20.0:
		var flame_toggle: bool = (fc & 0x02) != 0
		var flame_height: float = 12.0 if flame_toggle else 8.0
		var flame_color: Color = Color(1.0, 0.6, 0.1, 1.0)
		draw_rect(Rect2(rx + 1.0, ry + 16.0, 6.0, flame_height), flame_color)
		draw_rect(Rect2(rx + 2.0, ry + 16.0 + flame_height, 4.0, 4.0), Color(1.0, 0.2, 0.0, 1.0))

func _draw_rom_setup_screen() -> void:
	draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
	# Red warning border
	draw_rect(Rect2(12, 12, 232, 216), COLOR_TEXT_RED, false, 2.0)

	_draw_text("TETRIS ROM REQUIRED", Vector2(48, 50), COLOR_TEXT_RED)
	_draw_text("Mandatory Ingestion Mode", Vector2(40, 75), COLOR_WHITE)
	_draw_text("Zero Procedural Fallbacks", Vector2(36, 95), COLOR_BORDER_ACCENT)
	_draw_text("Please supply a valid", Vector2(44, 125), COLOR_WHITE)
	_draw_text("1989 NES Tetris ROM at:", Vector2(44, 140), COLOR_WHITE)
	_draw_text("user://nes_data/tetris.nes", Vector2(32, 160), COLOR_TEXT_RED)
	_draw_text("or in the workspace root.", Vector2(36, 175), COLOR_WHITE)
	_draw_text("Then restart the game.", Vector2(44, 205), COLOR_BORDER_ACCENT)

func _draw_background() -> void:
	# 256x240 dark canvas background
	draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)

func _draw_playfield_frame() -> void:
	var pf_x: float = float(Constants.PLAYFIELD_OFFSET_X)
	var pf_y: float = float(Constants.PLAYFIELD_OFFSET_Y)
	var pf_w: float = float(Constants.GRID_COLUMNS * Constants.TILE_SIZE)
	var pf_h: float = float(Constants.VISIBLE_ROWS * Constants.TILE_SIZE)

	# Inner Playfield Black Background
	draw_rect(Rect2(pf_x, pf_y, pf_w, pf_h), COLOR_BLACK)

	# NES Bevel Borders around Playfield (Left, Right, Bottom)
	# Left border (2px wide)
	draw_line(Vector2(pf_x - 2, pf_y - 1), Vector2(pf_x - 2, pf_y + pf_h + 2), COLOR_BORDER_FRAME, 1.0)
	draw_line(Vector2(pf_x - 1, pf_y - 1), Vector2(pf_x - 1, pf_y + pf_h + 1), COLOR_BORDER_ACCENT, 1.0)
	# Right border (2px wide)
	draw_line(Vector2(pf_x + pf_w, pf_y - 1), Vector2(pf_x + pf_w, pf_y + pf_h + 1), COLOR_BORDER_ACCENT, 1.0)
	draw_line(Vector2(pf_x + pf_w + 1, pf_y - 1), Vector2(pf_x + pf_w + 1, pf_y + pf_h + 2), COLOR_BORDER_FRAME, 1.0)
	# Bottom border (2px high)
	draw_line(Vector2(pf_x - 2, pf_y + pf_h), Vector2(pf_x + pf_w + 2, pf_y + pf_h), COLOR_BORDER_ACCENT, 1.0)
	draw_line(Vector2(pf_x - 2, pf_y + pf_h + 1), Vector2(pf_x + pf_w + 2, pf_y + pf_h + 1), COLOR_BORDER_FRAME, 1.0)

func _draw_playfield_matrix() -> void:
	var grid: BoardGrid = null
	if game_state != null:
		grid = game_state.grid
	if grid == null:
		return

	var reg: Node = get_node_or_null("/root/ContentRegistry")

	# Render visible rows 2 through 21
	for r in range(Constants.HIDDEN_ROWS, Constants.GRID_ROWS):
		for c in range(Constants.GRID_COLUMNS):
			var tile_type: int = grid.get_cell(c, r)
			if tile_type > 0:
				var screen_pos: Vector2 = grid_to_screen(Vector2i(c, r))
				if reg != null:
					var tex: Texture2D = reg.get_tile_texture(tile_type, current_level)
					if tex != null:
						draw_texture(tex, screen_pos)
				else:
					# Simple fallback rectangle if ContentRegistry not ready
					var col_fallback: Color = COLOR_WHITE if tile_type == 1 else COLOR_BORDER_ACCENT
					draw_rect(Rect2(screen_pos.x, screen_pos.y, 8, 8), col_fallback)

func _draw_active_piece() -> void:
	if game_state == null:
		return
	if game_state.current_state != GameStateMachine.State.ACTIVE_PLAY:
		return

	var piece: PieceController = game_state.piece
	if piece == null or not piece.is_active:
		return

	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var tile_type: int = Constants.TILE_TYPE_FROM_PIECE[piece.piece_type]
	var minos: Array[Vector2i] = piece.get_mino_positions()

	for mino in minos:
		# Only render minos that have entered the visible area (rows 2..21)
		if mino.y >= Constants.HIDDEN_ROWS and mino.y < Constants.GRID_ROWS:
			var screen_pos: Vector2 = grid_to_screen(mino)
			if reg != null:
				var tex: Texture2D = reg.get_tile_texture(tile_type, current_level)
				if tex != null:
					draw_texture(tex, screen_pos)
			else:
				draw_rect(Rect2(screen_pos.x, screen_pos.y, 8, 8), COLOR_WHITE)

func _draw_preview_box() -> void:
	var box_x: float = float(Constants.PREVIEW_OFFSET_X)
	var box_y: float = float(Constants.PREVIEW_OFFSET_Y)
	var box_w: float = 32.0
	var box_h: float = 32.0

	# Preview box background & border
	draw_rect(Rect2(box_x, box_y, box_w, box_h), COLOR_BLACK)
	draw_rect(Rect2(box_x, box_y, box_w, box_h), COLOR_BORDER_ACCENT, false, 1.0)

	# Label "NEXT" above preview box
	_draw_text("NEXT", Vector2(box_x + 4, box_y - 4), COLOR_WHITE)

	if next_piece_type < 0 or next_piece_type >= Constants.PIECE_COUNT:
		return

	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var spawn_ori: int = Constants.SPAWN_ORIENTATIONS[next_piece_type]
	var tile_type: int = Constants.TILE_TYPE_FROM_PIECE[next_piece_type]
	var anchor: Vector2 = get_preview_anchor(next_piece_type)

	var offsets: Array[Vector2i] = []
	if reg != null:
		offsets = reg.get_mino_offsets(spawn_ori)
	else:
		offsets = [Vector2i.ZERO]

	for offset in offsets:
		var pos: Vector2 = anchor + Vector2(float(offset.x * Constants.TILE_SIZE), float(offset.y * Constants.TILE_SIZE))
		if reg != null:
			var tex: Texture2D = reg.get_tile_texture(tile_type, current_level)
			if tex != null:
				draw_texture(tex, pos)
		else:
			draw_rect(Rect2(pos.x, pos.y, 8, 8), COLOR_WHITE)

func _draw_hud() -> void:
	# 1. Lines counter (Top Center: X: 152, Y: 16)
	_draw_text("LINES", Vector2(152, 16), COLOR_WHITE)
	if game_state != null and game_state.current_game_type == Constants.GameType.TYPE_B:
		_draw_text("%02d" % game_state.score_mgr.lines_remaining, Vector2(160, 26), COLOR_WHITE)
	else:
		_draw_text("%03d" % current_lines, Vector2(160, 26), COLOR_WHITE)

	# 2. Top Score (Upper Right: X: 192, Y: 32)
	_draw_text("TOP", Vector2(192, 32), COLOR_WHITE)
	_draw_text("%06d" % top_score, Vector2(192, 42), COLOR_WHITE)

	# 3. Score (Right Sidebar: X: 192, Y: 56)
	_draw_text("SCORE", Vector2(192, 56), COLOR_WHITE)
	_draw_text("%06d" % current_score, Vector2(192, 66), COLOR_WHITE)

	# 4. Level (Lower Right: X: 208, Y: 160)
	_draw_text("LEVEL", Vector2(208, 160), COLOR_WHITE)
	_draw_text("%02d" % current_level, Vector2(216, 172), COLOR_WHITE)

	# 5. Statistics (Left Sidebar: X: 16 to 80, Y: 80 to 200)
	_draw_text("STATISTICS", Vector2(16, 80), COLOR_TEXT_RED)
	var piece_labels: Array[String] = ["T", "J", "Z", "O", "S", "L", "I"]
	for i in range(Constants.PIECE_COUNT):
		var y_pos: float = 98.0 + float(i * 14)
		_draw_text(piece_labels[i], Vector2(24, y_pos), COLOR_TEXT_RED)
		_draw_text("%03d" % piece_stats[i], Vector2(48, y_pos), COLOR_WHITE)

func _draw_game_over_banner() -> void:
	var pf_x: float = float(Constants.PLAYFIELD_OFFSET_X)
	var pf_y: float = float(Constants.PLAYFIELD_OFFSET_Y)
	# Center banner over playfield
	var banner_rect: Rect2 = Rect2(pf_x + 4, pf_y + 70, 72, 24)
	draw_rect(banner_rect, COLOR_BLACK)
	draw_rect(banner_rect, COLOR_TEXT_RED, false, 1.0)
	_draw_text("GAME", Vector2(pf_x + 24, pf_y + 80), COLOR_WHITE)
	_draw_text("OVER", Vector2(pf_x + 24, pf_y + 90), COLOR_WHITE)

func _draw_text(text: String, pos: Vector2, color: Color) -> void:
	if _hud_font == null:
		_hud_font = ThemeDB.fallback_font
	if _hud_font != null:
		draw_string(_hud_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)

# --- Coordinate Helpers ---

## Maps a logical grid coordinate (0..9, 2..21) to screen viewport pixel coordinates.
static func grid_to_screen(grid_pos: Vector2i) -> Vector2:
	var sx: float = float(Constants.PLAYFIELD_OFFSET_X + grid_pos.x * Constants.TILE_SIZE)
	var sy: float = float(Constants.PLAYFIELD_OFFSET_Y + (grid_pos.y - Constants.HIDDEN_ROWS) * Constants.TILE_SIZE)
	return Vector2(sx, sy)

## Calculates authentic preview box mino anchor coordinate for a tetromino piece type.
static func get_preview_anchor(piece_type: int) -> Vector2:
	var origin: Vector2 = Vector2(float(Constants.PREVIEW_OFFSET_X), float(Constants.PREVIEW_OFFSET_Y))
	match piece_type:
		Constants.PieceType.O:
			return origin + Vector2(20.0, 12.0)
		Constants.PieceType.I:
			return origin + Vector2(20.0, 16.0)
		_:
			return origin + Vector2(16.0, 12.0)

# --- EventBus Handlers ---

func _on_piece_spawned(p_type: int, _pos: Vector2i, _ori: int) -> void:
	if p_type >= 0 and p_type < piece_stats.size():
		piece_stats[p_type] += 1
	if game_state != null:
		next_piece_type = game_state.next_piece_type
	queue_redraw()

func _on_piece_moved(_type: int, _pos: Vector2i, _ori: int) -> void:
	queue_redraw()

func _on_piece_rotated(_type: int, _pos: Vector2i, _ori: int) -> void:
	queue_redraw()

func _on_piece_locked(_type: int, _pos: Vector2i, _ori: int) -> void:
	queue_redraw()

func _on_lines_clearing(rows: Array[int], step: int) -> void:
	clearing_rows = rows
	clearing_step = step
	queue_redraw()

func _on_lines_cleared(_count: int, _rows: Array[int]) -> void:
	clearing_rows.clear()
	clearing_step = -1
	queue_redraw()

func _on_score_updated(new_score: int, _points_added: int) -> void:
	current_score = new_score
	if current_score > top_score:
		top_score = current_score
	queue_redraw()

func _on_lines_updated(new_lines: int) -> void:
	current_lines = new_lines
	queue_redraw()

func _on_level_updated(new_level: int) -> void:
	current_level = new_level
	queue_redraw()

func _on_game_over() -> void:
	is_game_over = true
	queue_redraw()

func _on_game_restarted() -> void:
	is_game_over = false
	current_score = 0
	current_lines = 0
	clearing_rows.clear()
	clearing_step = -1
	for i in range(piece_stats.size()):
		piece_stats[i] = 0
	queue_redraw()
