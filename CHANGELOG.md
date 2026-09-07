# Changelog

All notable changes to **PZ RPG** are recorded here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/); this
project uses SemVer and is in `0.x` (anything may change).

## [Unreleased]

### Changed
- Character sheet window `560x660` -> `620x720`; both tabs reserve room for the
  scrollbar so right-aligned text no longer clips.
- Skills tab row layout reworked: `name / Level N` on line 1, blurb + xp text on
  line 2, XP bar on line 3, real gaps between rows (blurbs no longer read as
  belonging to the next skill). Brighter XP bar.
- Keybind moved to the vanilla `keyBinding` table (like A Little Help) — shows
  in **Options > Key Bindings > [PZ RPG]** as `PZ RPG: Character Sheet`,
  rebindable, default **K**.
- Sheet clears a demonstrably-stale "- Game Paused -" banner (shown while the
  game is not actually paused) whenever it's open.

### Added
- **Strength — STR-EFFECT-1**: raw melee damage. The held weapon's min/max
  damage is scaled `× (1 + 0.30·(lvl/100)^1.4)` — ~+4% at L25, +11% at L50,
  +20% at L75, **+30% at L100**. "Moderate" tier (offensive skill: above the
  conservative defensive ceiling, below Attack+Fitness). B42 rolls swing damage
  off the `HandWeapon` instance; no Lua hook in the damage calc. Same
  stack-safe reconcile as Attack — the applied factor lives on the weapon's
  `getModData()` (`PZRPG_strDmg`), divided back out each `OnPlayerUpdate` to
  recover the true base before re-applying. Also trickles vanilla Strength
  (`vanillaXp = { Strength = 0.06 }`). Carry capacity + shove force are
  STR-EFFECT-2. Tuning at `PZRPG.tuning.strength`.
- **Attack — ATK-EFFECT-1**: first combat *level effect*. Attack is the melee
  **stamina** skill — the higher the level, the less endurance a swing costs, so
  you last longer in a fight. The held weapon's `enduranceMod` is scaled down
  `factor = 1 - 0.85·(lvl/100)^1.5` (~11% cheaper at L25, 30% at L50, 55% at
  L75, **85% at L100**), stacking *multiplicatively* on top of
  `PZRPG_05_Exertion`'s flat 65% refund — a maxed Attack + Fitness character's
  swings are nearly free, by design. `CombatManager` reads `enduranceMod` off
  the `HandWeapon` each swing; B42 exposes no Lua hook inside the drain calc.
  Stack-safe: the applied factor is stored on the weapon's `getModData()` and
  reconciled every `OnPlayerUpdate` (divide it back out, recompute from level,
  re-apply), so a level-up / weapon swap / `-debug` reload never compounds it.
  Hit chance is deliberately not touched. Attack now also trickles vanilla
  Fitness (`vanillaXp = { Fitness = 0.08 }`). Tuning at `PZRPG.tuning.attack`.
- **Mining — MINE-1b**: a depleted boulder is now **faded** (`setAlpha 0.5`)
  and captioned with a floating **"Depleted / 1d 6h"** timer above it
  (`PZRPG_47_MiningOverlay.lua`). (Fixed: the full-screen overlay element
  defaulted to `wantMouseEvents = true` and froze all interaction — now
  draw-only. Also reworked `ISMineBoulderAction` from anim-driven to a normal
  timed action with per-swing XP on job-delta thresholds, so it can't hang.) A throttled `OnTick` scans nearby squares for
  boulders on cooldown; a full-screen UI element draws the captions and keeps
  the fade applied; on recovery the alpha is restored and the modData cleared.
- **Mining — MINE-1**: right-click a world boulder (`boulders_*` sprite) with a
  pickaxe in your inventory → **Mine Boulder** → `ISMineBoulderAction`
  (`PZRPG_46`). **Swing-based like chopping a tree** — anim-driven, `+2 Mining`
  bubble **per swing** (via `PZRPG.xpDrops.immediate`), progress bar fills per
  hit; after 6 swings the boulder **drops 6–12 `Base.Stone2` + a guaranteed
  `Base.IronOre` (+1 bonus on a level-scaled 8%→60% roll) on the ground** (like
  logs from a felled tree; `Base.IronOre` is a real B42 item the blacksmith
  furnace already smelts) with `+N Stone` / `+N Iron Ore!` halos.
  Pickaxe gated three ways: menu only shows with one in inventory, `isValid()`
  re-checks it's held every tick, `:start()` auto-equips it. Boulder then goes
  on a **48h (2-day) cooldown** on its own `getModData()`; the menu option
  shows greyed-out with the time left. Iron-ore chance `8% → 25%` over 1–100.
  Tuning at `PZRPG.tuning.mining`.
- **Woodcutting — WC-2**: level-scaled chop-speed bonus. After each vanilla
  swing, shave `base * SPEED_MAX * (lvl/100)^SPEED_EXP` extra off the tree's
  health (never below 1 — vanilla always lands the felling blow). Defaults
  `SPEED_MAX 0.80 / SPEED_EXP 1.8` → ~+7% at L25, +23% at L50, +80% at L100.
  Sheet blurb shows the current %.
- **XP drops** (`PZRPG_08_XpDrops.lua`) — a floating "+N Skill" halo over the
  player on every skill XP gain, OSRS-style. Accumulated per skill and flushed
  ~0.6s after the last gain (one "+15 Woodcutting", not ten "+1.5"s). Toggle
  with `PZRPG.xpDrops.enabled`. `addXp` feeds it for every skill automatically.
  (Fixed: `next` is nil in Kahlua — the tick handler used it and error-spammed.)
- Per-skill tuning tables exposed at `PZRPG.tuning.<id>` for live console
  tweaks (started with Woodcutting; `XP_PER_SWING` 10 -> 1.5).
- **CONST-EFFECT-1** — Constitution's first level effect: a chance to shrug off
  the Knox infection the tick a bite/scratch would transmit it (`OnPlayerUpdate`
  watches `getBodyDamage():IsInfected()`; on a fresh true, rolls per infected
  body part and `SetInfected(false)` on a save). L100 ≈ 55% scratch / 20% bite;
  vanilla still decides whether infection happens, we only get the save.
- **DEX-1** — Dexterity's stealth side mirrors vanilla `Sneak` + `Lightfoot` +
  `Nimble`. Lockpicking deferred (no clean B42 hook). No level effect.
- **CMB-1** — combat cluster wired, XP only (no level effects — combat is the
  balance-sensitive one, effects come much later):
  - **Attack** ← `OnWeaponHitXp`, `8 * hitCount`
  - **Strength** ← `OnWeaponHitXp`, `12 * damage`
  - **Defense** ← `OnPlayerUpdate` body-health drop (`250 * hp`, ignores <0.5
    and >15/tick so hunger noise and death don't count)
  - **Constitution** ← health drop at half rate + `2 * hitCount` per melee hit
- **FIRE-1** — Firemaking wired (`PZRPG_21_Skill_Firemaking.lua`). No vanilla
  perk maps to it, so it uses the new **`PZRPG.wrapAction(cls, method, fn)`**
  util (`PZRPG_07_ActionWrap.lua`, reload-safe) to hook `:perform` on
  `ISLightFromKindle` / `ISLightFromLiterature` / `ISLightFromPetrol` /
  `ISAddFuelAction`: fire catches = 150 xp, kindling breaks = 20, add fuel = 15.
- **MIRROR-1** — `PZRPG_06_VanillaMirror.lua` hooks `Events.AddXP` and mirrors a
  scaled proportion of a vanilla perk's XP into any skill declaring
  `mirrorVanilla = { <perk> = <weight> }`, times one dial
  (`PZRPG.mirror.GLOBAL_MULT`, placeholder 5.0). Feed-depth guard stops it
  looping with the `vanillaXp` feed. Wired: **Cooking**←Cooking,
  **Fishing**←Fishing, **Foraging**←PlantScavenging, **Smithing**←Blacksmith
  +MetalWelding, **Crafting**←Woodwork+Tailoring+Carving. No level effects yet.
- **Woodcutting — WC-1** (`PZRPG_10_Skill_Woodcutting.lua`): `XP_PER_SWING = 10`.
  Wraps `ISChopTreeAction:animEvent` (`"ChopTree"`) — `OnWeaponHitTree` turned
  out to only fire for melee-whacking a tree, not the chop action. Wrap is
  installed on `OnGameBoot` (that class loads after `PZRPG_10`). No level effect
  yet (chop speed = WC-2, yield = WC-3).
- **`vanillaXp` feed** (`PZRPG_03_Xp.lua`): `addXp` now trickles a fraction of a
  skill's XP into vanilla perks when the def declares
  `vanillaXp = { Fitness = 0.15, Strength = 0.08 }` (perk name -> ratio).
  Silent, respects vanilla multipliers. Woodcutting feeds Fitness + Strength.
- **Cooking** placeholder skill (`PZRPG_23`, Production).
- **Exertion softening** (`PZRPG_05_Exertion.lua`) — each player-update tick,
  refund a fraction of any endurance drop when the player isn't running, so
  physical work is sustainable instead of "chop once, sit down". One knob,
  `PZRPG.exertion.ENDURANCE_REFUND` (default 0.65 => work ~35% as tiring),
  live-tunable from the `-debug` console. Fatigue softening present but off by
  default. First deliberate vanilla rebalance — see `DESIGN.md` §3a.
- **Full skill roster stubbed** — placeholder `registerSkill` for every skill in
  `DESIGN.md` §5, one file each (`PZRPG_11..40_Skill_*.lua`), so the Skills tab
  shows the whole grid grouped by category. No behaviour yet — each gets its XP
  hook + level effect when built as its own slice, in whatever order we pick.
  - Gathering: Woodcutting, Mining, Foraging, Fishing
  - Production: Smithing, Firemaking, Crafting
  - Combat: Attack, Strength, Defense, Constitution
  - Dexterity: Dexterity (lockpicking / stealth / noise)

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
