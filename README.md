# ReTetris

> **Clean-Room 1989 NES Tetris Re-Implementation**  
> Built with **Godot 4.3+**, **Strictly Typed GDScript**, and the **`gl_compatibility`** renderer.  
> **Architecture**: Mandatory ROM Ingestion & Data Extraction (Zero Procedural Fallbacks).

---

## Overview

**ReTetris** is an authentic, clean-room software re-implementation of 1989 Nintendo Entertainment System (NES) Tetris (NTSC release). The goal of this project is a 100% faithful, frame-accurate simulation of the original game's mechanics, timings, audio sequences, and visual presentation, while adhering strictly to a zero-copyrighted-assets legal boundary.

The simulation runs deterministically inside Godot's `_physics_process` at a fixed 60 TPS, matching the NTSC NES console's VBlank timing.

---

## Legal Boundary & Mandatory ROM Ingestion

- **Clean-Room Engine Boundary**: The Git repository contains **strictly zero** proprietary Nintendo, Bullet-Proof Software, or The Tetris Company assets, ROM dumps, graphics, or audio recordings. All engine code is 100% clean-room GDScript.
- **Mandatory User ROM Ingestion (`user://nes_data/tetris.nes`)**:
  - The engine enforces a **Mandatory ROM Ingestion** architecture. There are **zero procedural fallbacks** (no procedural tile synthesis, no hardcoded approximations, and no synthetic audio fallbacks).
  - The runtime **strictly refuses to start gameplay** unless a valid, legally acquired 1989 NES Tetris ROM (`tetris.nes`) is present and imported into `user://nes_data/`.
  - **Startup Guard & Missing ROM Screen**: If `user://nes_data/` is missing extracted assets (and no `tetris.nes` is found for auto-extraction), the engine immediately halts game initialization and presents an on-screen setup prompt directing the user where to place their ROM.
- **Reference Disassembly (`TetrisNESDisasm/`)**: The workspace includes a local disassembly of the original NES ROM used strictly as an analytical reference to verify authentic routines (two-roll randomizer, frame gravity counters, ARE timing formulas, and RAM state) without incorporating proprietary code into the clean-room engine.

---

## 100% Authentic ROM Extraction Pipeline (`src/importer/`)

Upon startup with a valid ROM, the integrated importer automatically validates the file via cryptographic checksums (SHA-256 / CRC32) and extracts 100% of authentic game data into `user://nes_data/`:

1. **Graphics (CHR-ROM)**:
   - Unpacks all 16KB of 2bpp planar pattern tables across all 4 banks.
   - Extracts playfield mino blocks (bevel, gem, square highlight), UI frames, borders, NES bitmap font glyphs, title screen/menu artwork, and ending/rocket sequence sprites into PNG texture atlases.
2. **Palettes & Lookup Tables (PRG-ROM)**:
   - Extracts the 10 authentic cycling level color palettes directly from PRG-ROM address `$984C` (ROM offset `0x00185C`).
   - Extracts exact gravity frame tables, BPS scoring values, piece spawn orientations, and preview coordinate offsets directly from PRG-ROM—eliminating all hardcoded estimates.
3. **Audio Data (PRG-ROM / 2A03 APU Data)**:
   - Extracts authentic APU register sequences, pitch/wave lookup tables, note duration tables, and envelope data directly from ROM sound engine tables.
   - Powers authentic music playback (Music 1 / Korobeiniki, Music 2, Music 3, High Score, Ending) and all gameplay sound effects.

---

## Simulation Specifications

- **Native Viewport**: 256x240 resolution with pixel-perfect nearest-neighbor scaling (`viewport` mode, `keep` aspect).
- **Playfield Dimensions**: 10x20 visible matrix with 2 hidden spawn buffer rows (total 10x22 grid).
- **1989 Two-Roll Piece Randomizer**: Authentic piece generator with a verified ~3.57% duplicate rate (Roll 1: 0..7; if duplicate or 7, Roll 2: 0..6).
- **Nintendo Rotation System (NRS)**: Authentic rotation states with strictly **zero** wall-kicks and **zero** floor-kicks.
- **Delayed Auto-Shift (DAS)**: 16-frame initial charge counter, 6-frame repeat interval, and DAS preservation across piece lock and ARE delays.
- **Frame-Accurate Gravity**: Authentic level timing table spanning Level 00 (48 frames/drop) down to Level 19–28 (2 frames/drop *"Kill Screen"*) and Level 29+ (1 frame/drop).
- **ARE & Line Clear Timing**: Dynamic entry delay based on lock height ($10 + 2 \times \lfloor (21 - Y_{\text{lock}}) / 4 \rfloor$ frames) and authentic 20-frame (5-step) center-outward line clear animation.
- **Scoring & Level Transitions**: Original BPS score multipliers ($40, 100, 300, 1200 \times (\text{Level} + 1)$), +1 point per soft-drop cell, and starting level transition thresholds.

---

## Architecture & Code Quality

- **Godot 4.3+ Compatibility Renderer (`gl_compatibility`)**: Optimized for lightweight, thermally efficient performance across low-spec desktop (Sandy Bridge AVX-only) and mobile dev nodes (ARM64 Fedora PRoot).
- **Strict Static Typing**: 100% strictly typed GDScript for compile-time safety and optimal engine bytecode execution.
- **Decoupled Autoload Singletons**:
  - `EventBus`: Typed global signal dispatcher for game events.
  - `ContentRegistry`: Ingests extracted tables, palettes, matrices, and tile textures.
- **Composition Over Inheritance**: Modular systems (`BoardGrid`, `DASHandler`, `PieceController`, `ScoreManager`, `PlayfieldRenderer`, `AudioManager`, `CHRExtractor`).

---

## Documentation

Comprehensive project documentation is maintained inside the `docs/` directory:

- [ARCHITECTURE.md](docs/ARCHITECTURE.md): Mathematical models, timing tables, mandatory ROM ingestion architecture, and component diagrams.
- [STATUS.md](docs/STATUS.md): Implementation roadmap and verification checklist.
- [MEMORY.md](docs/MEMORY.md): Hardware constraints (AVX-only i5-2400, Termux PRoot ARM64) and architectural invariants.
- [AGENTS.md](AGENTS.md): Global agent execution blueprint.

---

## Controls

| Action | Keyboard Mapping | Gamepad (NES Layout) |
| :--- | :--- | :--- |
| **Move Left / Right** | Left / Right Arrow | D-Pad Left / Right |
| **Soft Drop** | Down Arrow | D-Pad Down |
| **Rotate Clockwise** | `X` / `Up Arrow` | Button A |
| **Rotate Counter-Clockwise** | `Z` | Button B |
| **Pause** | `Escape` / `Enter` | Start |
| **Reset** | `R` | Select |

---

## Verification & Status Commands (`fish` Shell)

```fish
# Check workspace git status
git status

# Verify project configuration headless
godot --headless --path . --quit

# Run complete automated verification test harness
godot --headless -s tests/test_runner.gd
```

---

## License

This project is licensed under the MIT License. It contains strictly zero copyrighted code, graphics, or audio belonging to Nintendo, Bullet-Proof Software, or The Tetris Company. All assets must be supplied by the user via their own legally dumped ROM.
