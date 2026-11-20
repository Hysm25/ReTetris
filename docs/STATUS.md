# Project Status (`docs/STATUS.md`)

## Current Phase
- **Phase 1: Clean-Room Foundation & Core Simulation**
  - **Completed Milestone**: 1. Core Autoloads & Enums (`constants.gd`, `event_bus.gd`, `content_registry.gd`)
  - **Next Target**: 2. Gameplay Simulation Components (`piece_randomizer.gd`, `board_grid.gd`, `das_handler.gd`, etc.)

---

## Completed (Setup, Scaffolding & Milestone 1)
- [x] Initialized Git repository with clean-room `.gitignore` (strictly excluding all ROM binaries, dumps, and runtime data).
- [x] Configured repository environment files (`.editorconfig`, `.gitattributes`).
- [x] Preserved untouched global context blueprints (`AGENTS.md`, `docs/USER.md`, `docs/SOUL.md`).
- [x] Integrated local reference disassembly (`TetrisNESDisasm/`) for reverse engineering and parameter validation.
- [x] Defined comprehensive system architecture (`docs/ARCHITECTURE.md`):
  - Legal zero-copyrighted assets boundary (procedural generation fallback + optional 2bpp CHR-ROM extraction).
  - Authentic NTSC 60Hz NES Tetris specifications (10x22 grid, 256x240 viewport, two-roll RNG, NRS with zero kicks, 16/6 DAS with preservation, frame-accurate gravity, ARE, BPS scoring, and starting level transitions).
  - Deterministic 60 TPS `_physics_process` simulation, strictly typed GDScript, composition over inheritance, and decoupled autoloads.
- [x] Documented hardware constraints and architectural memory (`docs/MEMORY.md`):
  - AVX-only Intel Core i5-2400 Sandy Bridge (CachyOS), ARM64 Termux Fedora PRoot, and `fish` shell syntax standards.
- [x] Configured baseline `project.godot`:
  - `gl_compatibility` renderer for efficient low-end desktop and mobile execution.
  - Native 256x240 viewport resolution with 3x integer scaling override (768x720) and `viewport`/`keep` aspect mode.
  - Nearest-neighbor texture filter (`default_texture_filter = 0`).
  - Fixed 60 TPS physics tick rate (`physics_ticks_per_second = 60`).
  - Registered `EventBus` and `ContentRegistry` autoload declarations.
- [x] Established project directory scaffolding (`src/core/`, `src/game/`, `src/audio/`, `src/importer/`, `tests/`).
- [x] Authored repository `README.md` reflecting clean-room scope and pre-implementation baseline.
- [x] **Milestone 1 Completed & Verified**: Core Autoloads & Enums:
  - [x] Implemented `src/core/constants.gd`:
    - Full 7 tetromino definitions (`T`, `J`, `Z`, `O`, `S`, `L`, `I`), 20 authentic NES orientations, playfield geometry (10x22 grid, 10x20 visible, 2 hidden spawn rows, 256x240 viewport, screen offsets).
    - Authentic NTSC gravity frames lookup table (Levels 0 through 29+).
    - BPS scoring coefficients (40, 100, 300, 1200) and starting level transition formulas ($\min(S \times 10 + 10, \max(100, S \times 10 - 50))$).
    - Authentic NES 64-color master palette & 10 cycling level palettes (Levels 0-9) matching NES disassembly color tables.
    - DAS constants (16 charge, 6 repeat, 10 reload) and ARE formulas ($10 + 2 \times \lfloor(21 - Y_{\text{lock}})/4\rfloor$).
    - Full bidirectional NRS rotation tables (`ROTATION_TABLE_CW`, `ROTATION_TABLE_CCW`).
  - [x] Implemented `src/core/event_bus.gd`:
    - Fully typed global signal dispatcher for simulation lifecycle (`piece_spawned`, `piece_moved`, `piece_rotated`, `piece_locked`, `lines_clearing`, `lines_cleared`, `score_updated`, `lines_updated`, `level_updated`, `game_over`, `game_restarted`).
    - Helper typed emitter methods for decoupled architecture.
  - [x] Implemented `src/core/content_registry.gd`:
    - Authentic mino relative offset coordinates `ORIENTATION_MINO_OFFSETS` for all 20 orientations.
    - Static 4x4 coordinate offset matrices for all tetrominoes across all rotation states.
    - Clean-room procedural 8x8 pixel tile generator creating authentic pixel patterns for `PRIMARY` (bevel), `SECONDARY` (gem), and `TERTIARY` (inset highlight) styles using `Image` and `ImageTexture`.
    - Dynamic level tile texture cache and 32x8 tile atlas generator (`get_level_tile_atlas`).
  - [x] Implemented headless automated test suite `tests/test_core.gd` and harness `tests/test_runner.gd` (10/10 test suites passed headlessly via Godot 4.7.1).

---

## Phase 1 Implementation Roadmap (Pending)

### 1. Core Autoloads & Enums (Completed)
- [x] Implement `src/core/constants.gd`:
  - Tetromino IDs (`T`, `J`, `Z`, `O`, `S`, `L`, `I`), orientations (0..3 or 0..1), grid dimensions (10x22, 10x20 visible).
  - NTSC gravity frames lookup table (Levels 0 through 29+).
  - BPS scoring coefficients (40, 100, 300, 1200) and starting level transition formulas.
  - Authentic NES 64-color master palette & level color schemes (Levels 0-9 cycling).
- [x] Implement `src/core/event_bus.gd`:
  - Full implementation of typed global signals for simulation lifecycle (`spawned`, `moved`, `rotated`, `locked`, `clearing`, `cleared`, `score_updated`, `level_updated`, `game_over`).
- [x] Implement `src/core/content_registry.gd`:
  - Static 4x4 coordinate offset matrices for all 7 tetrominoes across all rotation states.
  - Clean-room procedural 8x8 pixel tile generator (bevel, gem, and block styles via `Image`/`ImageTexture`).
  - Level palette lookup and dynamic tile atlas generation.

### 2. Gameplay Simulation Components
- [ ] Implement `src/game/piece_randomizer.gd`:
  - Authentic 1989 two-roll randomizer algorithm ($R_1 \in [0, 7]$, if duplicate or 7, $R_2 \in [0, 6]$).
- [ ] Implement `src/game/board_grid.gd`:
  - 10x22 2D cell storage with fast bounds checking and occupancy queries.
  - Piece locking into grid cells.
  - Full-row detection, 5-step center-outward row clearing, and row collapse.
- [ ] Implement `src/game/das_handler.gd`:
  - Frame-accurate 16-frame initial charge counter and 6-frame repeat interval.
  - Directional change reset and DAS preservation across piece locks and ARE delays.
- [ ] Implement `src/game/piece_controller.gd`:
  - Active piece translation, NRS rotation (strictly validating against grid bounds and occupied cells with zero kicks).
  - Frame-accurate gravity step accumulator governed by level timing table.
  - Soft drop handling (1 drop every 2 frames, +1 score per cell).
  - Instant locking on contact without modern grace periods.
- [ ] Implement `src/game/game_state_machine.gd`:
  - Finite State Machine: `SPAWNING`, `ACTIVE_PLAY`, `ARE_DELAY`, `LINE_CLEAR_ANIM`, `GAME_OVER`.
  - Authentic entry delay calculation: $\text{ARE} = 10 + 2 \times \lfloor (21 - Y_{\text{lock}}) / 4 \rfloor$ frames.
  - 20-frame (5 steps $\times$ 4 frames) center-outward line clear animation.
  - Top-out / lockout detection in spawn rows 0-1.
- [ ] Implement `src/game/score_manager.gd`:
  - BPS line clear scoring formula ($40, 100, 300, 1200 \times (\text{Level} + 1)$).
  - Soft drop point accumulation.
  - Starting level transition threshold $\min(S \times 10 + 10, \max(100, S \times 10 - 50))$ and subsequent 10-line level advancement.

### 3. Rendering, Audio & Importer
- [ ] Implement `src/game/playfield_renderer.gd`:
  - Pixel-perfect 256x240 viewport rendering using CanvasItems / TileMapLayer.
  - 10x20 visible playfield bounding box at authentic NES screen offsets.
  - Next-piece preview box rendering.
  - HUD text rendering (Score, Lines, Level, Statistics).
  - Center-outward line clear animation rendering.
- [ ] Implement `src/audio/audio_manager.gd`:
  - Procedural sound synthesis mimicking 2A03 APU pulse, triangle, and noise channels for piece movement, rotation, lock, line clear, level transition, and game over.
- [ ] Implement `src/importer/chr_extractor.gd`:
  - Pure GDScript iNES header parsing and 2bpp planar CHR-ROM decoder into `user://nes_data/`.

### 4. Automated Headless Verification Test Suite
- [ ] Implement `tests/test_runner.gd` (headless test harness executable via `godot --headless --path . --quit`):
  - `tests/test_randomizer.gd`: Verify 100,000-roll distribution matches theoretical ~3.57% duplicate rate.
  - `tests/test_gravity_timing.gd`: Verify exact frame intervals per drop across Levels 00 through 29+.
  - `tests/test_das.gd`: Verify 16-frame initial charge, 6-frame repeat, and ARE preservation.
  - `tests/test_nrs_rotation.gd`: Verify all 7 tetromino rotations and assert total rejection of wall/floor kicks.
  - `tests/test_scoring.gd`: Verify exact scoring outputs and starting level transitions (e.g. Level 0, 9, 18, 19).
  - `tests/test_grid_collapse.gd`: Verify 5-step center-outward clearing and row shifts.
