# Project Architecture (`docs/ARCHITECTURE.md`)

> **Project**: Clean-Room Re-implementation of 1989 NES Tetris in **Godot 4.3+ (Strictly Typed GDScript)**.  
> **Goal**: 100% faithful, frame-accurate NTSC 60Hz NES Tetris simulation with zero copyrighted Nintendo or Bullet-Proof Software assets, featuring a deterministic 60 TPS physics process, procedural pixel tile generation, and an optional 2bpp CHR-ROM asset extraction pipeline.

---

## 1. Legal & Clean-Room Asset Boundary

This project is an independent clean-room software re-implementation created strictly through observation of authentic game mechanics, reverse-engineered timing specifications, and published mathematical formulas.

### Reference Disassembly
- The workspace includes a local disassembly reference (`TetrisNESDisasm/`) derived from the original 1989 NES binary.
- This disassembly is utilized strictly for reverse-engineering verification of authentic mechanics (randomizer logic, frame gravity tables, ARE timing counters, DAS behavior, and scoring formulas).
- Absolutely zero binary assets or proprietary code from `TetrisNESDisasm/` are packaged or compiled into the engine runtime.

### Boundary Invariants
1. **Zero Copyrighted Assets in Repository**:
   - Absolutely no proprietary Nintendo / Bullet-Proof Software ROMs, CHR dumps, PRG code, music recordings, or copyrighted graphics are committed to version control.
   - Git ignores all ROM binaries (`*.nes`, `*.fds`, `*.bin`, `*.rom`, `*.sav`) and runtime data directories (`user://nes_data/`, `extracted/`).
2. **Dual Asset Pipeline**:
   - **Path A — Clean-Room Procedural Generation (Default Fallback)**:
     - Algorithmic generation of authentic 8x8 pixel tiles (bevelled block, gem block, square block) directly in GDScript via `Image` and `ImageTexture`.
     - Algorithmic procedural audio synthesis (simulating the 2A03 APU pulse, triangle, and noise channels) or royalty-free clean WAV SFX.
     - The game is 100% playable out-of-the-box without requiring any external files.
   - **Path B — Optional User ROM Ingestion (`user://nes_data/`)**:
     - Users may optionally place a legally dumped `tetris.nes` file into `user://nes_data/`.
     - An integrated pure-GDScript CHR-ROM extractor parses the iNES header, locates the 8KB CHR-ROM bank, unpacks 2bpp planar NES tile graphics, maps them to authentic palettes, and caches the extracted textures locally.

```
+-----------------------------------------------------------------------+
|                         Legal Asset Pipeline                          |
|                                                                       |
|  +---------------------------+       +-----------------------------+  |
|  | Procedural Tile Generator |       | Optional: user://nes_data/  |  |
|  | (Clean-Room 8x8 GDScript) |       | (User-provided tetris.nes)  |  |
|  +-------------+-------------+       +--------------+--------------+  |
|                |                                    |                 |
|                |                                    v                 |
|                |                     +-----------------------------+  |
|                |                     | CHR-ROM 2bpp Tile Extractor |  |
|                |                     | (Pure GDScript / iNES)      |  |
|                |                     +--------------+--------------+  |
|                |                                    |                 |
|                v                                    v                 |
|  +-----------------------------------------------------------------+  |
|  |             ContentRegistry (Texture & Palette Bank)             |  |
|  +-----------------------------------------------------------------+  |
+-----------------------------------------------------------------------+
```

---

## 2. NTSC 60Hz NES Hardware & Display Specifications

The engine is calibrated to replicate the exact timing and visual geometry of the 1989 Nintendo Entertainment System (NTSC, Ricoh 2A03 CPU running at 1.789773 MHz, PPU at 5.369318 MHz, ~60.0988 frames per second).

| Specification | Authentic NES Hardware Value | Godot 4.3 Engine Mapping |
| :--- | :--- | :--- |
| **Native Resolution** | 256 x 240 pixels | `window/size/viewport_width = 256`<br>`window/size/viewport_height = 240` |
| **Window Stretch Mode** | CRT / Pixel-aspect | `stretch/mode = "viewport"`, `stretch/aspect = "keep"` |
| **Texture Filter** | PPU Pixel Nearest-Neighbor | `textures/canvas_textures/default_texture_filter = 0` (Nearest) |
| **Simulation Tick Rate** | ~60.0988 Hz (NTSC VBlank) | `common/physics_ticks_per_second = 60` (`_physics_process`) |
| **Tile Dimensions** | 8 x 8 pixels | 8 x 8 pixel grid units |
| **Visible Playfield** | 10 columns x 20 rows | 80 x 160 pixels (Viewport bounds: X: 96..175, Y: 40..199) |
| **Spawn Buffer** | 2 hidden rows (top) | Logical grid is 10 x 22 (Rows 0..1 hidden, Rows 2..21 visible) |

---

## 3. Authentic 1989 NES Tetris Mechanics & Formulas

### 3.1 Logical Playfield (`BoardGrid`)
- **Dimensions**: 10 columns (X: 0..9) by 22 rows (Y: 0..21).
  - Rows 0 and 1: Hidden spawn rows (used for tetromino entry and game-over lockout).
  - Rows 2 through 21: The 20 visible rows rendered on screen.
- **Cell Representation**: Integer enum or tile ID:
  - `0`: Empty.
  - `1`: Block Type A (Primary palette color).
  - `2`: Block Type B (Secondary palette color).
  - `3`: Block Type C (Tertiary/Highlight color).

### 3.2 1989 Piece Randomizer (Two-Roll Algorithm)
Authentic 1989 NES Tetris does NOT use the modern 7-bag randomizer. It uses a pseudo-random two-roll mechanism with a bias against consecutive piece duplicates:

1. **Roll 1**: Pick an integer $R_1 \in [0, 7]$ uniformly (8 possibilities: 0=T, 1=J, 2=Z, 3=O, 4=S, 5=L, 6=I, 7=Dummy).
2. **Evaluation**:
   - If $R_1 == \text{previous\_piece\_id}$ OR $R_1 == 7$:
     - **Roll 2**: Pick an integer $R_2 \in [0, 6]$ uniformly (7 possibilities: 0..6).
     - $\text{piece\_id} = R_2$.
   - Else:
     - $\text{piece\_id} = R_1$.
3. Update $\text{previous\_piece\_id} = \text{piece\_id}$.

**Repeat Probability**:
$$P(\text{duplicate}) = P(R_1 = \text{prev}) \cdot P(R_2 = \text{prev}) + P(R_1 = 7) \cdot P(R_2 = \text{prev}) = \frac{1}{8} \cdot \frac{1}{7} + \frac{1}{8} \cdot \frac{1}{7} = \frac{2}{56} = \frac{1}{28} \approx 3.57\%$$
(Non-repeated pieces each have a probability of $(1 - 1/28) / 6 \approx 16.07\%$).

### 3.3 Nintendo Rotation System (NRS)
- **Zero Kicks**: There are **no wall-kicks** and **no floor-kicks**. If a rotated piece collides with any occupied cell or the playfield boundary ($X < 0, X \ge 10, Y \ge 22$), the rotation is rejected unconditionally.
- **Rotation States**:
  - **T, J, L**: 4 rotation states ($0 \rightarrow 1 \rightarrow 2 \rightarrow 3$).
  - **I, S, Z**: 2 rotation states (bi-directional toggle: $0 \leftrightarrow 1$).
  - **O**: 1 rotation state (invariant).
- **Controls**:
  - `Button A`: Rotate Clockwise (+1 state).
  - `Button B`: Rotate Counter-Clockwise (-1 state).

### 3.4 Delayed Auto-Shift (DAS)
DAS governs horizontal movement timing:
- **Initial Press (Tap)**: The piece moves immediately by 1 column on frame 0.
- **DAS Charge Counter**: Set to **16 frames**.
- **Auto-Repeat Rate**: Once the 16-frame charge counter expires while holding the directional key, the piece shifts 1 column every **6 frames**.
- **DAS Preservation (Pre-charging)**:
  - DAS charge is maintained across piece locks, entry delays (ARE), and line clear animations.
  - If a player holds a direction during ARE, the counter continues to count, allowing the piece to move immediately upon spawning if the counter reaches 16.
- **Direction Reversal**: Changing direction immediately resets the DAS counter to 0.

### 3.5 Gravity Timing Table
Gravity determines the number of frames per single-cell downward drop based on the current level:

| Level | Frames per Drop | Speed (Cells/sec at 60Hz) |
| :--- | :--- | :--- |
| **00** | 48 | ~1.25 |
| **01** | 43 | ~1.40 |
| **02** | 38 | ~1.58 |
| **03** | 33 | ~1.82 |
| **04** | 28 | ~2.14 |
| **05** | 23 | ~2.61 |
| **06** | 18 | ~3.33 |
| **07** | 13 | ~4.62 |
| **08** | 8 | 7.50 |
| **09** | 6 | 10.00 |
| **10 – 12** | 5 | 12.00 |
| **13 – 15** | 4 | 15.00 |
| **16 – 18** | 3 | 20.00 |
| **19 – 28** | 2 | 30.00 (*"Kill Screen"*) |
| **29+** | 1 | 60.00 (*Max engine speed*) |

### 3.6 Soft Drop & Lock Mechanic
- **Soft Drop**: Holding Down accelerates the fall speed to 1 cell every 2 frames.
  - Awards **+1 point** per grid cell dropped while holding Down.
  - Hard drop does **not** exist in 1989 NES Tetris.
- **Instant Lock**: NES Tetris does **not** have modern lock delay (grace period). When a piece contacts the surface on a gravity or soft-drop tick, it locks into the grid immediately on that tick.

### 3.7 ARE (Appearance / Entry Delay)
After a piece locks, there is an entry delay before the next piece enters the playfield:
- **Base ARE (No Line Clear)**:
  - Calculated based on the lock height ($Y_{\text{lock}} \in [2, 21]$):
    $$\text{ARE} = 10 + 2 \times \left\lfloor \frac{21 - Y_{\text{lock}}}{4} \right\rfloor \text{ frames}$$
  - Range: 10 frames (bottom row 21) to 18 frames (top row 2).
- **Line Clear Animation ARE**:
  - When 1 to 4 lines are cleared, an authentic center-outward clear animation plays for **20 frames** (5 stages $\times$ 4 frames):
    - Stage 1 (frames 0–3): Clear columns 4 & 5.
    - Stage 2 (frames 4–7): Clear columns 3 & 6.
    - Stage 3 (frames 8–11): Clear columns 2 & 7.
    - Stage 4 (frames 12–15): Clear columns 1 & 8.
    - Stage 5 (frames 16–19): Clear columns 0 & 9.
  - Line drop shift occurs upon animation completion, followed by an additional ARE delay (~17–20 frames) before the next tetromino enters.

### 3.8 Authentic Scoring & Level Progression
- **Line Clear Scoring**:
  $$\text{Score}_{\text{Single}} = 40 \times (\text{Level} + 1)$$
  $$\text{Score}_{\text{Double}} = 100 \times (\text{Level} + 1)$$
  $$\text{Score}_{\text{Triple}} = 300 \times (\text{Level} + 1)$$
  $$\text{Score}_{\text{Tetris}} = 1200 \times (\text{Level} + 1)$$
- **Level Transitions**:
  - Starting Level $S \in [0, 19]$.
  - The first level transition occurs when total lines cleared reaches:
    $$\text{Threshold}_0 = \min(S \times 10 + 10, \max(100, S \times 10 - 50))$$
    - If starting at Level 0: Transition at 10 lines.
    - If starting at Level 9: Transition at 100 lines.
    - If starting at Level 18: Transition at 130 lines.
    - If starting at Level 19: Transition at 140 lines.
  - After $\text{Threshold}_0$ is reached, every subsequent level transition requires clearing exactly **10 lines**.

### 3.9 Level Palette Cycling
The color scheme shifts every level based on the last digit of the level number ($\text{Level} \pmod{10}$):

| Level Digit | Primary Color | Secondary Color | Tertiary Color |
| :---: | :--- | :--- | :--- |
| **0** | Blue (`#0058F8`) | Light Blue (`#3CBCFC`) | White (`#FCFCFC`) |
| **1** | Green (`#00A800`) | Light Green (`#80D010`) | White (`#FCFCFC`) |
| **2** | Purple (`#880070`) | Pink (`#F878F8`) | White (`#FCFCFC`) |
| **3** | Dark Blue (`#0058F8`) | Cyan (`#58F898`) | White (`#FCFCFC`) |
| **4** | Magenta (`#D80058`) | Green (`#00E800`) | White (`#FCFCFC`) |
| **5** | Light Green (`#58F898`) | Light Purple (`#6888FC`) | White (`#FCFCFC`) |
| **6** | Dark Red (`#E40058`) | Orange (`#F83800`) | White (`#FCFCFC`) |
| **7** | Dark Purple (`#6844FC`) | Purple (`#9878F8`) | White (`#FCFCFC`) |
| **8** | Dark Blue (`#0058F8`) | Ochre / Orange (`#F85800`) | White (`#FCFCFC`) |
| **9** | Orange (`#F83800`) | Light Orange (`#FFA044`) | White (`#FCFCFC`) |

---

## 4. Software Architecture & Design Patterns

### 4.1 Architectural Invariants
1. **Deterministic 60 TPS Simulation**:
   - All core gameplay logic (gravity counters, DAS timers, ARE phases, piece movement, line collapse) runs strictly inside `_physics_process(delta)` where `delta == 1.0 / 60.0`.
   - `_process(delta)` is reserved solely for UI smoothing or rendering interpolations if needed.
2. **Strict Static Typing**:
   - Untyped variables, parameters, or return signatures are strictly prohibited (e.g. `var speed := 0` or `var speed: int = 0`, `func update() -> void:`).
3. **Composition Over Inheritance**:
   - Distinct systems are decoupled into focused nodes and utility classes rather than a monolithic hierarchy.
4. **No God Objects**:
   - `Main.gd` coordinates top-level orchestration and scene attachment only. State, physics, scoring, rendering, and input are encapsulated in dedicated modules.

```
                           +-------------------+
                           |    Main Scene     |
                           +---------+---------+
                                     |
      +----------------+-------------+------------+----------------+
      |                |                          |                |
      v                v                          v                v
+-----------+  +---------------+          +---------------+  +------------+
| BoardGrid |  |PieceController|          | ScoreManager  |  |PlayfieldR..|
+-----+-----+  +-------+-------+          +-------+-------+  +-----+------+
      |                |                          |                |
      +----------------+------------+-------------+----------------+
                                    |
                                    v (Signals)
                           +-------------------+
                           |     EventBus      |
                           +-------------------+
                                    ^
                                    | (Lookups)
                           +-------------------+
                           |  ContentRegistry  |
                           +-------------------+
```

### 4.2 Planned Autoload Singletons

#### 1. `EventBus` (`res://src/core/event_bus.gd`)
Decoupled typed signal bus for engine-wide state notifications:
```gdscript
signal piece_spawned(piece_type: int, position: Vector2i, orientation: int)
signal piece_moved(piece_type: int, position: Vector2i, orientation: int)
signal piece_rotated(piece_type: int, position: Vector2i, orientation: int)
signal piece_locked(piece_type: int, position: Vector2i, orientation: int)
signal lines_clearing(rows: Array[int], frame_step: int)
signal lines_cleared(count: int, rows: Array[int])
signal score_updated(current_score: int, points_added: int)
signal lines_updated(total_lines: int)
signal level_updated(new_level: int)
signal game_over()
signal game_restarted()
```

#### 2. `ContentRegistry` (`res://src/core/content_registry.gd`)
Central repository for static game tables, tetromino matrices, palettes, and tile textures:
- Tetromino rotation offsets: 4 orientations $\times$ 4 coordinates for each of the 7 pieces.
- Authentic gravity lookup tables.
- NES 64-color master palette & per-level palette mappings.
- Active tile textures (procedurally generated or CHR-ROM extracted).

### 4.3 Planned Target Module Responsibilities

1. **`BoardGrid` (`src/game/board_grid.gd`)**:
   - Encapsulates the 10x22 grid matrix.
   - Manages bounds validation, cell occupancy queries, piece placement, line completion detection, and line collapse.
2. **`DASHandler` (`src/game/das_handler.gd`)**:
   - Tracks directional input frames (Left/Right).
   - Manages the 16-frame charge and 6-frame repeat intervals.
   - Preserves DAS state across piece transitions and ARE delays.
3. **`PieceController` (`src/game/piece_controller.gd`)**:
   - Manages active piece state (type, grid position, orientation).
   - Advances gravity counters using level timing tables.
   - Handles soft drop input and validates rotation/translation via `BoardGrid`.
   - Triggers piece lock and signals `EventBus`.
4. **`ScoreManager` (`src/game/score_manager.gd`)**:
   - Implements authentic BPS scoring, lines cleared tracking, and starting level transition formulas.
5. **`PlayfieldRenderer` (`src/game/playfield_renderer.gd`)**:
   - Renders the 10x20 visible matrix, active piece, next-piece preview, and 5-step center-outward line clear animation using 8x8 tile textures.
6. **`AudioManager` (`src/audio/audio_manager.gd`)**:
   - Procedural synthesis or sound-bank playback for piece movement blips, rotation clicks, drop thuds, line-clear chirps, and game-over jingles.
7. **`CHR2BPPExtractor` (`src/importer/chr_extractor.gd`)**:
   - Pure GDScript parser for optional user-provided `.nes` files.
   - Decodes 2bpp bitplanes into indexed 8x8 `Image` textures.

---

## 5. Planned Target Directory Layout

```text
res://
├── project.godot                     # Godot 4.3 project configuration (GL Compatibility)
├── .editorconfig                     # Editor formatting standards
├── .gitattributes                    # Git line-ending normalization
├── .gitignore                        # Clean-room asset boundaries & Godot ignores
├── AGENTS.md                         # Global agent execution blueprint (Untouched)
├── README.md                         # Clean-room project overview & instructions
├── TetrisNESDisasm/                  # Local reference disassembly (Reverse-engineering reference)
├── docs/
│   ├── ARCHITECTURE.md               # Authentic NES Tetris architectural specifications
│   ├── MEMORY.md                     # Hardware constraints & persistent project notes
│   ├── STATUS.md                     # Phase roadmap & verification checklist
│   ├── USER.md                       # User profile & environment context (Untouched)
│   └── SOUL.md                       # Assistant persona & execution rules (Untouched)
├── src/
│   ├── core/
│   │   ├── constants.gd              # [Planned] Game enums, dimensions, scoring tables, timings
│   │   ├── event_bus.gd              # [Stub] Typed signal dispatcher
│   │   └── content_registry.gd       # [Stub] Tetromino matrices, palettes, textures
│   ├── game/
│   │   ├── board_grid.gd             # [Planned] 10x22 grid state & collision queries
│   │   ├── das_handler.gd            # [Planned] Frame-accurate 16/6 DAS input handler
│   │   ├── piece_controller.gd       # [Planned] Active tetromino state & gravity simulation
│   │   ├── piece_randomizer.gd       # [Planned] 1989 two-roll randomizer implementation
│   │   ├── score_manager.gd          # [Planned] Authentic scoring & level transitions
│   │   ├── playfield_renderer.gd     # [Planned] 256x240 canvas item & 8x8 tile renderer
│   │   └── game_state_machine.gd     # [Planned] Play, ARE, LineClear, GameOver states
│   ├── audio/
│   │   └── audio_manager.gd          # [Planned] Sound dispatcher & procedural APU synthesizer
│   ├── importer/
│   │   └── chr_extractor.gd          # [Planned] Pure GDScript iNES header & 2bpp CHR-ROM parser
│   └── main.tscn                     # [Stub] Root scene placeholder
└── tests/
    ├── test_runner.gd                # [Planned] Headless verification harness
    ├── test_randomizer.gd            # [Planned] Verification of 1989 piece distribution
    ├── test_gravity_timing.gd        # [Planned] Verification of frame-accurate gravity drops
    ├── test_das.gd                   # [Planned] Verification of 16-frame charge & 6-frame repeat
    ├── test_nrs_rotation.gd          # [Planned] Verification of NRS rotation & kick absence
    └── test_scoring.gd               # [Planned] Verification of BPS scoring & level transitions
```
