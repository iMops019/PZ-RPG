# Changelog

All notable changes to **PZ RPG** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project uses SemVer and is in `0.x` (anything may change).

## [Unreleased]

### Docs
- `ENGINEERING.md` §4 opens with "the four things that keep biting us" —
  Java-object-vs-Lua-table, B41≠B42, the Kahlua sandbox (no `io`/`os`), and the
  Lua/OO footguns (method/static name collisions, full-screen `ISUIElement`
  eating clicks, deploy-before-test).

### Fixed (pre-commit, first in-game test)
- Character sheet crashed with a stack overflow on close — a static
  `PZRPG_Sheet.close()` shadowed the `:close()` method and recursed. Removed the
  static; `toggle()` calls the method.
- Welcome flow: **no longer pauses the game.** `setGameSpeed(0)` freezes the
  input loop the sheet's text fields need, so the player couldn't type. The
  game stays live (spawn is a safe interior); the backdrop is now purely visual
  and does not consume mouse events, so it can't block the sheet's controls.
- Welcome flow also stacked on top of PZ's **Survival Guide** ("how to play"),
  which opens on spawn — now it **waits** until the Survival Guide / main menu /
  any modal is gone (rechecking every ~0.3s, 60s cap so it can never hang)
  before appearing. Per-tick safety sweep clears a stray backdrop. Docked
  auto-open waits the same way.
- Welcome flow **no longer pauses the game and has no backdrop** — `ISUIElement`
  defaults `wantMouseEvents = true`, so the full-screen dim panel was silently
  eating every click meant for the fields. (It "worked" once only because the
  pause changed PZ's input routing.) Now: plain sheet, game live, fields take
  input. `prerender` clears a stale "- Game Paused -" banner left by another mod.
- Sheet keybind defaults to **K**. Note: K is also PZ's `-debug` "Display FPS"
  bind on the dev machine, so both fire until one is cleared in Options; in a
  normal install K is free.

### Added
- **Character Sheet** — a tabbed `ISCollapsableWindow` (`PZRPG_Sheet`), opened
  with **K** (`PZRPG_60_Input.lua`):
  - *Profile tab* (`PZRPG_51`): vanilla name / profession / days survived /
    traits (read-only, via new `PZRPG.vanilla*` helpers in `PZRPG_04_Profile`)
    plus editable RP fields — alias, age, sex, height/build, hometown, prior
    occupation, goal, personality, bio (`PZRPG.PROFILE_FIELDS`).
  - *Skills tab* (`PZRPG_52`): registered skills grouped by category, each with
    level, an XP bar to the next level, and its `describe(level)` blurb.
  - *First-run* (`PZRPG_55`): on a new character the sheet opens centered with
    the sim **paused**, only a "Begin Survival" button; Begin saves the profile,
    marks it created, unpauses, docks the window.
  - *Display mode* (`profile.sheetMode`): "docked" (reopens on load at the saved
    position, `PZRPG_56`) or "toggle" (hidden until K); footer button flips it.
- **Skill categories** — `PZRPG.CATEGORIES` (Gathering / Production / Combat /
  Dexterity / Other), a `category` field on the skill def, and
  `PZRPG.skillsByCategory()`. Woodcutting is `gathering`.
- **Profile store** (`PZRPG_04_Profile.lua`) — `getModData().PZRPG.profile`
  (`created`, `sheetMode`, `sheetX/Y`, `fields`). Additive to the save table —
  no `SAVE_VERSION` bump / migration.
- **Save layer** (`PZRPG_01_Save.lua`) — `PZRPG.getData(player)` creates and
  migrates the per-character table `player:getModData().PZRPG =
  { version, skills = { <id> = { xp } } }` on `OnCreatePlayer` / `OnGameStart`.
  `PZRPG._migrations` is an ordered from-version → step map; missing steps for a
  bumped `SAVE_VERSION` are treated as additive and just advance the marker.
  Never wipes. A newer-than-build save is left untouched with a warning.
- **Skill registry** (`PZRPG_02_SkillRegistry.lua`) — `PZRPG.registerSkill{ id,
  name, order, icon?, describe? }`, `PZRPG.skills`, `PZRPG.skillsSorted()`.
  Idempotent (re-register replaces), reload-safe.
- **XP accessors** (`PZRPG_03_Xp.lua`) — `getXp` / `getLevel` / `getXpProgress`
  / `addXp`. Per-skill entries created lazily on first touch. `addXp` fires
  `notifyLevelUp` on a level crossing → green arrow halo (vanilla's
  `HaloTextHelper.addTextWithArrow`) + log line + `addLevelUpListener` fan-out.
- **Woodcutting placeholder** (`PZRPG_10_Skill_Woodcutting.lua`) — registers the
  skill only, to exercise the registry + sheet. No XP hook yet (Phase 2).
- `PZRPG.curve` — the shared 1-100 XP curve in Core:
  `xpForLevel(n) = floor(COEFF * (n-1)^EXPONENT)` with `COEFF`/`EXPONENT` as
  tuning knobs, plus `levelForXp(xp)` (linear walk, exact) and a
  `PZRPG.curve.dump()` debug-console check. Defaults `COEFF=15, EXPONENT=2.5`
  put level 100 near 1.46M total XP, level 50 near 252k. Level is derived, never
  stored, so the knobs retune with no migration. Nothing awards XP yet.
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
- XP curve is a **custom smooth tunable formula**, not OSRS's table — one
  `COEFF * (n-1)^EXPONENT` shape retuned via two knobs (`DESIGN.md` §9 Q1).
