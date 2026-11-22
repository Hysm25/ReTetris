class_name Constants
extends RefCounted

## Core constants, authentic timings, geometry, and tables for 1989 NES Tetris.
## All values are reverse-engineered from and verified against the authentic 1989 NTSC NES binary.

# --- Display & Viewport Geometry ---
const SCREEN_WIDTH: int = 256
const SCREEN_HEIGHT: int = 240
const WINDOW_SCALE: int = 3
const TILE_SIZE: int = 8
const NES_CPU_FREQ: float = 1789772.72727 # NTSC NES 2A03 CPU clock rate in Hz

# --- Logical Playfield Dimensions ---
const GRID_COLUMNS: int = 10
const GRID_ROWS: int = 22
const VISIBLE_ROWS: int = 20
const HIDDEN_ROWS: int = 2

# Screen offsets for visible playfield (10x20 visible: 80x160 px, bounds: X: 96..175, Y: 48..207)
const PLAYFIELD_OFFSET_X: int = 96
const PLAYFIELD_OFFSET_Y: int = 48

# Next-piece preview box screen offset
const PREVIEW_OFFSET_X: int = 192
const PREVIEW_OFFSET_Y: int = 112

# Authentic Spawn Coordinates (Column 5, Row 0 in 10x22 grid)
const SPAWN_X: int = 5
const SPAWN_Y: int = 0
const SPAWN_POSITION: Vector2i = Vector2i(SPAWN_X, SPAWN_Y)

# --- Timing & Simulation ---
const SIMULATION_TPS: int = 60
const PHYSICS_DELTA: float = 1.0 / 60.0

# DAS (Delayed Auto-Shift)
const DAS_INITIAL_DELAY: int = 16       # 16 frames initial charge counter
const DAS_REPEAT_INTERVAL: int = 6       # 6 frames auto-repeat interval
const DAS_RELOAD_VALUE: int = 10         # Internal counter reloaded to 10 on repeat (16 - 10 = 6)

# ARE (Appearance / Entry Delay)
const ARE_LINE_CLEAR_STEPS: int = 5      # Center-outward animation steps
const ARE_LINE_CLEAR_FRAME_STEP: int = 4 # Frames per animation step
const ARE_LINE_CLEAR_TOTAL_FRAMES: int = 20 # 5 steps * 4 frames = 20 frames
const ARE_POST_CLEAR_FRAMES: int = 17    # ARE frames after line drop before next spawn

# --- Controller Input Bitmask ---
const BUTTON_A: int = 0x80
const BUTTON_B: int = 0x40
const BUTTON_SELECT: int = 0x20
const BUTTON_START: int = 0x10
const BUTTON_UP: int = 0x08
const BUTTON_DOWN: int = 0x04
const BUTTON_LEFT: int = 0x02
const BUTTON_RIGHT: int = 0x01

# --- Input Action Names ---
const ACTION_LEFT: String = "tetris_left"
const ACTION_RIGHT: String = "tetris_right"
const ACTION_DOWN: String = "tetris_down"
const ACTION_UP: String = "tetris_up"
const ACTION_A: String = "tetris_a"
const ACTION_B: String = "tetris_b"
const ACTION_START: String = "tetris_start"
const ACTION_SELECT: String = "tetris_select"
const ACTION_TOGGLE_CRT: String = "tetris_toggle_crt"
const ACTION_TOGGLE_FULLSCREEN: String = "tetris_toggle_fullscreen"
const ACTION_RESET: String = "tetris_reset"

# --- Game Modes & Menu Navigation ---
enum GameType {
	TYPE_A = 0,
	TYPE_B = 1,
}

enum MusicType {
	MUSIC_1 = 0, # Korobeiniki
	MUSIC_2 = 1,
	MUSIC_3 = 2,
	OFF = 3,
}

enum MenuMode {
	NONE = 0,
	TITLE_SCREEN = 1,
	GAME_TYPE_MENU = 2,
	LEVEL_MENU = 3,
	IN_GAME = 4,
	HIGH_SCORE_ENTRY = 5,
	HIGH_SCORE_TABLE = 6,
	ENDING_ANIMATION = 7,
	DEMO = 8,
}

# Attract-Mode Demo Constants (1280 frames ~21.3s title screen timeout)
const TITLE_DEMO_TIMEOUT_FRAMES: int = 1280

# Authentic 2A03 PRG-ROM Music Track IDs
enum MusicTrack {
	TITLE_SCREEN = 0,
	B_TYPE_GOAL = 1,
	MUSIC_1 = 2,           # Korobeiniki
	MUSIC_2 = 3,           # Troika
	MUSIC_3 = 4,           # Kalinka
	MUSIC_1_FAST = 5,
	MUSIC_2_FAST = 6,
	MUSIC_3_FAST = 7,
	CONGRATULATIONS = 8,
	ENDING_ROCKET = 9,
	OFF = -1,
}

# Topout Curtain Wipe Constants (64-frame initial delay, 20 visible rows, 4 frames per row)
const CURTAIN_INITIAL_DELAY: int = 16
const CURTAIN_ROWS: int = 20
const CURTAIN_FRAME_STEP: int = 4
const CURTAIN_TILE_ID: int = 0x4F

# Ending Sequence & Rocket Constants
enum RocketTier {
	TIER_0_SMALL = 0,        # Score 30,000 - 49,999
	TIER_1_MEDIUM_SMALL = 1, # Score 50,000 - 69,999
	TIER_2_MEDIUM = 2,       # Score 70,000 - 99,999
	TIER_3_LARGE = 3,        # Score 100,000 - 119,999
	TIER_4_CATHEDRAL = 4,    # Score 120,000+
}
const ROCKET_LAUNCH_DELAY_FRAMES: int = 240 # 4 seconds launchpad hold before liftoff
const ROCKET_SPEED_ACCEL_Y: int = 128       # Y position threshold where speed doubles

# Type B Mode Configurations
const TYPE_B_GOAL_LINES: int = 25
const TYPE_B_GARBAGE_ROWS: Array[int] = [0, 3, 5, 8, 10, 12] # Heights 0..5
const TYPE_B_RNG_TABLE: Array[int] = [
	0, # EMPTY
	1, # PRIMARY
	0, # EMPTY
	2, # SECONDARY
	3, # TERTIARY
	3, # TERTIARY
	0, # EMPTY
	0, # EMPTY
]

# Audio Menu SFX Identifiers
const SFX_CURSOR: int = 7
const SFX_MENU_START: int = 8
const SFX_CURTAIN: int = 9
const SFX_ROCKET: int = 10

# --- Tetromino Types ---
enum PieceType {
	T = 0,
	J = 1,
	Z = 2,
	O = 3,
	S = 4,
	L = 5,
	I = 6,
}
const PIECE_COUNT: int = 7

# --- Tile Visual Styles ---
enum TileType {
	EMPTY = 0,
	PRIMARY = 1,    # Bevelled / Frame style (tile1 in NES: $7B)
	SECONDARY = 2,  # Gem / Specular style (tile2 in NES: $7C)
	TERTIARY = 3,   # Square inset / Primary with highlight (tile3 in NES: $7D)
}

# --- Orientation IDs (Authentic 19 NES orientations + hidden state) ---
enum Orientation {
	T_UP = 0,
	T_RIGHT = 1,
	T_DOWN = 2,
	T_LEFT = 3,
	J_LEFT = 4,
	J_UP = 5,
	J_RIGHT = 6,
	J_DOWN = 7,
	Z_HORIZ = 8,
	Z_VERT = 9,
	O_FIXED = 10,
	S_HORIZ = 11,
	S_VERT = 12,
	L_RIGHT = 13,
	L_DOWN = 14,
	L_LEFT = 15,
	L_UP = 16,
	I_VERT = 17,
	I_HORIZ = 18,
	HIDDEN = 19,
}
const ORIENTATION_COUNT: int = 20

# Spawn orientation for each piece type (T, J, Z, O, S, L, I)
const SPAWN_ORIENTATIONS: Array[int] = [
	Orientation.T_DOWN,   # T (Orientation 2)
	Orientation.J_DOWN,   # J (Orientation 7)
	Orientation.Z_HORIZ,  # Z (Orientation 8)
	Orientation.O_FIXED,  # O (Orientation 10)
	Orientation.S_HORIZ,  # S (Orientation 11)
	Orientation.L_DOWN,   # L (Orientation 14)
	Orientation.I_HORIZ,  # I (Orientation 18)
]

# Mapping from Orientation to PieceType
const PIECE_TYPE_FROM_ORIENTATION: Array[int] = [
	PieceType.T, PieceType.T, PieceType.T, PieceType.T,
	PieceType.J, PieceType.J, PieceType.J, PieceType.J,
	PieceType.Z, PieceType.Z,
	PieceType.O,
	PieceType.S, PieceType.S,
	PieceType.L, PieceType.L, PieceType.L, PieceType.L,
	PieceType.I, PieceType.I,
	-1, # HIDDEN
]

# Mapping from PieceType to visual TileType
const TILE_TYPE_FROM_PIECE: Array[int] = [
	TileType.PRIMARY,   # T
	TileType.TERTIARY,  # J
	TileType.SECONDARY, # Z
	TileType.PRIMARY,   # O
	TileType.TERTIARY,  # S
	TileType.SECONDARY, # L
	TileType.PRIMARY,   # I
]

# Authentic Rotation Transitions (Clockwise / Button A)
const ROTATION_TABLE_CW: Array[int] = [
	Orientation.T_RIGHT, # from T_UP ($00)
	Orientation.T_DOWN,  # from T_RIGHT ($01)
	Orientation.T_LEFT,  # from T_DOWN ($02)
	Orientation.T_UP,    # from T_LEFT ($03)

	Orientation.J_UP,    # from J_LEFT ($04)
	Orientation.J_RIGHT, # from J_UP ($05)
	Orientation.J_DOWN,  # from J_RIGHT ($06)
	Orientation.J_LEFT,  # from J_DOWN ($07)

	Orientation.Z_VERT,  # from Z_HORIZ ($08)
	Orientation.Z_HORIZ, # from Z_VERT ($09)

	Orientation.O_FIXED, # from O_FIXED ($0A)

	Orientation.S_VERT,  # from S_HORIZ ($0B)
	Orientation.S_HORIZ, # from S_VERT ($0C)

	Orientation.L_DOWN,  # from L_RIGHT ($0D)
	Orientation.L_LEFT,  # from L_DOWN ($0E)
	Orientation.L_UP,    # from L_LEFT ($0F)
	Orientation.L_RIGHT, # from L_UP ($10)

	Orientation.I_HORIZ, # from I_VERT ($11)
	Orientation.I_VERT,  # from I_HORIZ ($12)

	Orientation.HIDDEN,  # from HIDDEN ($13)
]

# Authentic Rotation Transitions (Counter-Clockwise / Button B)
const ROTATION_TABLE_CCW: Array[int] = [
	Orientation.T_LEFT,  # from T_UP ($00)
	Orientation.T_UP,    # from T_RIGHT ($01)
	Orientation.T_RIGHT, # from T_DOWN ($02)
	Orientation.T_DOWN,  # from T_LEFT ($03)

	Orientation.J_DOWN,  # from J_LEFT ($04)
	Orientation.J_LEFT,  # from J_UP ($05)
	Orientation.J_UP,    # from J_RIGHT ($06)
	Orientation.J_RIGHT, # from J_DOWN ($07)

	Orientation.Z_VERT,  # from Z_HORIZ ($08)
	Orientation.Z_HORIZ, # from Z_VERT ($09)

	Orientation.O_FIXED, # from O_FIXED ($0A)

	Orientation.S_VERT,  # from S_HORIZ ($0B)
	Orientation.S_HORIZ, # from S_VERT ($0C)

	Orientation.L_UP,    # from L_RIGHT ($0D)
	Orientation.L_RIGHT, # from L_DOWN ($0E)
	Orientation.L_DOWN,  # from L_LEFT ($0F)
	Orientation.L_LEFT,  # from L_UP ($10)

	Orientation.I_HORIZ, # from I_VERT ($11)
	Orientation.I_VERT,  # from I_HORIZ ($12)

	Orientation.HIDDEN,  # from HIDDEN ($13)
]

# --- Gravity Frames Per Drop Lookup Table (Levels 0 through 29+) ---
const GRAVITY_TABLE: Array[int] = [
	48, 43, 38, 33, 28, 23, 18, 13, 8, 6,
	5, 5, 5, 4, 4, 4, 3, 3, 3, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 1
]

# --- BPS Scoring Table ---
const SCORE_POINTS_PER_LINES: Array[int] = [0, 40, 100, 300, 1200]
const SCORE_SOFT_DROP_PER_CELL: int = 1

# --- Line Clear Center-Outward Column Indices ---
const LINE_CLEAR_LEFT_COLS: Array[int] = [4, 3, 2, 1, 0]
const LINE_CLEAR_RIGHT_COLS: Array[int] = [5, 6, 7, 8, 9]

# --- Authentic NES 64-Color 2C02 Master Palette ---
const NES_MASTER_PALETTE: Array[Color] = [
	# 0x00 - 0x0F
	Color("#666666"), Color("#002A88"), Color("#1412A7"), Color("#3B00A4"),
	Color("#5C007E"), Color("#6E0040"), Color("#6C0600"), Color("#561D00"),
	Color("#333500"), Color("#0B4800"), Color("#005200"), Color("#004F08"),
	Color("#00404D"), Color("#000000"), Color("#000000"), Color("#000000"),
	# 0x10 - 0x1F
	Color("#ADADAD"), Color("#155FD9"), Color("#4240FF"), Color("#7527FE"),
	Color("#A01ACC"), Color("#B71E7B"), Color("#B53120"), Color("#994E00"),
	Color("#6B6D00"), Color("#388700"), Color("#0C9300"), Color("#008F32"),
	Color("#007C8D"), Color("#000000"), Color("#000000"), Color("#000000"),
	# 0x20 - 0x2F
	Color("#FFFFFF"), Color("#64B0FF"), Color("#9290FF"), Color("#C676FF"),
	Color("#F36AFF"), Color("#FE6ECC"), Color("#FE8176"), Color("#ECA435"),
	Color("#BDC700"), Color("#82DE00"), Color("#46EB29"), Color("#27E47C"),
	Color("#20D8D5"), Color("#4F4F4F"), Color("#000000"), Color("#000000"),
	# 0x30 - 0x3F
	Color("#FFFFFF"), Color("#C0DFFF"), Color("#D3D2FF"), Color("#E8C8FF"),
	Color("#FBC2FF"), Color("#FEC4EA"), Color("#FECCC5"), Color("#F7DBA9"),
	Color("#E5E99B"), Color("#CEF49A"), Color("#B4F7B0"), Color("#A3F4CE"),
	Color("#9FF0F4"), Color("#B8B8B8"), Color("#000000"), Color("#000000")
]

# --- Authentic Level Palettes (Levels 0 through 9 cycling) ---
# Format per level: [Primary (tile1), Secondary (tile2), Tertiary (tile3/white)]
const LEVEL_PALETTES: Array[Array] = [
	[Color("#0058F8"), Color("#3CBCFC"), Color("#FCFCFC")], # Level 0: Blue, Light Blue, White
	[Color("#00A800"), Color("#80D010"), Color("#FCFCFC")], # Level 1: Green, Light Green, White
	[Color("#880070"), Color("#F878F8"), Color("#FCFCFC")], # Level 2: Purple, Pink, White
	[Color("#0058F8"), Color("#58F898"), Color("#FCFCFC")], # Level 3: Blue, Cyan, White
	[Color("#D80058"), Color("#00E800"), Color("#FCFCFC")], # Level 4: Magenta, Green, White
	[Color("#58F898"), Color("#6888FC"), Color("#FCFCFC")], # Level 5: Light Green, Light Purple, White
	[Color("#E40058"), Color("#F83800"), Color("#FCFCFC")], # Level 6: Dark Red, Orange, White
	[Color("#6844FC"), Color("#9878F8"), Color("#FCFCFC")], # Level 7: Dark Purple, Purple, White
	[Color("#0058F8"), Color("#F85800"), Color("#FCFCFC")], # Level 8: Dark Blue, Ochre/Orange, White
	[Color("#F83800"), Color("#FFA044"), Color("#FCFCFC")], # Level 9: Orange, Light Orange, White
]

# Authentic NES color indices per level (bg, fg, c3, c4) from main.asm:2871-2876
const LEVEL_COLOR_INDICES: Array[Array] = [
	[0x0F, 0x30, 0x21, 0x12], # Level 0
	[0x0F, 0x30, 0x29, 0x1A], # Level 1
	[0x0F, 0x30, 0x24, 0x14], # Level 2
	[0x0F, 0x30, 0x2A, 0x12], # Level 3
	[0x0F, 0x30, 0x2B, 0x15], # Level 4
	[0x0F, 0x30, 0x22, 0x2B], # Level 5
	[0x0F, 0x30, 0x00, 0x16], # Level 6
	[0x0F, 0x30, 0x05, 0x13], # Level 7
	[0x0F, 0x30, 0x16, 0x12], # Level 8
	[0x0F, 0x30, 0x27, 0x16], # Level 9
]

# --- Static Helper Functions ---

static func get_gravity_frames(level: int) -> int:
	if level <= 0:
		return GRAVITY_TABLE[0]
	if level >= GRAVITY_TABLE.size():
		return 1
	return GRAVITY_TABLE[level]

static func get_line_clear_score(lines: int, level: int) -> int:
	if lines < 1 or lines > 4:
		return 0
	return SCORE_POINTS_PER_LINES[lines] * (maxi(0, level) + 1)

static func get_first_level_transition_lines(start_level: int) -> int:
	var clamped_level: int = maxi(0, start_level)
	return mini(clamped_level * 10 + 10, maxi(100, clamped_level * 10 - 50))

static func get_base_are(lock_row: int) -> int:
	var clamped_y: int = clampi(lock_row, 2, 21)
	return 10 + 2 * int(floor(float(21 - clamped_y) / 4.0))

static func get_rotated_orientation(current_orientation: int, clockwise: bool) -> int:
	if current_orientation < 0 or current_orientation >= ORIENTATION_COUNT:
		return current_orientation
	if clockwise:
		return ROTATION_TABLE_CW[current_orientation]
	else:
		return ROTATION_TABLE_CCW[current_orientation]

static func get_level_palette(level: int) -> Array[Color]:
	var idx: int = absi(level) % 10
	var res: Array[Color] = []
	for c in LEVEL_PALETTES[idx]:
		res.append(c)
	return res
