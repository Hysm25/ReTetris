---
tags: [ai-context, profile]
updated: 2026-11-19
---

# User Profile & System Context (`docs/USER.md`)

## 1. Identity & Communication
- **Role**: Engineering Student (Age: 20), Port Said, Egypt.
- **Languages**: Native Egyptian Arabic (casual chat) | Fluent English (code, comments, technical docs, architecture).
- **Tone**: Direct, technical, zero conversational fluff.

---

## 2. Hardware & Operating Environments
- **Primary Desktop**: Dell OptiPlex 390 (Intel Core i5-2400 Sandy Bridge, 4C/4T, AMD Radeon GPU) running **CachyOS Linux** (Arch-based, KDE Plasma).
  - *Hard Constraint*: CPU supports **AVX only** (NO AVX2). Avoid AVX2 binaries; require **`bun-baseline`** for Bun. Keep RAM/CPU overhead low.
- **Mobile Dev Node**: Xiaomi Redmi Note 15 5G (Snapdragon 6 Gen 3, Adreno 710) running Android 16 (HyperOS) with **Termux** + **Fedora PRoot** (`aarch64`, `dnf`).
  - *Hard Constraint*: No `systemd` inside PRoot. Optimize for mobile thermals and memory.
- **Shell**: **`fish`** everywhere (`set -gx VAR val`, `set -a PATH /path`). Standalone `.sh` scripts use POSIX/Bash (`#!/usr/bin/env bash`).
- **Editor & Tools**: **Zed Editor** (often via SSH to Termux/Linux), `bun`, `uv`, `pi` (terminal AI agent), Obsidian + Pandoc/LaTeX.

---

## 3. Technical Stack & Skill Split

### Core / Daily Stack (Proficient — Zero Hand-Holding)
- **Next.js, Bun, Node.js, Modern TypeScript / JavaScript**.
- Skip basic explanations; deliver clean, idiomatic, strictly typed production code directly.

### AI-Assisted Stack (Guided — Complete Implementations)
- **Game Dev**: **Godot 4.x**, **GDScript** (strictly typed), Shaders, Engine/Modding Architecture.
- **Systems & RE**: **Rust**, **C**, **C++** (reverse engineering, SDL3 porting, binary recompilation).
- **JVM & Scripting**: **Kotlin**, **Java** (PaperMC plugins), **Python** (async, automation, scientific tooling).
- **Directives**: Provide complete, self-contained code (no `...` or `// TODO`), explain non-obvious logic/lifecycle/memory invariants in comments, and include exact `fish` build/run commands for CachyOS or Termux Fedora PRoot.
