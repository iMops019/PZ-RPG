# PZ RPG — Roadmap

Phased, slice-by-slice. Each slice ends verified in-game and committed
(`ENGINEERING.md` §2). Numbers are order, not estimates. Nothing here is a
promise — we re-slice when reality disagrees.

---

## Phase 0 — Scaffold  ✅

- Repo, `common/` layout, `deploy.ps1`, docs, `.gitattributes` (CRLF `mod.info`).
- Core stub that logs `[PZ RPG] loaded` — proves B42 discovers the mod.

## Phase 1 — The spine: save layer + character sheet

The foundation everything hangs on. No gameplay effect yet.

1. **`PZRPG_00_Core` real:** namespace, `log`, `hookEvent`, `VERSION`,
   `SAVE_VERSION`.
2. **XP curve:** `PZRPG.curve.xpForLevel` / `levelForXp` for 1–100, in one place.
   Unit-check the endpoints in-game via the debug console.
3. **Save layer:** `PZRPG.getData(player)` — create + migrate on `OnCreatePlayer`
   / `OnGameStart`. `version = SAVE_VERSION`. Verified: new character gets the
   table; an old save loads and is migrated, not wiped.
4. **Skill registry:** `PZRPG.registerSkill`, `PZRPG.skills`. Register **one
   placeholder skill** ("woodcutting", no behaviour) to exercise it.
5. **XP accessors:** `getXp` / `getLevel` / `addXp` + level-up notification.
   Verified: `addXp` from the debug console moves the number, crosses a level,
   fires the halo/sound.
6. **Character sheet — the user drives this.** Stop, get the full vision (layout,
   HUD vs pop-up, per-row content, keybind). Then build it read-only: list
   registered skills, level, XP bar.

Exit: open the sheet, see Woodcutting at some level, close it, save, reload, the
number persisted.

## Phase 2 — First real skill: Woodcutting

Vertical slice of one whole skill, as the template for the rest.

1. **XP hook:** award Woodcutting XP when the player finishes a vanilla tree-chop.
   Number appears on the sheet.
2. **Tuning table:** base values + per-level curve for the chop-speed multiplier.
3. **Level effect:** scale chop action time on the shallow curve (`DESIGN.md` §4).
   Verified: level 1 vs a debug-set level 80 feels different, not broken.
4. **Yield bonus:** small extra-log/twig roll at higher levels.
5. **Polish:** level-up message names the skill; sheet blurb shows current effect.

## Phase 3 — Mining + new content

1. Mineable **boulder** objects (reuse vanilla rocks first; our own if needed).
2. Right-click **Mine** with a pickaxe → timed action → Stone.
3. **Iron Ore** item + recolored sprite; ore-chance scales with Mining level.
4. Boulder depletion / respawn behaviour.
5. Level effects: mine speed, ore chance, pick durability.

## Phase 4 — Smithing

1. Smelt Iron Ore → Iron Bar (station: reuse vanilla metalworking or add a
   smelter).
2. Smithing XP on smelt + forge.
3. **Unlock tree:** metal recipes gated by Smithing level.
4. Level effects: material waste, smithed-item durability.

## Phase 5 — Combat skills

Attack / Strength / Defense / Constitution. Most balance-sensitive — arrives only
after the framework is proven. Kept modest so PZ still kills you.

## Phase 6 — Dexterity

Lockpicking, Stealth, Noise under one skill (split later if needed).

## Later / unscheduled

- Foraging/Herbalism, Fishing, Firemaking, Crafting/Fletching.
- Sandbox options surfaced for every tuning value.
- Revisit **core + addon mod split** (`DESIGN.md` §8) now that the Core API is
  proven.
- Multiplayer: make XP writes server-authoritative.
- Translations pass.
- A Little Help crossover? (helpers that train/use PZ RPG skills) — separate call.

---

## Cross-cutting rules

- **Every phase after 1 must keep old saves loading.** Save-schema changes are
  migrations.
- **One skill's bug never breaks another** — the registry seam (`ARCHITECTURE.md`
  §4) is the firewall.
- Tuning values live in tables, not logic.
