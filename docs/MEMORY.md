---
tags: [ai-context, memory]
updated: 2026-11-20
---

# Persistent Memory & Quirks (`docs/MEMORY.md`)

## 1. Project Context & Objectives
- **Clean-Room ReTetris**: Faithful, clean-room 1989 NES Tetris re-implementation built with Godot 4.3+ and strictly typed GDScript.
- **Simulation Target**: Frame-accurate NTSC 60Hz NES Tetris (Nintendo version, Nov 1989) running on a deterministic 60 TPS `_physics_process` loop.
- **Legal & Asset Boundary**: Strictly zero copyrighted assets committed to version control.
  - Fallback: Clean-room procedural 8x8 pixel tile generator (GDScript `Image` / `ImageTexture`) + procedural 2A03 APU square/triangle/noise sound synthesis.
  - Optional ROM Ingestion: Pure GDScript 2bpp CHR-ROM parser extracting original tile graphics from user-provided `user://nes_data/tetris.nes`.
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
- **Composition Over Inheritance & No God Objects**:
  - Systems are decoupled into specialized components: `BoardGrid`, `DASHandler`, `PieceController`, `ScoreManager`, `PlayfieldRenderer`, and `AudioManager`.
- **Autoload Singletons**:
  1. `EventBus` (`res://src/core/event_bus.gd`): Typed global event dispatcher.
  2. `ContentRegistry` (`res://src/core/content_registry.gd`): Ingests tables, palettes, matrices, and tile textures.
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
- Authored comprehensive project documentation:
  - `docs/ARCHITECTURE.md`: Exhaustive 1989 NES Tetris specification (geometry, two-roll RNG, NRS, DAS, gravity/ARE timing, scoring, procedural generation fallback, and optional 2bpp CHR-ROM extractor).
  - `docs/MEMORY.md`: Hardware constraints (AVX-only Sandy Bridge, Termux PRoot ARM64, `fish` shell) and architectural invariants.
  - `docs/STATUS.md`: Phase 1 roadmap checklist for implementation and headless verification.
  - `README.md`: Repository scope, architecture overview, and build instructions.
- Configured baseline `project.godot`:
  - `gl_compatibility` renderer for low-overhead execution on both Intel HD graphics and mobile Adreno 710.
  - Native 256x240 viewport resolution with integer scaling override (768x720, 3x scale).
  - Nearest-neighbor texture filter (`default_texture_filter = 0`).
  - 60 TPS physics tick rate.
- **Current Execution Status**:
  - **Milestone 1 Completed**: Core Autoloads & Enums (`src/core/constants.gd`, `src/core/event_bus.gd`, `src/core/content_registry.gd`).
  - **Milestone 2 Completed**: Gameplay Simulation Components (`src/game/piece_randomizer.gd`, `src/game/board_grid.gd`, `src/game/das_handler.gd`, `src/game/piece_controller.gd`, `src/game/score_manager.gd`, `src/game/game_state_machine.gd`).
  - **Milestone 3 Completed**: Rendering, Audio & Importer (`src/game/playfield_renderer.gd`, `src/audio/audio_manager.gd`, `src/importer/chr_extractor.gd`, `src/main.gd`, `src/main.tscn`).
  - **Headless Verification**: Executed and verified headlessly via `godot --headless --path . --quit` and `godot --headless -s tests/test_runner.gd` (Godot 4.7.1 on Fedora PRoot ARM64), running 10 comprehensive automated test suites (`test_core.gd`, `test_randomizer.gd`, `test_board_grid.gd`, `test_das.gd`, `test_piece_controller.gd`, `test_score_manager.gd`, `test_game_simulation.gd`, `test_renderer.gd`, `test_audio.gd`, `test_importer.gd`) passing 100% of assertions with zero errors or warnings.
  - **Key Features Verified**:
    1. `PieceRandomizer`: Authentic 1989 two-roll pseudo-randomizer yielding a verified 3.55% duplicate rate across 100,000 rolls (matching theoretical $1/28 \approx 3.571\%$) and uniform 1/7 piece spread.
    2. `BoardGrid`: 10x22 grid storage, fast bounds checking, zero-kick placement queries, piece locking, full-row detection, authentic 5-step center-outward row clearing, and multi-row collapse.
    3. `DASHandler`: 16-frame initial charge, 6-frame repeat interval (reloaded to 10), directional reversal reset, and ARE/line-clear pre-charging preservation.
    4. `PieceController`: Horizontal translation, NRS rotation strictly rejecting wall/floor kicks, 60 TPS gravity timers across levels 0–29+, 2-frame soft-drop step (+1 point per cell), mino positions query (`get_mino_positions`), and instant contact lock without grace periods.
    5. `ScoreManager`: BPS scoring ($40, 100, 300, 1200 \times (\text{level} + 1)$), soft-drop accumulation, starting level thresholds ($\min(S \times 10 + 10, \max(100, S \times 10 - 50))$), and 10-line transitions.
    6. `GameStateMachine`: 60 TPS deterministic finite state machine (`SPAWNING`, `ACTIVE_PLAY`, `LINE_CLEAR_ANIM`, `ARE_DELAY`, `GAME_OVER`), base ARE calculation ($10 + 2 \times \lfloor(21 - Y_{\text{lock}})/4\rfloor$), 20-frame line clear anim, and topout detection.
    7. `PlayfieldRenderer`: Pixel-perfect 256x240 viewport CanvasItem renderer, 10x20 visible playfield bounding box at (X: 96, Y: 40), locked mino cells mapped to level palettes, active piece rendering, preview box at (X: 192, Y: 112) with authentic anchor offsets, HUD text rendering (Lines, Top, Score, Level, Statistics), and Game Over banner.
    8. `AudioManager`: 100% clean-room procedural 2A03 APU audio synthesizer (Pulse, Triangle, Noise channels) using `AudioStreamGenerator`, authentic SFX envelopes (`SHIFT`, `ROTATE`, `LOCK`, `LINE_CLEAR`, `TETRIS`, `LEVEL_UP`, `GAME_OVER`), real-time streaming, and headless synthesis buffers.
    9. `CHRExtractor`: Pure GDScript iNES header parsing (`NES\x1A`), 2bpp planar tile decoding, 128x128 bank sheet and 8x8 tile image generation, PRG-ROM palette extraction (CPU $984C / ROM offset 0x00185C), and `apply_to_content_registry` texture injection.
    10. `Main Scene`: Root scene coordinator (`src/main.gd`, `src/main.tscn`) wiring state machine, renderer, and audio manager to the 60 TPS simulation loop.
  - **Next Target**: Phase 2: Menu Flow, Title Screen, Game Type A/B Selection, Music Selection & High Scores.
