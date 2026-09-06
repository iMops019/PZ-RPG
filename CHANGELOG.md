# Changelog

All notable changes to **PZ RPG** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project uses SemVer and is in `0.x` (anything may change).

## [Unreleased]

### Added
- Project scaffold: `common/` mod layout (`id = PZRPG`), `deploy.ps1` +
  `dev-deploy.bat`, `.gitattributes` (CRLF `mod.info` for B42's line parser).
- Docs: `DESIGN.md` (vision — an OSRS-style 1–100 skilling layer over vanilla
  survival), `ARCHITECTURE.md` (modular-monolith structure, the Core ↔ skill
  seam, the per-character versioned save layer), `ROADMAP.md` (phased slices),
  `ENGINEERING.md` (working method, PZ modding reference, hot-reload contract).
- `PZRPG_00_Core.lua` stub — logs `[PZ RPG] loaded` on `OnGameBoot` so B42
  mod discovery can be confirmed. No systems yet.

### Decided
- **One mod, internally modular** (not core + separate skill mods yet) — the
  Core API is unproven and B42 local-mod dependencies are fragile. Revisit at
  1.0. See `DESIGN.md` §8.
- PZ RPG skills are a **separate 1–100 track**; vanilla skills stay untouched.
- **Level is derived from XP, never stored.**
