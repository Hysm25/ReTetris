---
tags: [ai-context, memory]
updated: 2026-11-20
---

# Persistent Memory & Quirks (`docs/MEMORY.md`)

## 1. Project Context & Objectives
- **Clean-Room ReTetris**: Faithful, clean-room 1989 NES Tetris re-implementation built with Godot 4.3+ and strictly typed GDScript.
- **Simulation Target**: Frame-accurate NTSC 60Hz NES Tetris (Nintendo version, Nov 1989) running on a deterministic 60 TPS `_physics_process` loop.
- **Legal Boundary & Mandatory ROM Ingestion**:
  - **Zero Copyrighted Assets in Git**: Absolutely zero proprietary ROM binaries, CHR dumps, PRG code, audio recordings, or copyrighted graphics are committed to version control.
  - **Mandatory ROM Ingestion (Zero Procedural Fallbacks)**: Procedural tile synthesis and procedural audio approximations are strictly prohibited in the final architecture. The engine refuses to initialize gameplay unless a valid user-provided `tetris.nes` ROM is present in `user://nes_data/` (or workspace root for auto-extraction).
  - **Missing ROM Screen**: If extracted assets are missing and no ROM is found, the runtime halts initialization and displays a dedicated setup screen instructing the user where to supply `tetris.nes`.
  - **100% Data & Asset Extraction**:
    - The importer validates the ROM via SHA-256 / CRC32 checksums.
    - Extracts 100% of authentic game graphics from 16KB CHR-ROM (tiles, font glyphs, borders, menus, ending sprites).
    - Extracts 100% of authentic game tables from PRG-ROM (palettes at `$984C`, gravity timing tables, BPS scoring values, spawn orientations, preview offsets).
    - Extracts 100% of authentic APU sound tables, note durations, envelope streams, and BGM tracks from PRG-ROM sound data.
- **Reference Disassembly**:
  - The repository includes a local disassembly reference (`TetrisNESDisasm/`) and local test ROM (`Tetris (USA).nes`, git-ignored).
  - Used strictly for reverse-engineering validation of authentic timings, RNG mechanics, RAM addresses, and formulas without incorporating proprietary code into the clean-room engine.
- **Display Target**: 256x240 native NES viewport resolution, integer scaling (`viewport` stretch mode, `keep` aspect ratio), and nearest-neighbor texture filtering (no blurry bilinear filtering).

---

## 2. Hardware Constraints & Environment Quirks
- **Primary Desktop**: Dell OptiPlex 390 (Intel Core i5-2400 Sandy Bridge, 4C/4T, AMD Radeon GPU) running **CachyOS Linux** (KDE Plasma).
  - *Hard Constraint*: Sandy Bridge CPU supports **AVX only** (NO AVX2 / FMA3). Pre-compiled binaries with AVX2 will crash with `SIGILL`.
  - *Bun Constraint*: Standard `bun` release crashes on Sandy Bridge; must use **`bun-baseline`**.
  - *C/C++ Flags*: Compile native modules with `-march=sandybridge` or `-mno-avx2`.
  - *Rust Flags*: `.cargo/config.toml` target `rustflags = ["-C", "target-cpu=sandybridge"]`.
- **Mobile Dev Node**: Xiaomi Redmi Note 15 5G (Snapdragon 6 Gen 3, Adreno 710) running Android 16 (HyperOS) with **Termux** + **Fedora PRoot** (`aarch64`, `dnf`).
  - *Hard Constraint*: Optimize for thermal and memory efficiency.
  - *Systemd Absence*: `systemd` is unavailable inside PRoot (`systemctl` fails). Avoid background service commands relying on PID 1 init. Run daemons directly or via script wrappers.
  - *DNF Mirrors*: Keep `max_parallel_downloads=10` and `fastestmirror=True` in `/etc/dnf/dnf.conf`.
- **Primary Shell**: **`fish`** across both CachyOS desktop and Termux PRoot.
  - Interactive terminal commands must strictly use `fish` syntax (e.g. `set -gx VAR val`, `set -a PATH /path`).
  - Standalone scripts must use POSIX/Bash with explicit shebang (`#!/usr/bin/env bash`).
- **Safe Execution Policy**:
  - Always request explicit user confirmation before executing destructive operations (`rm -rf`, overwriting unversioned files), persistent OS/system modifications, package removals, or `git push` to remote repositories.

---

## 3. Architectural Invariants
- **Deterministic 60 TPS Simulation**:
  - All physics, gravity timers, DAS charging, ARE delays, and line-clear stages run exclusively inside `_physics_process(delta)`.
  - `physics_ticks_per_second` is locked to 60.
- **Strict Static Typing**:
  - Strict typing is mandatory for all variables, constants, function arguments, and return types. No untyped signatures allowed.
- **Mandatory ROM Ingestion & Zero Hardcoded Approximations**:
  - All visual assets (tiles, fonts, UI borders), color palettes, gravity frame counters, scoring multipliers, APU register envelopes, and music tracks must be sourced from authentic ROM bytes extracted into `user://nes_data/`.
  - Procedural fallbacks and hardcoded approximation tables are completely removed.
- **Startup Gate & ROM Guard**:
  - On startup, the engine verifies the presence of extracted data in `user://nes_data/`. If missing, it checks for `tetris.nes` to auto-extract. If no ROM is present, gameplay refuses to start, and the engine displays a Missing ROM prompt.
- **Composition Over Inheritance & No God Objects**:
  - Systems are decoupled into specialized components: `BoardGrid`, `DASHandler`, `PieceController`, `ScoreManager`, `PlayfieldRenderer`, `AudioManager`, and `CHRExtractor`.
- **Autoload Singletons**:
  1. `EventBus` (`res://src/core/event_bus.gd`): Typed global event dispatcher.
  2. `ContentRegistry` (`res://src/core/content_registry.gd`): Ingests extracted tables, palettes, matrices, and tile textures.
- **Authentic NES Tetris Specifications**:
  - **Grid**: 10 columns x 22 rows (Rows 0-1 hidden spawn buffer, Rows 2-21 visible playfield).
  - **Randomizer**: Authentic 1989 two-roll piece generation (Roll 1: 0..7, if duplicate of previous or 7, Roll 2: 0..6; yields ~3.57% duplicate rate).
  - **Rotation**: Nintendo Rotation System (NRS) with zero wall-kicks and zero floor-kicks.
  - **DAS**: 16-frame charge, 6-frame repeat rate, with charge preserved across piece lock and ARE delays.
  - **Gravity Table**: Level 0 (48 frames/drop) down to Level 19-28 (2 frames/drop) and Level 29+ (1 frame/drop).
  - **ARE (Entry Delay)**: $10 + 2 \times \lfloor (21 - Y_{\text{lock}}) / 4 \rfloor$ frames without line clear; 20-frame 5-step center-outward animation when lines clear.
  - **Scoring**: Original BPS line clear score formula ($40, 100, 300, 1200 \times (\text{Level} + 1)$) and $+1$ point per soft drop cell.
  - **Level Transition**: First transition at $\min(S \times 10 + 10, \max(100, S \times 10 - 50))$ for starting level $S$, then every 10 lines.

---

## 4. Active Session Notes & Clean-Slate Baseline Log
- Initialized clean-room project repository for ReTetris.
- Established clean-room asset boundary: configured `.gitignore` to strictly exclude all ROMs (`*.nes`, `*.fds`, `*.rom`, `*.bin`, `*.sav`) and runtime data dumps (`nes_data/`, `user/`, `extracted/`).
- Added workspace standards (`.editorconfig`, `.gitattributes`).
- Preserved untouched global context blueprints:
  - `AGENTS.md`
  - `docs/USER.md`
  - `docs/SOUL.md`
- Integrated local reference disassembly (`TetrisNESDisasm/`) for reverse engineering and parameter validation.
- Configured baseline `project.godot`:
  - `gl_compatibility` renderer for low-overhead execution on both Intel HD graphics and mobile Adreno 710.
  - Native 256x240 viewport resolution with integer scaling override (768x720, 3x scale).
  - Nearest-neighbor texture filter (`default_texture_filter = 0`).
  - 60 TPS physics tick rate.
- **Phase 1 Baseline Completion**:
  - **Milestone 1 Completed**: Core Autoloads & Enums (`constants.gd`, `event_bus.gd`, `content_registry.gd`).
  - **Milestone 2 Completed**: Gameplay Simulation Components (`piece_randomizer.gd`, `board_grid.gd`, `das_handler.gd`, `piece_controller.gd`, `score_manager.gd`, `game_state_machine.gd`).
  - **Milestone 3 Completed**: Rendering, Audio & Importer (`playfield_renderer.gd`, `audio_manager.gd`, `chr_extractor.gd`, `main.gd`, `main.tscn`).
  - **Headless Verification**: Executed and verified headlessly via `godot --headless --path . --quit` and `godot --headless -s tests/test_runner.gd` (Godot 4.7.1 on Fedora PRoot ARM64), running 10 comprehensive automated test suites (`test_core.gd`, `test_randomizer.gd`, `test_board_grid.gd`, `test_das.gd`, `test_piece_controller.gd`, `test_score_manager.gd`, `test_game_simulation.gd`, `test_renderer.gd`, `test_audio.gd`, `test_importer.gd`) passing 100% of assertions with zero errors or warnings.
- **Phase 1.5 Refactor Completion (Mandatory ROM Asset & Data Ingestion)**:
  - **Cryptographic Verification**: Implemented pure GDScript SHA-256 and CRC32 checksum routines for authentic 1989 NTSC NES Tetris (PRG-ROM 32KB: `a2de...` / `0x943DFBBE`, CHR-ROM 16KB: `2378...` / `0x251AF21C`).
  - **100% Authentic Data Extraction**:
    - CHR-ROM: Extracts 16KB pattern tables across all 4 banks (Bank 0 Title/Menu, Bank 1 Type B, Bank 2 Type A/Endings, Bank 3 In-game blocks/fonts).
    - PRG-ROM: Extracts palettes at CPU `$984C` (`0x00185C`), gravity drop table at CPU `$898E` (`0x00099E`), BCD-encoded points scoring table at CPU `$9CA5` (`0x001CB5`, decoded to 0, 40, 100, 300, 1200), spawn orientations at CPU `$994E` (`0x00195E`), and APU sound tables at CPU `$C645`, `$C6EB`, `$C737`.
  - **Elimination of Procedural Fallbacks**:
    - Completely removed `generate_procedural_tile_image()` and synthetic tile generation logic from `ContentRegistry`.
    - ContentRegistry and AudioManager require authentic extracted ROM assets and reject gameplay initialization if uninitialized.
  - **Startup ROM Guard & Missing ROM Screen**:
    - Implemented automatic ROM ingestion in `main.gd` scanning `user://nes_data/` and root `tetris.nes`.
    - Added `ROM_SETUP` state to `GameStateMachine` and dedicated setup prompt in `PlayfieldRenderer` directing player to provide `tetris.nes` when data is missing.
  - **Headless Verification**: Executed `godot --headless --path . --quit` and `godot --headless -s tests/test_runner.gd` with 10/10 test suites passing cleanly with zero errors.
- **Phase 2 Completion (Menu Flow & Game Modes)**:
  - **Menu Controller**: Implemented `src/game/menu_controller.gd` orchestrating authentic 60 TPS menu state machine (`TITLE_SCREEN`, `GAME_TYPE_MENU`, `LEVEL_MENU`, `IN_GAME`).
  - **Authentic PPU Nametable Extraction**: Added `decode_ppu_nametable_stream()` and `render_nametable_image()` in `src/importer/chr_extractor.gd` extracting Title Screen (`0x003229`), Game Type menu (`0x00368A`), Level menu Type B (`0x003AEB`), and Type A height patch (`0x00496D`), rendering 256x240 authentic textures via CHR Bank 0 and menu palette (`$9731` / `0x002D3B`).
  - **Game Modes & Navigation**:
    - Title Screen: Blinking "PUSH START BUTTON", Start button transitions to Game Type Menu.
    - Game Type Menu: Left/Right selects A-TYPE / B-TYPE; Up/Down selects MUSIC-1, MUSIC-2, MUSIC-3, OFF with audio preview and cursor flicker.
    - Level Menu: 2x5 grid navigation for Levels 0..9 (Left/Right step 1, Up/Down jump 5).
    - Authentic A+Start Secret: Holding Button A while pressing Start launches starting levels 10..19.
    - Type B Height Selection: Button A toggles between Level and Height selection; 2x3 grid navigation for Heights 0..5 (Left/Right step 1, Up/Down jump 3).
  - **Type B Simulation Mechanics**:
    - Implemented `BoardGrid.setup_type_b_garbage()` generating 0, 3, 5, 8, 10, 12 rows for heights 0..5 using authentic `rngTable` and `typeBGuaranteeBlank` (guaranteed blank holes per row).
    - Implemented 25-line goal countdown and victory bonus `(Level + 1) * 1000 + Height * 1000` in `ScoreManager`.
  - **Headless Verification**: Ran `godot --headless --path . --quit` and full automated test suite `godot --headless -s tests/test_runner.gd` with **11/11 test suites passing cleanly** (including `tests/test_menu.gd`).
- **Phase 3 Completion (High Score System & Polish)**:
  - **High Score Manager**: Implemented `src/game/high_score_manager.gd` with Top 3 tables for Game A and Game B, persistent storage in `user://high_scores.dat`, authentic PRG-ROM default high scores (`0x002D77`), and authentic tie-breaking rules (prefers newer score).
  - **High Score Entry & Table**:
    - Extracted High Scores nametable (`0x003D3E`) and Enter High Score nametable (`0x0043AD`).
    - Implemented 6-character initials input with Up/Down character cycling, Left/Right navigation, and held auto-repeat in `MenuController`.
    - Implemented High Scores Table with Left/Right toggle between A-TYPE and B-TYPE.
  - **Topout Curtain Wipe Animation**:
    - Implemented authentic 20-row curtain wipe in `GameStateMachine`: 64-frame initial delay, 20 rows filled (4 frames per row, 80 frames, 148 frames full cycle), and noise channel `SFX_CURTAIN`.
  - **Rocket Ending Animations**:
    - Extracted ending screen nametable (`0x004E17`) and ending palette (`0x002D53`).
    - Implemented 5 authentic score tiers for Type A (30k small, 50k medium-small, 70k medium, 100k large, 120k Saint Basil's cathedral), 240-frame launchpad hold, liftoff climb, and animated thruster flames.
  - **Headless Verification**: Ran `godot --headless --path . --quit` and full automated test suite `godot --headless -s tests/test_runner.gd` with **12/12 test suites passing cleanly** (including `tests/test_high_scores.gd`).
- **Phase 4 Completion (Full 2A03 APU Music Bytecode Engine & Demo Playback)**:
  - **Multi-Channel 2A03 APU Bytecode Player**: Implemented `src/audio/music_bytecode_player.gd` interpreting authentic PRG-ROM sound routines and volume envelopes at 60 TPS across Pulse 1, Pulse 2, Triangle, and Noise channels.
  - **10 Authentic Tracks**: Full bytecode support for Track 0 (Title), Track 1 (B-Type Goal), Track 2 (Music 1 Korobeiniki), Track 3 (Music 2 Troika), Track 4 (Music 3 Kalinka), fast tempo tracks 5-7, Track 8 (Congratulations), and Track 9 (Ending Rocket theme).
  - **Attract-Mode Demo Playback**: Implemented `src/game/demo_controller.gd` feeding recorded inputs from PRG-ROM offset `0x005D10` (CPU `$DD00`, 512 bytes) and authentic piece generation from `0x005F10` (CPU `$DF00`, 256 bytes) after 1280 frames of idle time on the title screen, with immediate Start-button exit.
  - **Retro CRT Scanline Shader**: Added lightweight CanvasItem shader `src/shaders/crt_scanlines.gdshader` with runtime toggle support in `PlayfieldRenderer`.
  - **Headless Verification**: Ran `godot --headless --path . --quit` and full automated test suite `godot --headless -s tests/test_runner.gd` with **13/13 test suites passing cleanly** (including `tests/test_music_engine.gd`).
  - **Next Target Milestone**: Standalone desktop and mobile packaging / input customization.
