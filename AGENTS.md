# Global Execution Blueprint (`AGENTS.md`)

> **Purpose**: Global operational blueprint and execution rules for AI agents across all workspaces.

---

## 1. Context Injections
- **User Profile & Environment**: @[USER](docs/USER.md) (Fallback: `~/.ai-context/USER.md`)
- **Assistant Persona & Guardrails**: @[SOUL](docs/SOUL.md) (Fallback: `~/.ai-context/SOUL.md`)
- **Persistent Memory & Quirks**: @[MEMORY](docs/MEMORY.md) (Fallback: `~/.ai-context/MEMORY.md`)
- **Architecture & System Design**: @[ARCHITECTURE](docs/ARCHITECTURE.md)
- **Project Progress & Plan**: @[STATUS](docs/STATUS.md)

---

## 2. Universal Build & Run Templates (`fish` Shell)
> All interactive commands must be formatted for the `fish` shell.

```fish
# JavaScript / TypeScript (Bun - use bun-baseline on Sandy Bridge):
bun install
bun run dev
bun test

# Python (uv):
uv sync
# or: uv venv; source .venv/bin/activate.fish; uv pip install -r requirements.txt

# Rust:
cargo fetch
cargo run
cargo test

# Godot 4 (CLI / Headless check):
godot --headless --path . --quit
godot --path .
```
