# ReTetris

> **Clean-Room 1989 NES Tetris Re-Implementation**  
> Built with **Godot 4.3+**, **Strictly Typed GDScript**, and the **`gl_compatibility`** renderer.  
> **Status**: *Pre-Implementation Baseline / Specification Phase*

---

## Overview

**ReTetris** is an authentic, clean-room software re-implementation of 1989 Nintendo Entertainment System (NES) Tetris (NTSC release). The goal of this project is a 100% faithful, frame-accurate simulation of the original game's mechanics, timings, and visual presentation, while adhering strictly to a zero-copyrighted-assets legal boundary.

The simulation is designed to run deterministically inside Godot's `_physics_process` at a fixed 60 TPS, matching the NTSC NES console's VBlank timing.

---

## Legal Boundary & Reference Disassembly

- **Clean-Room Boundary**: Contains **zero** proprietary Nintendo or Bullet-Proof Software assets, ROMs, or audio dumps in version control.
- **Reference Disassembly (`TetrisNESDisasm/`)**: The workspace includes a local disassembly of the original NES ROM used strictly as an analytical reference to verify authentic routines (two-roll randomizer, frame gravity counters, ARE timing formulas, and RAM state) without incorporating proprietary code into the clean-room engine.
- **Dual Asset Pipeline**:
  - **Procedural Asset Fallback**: Algorithmic 8x8 pixel tile generation (bevel, gem, and block styles) and procedural APU-style sound synthesis allow out-of-the-box playability.
  - **Optional 2bpp CHR-ROM Extractor**: Users may optionally supply a legal `tetris.nes` in `user://nes_data/`, which the engine decodes on-the-fly using a pure GDScript iNES parser.

---

## Planned Simulation Specifications

- **Native Viewport**: 256x240 resolution with pixel-perfect nearest-neighbor scaling (`viewport` mode, `keep` aspect).
- **Playfield Dimensions**: 10x20 visible matrix with 2 hidden spawn buffer rows (total 10x22 grid).
- **1989 Two-Roll Piece Randomizer**: Authentic piece generator with a ~3.57% duplicate rate (Roll 1: 0..7; if duplicate or 7, Roll 2: 0..6).
- **Nintendo Rotation System (NRS)**: Authentic rotation states with strictly **zero** wall-kicks and **zero** floor-kicks.
- **Delayed Auto-Shift (DAS)**: 16-frame initial charge counter, 6-frame repeat interval, and DAS preservation across piece lock and ARE delays.
- **Frame-Accurate Gravity**: Authentic level timing table spanning Level 00 (48 frames/drop) down to Level 19–28 (2 frames/drop *"Kill Screen"*) and Level 29+ (1 frame/drop).
- **ARE & Line Clear Timing**: Dynamic entry delay based on lock height ($10 + 2 \times \lfloor (21 - Y_{\text{lock}}) / 4 \rfloor$ frames) and authentic 20-frame (5-step) center-outward line clear animation.
- **Scoring & Level Transitions**: Original BPS score multipliers ($40, 100, 300, 1200 \times (\text{Level} + 1)$), +1 point per soft-drop cell, and starting level transition thresholds.

---

## Architecture & Code Quality

- **Godot 4.3+ Compatibility Renderer (`gl_compatibility`)**: Optimized for lightweight, thermally efficient performance on low-spec hardware (Sandy Bridge x86_64 and ARM64 PRoot).
- **Strict Static Typing**: 100% typed GDScript for compile-time safety and optimal engine bytecode execution.
- **Decoupled Autoload Singletons**:
  - `EventBus`: Typed global signal dispatcher for game events.
  - `ContentRegistry`: Ingests tables, palettes, matrices, and tile textures.
- **Composition Over Inheritance**: Modular nodes (`BoardGrid`, `DASHandler`, `PieceController`, `ScoreManager`, `PlayfieldRenderer`, `AudioManager`).

---

## Documentation

Comprehensive project documentation is maintained inside the `docs/` directory:

- [ARCHITECTURE.md](docs/ARCHITECTURE.md): Mathematical models, timing tables, legal asset boundary, and component diagrams.
- [STATUS.md](docs/STATUS.md): Implementation roadmap and verification checklist.
- [MEMORY.md](docs/MEMORY.md): Hardware constraints (AVX-only i5-2400, Termux PRoot ARM64) and architectural invariants.
- [AGENTS.md](AGENTS.md): Global agent execution blueprint.

---

## Planned Target Controls

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
```

---

## License

This project is licensed under the MIT License. It does not contain any copyrighted code, graphics, or audio belonging to Nintendo, Bullet-Proof Software, or The Tetris Company.
