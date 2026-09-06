# PZ RPG — Architecture

> Status: **the save layer + Core seam are being designed here now** (first
> slice). Skill modules and the sheet UI are sketched; they firm up as we build
> them. Read `ENGINEERING.md` for how we work and `DESIGN.md` for what we're
> building.

---

## 1. Mod structure

**One mod, `id = PZRPG`, internally modular.** (Rationale in `DESIGN.md` §8.)

```
common/
  mod.info                         id = PZRPG   (CRLF)
  media/
    lua/
      shared/
        PZRPG_00_Core.lua          namespace, log, hookEvent, curve math,
                                   skill registry, the save layer
        PZRPG_10_Skill_Woodcutting.lua   \  each skill module: tuning table,
        PZRPG_11_Skill_Mining.lua        |  event hooks -> PZRPG.addXP,
        PZRPG_12_Skill_Smithing.lua      /  level-effect code
        ...
      client/
        PZRPG_50_CharacterSheet.lua   the sheet window (reads the registry)
        PZRPG_60_Input.lua            keybind to open the sheet
      server/
        (authoritative XP writes if/when MP matters; SP runs this tree too)
    sandbox-options.txt              global XP rate, per-skill enable
```

- The game loads a context **alphabetically**; the `_NN_` prefixes make load
  order a fact. `shared` loads before `client`/`server`.
- `PZRPG_00_Core` must load first — every skill module calls `PZRPG.registerSkill`
  and `PZRPG.hookEvent` at load time.
- Leave number gaps so a module can slot in later.

---

## 2. Namespace

Everything hangs off one global table, `PZRPG`.

| Member | Kind | Purpose |
| --- | --- | --- |
| `PZRPG.VERSION` | string | mod version |
| `PZRPG.SAVE_VERSION` | int | current save-schema version (for migrations) |
| `PZRPG.log(msg)` | fn | `print("[PZ RPG] " .. msg)` |
| `PZRPG.hookEvent(event, key, fn)` | fn | reload-safe `Events` registration |
| `PZRPG.skills` | table | `id -> skill def` (the registry) |
| `PZRPG.registerSkill(def)` | fn | a skill module registers itself |
| `PZRPG.curve` | table | `xpForLevel(n)` / `levelForXp(xp)` — the shared 1–100 curve |
| `PZRPG.getData(player)` | fn | the player's `PZRPG` save table (created + migrated on demand) |
| `PZRPG.getXp(player, skillId)` | fn | raw XP in a skill |
| `PZRPG.getLevel(player, skillId)` | fn | level derived from XP |
| `PZRPG.addXp(player, skillId, amount)` | fn | add XP, fire level-up, mark dirty |
| `PZRPG.onLevelUp` | event-ish | Core notifies; skill modules / UI can listen |

No bare globals. Skill modules may use a `PZRPG_Skill_<Name>` global only if they
genuinely need a class table; prefer keeping everything in the registry def.

---

## 3. The save layer  ← first slice

### Where it lives

Per **character**: `player:getModData().PZRPG`. This table is serialized with the
save automatically and is unique per character (dies with the character — see
`DESIGN.md` §9 Q6, current lean).

A save-wide table (`ModData.getOrCreate("PZRPG")`) is **reserved** for
save-global config later; not used in slice 1.

### Shape

```lua
player:getModData().PZRPG = {
    version = 1,                 -- == PZRPG.SAVE_VERSION when current
    skills = {
        woodcutting = { xp = 0 },
        mining      = { xp = 0 },
        -- one entry per registered skill; created lazily
    },
    -- future: unlocks = { smithing = { "IronKnife", ... } }, settings = { ... }
}
```

**Level is never stored.** It is always `PZRPG.curve.levelForXp(entry.xp)`. XP is
the single source of truth, so the curve can be retuned without a migration and
there's no desync to debug.

### Lifecycle

| When | What Core does |
| --- | --- |
| `OnCreatePlayer` (and `OnGameStart` for the SP player) | `PZRPG.getData(player)` — create the table if absent, then run `migrate(data)` |
| `migrate(data)` | while `data.version < PZRPG.SAVE_VERSION`, apply the step for `data.version`, bump it. Each step is a small pure function. Never wipe. |
| `PZRPG.addXp(...)` | mutate `data.skills[id].xp`; the game persists `getModData()` on its own save cycle. An explicit `OnSave` flush only if we find we need one. |
| a skill registered **after** a save exists | `getData` adds its `skills[id] = {xp=0}` entry on next access — no migration needed |

### Accessors (Core API for skills)

```lua
PZRPG.getData(player)            -> the table above (migrated)
PZRPG.getXp(player, "woodcutting")   -> number
PZRPG.getLevel(player, "woodcutting")-> 1..100
PZRPG.addXp(player, "woodcutting", 12)
    -- clamps, applies PZRPG.curve, detects a level crossing,
    -- calls PZRPG.notifyLevelUp(player, skillId, newLevel) on a crossing
```

Skill modules **never touch `getModData()` directly** — always through these.

---

## 4. The skill registry seam

A skill module, at load:

```lua
PZRPG.registerSkill{
    id      = "woodcutting",
    name    = "Woodcutting",          -- getText key later
    icon    = "media/ui/PZRPG/woodcutting.png",
    order   = 10,                       -- sort in the sheet
    tuning  = require "PZRPG/tuning/woodcutting",  -- or an inline table
    describe = function(level) return ("Chop speed +%d%%"):format(...) end,
}
```

Then it wires its own behaviour with `PZRPG.hookEvent` and calls `PZRPG.addXp`
from the relevant game event. The level **effect** (e.g. faster chopping) is the
skill module's job — Core doesn't know what a skill *does*, only that it exists,
has XP, and has a level.

This is the seam that would become a mod boundary if we ever split: Core exports
`registerSkill` / `addXp` / `curve` / `getLevel`; a skill imports only those.

---

## 5. Character sheet (sketch — slice 1, second half)

- Client window, opened by a keybind (`PZRPG_60_Input.lua`).
- Iterates `PZRPG.skills` (sorted by `order`), one row per skill: name, level,
  XP bar to next level, `describe(level)` blurb.
- Read-only in slice 1. No allocation, no buttons beyond close.
- **The user will detail the full vision when we start this** — layout, HUD vs
  pop-up, what each row shows. Treat the above as a placeholder.

---

## 6. Hot-reload contract

Per `ENGINEERING.md` §6. Specifics here:

- `PZRPG = PZRPG or {}`; `PZRPG.skills = PZRPG.skills or {}` — the registry
  survives a reload; `registerSkill` overwrites its own `id` entry idempotently.
- Event hooks go through `PZRPG.hookEvent(event, key, fn)`.
- The sheet window is torn down and rebuilt on reload.
- The save layer is inherently reload-safe (it reads `getModData()` fresh).

---

## 7. Decisions log

| Date | Decision | Why |
| --- | --- | --- |
| 2026-09-06 | One mod, modular monolith (not core + addon mods yet) | Core API unproven; B42 local-mod deps fragile; per-slice overhead. Revisit at 1.0. `DESIGN.md` §8. |
| 2026-09-06 | Level derived from XP, never stored | One source of truth; retune the curve with no migration. |
| 2026-09-06 | PZ RPG data per-character in `getModData().PZRPG`, versioned + migrated | Auto-serialized, character-scoped, survives with the save. |
| 2026-09-06 | Vanilla skills untouched, separate 1–100 track | `DESIGN.md` §3. |
