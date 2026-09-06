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

Nothing in-game yet. This is the scaffold: repo layout, deploy tooling, docs, and
a Core stub that only logs `[PZ RPG] loaded` so we can confirm B42 discovers the
mod. **First real slice: the per-character save layer + a character sheet screen**
(see the roadmap).

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
