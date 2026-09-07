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

**Core (`common/media/lua/shared/PZRPG_0N_*.lua`)**

- **XP curve** 1–100 — `floor(15·(n-1)^2.5)`, two tuning knobs. Level is always
  derived from XP, never stored.
- **Save layer** — per-character `getModData().PZRPG`, versioned + migrated.
- **Skill registry** + XP accessors (`getXp` / `getLevel` / `getXpProgress` /
  `addXp`); level-up halo; **XP drop** bubbles (`+15 Woodcutting`).
- **Exertion softening** — refunds most of the endurance drain from physical
  work (not running), so you can chop → gather → light a fire → saw without
  collapsing. One knob (`PZRPG.exertion.ENDURANCE_REFUND`).
- **Vanilla links** (`docs/DESIGN.md` §3a): skills trickle vanilla Fitness /
  Strength XP (`vanillaXp`), and skills that map to a vanilla perk mirror its
  XP (`mirrorVanilla`, e.g. Cooking ← vanilla Cooking).
- `PZRPG.wrapAction(cls, method, fn)` — reload-safe hook onto vanilla timed
  actions.
- **Timed buff engine** (`PZRPG_09_Buffs.lua`) — `PZRPG.buffs.apply / .get /
  .clear / .remaining`; source-tracked, self-expiring "Well Fed"-style buffs
  (`mending`, `scholar`, `infectionResist`, `toughness`, `strong`, …). First
  used by Cooking's Field Recipes.
- **Sandbox options** — `common/media/sandbox-options.txt`; first knob is
  `PZRPG.MaximumFireFuelHours` (default 12).

**Character Sheet** (press **K**, or Options → Key Bindings) — tabbed window:

- **Profile** — vanilla name / profession / traits (read-only) + RP fields
  (alias, age, height, hometown, goal, personality, bio…). New characters get a
  "fill out your sheet" screen; **Begin Survival** starts the run.
- **Skills** — the roster by category, level + XP bar + blurb.

**Skills** (every skill earns XP from real play; level effects land slice by slice)

| Skill | Trains from | Level effect so far |
|---|---|---|
| Woodcutting | each axe swing at a tree | faster chop |
| Mining | right-click a world boulder with a pickaxe → Stone + Iron Ore | — (pick wear + coal: MINE-2) |
| Fishing | right-click water with a rod (custom action) | bite rate, species & size gate |
| Foraging | mirrored vanilla perk | — (none planned) |
| Firemaking | lighting / fuelling a campfire, + a trickle while you sit by a lit fire | ignition odds ↑ with level; 12h fuel cap; fires burn slower |
| Cooking | mirrored vanilla perk | a cooked meal heals (meal size × level); **Field Recipes** → "Prepare" a discovered dish for a timed buff |
| Attack / Strength | landing melee hits | −endurance per swing / +melee damage |
| Defense / Constitution | taking a hit and surviving | block + damage reduction / infection resist + faster bleed-stop |

## Project layout

```
PZ RPG/
  common/                       the entire mod payload
    mod.info                    metadata (id = PZRPG) — CRLF, required for B42 discovery
    poster.png  icon.png        (todo)
    media/
      scripts/                  pzrpg_food.txt — Field Recipe dish items
      sandbox-options.txt       player-facing knobs (PZRPG.MaximumFireFuelHours)
      lua/
        shared/                 PZRPG_00-09 Core (curve, save, registry, xp,
                                exertion, mirror, wrapAction, xp-drops, buffs) +
                                PZRPG_10-40 one file per skill, + sibling files
                                (PZRPG_25/26 cooking recipes & Prepare action,
                                PZRPG_46 mine action, PZRPG_48 fish action)
        client/                 PZRPG_44-49 context menus & overlays,
                                PZRPG_50-56 character sheet, PZRPG_60 keybind
        server/                 authoritative XP / save writes (SP runs this too)
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
