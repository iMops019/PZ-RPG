# PZ RPG — Architecture

> Status: **Phase 1 Core is built** — curve, save layer, registry, XP accessors
> (`common/media/lua/shared/PZRPG_0N_*.lua`). The character sheet is next and
> still a sketch (§5). Read `ENGINEERING.md` for how we work and `DESIGN.md` for
> what we're building.

---

## 1. Mod structure

**One mod, `id = PZRPG`, internally modular.** (Rationale in `DESIGN.md` §8.)

```
common/
  mod.info                         id = PZRPG   (CRLF)
  media/
    lua/
      shared/
        PZRPG_00_Core.lua            namespace, log, hookEvent, VERSION, curve
        PZRPG_01_Save.lua            per-character save table + migrations
        PZRPG_02_SkillRegistry.lua   registerSkill / skills / skillsSorted
        PZRPG_03_Xp.lua              getXp / getLevel / addXp / level-up
                                    (+ routes def.vanillaXp -> vanilla perks)
        PZRPG_04_Profile.lua        RP profile + vanilla-character read views
        PZRPG_05_Exertion.lua       softens vanilla endurance drain (DESIGN 3a)
        PZRPG_06_VanillaMirror.lua  Events.AddXP -> mirror into skills w/ mirrorVanilla
        PZRPG_07_ActionWrap.lua     PZRPG.wrapAction(cls, method, fn) -- reload-safe
        PZRPG_08_XpDrops.lua        floating "+N Skill" bubbles (accumulated, flushed)
        PZRPG_10_Skill_Woodcutting.lua   \
        PZRPG_11_Skill_Mining.lua        |  one file per skill: tuning table,
        PZRPG_12_Skill_Foraging.lua      |  event hooks / wrapAction / mirror,
        PZRPG_13_Skill_Fishing.lua       |  and level-effect code.
        PZRPG_20_Skill_Smithing.lua      |  _1N_ gathering, _2N_ production,
        PZRPG_21_Skill_Firemaking.lua    |  _3N_ combat, _4N_ dexterity.
        PZRPG_22_Skill_Crafting.lua      |
        PZRPG_23_Skill_Cooking.lua       |  Some skills add sibling files:
        PZRPG_30_Skill_Attack.lua        |  PZRPG_46_MineBoulderAction (shared).
        PZRPG_31_Skill_Strength.lua      |
        PZRPG_32_Skill_Defense.lua       |
        PZRPG_33_Skill_Constitution.lua  |
        PZRPG_40_Skill_Dexterity.lua     /
      client/
        PZRPG_45_MiningContext.lua   "Mine Boulder" world context option
        PZRPG_47_MiningOverlay.lua   depleted-boulder fade + "Depleted 1d 6h" caption
        PZRPG_50_Sheet.lua           the tabbed ISCollapsableWindow
        PZRPG_51_SheetProfile.lua    Profile tab: vanilla info + RP fields
        PZRPG_52_SheetSkills.lua     Skills tab: skills by category + XP bars
        PZRPG_55_Welcome.lua         first-run: paused "fill your sheet" flow
        PZRPG_56_Dock.lua            reopen a docked sheet on load
        PZRPG_60_Input.lua           K keybind -> PZRPG_Sheet.toggle()
      server/
        (authoritative XP writes if/when MP matters; SP runs this tree too)
    sandbox-options.txt              global XP rate, per-skill enable
```

- The game loads a context **alphabetically**; the `_NN_` prefixes make load
  order a fact. `shared` loads before `client`/`server`.
- The `_0N_` Core files load before any skill module — a skill calls
  `PZRPG.registerSkill` / `PZRPG.hookEvent` at load time. Core order:
  `00` Core · `01` Save · `02` Registry · `03` Xp · `04` Profile · `05`
  Exertion · `06` VanillaMirror · `07` ActionWrap · `08` XpDrops.
- **Load-order gotcha:** vanilla `shared/TimedActions/*` loads *after* our
  `PZRPG_1N_*` (alphabetical), so a skill that `wrapAction`s such a class must
  do it on `OnGameBoot` (and, for `-debug` reloads, directly too — `wrapAction`
  is idempotent). Vanilla `shared/Camping/*` loads *before* us.
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
| `PZRPG.skillsSorted()` | fn | registered skills as an array, sorted by `order` then `id` |
| `PZRPG.curve` | table | `xpForLevel(n)` / `levelForXp(xp)` / `MAX_LEVEL` — the shared 1–100 curve |
| `PZRPG.getData(player)` | fn | the player's `PZRPG` save table (created + migrated on demand) |
| `PZRPG.getXp(player, skillId)` | fn | raw XP in a skill |
| `PZRPG.getLevel(player, skillId)` | fn | level derived from XP |
| `PZRPG.getXpProgress(player, skillId)` | fn | `into, span, fraction` within the current level (XP bars) |
| `PZRPG.addXp(player, skillId, amount)` | fn | add XP; routes `vanillaXp`; feeds the XP drop; fires level-up; returns `newXp, newLevel` |
| `PZRPG.notifyLevelUp(player, skillId, old, new)` | fn | halo + log + fan out to listeners (called by `addXp`) |
| `PZRPG.addLevelUpListener(key, fn)` | fn | register a reload-safe `fn(player, skillId, old, new)` |
| `PZRPG.skillsByCategory()` | fn | `{ {category, skills}, ... }` for the sheet |
| `PZRPG.wrapAction(cls, method, fn)` | fn | reload-safe: run `fn(self,...)` after `cls.method` |
| `PZRPG.exertion` | table | endurance-softening knobs (`PZRPG_05`) |
| `PZRPG.mirror` | table | `GLOBAL_MULT` for the vanilla-perk mirror (`PZRPG_06`) |
| `PZRPG.xpDrops` | table | floating "+N Skill" bubble knobs (`PZRPG_08`) |
| `PZRPG.tuning` | table | per-skill tuning tables, `PZRPG.tuning.<id>` (live-tunable) |

**Skill def fields:** `id`, `name`, `category`, `order`, `describe(level)`,
optional `icon`, `vanillaXp = { <perk> = ratio }`,
`mirrorVanilla = { <perk> = weight }`.

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
| a skill registered **after** a save exists | the XP accessors add `skills[id] = {xp=0}` on first touch — no migration needed |

### Accessors (Core API for skills)

```lua
PZRPG.getData(player)                  -> the table above (migrated)
PZRPG.getXp(player, "woodcutting")     -> number
PZRPG.getLevel(player, "woodcutting")  -> 1..100
PZRPG.getXpProgress(player, "woodcutting")  -> into, span, fraction (XP bars)
PZRPG.addXp(player, "woodcutting", 12)
    -- ignores amount <= 0, applies PZRPG.curve, detects a level crossing,
    -- calls PZRPG.notifyLevelUp(player, skillId, oldLevel, newLevel) on a crossing
    -- returns newXp, newLevel
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

## 5. Character sheet

A tabbed `ISCollapsableWindow` (`PZRPG_Sheet`, kept as one hidden-between-opens
instance), opened with **K** or the first-run flow.

- **Profile tab** (`PZRPG_51`): the vanilla character read-only — name,
  profession, days/hours survived, known traits (via the `PZRPG.vanilla*`
  helpers in `PZRPG_04_Profile`). Below, one editable text box per
  `PZRPG.PROFILE_FIELDS` entry (alias, age, sex, height, hometown, prior
  occupation, goal, personality, bio). Values live in
  `getModData().PZRPG.profile.fields`; written on tab-switch / close / "Begin".
- **Skills tab** (`PZRPG_52`): `PZRPG.skillsByCategory()` — a category header
  then a row per skill (name, level, XP bar from `PZRPG.getXpProgress`,
  `describe(level)` blurb). Read-only.
- **First run** (`PZRPG_55`): if `profile.created` is false, the sheet opens
  centered (after PZ's Survival Guide / any modal has cleared — polled with a
  60s cap) with a dim non-blocking backdrop and only a "Begin Survival" button.
  The game stays **live** — `setGameSpeed(0)` freezes the input loop the text
  fields need, so we don't pause. Begin commits, `markProfileCreated`, removes
  the backdrop, drops the window to a resting corner.
- **Display mode** (`profile.sheetMode`): `"docked"` (default — `PZRPG_56`
  reopens it at `profile.sheetX/Y` on load) or `"toggle"` (hidden until the
  keybind). The footer button flips the mode.
- **Keybind** (`PZRPG_60`): appended to the global `keyBinding` table as
  `PZ RPG: Character Sheet` under a `[PZ RPG]` category, default **K** —
  rebindable in Options > Key Bindings.
- Window is `620 x 720`, non-resizable. Both tab panels reserve ~17px on the
  right for the scrollbar.

Data model + accessors: `docs/ARCHITECTURE.md` §3 and `PZRPG_04_Profile.lua`.
`profile` is additive to the save table — no `SAVE_VERSION` bump.

---

## 6. Hot-reload contract

Per `ENGINEERING.md` §6. Specifics here:

- `PZRPG = PZRPG or {}`; `PZRPG.skills = PZRPG.skills or {}` — the registry
  survives a reload; `registerSkill` overwrites its own `id` entry idempotently.
- Event hooks go through `PZRPG.hookEvent(event, key, fn)`.
- The one sheet instance lives at `PZRPG._sheet` (not on the class table, which
  a reload replaces); `PZRPG_50_Sheet.lua` removes a stale one at load.
- The save layer is inherently reload-safe (it reads `getModData()` fresh).

---

## 7. Decisions log

| Date | Decision | Why |
| --- | --- | --- |
| 2026-09-06 | One mod, modular monolith (not core + addon mods yet) | Core API unproven; B42 local-mod deps fragile; per-slice overhead. Revisit at 1.0. `DESIGN.md` §8. |
| 2026-09-06 | Level derived from XP, never stored | One source of truth; retune the curve with no migration. |
| 2026-09-06 | XP curve = custom `floor(COEFF * (n-1)^EXPONENT)`, 2 knobs, not OSRS's table | Retune globally from two numbers; per-action XP stays small whole numbers. `DESIGN.md` §4. |
| 2026-09-06 | PZ RPG data per-character in `getModData().PZRPG`, versioned + migrated | Auto-serialized, character-scoped, survives with the save. |
| 2026-09-06 | Vanilla skills untouched, separate 1–100 track | `DESIGN.md` §3. |
| 2026-09-06 | Character sheet = RP document (tabs: Profile + Skills), not just a skills list | User's call. Name/profession/traits read from vanilla, read-only; RP fields (`PZRPG.PROFILE_FIELDS`) editable, stored in `profile.fields`. |
| 2026-09-06 | First-run welcome does NOT pause the sim | `setGameSpeed(0)` freezes the input loop the sheet's text fields need — the player couldn't type. Game stays live; spawn is a safe interior. (Tried pause first; reverted after in-game test.) |
| 2026-09-06 | Skills feed vanilla Fitness/Strength XP; `def.vanillaXp` map routed by `addXp` | Realism + physical skills stay worth training. `DESIGN.md` §3a. |
| 2026-09-06 | PZ RPG softens vanilla endurance drain (`PZRPG_05_Exertion`) — a deliberate vanilla rebalance | Vanilla "chop once, sit down" fights "let the player play". One knob, off-able. `DESIGN.md` §3a. |
