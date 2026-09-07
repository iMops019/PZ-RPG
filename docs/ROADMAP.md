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

1. ✅ **`PZRPG_00_Core` real:** namespace, `log`, `hookEvent`, `VERSION`,
   `SAVE_VERSION`.
2. ✅ **XP curve** (`PZRPG_00_Core`): `curve.xpForLevel` / `levelForXp`, 1–100,
   two knobs. Debug boot dump (`-debug`) checks the endpoints + round-trip.
3. ✅ **Save layer** (`PZRPG_01_Save`): `PZRPG.getData(player)` — create +
   migrate on `OnCreatePlayer` / `OnGameStart`.
4. ✅ **Skill registry** (`PZRPG_02_SkillRegistry`): `registerSkill`, `skills`,
   `skillsByCategory`; placeholder `woodcutting` (`PZRPG_10`).
5. ✅ **XP accessors** (`PZRPG_03_Xp`): `getXp` / `getLevel` / `getXpProgress` /
   `addXp` + level-up halo.
6. ✅ **Character sheet** (`PZRPG_50`–`56`, `60`): the user's RP-document design
   — tabbed window (Profile + Skills), editable RP fields, paused first-run
   welcome, docked/toggle modes, K keybind.

**Verification pass (one sitting, `-debug`):**
- Console: `curve.dump` endpoints + round-trips match; `save: ready` line.
- New character: paused "Welcome to PZ RPG" sheet → fill fields → Begin → game
  resumes, sheet docks.
- K toggles the sheet. Skills tab shows Woodcutting under "Gathering" at Lv 1.
- `PZRPG.addXp(getPlayer(), "woodcutting", 500)` in the Lua console → level
  moves, halo fires, Skills tab bar updates.
- Save, quit to menu, reload: profile fields + any XP persisted; docked sheet
  reopens where it was.

## Phase 1.5 — Skill roster stubbed  ✅

Every skill has a `PZRPG_1N..4N_Skill_*.lua` file so the Skills tab shows the
full grid by category.

## Phase 2 — Wire the roster (XP) + core progression systems  ✅

- **Exertion softening** (`PZRPG_05`), **vanilla-XP feed** (`vanillaXp`),
  **vanilla-perk mirror** (`PZRPG_06` / `mirrorVanilla`), **`wrapAction`**
  (`PZRPG_07`), **XP drops** (`PZRPG_08`).
- Every skill trains from real activity **except Mining**:
  - Woodcutting — wraps `ISChopTreeAction:animEvent`, per swing.
  - Cooking / Fishing / Foraging / Smithing / Crafting / Dexterity — mirrored
    from the matching vanilla perk.
  - Firemaking — wraps the campfire light / fuel actions.
  - Attack / Strength — `OnWeaponHitXp`; Defense / Constitution — body-health
    drop.
- **CONST-EFFECT-1** — Constitution's infection-resistance effect (the first
  level *effect*; `DESIGN.md` §4).

## Phase 3 — Level effects, slice by slice

Each skill's "how a level helps" (`DESIGN.md` §4). Suggested order, not a
commitment:

- **WC-2** Woodcutting chop speed · **WC-3** yield bonus · **WC-4** polish.
- Mining speed / ore chance / pick wear (after Phase 4 content).
- Foraging rare-find · Fishing bite rate · Cooking nutrition & waste ·
  Firemaking light speed & fuel efficiency · Smithing recipe-tier unlocks ·
  Crafting quality · Dexterity stealth radius & noise.
- **Combat effects, one slice each** (careful — `DESIGN.md` §4/§5). Defensive
  skills stay conservative; Attack + Fitness is allowed to spike end-game.
  **ATK-EFFECT-1 ✅** melee swings cost less endurance (held-weapon
  `enduranceMod`). **STR-EFFECT-1 ✅** +melee damage (held-weapon min/max).
  **DEF-EFFECT-1 ✅** block chance + damage reduction (health-drop refund).
  **CONST-EFFECT-2 ✅** resilience — faster bleed stop + slow regen while hurt.
  The combat cluster's first effects are all in. Later: **STR-EFFECT-2** carry
  capacity + shove · **DEF-EFFECT-2** real pre-hit dodge · **ATK-EFFECT-2**
  attack through the exhausted-endurance lockout.

## Phase 4 — Mining content

The only skill with no vanilla activity to hook.

- **MINE-1 ✅** — right-click B42's world `boulders_*` tiles with a pickaxe →
  `ISMineBoulderAction` → `Base.Stone2` + `Base.IronOre` (both real B42 items;
  no new sprites) + Mining XP. Per-boulder 2-day cooldown on `getModData()`.
  Iron-ore chance scales 8→25% over 1–100.
- **MINE-1b** — depleted-boulder visuals: `setAlpha` fade + floating
  "Depleted — 1d 6h" text (`PZRPG_47_MiningOverlay`, client).
- **MINE-2** — mine-speed & pick-wear level effects; maybe a real depletion
  (sprite swap) instead of just a cooldown; coal / other ores.

## Later / unscheduled

- Split Dexterity into Lockpicking / Stealth / Noise if it earns it.
- Smithing "unlock tree" of metal items gated by level (`DESIGN.md` §5).
- Sandbox options surfaced for every tuning value (now scattered in
  `PZRPG.tuning.*`, `PZRPG.exertion`, `PZRPG.mirror`, `PZRPG.xpDrops`).
- Wire values into an in-app Editor tab (like the Coins project).
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
