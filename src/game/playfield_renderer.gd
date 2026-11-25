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
var top_score: int = 10000
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
	refresh_top_score()
	_connect_event_bus()

## Refreshes the top score from HighScoreManager for the active game type.
func refresh_top_score() -> void:
	var g_type: int = Constants.GameType.TYPE_A
	if game_state != null:
		g_type = game_state.current_game_type
	elif menu_ctrl != null:
		g_type = int(menu_ctrl.get("game_type"))

	var hs_mgr: RefCounted = menu_ctrl.get("high_score_mgr") if menu_ctrl != null else null
	if hs_mgr != null and hs_mgr.has_method("get_top_score"):
		top_score = hs_mgr.get_top_score(g_type)
	else:
		top_score = 10000 if g_type == Constants.GameType.TYPE_A else 2000

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
	queue_redraw()

# --- Draw Logic ---

func _draw() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var stage_origin: Vector2 = ((vp_size - Vector2(float(Constants.SCREEN_WIDTH), float(Constants.SCREEN_HEIGHT))) * 0.5).floor()

	# 1. Seamless Widescreen / Native Background Tiling (rendered behind stage so transparent nametable margins blend seamlessly)
	_draw_outer_widescreen_background(vp_size, stage_origin)

	# 2. Transform into centered 256x240 stage coordinate space
	draw_set_transform(stage_origin, 0.0, Vector2.ONE)

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

func _draw_outer_widescreen_background(vp_size: Vector2, stage_origin: Vector2) -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var is_menu: bool = true
	if menu_ctrl != null:
		var mode: int = int(menu_ctrl.get("current_mode"))
		if mode == Constants.MenuMode.IN_GAME or mode == Constants.MenuMode.DEMO:
			is_menu = false
		else:
			is_menu = true
	elif game_state != null:
		if game_state.current_state == GameStateMachine.State.MENU or game_state.current_state == GameStateMachine.State.ROM_SETUP:
			is_menu = true
		else:
			is_menu = false

	var tile_tex: Texture2D = null
	if reg != null:
		if reg.has_method("get_background_pattern_tile_texture"):
			tile_tex = reg.get_background_pattern_tile_texture(is_menu)
		else:
			tile_tex = reg.get("background_pattern_tile_texture")

	if tile_tex == null:
		draw_rect(Rect2(Vector2.ZERO, vp_size), COLOR_BLACK)
		return

	var p_size: Vector2 = tile_tex.get_size()
	var pw: float = p_size.x if p_size.x > 0.0 else 64.0
	var ph: float = p_size.y if p_size.y > 0.0 else 64.0

	# Align tiling grid directly with stage_origin to prevent any seams
	var start_x: float = fmod(stage_origin.x, pw)
	if start_x > 0.0:
		start_x -= pw
	var start_y: float = fmod(stage_origin.y, ph)
	if start_y > 0.0:
		start_y -= ph

	var cur_y: float = start_y
	while cur_y < vp_size.y:
		var cur_x: float = start_x
		while cur_x < vp_size.x:
			draw_texture(tile_tex, Vector2(cur_x, cur_y))
			cur_x += pw
		cur_y += ph

func _draw_title_screen() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_title_screen_texture"):
		var tex: ImageTexture = reg.get_title_screen_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			_draw_nes_text("TETRIS", Vector2(104, 70), COLOR_WHITE)
	else:
		_draw_nes_text("TETRIS", Vector2(104, 70), COLOR_WHITE)

func _draw_game_type_menu() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_game_type_menu_texture"):
		var tex: ImageTexture = reg.get_game_type_menu_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)

	if menu_ctrl == null:
		return

	var timer: int = int(menu_ctrl.get("cursor_timer"))
	var arrow_r: Texture2D = reg.get_cursor_arrow_texture(false) if reg != null else null
	var arrow_l: Texture2D = reg.get_cursor_arrow_texture(true) if reg != null else null

	# Authentic NES Tetris sprite01GameTypeCursor:
	# Y = 63 ($3F). Type A: X = 63 ($3F), Type B: X = 159 ($9F).
	# Left arrow (>) at (X, Y), Right arrow (<, flipped) at (X + 58, Y).
	# Authentic flicker: (timer & 0x03) != 0 (3 frames on, 1 frame off).
	if (timer & 0x03) != 0:
		var g_type: int = int(menu_ctrl.get("game_type"))
		var gx: float = 63.0 if g_type == Constants.GameType.TYPE_A else 159.0
		var gy: float = 63.0
		if arrow_r != null and arrow_l != null:
			draw_texture(arrow_r, Vector2(gx, gy))
			draw_texture(arrow_l, Vector2(gx + 58.0, gy))
		else:
			draw_rect(Rect2(gx + 8.0, gy, 50.0, 8.0), COLOR_BORDER_ACCENT, false, 1.0)

	# Authentic NES Tetris sprite53MusicTypeCursor:
	# X = 103 ($67). Y = 143 ($8F) + music_type * 16.
	# Left arrow at (X, Y), Right arrow at (X + 74, Y).
	# Authentic flicker: (timer & 0x03) != 0.
	if (timer & 0x03) != 0:
		var m_type: int = int(menu_ctrl.get("music_type"))
		var mx: float = 103.0
		var my: float = 143.0 + float(m_type) * 16.0
		if arrow_r != null and arrow_l != null:
			draw_texture(arrow_r, Vector2(mx, my))
			draw_texture(arrow_l, Vector2(mx + 74.0, my))
		else:
			draw_rect(Rect2(mx + 8.0, my, 66.0, 8.0), COLOR_WHITE, false, 1.0)

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
	# Authentic NES Tetris levelToSpriteXOffset ($34 + col * 16) and levelToSpriteYOffset ($53 / $63)
	var lx: float = 52.0 + float(col) * 16.0
	var ly: float = 83.0 if row == 0 else 99.0

	var is_sel_height: bool = bool(menu_ctrl.get("selecting_height"))
	var show_lvl: bool = true
	if not is_sel_height:
		show_lvl = ((timer & 0x03) != 0)

	if show_lvl:
		draw_rect(Rect2(lx, ly, 16.0, 16.0), COLOR_BORDER_ACCENT, false, 1.0)

	if g_type == Constants.GameType.TYPE_B:
		var sel_h: int = int(menu_ctrl.get("selected_height"))
		var h_col: int = sel_h % 3
		var h_row: int = sel_h / 3
		# Authentic NES Tetris heightToPpuLowAddr ($9C + col * 16) and heightToPpuHighAddr ($53 / $63)
		var hx: float = 156.0 + float(h_col) * 16.0
		var hy: float = 83.0 if h_row == 0 else 99.0

		var show_h: bool = true
		if is_sel_height:
			show_h = ((timer & 0x03) != 0)

		if show_h:
			draw_rect(Rect2(hx, hy, 16.0, 16.0), COLOR_BORDER_ACCENT, false, 1.0)

	# Authentic High Scores Display at the bottom of the Level Menu (rows 20, 22, 24)
	var hs_mgr: RefCounted = menu_ctrl.get("high_score_mgr") if menu_ctrl != null else null
	if hs_mgr != null:
		var entries: Array = hs_mgr.call("get_entries", g_type)
		var y_offsets: Array[float] = [160.0, 176.0, 192.0]
		for i in range(mini(3, entries.size())):
			var entry: Dictionary = entries[i] as Dictionary
			var y: float = y_offsets[i]
			var name_str: String = String(entry.get("name", "      "))
			var score_val: int = int(entry.get("score", 0))
			var level_val: int = int(entry.get("level", 0))
			_draw_nes_text(name_str, Vector2(72, y), COLOR_WHITE)
			_draw_nes_text("%06d" % score_val, Vector2(136, y), COLOR_WHITE)
			_draw_nes_text("%02d" % level_val, Vector2(192, y), COLOR_WHITE)

func _draw_high_score_table() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_high_scores_texture"):
		var tex: ImageTexture = reg.get_high_scores_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
			_draw_nes_text("TOP - 3", Vector2(104, 50), COLOR_WHITE)
	else:
		draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
		_draw_nes_text("TOP - 3", Vector2(104, 50), COLOR_WHITE)

	if menu_ctrl == null or menu_ctrl.get("high_score_mgr") == null:
		return

	var g_type: int = int(menu_ctrl.get("game_type"))
	var hs_mgr: RefCounted = menu_ctrl.get("high_score_mgr")
	var entries: Array = hs_mgr.call("get_entries", g_type)

	var y_offsets: Array[float] = [160.0, 176.0, 192.0]
	for i in range(mini(3, entries.size())):
		var entry: Dictionary = entries[i] as Dictionary
		var y: float = y_offsets[i]
		var name_str: String = String(entry.get("name", "      "))
		var score_val: int = int(entry.get("score", 0))
		var level_val: int = int(entry.get("level", 0))

		_draw_nes_text(name_str, Vector2(72, y), COLOR_WHITE)
		_draw_nes_text("%06d" % score_val, Vector2(136, y), COLOR_WHITE)
		_draw_nes_text("%02d" % level_val, Vector2(192, y), COLOR_WHITE)

func _draw_high_score_entry() -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.has_method("get_enter_high_score_texture"):
		var tex: ImageTexture = reg.get_enter_high_score_texture()
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
			_draw_nes_text("CONGRATULATIONS", Vector2(72, 50), COLOR_WHITE)
	else:
		draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)
		_draw_nes_text("CONGRATULATIONS", Vector2(72, 50), COLOR_WHITE)

	if menu_ctrl == null or menu_ctrl.get("high_score_mgr") == null:
		return

	var g_type: int = int(menu_ctrl.get("entry_game_type"))
	var hs_mgr: RefCounted = menu_ctrl.get("high_score_mgr")
	var entries: Array = hs_mgr.call("get_entries", g_type)
	var rank: int = int(menu_ctrl.get("entry_rank"))
	var cursor_idx: int = int(menu_ctrl.get("entry_char_index"))
	var timer: int = int(menu_ctrl.get("cursor_timer"))
	var name_chars: Array = menu_ctrl.get("entry_name_chars") as Array

	var y_offsets: Array[float] = [160.0, 176.0, 192.0]
	for i in range(mini(3, entries.size())):
		var y: float = y_offsets[i]
		if i == rank:
			# Currently edited entry row
			# Authentic sprite0EHighScoreNameCursor: 8x8 solid box behind letter
			var is_cursor_visible: bool = ((timer & 0x03) != 0)
			for c_i in range(6):
				var cx: float = 72.0 + float(c_i) * 8.0
				var ch: String = name_chars[c_i] if c_i < name_chars.size() else " "
				if c_i == cursor_idx and is_cursor_visible:
					draw_rect(Rect2(cx, y, 8.0, 8.0), COLOR_TEXT_RED)
					_draw_nes_text(ch, Vector2(cx, y), COLOR_BLACK)
				else:
					_draw_nes_text(ch, Vector2(cx, y), COLOR_WHITE)

			var sc: int = int(menu_ctrl.get("entry_score"))
			var lvl: int = int(menu_ctrl.get("entry_level"))
			_draw_nes_text("%06d" % sc, Vector2(136, y), COLOR_WHITE)
			_draw_nes_text("%02d" % lvl, Vector2(192, y), COLOR_WHITE)
		else:
			# Existing high score entry
			var lookup_idx: int = i if i < rank else i - 1
			if lookup_idx >= 0 and lookup_idx < entries.size():
				var entry: Dictionary = entries[lookup_idx] as Dictionary
				_draw_nes_text(String(entry.get("name", "      ")), Vector2(72, y), COLOR_WHITE)
				_draw_nes_text("%06d" % int(entry.get("score", 0)), Vector2(136, y), COLOR_WHITE)
				_draw_nes_text("%02d" % int(entry.get("level", 0)), Vector2(192, y), COLOR_WHITE)

func _draw_ending_animation() -> void:
	if game_state == null:
		return

	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var tier: int = game_state.ending_tier
	var rx: float = game_state.ending_rocket_x
	var ry: float = game_state.ending_rocket_y
	var fc: int = game_state.ending_frame_counter

	if reg != null and reg.has_method("get_ending_texture"):
		var tex: ImageTexture = reg.get_ending_texture(tier)
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
		else:
			draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), Color("#000033"))
	else:
		draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), Color("#000033"))

	if reg != null and reg.has_method("draw_ending_rocket"):
		reg.draw_ending_rocket(self, tier, Vector2(rx, ry), fc)

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
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var g_type: int = game_state.current_game_type if game_state != null else 0
	if reg != null and reg.has_method("get_game_background_texture"):
		var tex: ImageTexture = reg.get_game_background_texture(g_type)
		if tex != null and tex.get_size() == Vector2(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT):
			draw_texture(tex, Vector2.ZERO)
			return
	draw_rect(Rect2(0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT), COLOR_BLACK)

func _draw_playfield_frame() -> void:
	var pf_x: float = float(Constants.PLAYFIELD_OFFSET_X)
	var pf_y: float = float(Constants.PLAYFIELD_OFFSET_Y)
	var pf_w: float = float(Constants.GRID_COLUMNS * Constants.TILE_SIZE)
	var pf_h: float = float(Constants.VISIBLE_ROWS * Constants.TILE_SIZE)

	# Inner Playfield Black Background
	draw_rect(Rect2(pf_x, pf_y, pf_w, pf_h), COLOR_BLACK)

	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg == null or not reg.get("is_initialized"):
		# NES Bevel Borders around Playfield (Left, Right, Bottom) for fallback
		draw_line(Vector2(pf_x - 2, pf_y - 1), Vector2(pf_x - 2, pf_y + pf_h + 2), COLOR_BORDER_FRAME, 1.0)
		draw_line(Vector2(pf_x - 1, pf_y - 1), Vector2(pf_x - 1, pf_y + pf_h + 1), COLOR_BORDER_ACCENT, 1.0)
		draw_line(Vector2(pf_x + pf_w, pf_y - 1), Vector2(pf_x + pf_w, pf_y + pf_h + 1), COLOR_BORDER_ACCENT, 1.0)
		draw_line(Vector2(pf_x + pf_w + 1, pf_y - 1), Vector2(pf_x + pf_w + 1, pf_y + pf_h + 2), COLOR_BORDER_FRAME, 1.0)
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

	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg == null or not reg.get("is_initialized"):
		draw_rect(Rect2(box_x, box_y, box_w, box_h), COLOR_BLACK)
		draw_rect(Rect2(box_x, box_y, box_w, box_h), COLOR_BORDER_ACCENT, false, 1.0)
		_draw_text("NEXT", Vector2(box_x + 4, box_y - 4), COLOR_WHITE)

	if next_piece_type < 0 or next_piece_type >= Constants.PIECE_COUNT:
		return

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
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	var is_init: bool = (reg != null and reg.get("is_initialized"))

	# Fallback static labels: ONLY drawn if extracted background nametable is missing
	if not is_init:
		_draw_text("LINES", Vector2(152, 16), COLOR_WHITE)
		_draw_text("TOP", Vector2(192, 32), COLOR_WHITE)
		_draw_text("SCORE", Vector2(192, 56), COLOR_WHITE)
		_draw_text("LEVEL", Vector2(208, 160), COLOR_WHITE)
		_draw_text("STATISTICS", Vector2(16, 80), COLOR_TEXT_RED)
		var piece_labels: Array[String] = ["T", "J", "Z", "O", "S", "L", "I"]
		for i in range(Constants.PIECE_COUNT):
			_draw_text(piece_labels[i], Vector2(24, 96.0 + float(i * 16)), COLOR_TEXT_RED)

	# 1. Lines counter (Top Center: PPU $2073 -> Row 3, Col 19: X: 152, Y: 24)
	if game_state != null and game_state.current_game_type == Constants.GameType.TYPE_B:
		draw_rect(Rect2(160.0, 24.0, 16.0, 8.0), COLOR_BLACK)
		_draw_nes_text("%02d" % game_state.score_mgr.lines_remaining, Vector2(160, 24), COLOR_WHITE)
	else:
		draw_rect(Rect2(152.0, 24.0, 24.0, 8.0), COLOR_BLACK)
		_draw_nes_text("%03d" % current_lines, Vector2(152, 24), COLOR_WHITE)

	# 2. Top Score (Upper Right: PPU $20B8 -> Row 5, Col 24: X: 192, Y: 40)
	draw_rect(Rect2(192.0, 40.0, 48.0, 8.0), COLOR_BLACK)
	_draw_nes_text("%06d" % top_score, Vector2(192, 40), COLOR_WHITE)

	# 3. Score (Right Sidebar: PPU $2118 -> Row 8, Col 24: X: 192, Y: 64)
	draw_rect(Rect2(192.0, 64.0, 48.0, 8.0), COLOR_BLACK)
	_draw_nes_text("%06d" % current_score, Vector2(192, 64), COLOR_WHITE)

	# 4. Level (Lower Right: PPU $22BA -> Row 21, Col 26: X: 208, Y: 168)
	draw_rect(Rect2(208.0, 168.0, 16.0, 8.0), COLOR_BLACK)
	_draw_nes_text("%02d" % current_level, Vector2(208, 168), COLOR_WHITE)

	# 5. Statistics (Left Sidebar: Rows 12, 14, 16, 18, 20, 22, 24, Col 6: X: 48, Y: 96 + i * 16)
	for i in range(Constants.PIECE_COUNT):
		var y_pos: float = 96.0 + float(i * 16)
		draw_rect(Rect2(48.0, y_pos, 24.0, 8.0), COLOR_BLACK)
		_draw_nes_text("%03d" % piece_stats[i], Vector2(48, y_pos), COLOR_TEXT_RED)

func _draw_game_over_banner() -> void:
	var pf_x: float = float(Constants.PLAYFIELD_OFFSET_X)
	var pf_y: float = float(Constants.PLAYFIELD_OFFSET_Y)
	# Center banner over playfield
	var banner_rect: Rect2 = Rect2(pf_x + 4, pf_y + 70, 72, 24)
	draw_rect(banner_rect, COLOR_BLACK)
	draw_rect(banner_rect, COLOR_TEXT_RED, false, 1.0)
	_draw_nes_text("GAME", Vector2(pf_x + 24, pf_y + 74), COLOR_WHITE)
	_draw_nes_text("OVER", Vector2(pf_x + 24, pf_y + 84), COLOR_WHITE)

func _draw_nes_text(text: String, pos: Vector2, color: Color = COLOR_WHITE) -> void:
	var reg: Node = get_node_or_null("/root/ContentRegistry")
	if reg != null and reg.get("is_initialized"):
		var cur_x: float = pos.x
		var u_text: String = text.to_upper()
		for i in range(u_text.length()):
			var ch: String = u_text[i]
			var tex: Texture2D = reg.get_font_glyph(ch)
			if tex != null:
				draw_texture(tex, Vector2(cur_x, pos.y), color)
			elif ch != " ":
				_draw_text(ch, Vector2(cur_x, pos.y + 7.0), color)
			cur_x += 8.0
	else:
		_draw_text(text, Vector2(pos.x, pos.y + 7.0), color)

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
	match piece_type:
		Constants.PieceType.O:
			return Vector2(208.0, 120.0)
		Constants.PieceType.I:
			return Vector2(208.0, 124.0)
		_:
			return Vector2(204.0, 120.0)

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
	queue_redraw()

func _on_lines_updated(new_lines: int) -> void:
	current_lines = new_lines
	queue_redraw()

func _on_level_updated(new_level: int) -> void:
	current_level = new_level
	queue_redraw()

func _on_game_over() -> void:
	is_game_over = true
	refresh_top_score()
	queue_redraw()

func _on_game_restarted() -> void:
	is_game_over = false
	current_score = 0
	current_lines = 0
	clearing_rows.clear()
	clearing_step = -1
	for i in range(piece_stats.size()):
		piece_stats[i] = 0
	refresh_top_score()
	queue_redraw()
