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

- **WC-2 ✅** Woodcutting chop speed. (No yield bonus — decided 2026-09-06; no
  WC-3/WC-4.)
- **MINE-2** — **pick-wear reduction + a level-scaled chance of coal** on a
  boulder drop. *No* mine-speed effect, *no* yield bonus (decided 2026-09-06).
  Maybe a real depletion (sprite swap) instead of the cooldown, still open.
- Foraging — **no level effect planned** (mirror XP only, user's call
  2026-09-06). · ~~Fishing bite rate~~ **FISH-2 ✅** (custom
  `ISPZRPGFishAction` — right-click water with a rod; bite rate + species gate +
  bait bonus scale with level; replaces the vanilla minigame) · **FISH-3 ✅**
  size-within-species (level shifts the small/medium/big mix; trophy tail at
  L72+) · **FISH-4** animation — tried driving `FishingStage` + suppressing
  vanilla's `FishingManager`; it killed the anim in-game, reverted. Vanilla's
  manager animates the cast/idle pose for free while a rod is held facing
  water. Kept the "one cast per progress bar" timing fix. · Smithing recipe-tier
  unlocks · Crafting quality · Dexterity stealth radius & noise.
- **Firemaking** (design locked 2026-09-06 — `DESIGN.md` §5). Physical system =
  the vanilla 3-stone campfire, no new object.
  - **FIRE-2 ✅** — fuel cap: PZ RPG sandbox slider (default 12h) overriding
    `getCampingFuelMax()` · flat always-on burn-efficiency slowdown
    (`PZRPG.tuning.firemaking`, *not* level-scaled) · rebalance the FIRE-1 XP
    numbers (light ≈ 40, feed ≈ 10).
  - **FIRE-3 ✅** — level → **ignition chance only**: fork
    `ISLightFromKindle:updateKindling`, catch-N `300→55` / break-M `300→1400`
    over L1→L100, + a tinder-in-bag multiplier (twigs / paper / sheets). L1 ==
    vanilla. Literature / petrol stay auto-success.
  - **FIRE-4 ✅** — passive tending XP: `+3 Firemaking` every `EveryTenMinutes`
    tick while a lit campfire is within 2 tiles of the player (client-only,
    one trickle/tick).
  - **FIRE-4.1** — campfire hover tooltip (train hint, time left, heat radius).
    Vanilla has only a *click*-opened `ISCampingInfoWindow` (fuel + state), no
    world-object hover tooltip — a real hover panel is its own UI slice.
  - **FIRE-5** — "rake charcoal" action off a burnt-down fire → Smithing input.
- **Cooking** (design locked 2026-09-06 — `DESIGN.md` §5).
  - **COOK-2 ✅** — no code: the vanilla Cooking mirror already scales with
    recipe involvement, so it *is* the "bonus for real cooking". (B42 has no
    clean cook/craft-complete Lua event anyway.)
  - **COOK-3 ✅** — "a cooked meal heals": wrap `ISEatFoodAction:complete`;
    a cooked/non-burnt/non-rotten food starts a 45-game-min general-health
    regen, total HP scaled by meal size (`|baseHunger|`) × a level mult
    (`1.0→2.5` over L1→L100, ≈2× by L30). Canned/raw/burnt heal nothing.
    Knobs in `PZRPG.tuning.cooking`.
  - **COOK-4a ✅** — the buff engine (`PZRPG_09_Buffs.lua`): `PZRPG.buffs.apply`
    / `.get` / `.list` / `.clear` / `.remaining`, per-`OnPlayerUpdate` driver,
    `scholar` XP-multiplier wrap, `mending` / `infectionResist` / `steady`
    effects, "Well Fed" halo. `packmule` / `warm` still planned (API work).
  - **COOK-4a.2 ✅** — `strong` / `toughness` / `guarded` / `vigor` folded into
    `PZRPG_30/31/32` (one line each).
  - **COOK-4b ✅** — custom `ISPZRPGPrepareDishAction` + heat-source context
    menu (`PZRPG_49`, client) + recipe model & known-store & auto-grant
    (`PZRPG_25`) + 3 starter dish item defs (`pzrpg_food.txt`, vanilla icons) +
    eat→buff hookup in the COOK-3 wrap.
  - **COOK-5** — recipe *study* action (book-style, saved progress, longer for
    rarer recipes) → Field Cookbook UI → world-loot recipe cards. Also: more
    recipes, and the `packmule` / `warm` buff types.
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
- **MINE-2** — pick-wear reduction + a level-scaled coal-drop chance on a
  boulder. **No mine-speed effect, no yield bonus** (decided 2026-09-06). Maybe
  a real depletion (sprite swap) instead of the cooldown — still open.

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
