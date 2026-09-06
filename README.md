# PZ RPG

An **RPG skilling overhaul** for Project Zomboid **Build 42** (42.20.4), in the
spirit of Old School RuneScape — many standalone skills, each **level 1–100**,
that sit *alongside* the vanilla game rather than replacing it.

Written in Lua (no build step). Single-player first. Private WIP.

Repo: <https://github.com/iMops019/PZ-RPG>

## Docs

- [docs/DESIGN.md](docs/DESIGN.md) — the vision: what "RPG" means here, the skill
  list, the OSRS-feel scaling philosophy, per-skill sketches
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the mod is wired: the Core /
  skill seam, the per-character save layer, load order, namespace
- [docs/ROADMAP.md](docs/ROADMAP.md) — phased build plan
- [docs/ENGINEERING.md](docs/ENGINEERING.md) — how we work (small vertical
  slices), Definition of Done, PZ modding reference, hot-reload contract
- [CHANGELOG.md](CHANGELOG.md) — what changed per version

## What it does right now

**Phase 1 — the spine.** No gameplay effect yet, but the framework is in:

- A shared **Core**: an XP curve (1–100, `floor(15 · (n-1)^2.5)`, two tuning
  knobs), a per-character **save layer** (`getModData().PZRPG`, versioned +
  migrated), a **skill registry**, and XP accessors (`getXp` / `getLevel` /
  `addXp`) with a level-up halo.
- A **Character Sheet** (press **K**) with two tabs:
  - **Profile** — your vanilla name / profession / traits (read-only) plus RP
    fields you fill in: alias, age, height, hometown, goal, personality, bio…
  - **Skills** — registered skills by category with level + XP bar. One
    placeholder skill so far (*Woodcutting*, no behaviour).
- On a **new character** the sheet opens with the game paused for a
  "fill out your sheet" beat; **Begin Survival** starts the run.

Next: **Phase 2 — Woodcutting** (award XP on a tree-chop, then a level effect).
See the roadmap.

## Project layout

```
PZ RPG/
  common/                       the entire mod payload
    mod.info                    metadata (id = PZRPG) — CRLF, required for B42 discovery
    poster.png  icon.png        (todo)
    media/
      lua/
        shared/                 PZRPG_00_Core and anything both sides need
        client/                 HUD, character sheet, input
        server/                 authoritative XP / save writes (SP runs this too)
      sandbox-options.txt       player-facing knobs (XP rates, per-skill toggles)
  docs/
  deploy.ps1                    copy common/ into the game + enable the mod
  dev-deploy.bat                double-click wrapper
```

## Installing / testing

No build step — "deploy" copies `common/` into the PZ user folder
(`C:\Users\conov\Zomboid\mods\PZRPG\common\`) and ticks the mod on in the
**New Game** load-order list.

```bash
powershell -ExecutionPolicy Bypass -File "C:\Users\conov\Documents\PZ Mods\PZ RPG\deploy.ps1"
```

| Command | Effect |
| --- | --- |
| `deploy.ps1` | copy files + enable in the New Game mod list |
| `deploy.ps1 -Saves latest` | also add it to the most recent existing save |
| `deploy.ps1 -Launch -Debug` | deploy, then start PZ with `-debug` |
| `deploy.ps1 -NoEnable` | copy files only, touch no mod list |

Lua is read at launch — **restart PZ** after deploying (with `-debug` you can
reload lua from the debug menu instead).

## Debugging

- **Live log:** launch via `ProjectZomboid64ShowConsole.bat` for a console that
  streams `[PZ RPG]` prints and Lua stack traces.
- **After the fact:** `C:\Users\conov\Zomboid\console.txt`, search `[PZ RPG]`.
