# Project Status (`docs/STATUS.md`)

## Current Phase
- **Phase 3: High Score System & Polish (Next Target)**
  - **Context**: Implement the persistent high score system (table, entry screen, signature inputs) and authentic game polish (curtain wipe topout animation, rocket ending sequence).
  - **Rule**: Zero procedural fallbacks. All graphics and palettes sourced directly from extracted ROM assets in `user://nes_data/`.
  - **Completed Foundation**:
    1. Core Autoloads & Enums (`constants.gd`, `event_bus.gd`, `content_registry.gd`)
    2. Gameplay Simulation Components (`piece_randomizer.gd`, `board_grid.gd`, `das_handler.gd`, `piece_controller.gd`, `score_manager.gd`, `game_state_machine.gd`)
    3. Baseline Rendering, Audio & Importer (`playfield_renderer.gd`, `audio_manager.gd`, `chr_extractor.gd`, `main.gd`, `main.tscn`)
    4. Mandatory ROM Ingestion Refactor (`chr_extractor.gd`, `content_registry.gd`, `audio_manager.gd`, `main.gd`, `playfield_renderer.gd`)
    5. Phase 2: Menu Flow & Game Modes (`menu_controller.gd`, nametable extraction, Type B mode, level 10-19 shortcut)

---

## Phase 2: Menu Flow & Game Modes (Completed)

### 1. Authentic Menu Flow & State Machine (`src/game/menu_controller.gd`)
- [x] Title Screen with authentic animated logo and copyright notice:
  - Compressed PPU nametable extracted from PRG-ROM offset `0x003229` (CPU `$B219`).
  - Rendered at 256x240 with CHR Bank 0 graphics and authentic menu palette.
  - Flashing "PUSH START BUTTON" text, advancing to Game Type Menu on `BUTTON_START`.
- [x] Game Type A / Type B Selection Screen:
  - Compressed PPU nametable extracted from PRG-ROM offset `0x00368A` (CPU `$B67A`).
  - Left/Right controller navigation between `A-TYPE` and `B-TYPE` with flashing selection box.
  - `BUTTON_B` returns to Title Screen; `BUTTON_START` advances to Level Menu.
- [x] Music Track Selection Screen:
  - Integrated into Game Type menu with options `MUSIC-1` (Korobeiniki), `MUSIC-2`, `MUSIC-3`, and `OFF`.
  - Up/Down navigation with live audio preview and flashing cursor arrow.
- [x] Starting Level (0–19) and Type B Height (0–5) selection menus:
  - Compressed PPU nametable extracted from PRG-ROM offset `0x003AEB` (CPU `$BADA`).
  - Dynamic Type A height blanking patch extracted from ROM offset `0x00496D` (CPU `$C95D`).
  - 2x5 grid navigation for Levels 0..9 (Left/Right step 1, Up/Down jump 5).
  - Authentic `A + START` secret: holding Button A while pressing Start adds 10 to selected level (Levels 10..19).
  - Type B Height selection: Button A toggles between Level and Height selection; 2x3 grid navigation for Heights 0..5 (Left/Right step 1, Up/Down jump 3).

### 2. Type B Mode Gameplay Simulation (`src/game/`)
- [x] Implemented `BoardGrid.setup_type_b_garbage()`:
  - Generates authentic starting garbage for heights 0..5 (`[0, 3, 5, 8, 10, 12]` rows).
  - Populates cells using authentic NES `rngTable` (`[0, 1, 0, 2, 3, 3, 0, 0]`).
  - Implemented `typeBGuaranteeBlank` ensuring at least one empty cell per row so lines never spawn pre-cleared.
- [x] Implemented Type B scoring & 25-line goal in `ScoreManager`:
  - `lines` and `lines_remaining` count down from 25 to 0.
  - Display HUD shows lines remaining in Type B mode.
  - Clearing 25 lines triggers goal achieved flag and awards authentic Type B completion bonus: `(Level + 1) * 1000 + Height * 1000`.

### 3. Automated Headless Verification
- [x] Created `tests/test_menu.gd` covering 9 comprehensive test suites:
  - MenuController initialization & default state.
  - Title screen Start button transition & sound.
  - Game Type menu navigation (A/B, Music 1..3 & Off, B button return).
  - Level menu navigation for Type A.
  - Authentic `A + START` level 10..19 cheat.
  - Type B height selection & Button A toggle.
  - Type B garbage row counts (0, 3, 5, 8, 10, 12) & guaranteed blank holes.
  - Type B 25-line countdown, goal achieved trigger, and completion bonus formula.
  - 1024-byte nametable decoding and 256x240 menu texture rendering.
- [x] Verified full headless test suite: **11/11 test suites passing cleanly** via `godot --headless -s tests/test_runner.gd`.

---

## Phase 1.5 Refactor: Mandatory ROM Ingestion (Completed)

### 1. Cryptographic ROM Verification & 100% Data Extraction (`src/importer/`)
- [x] Implemented cryptographic checksum validation (SHA-256 and CRC32) for user-supplied `tetris.nes`:
  - PRG-ROM (32KB): SHA-256 `a2de35dfa7333b0458762a1485fb612b6bdc9b5a15269f0fcf5a6be67c0d89de` / CRC32 `0x943DFBBE`
  - CHR-ROM (16KB): SHA-256 `23789834e66947081aa5d34efe092beb69a91273abc62089a8bb7c00f67ff751` / CRC32 `0x251AF21C`
- [x] Extracted 100% of authentic graphics from 16KB CHR-ROM into PNG texture atlases in `user://nes_data/`:
  - Bank 0: Title screen logo, copyright notice, menu graphics.
  - Bank 1: Type B setup menu, height indicators, congratulations screen.
  - Bank 2: Type A game frame, high score screen, ending rocket sequence.
  - Bank 3: In-game playfield mino blocks (bevel, gem, square highlight), UI borders, and NES font glyphs.
- [x] Extracted 100% of authentic game lookup tables directly from PRG-ROM into structured data caches in `user://nes_data/`:
  - Level color palettes (`$984C` / ROM offset `0x00185C`, 10 levels $\times$ 4 colors).
  - Gravity frame lookup tables (`$898E` / ROM offset `0x00099E`, Levels 00..29+).
  - BPS scoring coefficients (`$9CA5` / ROM offset `0x001CB5`, BCD decoded to 0, 40, 100, 300, 1200).
  - Authentic piece spawn orientations (`$994E` / ROM offset `0x00195E`, `[2, 7, 8, 10, 11, 14, 18]`).
- [x] Extracted 100% of authentic sound engine tables and music bytecode streams from PRG-ROM:
  - Note-to-frequency period lookup tables (`$C645` / `0x004655`).
  - Note duration tables (`$C6EB` / `0x0046FB`).
  - Music track bytecode streams: Music 1 (Korobeiniki), Music 2, Music 3, High Score, and Ending themes (`$C737` / `0x004747`).

### 2. Elimination of Procedural Fallbacks (`src/core/` & `src/audio/`)
- [x] Refactored `src/core/content_registry.gd`:
  - Completely removed `generate_procedural_tile_image()` and procedural tile synthesis algorithms.
  - Ingests 100% of tiles, fonts, frames, and tables from extracted ROM data in `user://nes_data/`.
  - Enforced strict uninitialized error handling: returns empty textures and rejects gameplay initialization if extracted assets are missing.
- [x] Refactored `src/audio/audio_manager.gd`:
  - Ingests extracted PRG-ROM pitch tables, duration counters, and music tables.
  - Configured authentic 16-bit timer periods and envelope timing.

### 3. Startup ROM Guard & Missing ROM Screen (`src/main.gd` & `src/game/`)
- [x] Added `ROM_SETUP` state to `GameStateMachine` and startup gate in `main.gd`:
  - Checks for existing extracted assets in `user://nes_data/`.
  - If missing, checks for `user://nes_data/tetris.nes` or workspace `tetris.nes` to trigger automatic extraction.
  - If no ROM is found, immediately halts game initialization and enters `ROM_SETUP` state.
- [x] Updated `src/game/playfield_renderer.gd` to render the authentic Missing ROM setup prompt when in `ROM_SETUP` state.

---

## Completed Milestones (Phase 1 Baseline)

### 1. Core Autoloads & Enums (Completed)
- [x] Initialized Git repository with clean-room `.gitignore` (strictly excluding all ROM binaries, dumps, and runtime data).
- [x] Configured repository environment files (`.editorconfig`, `.gitattributes`).
- [x] Preserved untouched global context blueprints (`AGENTS.md`, `docs/USER.md`, `docs/SOUL.md`).
- [x] Integrated local reference disassembly (`TetrisNESDisasm/`) for reverse engineering and parameter validation.
- [x] Implemented `src/core/constants.gd`: Authentic dimensions, gravity frames, BPS scoring formulas, master palettes, DAS timings, and NRS rotation tables.
- [x] Implemented `src/core/event_bus.gd`: Fully typed global signal dispatcher for simulation lifecycle events.
- [x] Implemented `src/core/content_registry.gd`: Authentic mino offsets, 4x4 coordinate matrices, and level texture caching.

### 2. Gameplay Simulation Components (Completed)
- [x] Implemented `src/game/piece_randomizer.gd`: Authentic 1989 two-roll randomizer verified statistically over 100,000 rolls with duplicate rate $3.55\%$ (matching theoretical $1/28 \approx 3.57\%$).
- [x] Implemented `src/game/board_grid.gd`: 10x22 cell matrix, fast bounds validation, cell occupancy queries, piece locking, full-row detection, 5-step center-outward clearing, and linear-time multi-row collapse.
- [x] Implemented `src/game/das_handler.gd`: Authentic 16-frame initial charge counter, 6-frame repeat interval (reloaded to 10), directional reversal reset, and pre-charging preserved across ARE and line clears.
- [x] Implemented `src/game/piece_controller.gd`: Active piece translation, NRS rotation strictly rejecting wall/floor kicks, level-based gravity timer, soft drop (1 drop / 2 frames with +1 score), mino position queries (`get_mino_positions`), and instant surface contact lock.
- [x] Implemented `src/game/score_manager.gd`: BPS scoring ($40, 100, 300, 1200 \times (\text{level} + 1)$), soft drop point tracking, starting level transition thresholds ($\min(S \times 10 + 10, \max(100, S \times 10 - 50))$), and subsequent 10-line level progression.
- [x] Implemented `src/game/game_state_machine.gd`: Complete finite state machine (`SPAWNING`, `ACTIVE_PLAY`, `LINE_CLEAR_ANIM`, `ARE_DELAY`, `GAME_OVER`, `ROM_SETUP`), deterministic 60 TPS `_physics_process` loop, ARE delay calculation, 20-frame 5-step center-outward line clear sequence, and spawn row lockout detection.

### 3. Rendering, Audio & Baseline Importer (Completed)
- [x] Implemented `src/game/playfield_renderer.gd`: Pixel-perfect 256x240 viewport CanvasItem renderer, 10x20 visible playfield bounding box at (X: 96, Y: 40), locked mino cells, active piece rendering, preview box at (X: 192, Y: 112), and HUD text rendering.
- [x] Implemented `src/audio/audio_manager.gd`: Clean-room 2A03 APU audio synthesizer (Pulse, Triangle, Noise channels) using `AudioStreamGenerator`, authentic SFX envelopes (`SHIFT`, `ROTATE`, `LOCK`, `LINE_CLEAR`, `TETRIS`, `LEVEL_UP`, `GAME_OVER`), and headless synthesis buffers.
- [x] Implemented `src/importer/chr_extractor.gd`: Pure GDScript iNES header parsing (`NES\x1A`), 2bpp planar tile decoding, 128x128 bank sheet and 8x8 tile image generation, PRG-ROM palette extraction (CPU $984C / ROM offset 0x00185C), and `apply_to_content_registry` texture injection.
- [x] Implemented `src/main.gd` & updated `src/main.tscn`: Root scene coordinator wiring state machine, renderer, and audio manager to the 60 TPS simulation loop.
- [x] Automated Headless Verification: 10 test suites passing 100% of assertions.

---

## Future Phases

### Phase 3: High Score System & Polish
- [ ] High Score Table with persistent storage in `user://high_scores.dat`.
- [ ] High Score Entry Screen with 3-character initials input.
- [ ] Topout animation curtain wipe and ending rocket sequence animations (from CHR Bank 2).
