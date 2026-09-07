# PZ RPG — Design

> Status: **early vision.** This captures the direction, not a locked spec.
> Anything marked _(sketch)_ is spit-balling to be pinned down when we build that
> system. We take our time; systems are built in small sections.

---

## 1. Vision

Project Zomboid is a survival sandbox. **PZ RPG layers an Old School RuneScape–style
skilling game on top of it** — not a copy of OSRS, but the *feel*:

- **Many separate skills**, each **level 1–100**, each with its own XP bar and its
  own long climb.
- Progress comes from **doing the thing** — chop trees to train Woodcutting, mine
  boulders to train Mining — not from spending abstract points.
- Higher levels make you **noticeably but not absurdly** better at that skill.
- Skills **feed each other**: Mining ore → Smithing bars → Smithing gear that
  makes the next tier of Mining or Combat easier. The web of dependencies is the
  game.
- It runs **alongside vanilla PZ**, which is untouched and still the survival
  layer underneath.

### The feel we're going for

| OSRS | PZ RPG |
| --- | --- |
| Chop a tree, get logs + Woodcutting XP, tree respawns | Chop a tree (vanilla action), get logs + **Woodcutting** XP; higher level = a bit faster |
| Mine a rock, get ore, rock respawns | Mine a **boulder** with a pickaxe → Stone / **Iron Ore**; boulder is consumed or depletes |
| Smelt ore → bars → smith gear at an anvil | Smelt Iron Ore → Iron Bar → **Smithing** recipes unlock more metal gear over levels |
| Combat XP split across Attack/Strength/Defence/HP | Combat XP split across **Attack / Strength / Defense / Constitution** |
| Thieving, Agility, stealth | **Dexterity** umbrella — lockpicking, stealth, noise |

### Non-goals

- Not replacing vanilla skills, XP, or character creation.
- Not a total conversion. The zombie apocalypse is still the setting and the
  threat.
- No "level 90 clears a forest in 20 seconds." Scaling stays grounded (§4).
- Multiplayer is not a launch target; design server-authoritative where cheap,
  don't block on MP.

---

## 2. Design pillars

1. **Grounded scaling.** A max-level skiller is efficient, not a superhero. The
   curve is felt over dozens of hours, not in the first afternoon.
2. **Train by playing.** XP is a side effect of the natural action. Minimal
   menu-fiddling.
3. **Skills are a web.** Every skill should have at least one input from and one
   output to another skill by the time it's "done."
4. **Vanilla-compatible.** Vanilla saves, vanilla skills, and other mods keep
   working. PZ RPG's data lives in its own namespace.
5. **Modular.** Each skill is a self-contained system that registers with the
   Core. You can ship, disable, or (later) extract one without touching the rest.
6. **Small sections.** Every skill arrives in slices — first the XP hook and the
   number, then the level effect, then the content, then the polish.

---

## 3. Relationship to vanilla

- **Vanilla skills (Carpentry, Aiming, …) stay a separate track** — same 0–10
  levels, same XP, same perks screen. PZ RPG skills are our own 1–100 track with
  their own XP store and UI; no shared cap or pool.
- Vanilla actions we piggy-back on (chopping, foraging, combat) keep doing their
  vanilla thing; we also award PZ RPG XP on the same event.

### 3a. Where we *do* touch vanilla  (decided 2026-09-06)

Two deliberate, tunable links — both opt-in and in one place:

- **Skills feed vanilla physical perks** (`vanillaXp`). Doing PZ RPG work
  passively trickles vanilla **Fitness / Strength** XP — realism, and the
  physical skills stay worth training. Declared per skill: `vanillaXp = {
  Fitness = 0.15, Strength = 0.08 }` (perk → fraction of the PZ RPG XP also
  granted). `PZRPG.addXp` routes it.
- **Skills mirror vanilla perks the other way** (`mirrorVanilla`, via
  `PZRPG_06_VanillaMirror` hooking `Events.AddXP`). Where a PZ RPG skill maps
  onto a vanilla perk — Cooking↔Cooking, Fishing↔Fishing, Foraging↔
  PlantScavenging, Smithing↔Blacksmith/MetalWelding, Crafting↔Woodwork/
  Tailoring/Carving, later combat — vanilla already detects the activity, so we
  mirror a scaled proportion of that perk's XP into our skill:
  `mirrorVanilla = { Cooking = 1.0 }`, scaled by one global dial
  (`PZRPG.mirror.GLOBAL_MULT`). A feed-depth guard keeps the two directions
  from looping.
- **Exertion is softened** (`PZRPG_05_Exertion`). Vanilla endurance drains so
  fast that work is "chop once, sit down". We refund a fraction of every
  endurance drop (except while running) so the loop — chop a tree, gather the
  twigs, start a fire, saw the logs — is sustainable before you're winded.
  One knob (`PZRPG.exertion.ENDURANCE_REFUND`, default 0.65 ⇒ work ~35% as
  tiring). Fatigue softening exists but is off by default. This *is* a vanilla
  rebalance — a deliberate exception to "don't rebalance vanilla", because the
  vanilla pace fights "let the player actually play".

---

## 4. The skill model

### Levels & XP

- Every skill: **level 1 to 100**.
- Each skill has an **XP total**; level is derived from XP via a shared curve.
- **Curve:** smoothly increasing, RuneScape-ish — cheap early levels, a long
  grind to 100. Custom formula (not OSRS's table), one place in Core:
  `xpForLevel(n) = floor(COEFF * (n-1)^EXPONENT)`, two tuning knobs. Defaults
  `COEFF=15, EXPONENT=2.5` → level 100 ≈ 1.46M total XP, level 50 ≈ 252k
  (~17% of the climb). Level 50 is the "comfortably self-sufficient" mark, 100 a
  long-haul goal. Retune once a skill actually awards XP (Phase 2).
- **Level-up** fires a notification (halo text + a sound) and a log line.

### How a level actually helps — the scaling rule

The effect of a level is a **multiplier or chance that moves gently with level**.
Concrete example, **Woodcutting**:

- Chopping is still the **vanilla chop action**. We do not reanimate or replace it.
- Level scales **chop speed** (action time) on a shallow curve:
  - Level 1: ~baseline (vanilla-ish, maybe a touch slower).
  - Level 50: noticeably quicker — you feel it.
  - Level 100: clearly faster than a fresh character, but **not** trivial — still
    a real action, still costs endurance, no infinite logs.
- Yield (logs / twigs / branches) may get a **small** bonus roll at higher levels
  — a little extra, not a jackpot.
- Target ceiling: a level-100 chopper is maybe ~1.5–2× a level-1 chopper's
  throughput, not 10×. _(numbers to be tuned in-game)_

Every skill follows this shape: **pick one or two real in-game quantities, scale
them on a shallow curve, cap the top end so it stays grounded.**

### Where the numbers live

All per-skill tuning (base times, per-level multipliers, XP rewards, drop
chances, the XP curve itself) sits in **tuning tables**, one per skill plus a
Core one, so values can be balanced fast and later surfaced as sandbox options
without hunting through logic.

---

## 5. Skill roster _(planned — not all at once)_

Grouped roughly. Order of implementation is set in the ROADMAP, not here.

### Gathering

| Skill | Trains by | Level effect _(sketch)_ | Outputs |
| --- | --- | --- | --- |
| **Woodcutting** | Chopping trees | Faster chop, small yield bonus | Logs, twigs, branches → Carpentry / Firemaking / Smithing (charcoal) |
| **Mining** | Mining boulders with a pickaxe | Faster mine, better ore chance, less pick wear | Stone, **Iron Ore**, (later: coal, other ores) → Smithing |
| **Foraging / Herbalism** _(later)_ | Foraging (vanilla zones) | Rare-find chance, more per pick | Plants → Cooking / medicine |
| **Fishing** | Right-click water with a rod → `ISPZRPGFishAction` (custom action, not the vanilla minigame — FISH-2) | Bite rate ↑, better/bigger species unlock, fish run bigger within a species (FISH-3), less junk; bait optional (flat bite bonus) | Fish (custom level-gated list of real B42 fish items) → Cooking |

### Production

| Skill | Trains by | Level effect _(sketch)_ | Notes |
| --- | --- | --- | --- |
| **Smithing** | Smelting ore, forging at an anvil | Unlocks recipe tiers; less material waste; better durability on smithed items | Iron Ore → Iron Bar → tools/weapons/armor. **Progression = an unlock tree of "metal" items** revealed as level rises. |
| **Firemaking** | Lighting fires + a passive trickle while a fire you're near stays lit; raking charcoal | **Ignition chance only** — higher level lights a fire more reliably, whatever the material (see below) | Charcoal feeds Smithing |
| **Cooking** | Any cooking action (vanilla-mirrored) + a bonus for cooking from raw; studying found recipes | Basic cooked staples restore more as you level; Field Recipes gate on level to cook (see below) | Fed by Foraging / Fishing / Farming / hunting; feeds survival |
| **Crafting / Fletching** _(later)_ | Working leather, wood, bone | Recipe unlocks, quality | Ties Woodcutting + hunting |

### Firemaking  (decided 2026-09-06)

No vanilla perk maps to it. The **physical system is the vanilla 3-stone campfire**
— no new world object. Firemaking layers four things onto it:

- **Fuel cap raised.** Vanilla caps a fire at `MaximumFireFuelHours` (default 8h;
  the ~6h number some remember is only the light-radius/smoke scaling). PZ RPG
  adds its own sandbox slider, **default 12h**, and overrides the global
  `getCampingFuelMax()` to honour it. A day of doing other things shouldn't come
  back to a dead fire.
- **Flat burn efficiency.** A fixed, *always-on, not level-scaled* slowdown on
  fuel drain (`SCampfireSystem:lowerFuelAmount` is plain Lua) — one knob in
  `PZRPG.tuning.firemaking`, ~0.75×/min to start. A deliberate vanilla rebalance
  in the same spirit as Exertion (§3a).
- **Level → ignition chance, nothing else.** Vanilla's kindle action
  (`ISLightFromKindle:updateKindling`, Lua) is a fixed `ZombRand(300)`/tick race
  to catch vs. snap your kindling. PZ RPG owns that method: catch-odds climb and
  break-odds fall with Firemaking level, **plus a bonus when real tinder
  (twigs / paper / sheets) is in the bag** — "twigs and paper start better than
  logs." Literature / petrol lighting stays auto-success (skill fantasy is
  friction ignition). Fuel efficiency is *not* a level effect — the flat
  rebalance already covers "fires last longer."
- **Charcoal output.** A "rake charcoal" action on a burnt-down fire → real B42
  charcoal items, feeds Smithing, trains Firemaking. Firemaking's skill-web
  output from day one.

**XP model — reward *keeping* a fire, not spamming lights.** Lighting ≈ 40,
feeding fuel ≈ 10, **plus a passive trickle every 10 min while a lit campfire is
within 2 tiles of you** (a day at camp ≈ a few lightings' worth). A campfire
mouse-over tooltip shows "Stand near to train Firemaking", time left, heat
radius.

Slices: **FIRE-2** cap slider + flat efficiency + XP rebalance · **FIRE-3**
ignition scaling + tinder bonus · **FIRE-4** passive tending XP + hover tooltip ·
**FIRE-5** charcoal.

### Cooking  (decided 2026-09-06)

Still vanilla-mirrored (`mirrorVanilla = { Cooking = 1.0 }`). Two layers:

- **Basic cooked food scales with level.** A tuning table of staple cooked foods
  by *tier* (Cooked Trout = tier 1 — "every kid learns to cook a fish"). Level
  raises what the food restores on a shallow curve — e.g. Cooked Trout ≈ 15 HP /
  10 hunger at L1 → ≈ 30 HP / 20 hunger by L30, flattening after. _(Mechanic to
  confirm when built: a brief HP-regen window on eating a properly-cooked staple,
  scaled by tier × level; vanilla nutrition left alone. Numbers all tunable.)_
  Normal food (deer venison, chicken, …) keeps its normal vanilla value and still
  grants Cooking XP.
- **Field Recipes** _(the marquee feature, later)_ — special recipes that produce
  a meal granting a **fixed timed buff** (e.g. *Bountiful Trout Platter* = raw
  trout + berries + onion + potatoes → 2h reduced infection chance). Each recipe
  has a **fixed** heal / hunger value, a **fixed** buff, and a **`minLevel` to
  cook**. Result items are **new item defs re-using vanilla food icons** — no art
  debt; B42's ingredient palette (`BerryGeneric` / `BerryBlack` / `BerryBlue`,
  `Potato` / `Onion` / `Carrots` / `Cabbage` / `Tomato` / `BellPepper`, `Apple`,
  `Grapes`, the fish list, venison, chicken) already covers inputs.
  - **Learning:** a found recipe is *studied* like reading a book — a timed
    action with saved progress you resume across sessions. Rarer / stronger
    recipes take much longer to finish ("practicing the meal in your head" until
    it's learned). On completion it enters a **Field Cookbook UI**; the item is
    consumed.
  - **Starter set:** 3–4 basic buff recipes (fish, venison, chicken; small
    buffs) **auto-known at character creation** — nothing in inventory. The
    strong recipes are world loot.

- **XP:** mirror + a bonus weighted toward real cooking (raw ingredients /
  multi-item meals, not reheating a can).
- **Food-sickness risk is left alone** — bad ingredients stay bad; Cooking level
  doesn't touch food poisoning.

Slices: **COOK-2** mirror + bonus XP · **COOK-3** staple-food level scaling +
tier table · **COOK-4** Field Recipe items + buffs + cook action + starter set ·
**COOK-5** recipe study action + Field Cookbook UI + world loot.

### Combat

| Skill | Trains by | Level effect _(sketch)_ |
| --- | --- | --- |
| **Attack** | Landing melee hits | Melee **stamina efficiency** — swings cost less endurance, so you last longer in a fight (pairs with Fitness for an end-game power spike, by design) |
| **Strength** | Landing melee hits (damage-dealt weighted) | Melee **damage** (STR-EFFECT-1); shove force + carry capacity (STR-EFFECT-2) |
| **Defense** | Being attacked / blocking | Damage taken reduction, block chance, less durability loss on armor |
| **Constitution** | All combat + surviving hits | Bonus effective health / injury resistance _(kept modest — PZ death is the point)_ |

Combat skills are the most sensitive to balance. XP wiring is in (CMB-1); level
*effects* land carefully, one at a time. Ceiling is **conservative for the
defensive skills** (a maxed fighter is better but PZ still kills you fast) but
**Attack + Fitness is allowed to feel like a god by end-game** — that's the
intended reward for a deep melee-survival grind (decided 2026-09-06).

B42 melee resolution is entirely Java-side — no Lua hook sits inside the
hit/damage/endurance calculation. So combat effects work one of two ways:
**(a) top up the equipped weapon instance's own stats** (`setEnduranceMod`,
`setExtraDamage`, `setHitChance` — `CombatManager` reads these live each swing),
reconciled against a per-item stored "how much we last changed it" so it's
swap-safe and never compounds; or **(b) a per-tick delta on the character**
(`setMaxWeightDelta`) or a post-hit health refund on the body-health drop we
already watch for XP (same idiom as `PZRPG_05_Exertion`).

- **Attack → melee stamina efficiency** (ATK-EFFECT-1): Attack is the *survival
  stamina* skill, not accuracy. While a melee weapon is equipped, its
  `enduranceMod` (the multiplier on a swing's endurance cost) is scaled down as
  Attack rises: `factor = 1 - 0.85·(lvl/100)^1.5` → ~11 % cheaper at L25, 30 %
  at L50, 55 % at L75, **85 % at L100**. Stacks *multiplicatively* on top of
  `PZRPG_05_Exertion`'s flat 65 % refund, so a maxed character's swings are
  nearly free — the deliberate Attack + Fitness end-game payoff. Method (a):
  `PZRPG_30` reconciles the held weapon each `OnPlayerUpdate`, storing the
  applied factor on the weapon's modData so a re-hold / level-up / reload never
  compounds it. Hit chance is left alone. Coefficients in
  `PZRPG_30_Skill_Attack.lua` TUNING. Candidate follow-ups (ATK-EFFECT-2):
  let a high level attack through the exhausted-endurance lockout
  (`setCantAttackWithLowestEndurance`).
- **Strength → melee damage** (STR-EFFECT-1): the held weapon's min/max damage
  is scaled `× (1 + 0.30·(lvl/100)^1.4)` → ~+4 % at L25, +11 % at L50, +20 % at
  L75, **+30 % at L100**. Offensive skill, so "moderate" — above the defensive
  ceiling, below Attack+Fitness. Method (a), same reconcile as Attack (factor
  stored on the weapon's modData). Also trickles vanilla Strength
  (`vanillaXp = { Strength = 0.06 }`). `PZRPG_31_Skill_Strength.lua` TUNING.
- **Strength → carry capacity & shove** (STR-EFFECT-2, planned): B42's
  carry-weight recalc (`IsoGameCharacter.maxWeight`, an int only written in the
  ctor + a `setMaxWeight` the game calls from somewhere not yet pinned down —
  `setMaxWeightBase` and `maxWeightDelta` are the candidate knobs) needs
  understanding first. Its own slice.
- **Defense → block chance & damage reduction** (DEF-EFFECT-1): on the
  body-health drop `PZRPG_32` already watches for XP, roll a block
  (`0 → 20 %` at L100, `(lvl/100)^1.5`) that hands the whole tick's loss back
  ("Defense: blocked!"); a failed roll still hands back `loss × reduction`
  (`0 → 30 %` at L100, `(lvl/100)^1.3`). Refund is `bd:AddGeneralHealth` on the
  same tick, so the bar barely flickers. Only *general* health is touched — the
  wound (scratch / bleed / fracture) still lands; that's Constitution's lane.
  Conservative by design: a maxed Defense ≈ 44 % average damage reduction, a
  bite still infects. A true pre-hit dodge via the one-shot `setAvoidDamage`
  flag is possible but timing-fragile — deferred to DEF-EFFECT-2.
  `PZRPG_32_Skill_Defense.lua` TUNING.
- **Constitution → infection resistance** (CONST-EFFECT-1): a chance to negate
  the Knox infection the instant a bite/scratch would transmit it. Vanilla still
  decides *whether* infection happens; we only get a save at transmission, never
  a cure. L100 ≈ 55% on scratches, 20% on bites — a maxed character still dies
  to most bites. Coefficients in `PZRPG_33_Skill_Constitution.lua` TUNING.
- **Constitution → resilience** (CONST-EFFECT-2): the injury-side counterpart
  to Defense's flat damage reduction. Two transient per-tick nudges in
  `PZRPG_33` (no persistent state written): (1) **bleeding resolves faster** —
  shave `0 → 2 %` (L100, `(lvl/100)^1.3`) off every bleeding part's remaining
  `getBleedingTime()` each tick, so a bleed at max Constitution ends ~2–3× as
  fast; (2) **slow passive regen while hurt** — `bd:AddGeneralHealth` up to
  `+0.004/tick` (L100, `(lvl/100)^1.4`, near-zero below ~L40), but *only* when
  not bleeding and not on a tick a hit landed (Defense's watcher owns those).
  Kept modest. `PZRPG_33_Skill_Constitution.lua` TUNING.

### Dexterity umbrella

One skill, several applications _(sketch — could split later)_:

| Application | Trains by | Level effect |
| --- | --- | --- |
| **Lockpicking** | Picking locks (doors, cars, containers) | Success chance, speed, fewer broken picks |
| **Stealth** | Moving undetected near zombies | Detection radius, movement noise |
| **Noise** | (passive) | How much sound your actions make — chopping, walking, gunfire falloff |

---

## 6. New content this implies

Tracked here so we don't forget the art/data debt:

- **Iron Ore** item + world sprite — recolor of the stone/boulder texture
  _(sketch: tint a copy of the vanilla rock sprite)_.
- **Boulder** world objects that can be mined — either reuse existing map rocks or
  spawn our own; need a "depleted" state.
- **Iron Bar**, intermediate smithing materials.
- **Smithed item tiers** — which vanilla metal items get gated behind Smithing
  levels, and any new ones.
- **Anvil / forge / smelter** — reuse vanilla metalworking stations or add ours.
- Icons + translation strings for every skill and item.
- A **character sheet** UI (first slice — see ROADMAP; the user will detail the
  vision when we get there).

---

## 7. The "Core"

**PZ RPG Core** is the engine every skill plugs into. It owns:

- The **XP store** on each character (save/load/migrate) — see `ARCHITECTURE.md`.
- The **level curve** and `xpToLevel` / `levelToXp` math.
- The **skill registry**: a skill calls `PZRPG.registerSkill{ id, name, icon, … }`
  at load; Core tracks it, the sheet renders it, XP routes to it.
- **`PZRPG.addXP(player, skillId, amount)`** and the level-up event.
- The **character sheet** shell (skills list its registered skills).
- Shared notification / sound / log helpers.
- Sandbox-option plumbing (global XP multiplier, per-skill enable).

A skill module (Woodcutting, Mining, …) is then just: a tuning table, the event
hooks that call `PZRPG.addXP`, and the code that applies its level effect.

See §8 for whether these ship as one mod or several.

---

## 8. Mod structure — recommendation

**Recommendation: build it as ONE mod now (`PZRPG`), with a hard internal
Core ↔ skill seam, and revisit splitting at the 1.0 mark.**

Why not separate mods yet:

- **The Core API is unproven.** How a skill registers, how the sheet renders it,
  how XP is stored and migrated — all of that needs to be iterated against the
  first 2–3 real skills *in one codebase*, cheaply. Freezing it across a mod
  boundary now is premature.
- **B42 local-mod dependencies are fragile.** There's no strong "requires Core
  ≥ x" enforcement; a stale or unloaded Core just breaks silently. One mod
  sidesteps load-order and version-skew bugs during the long dev phase.
- **Per-slice overhead.** We work in tiny slices and want many skills. Maintaining
  6+ mod scaffolds (each its own `mod.info`, deploy target, changelog, Workshop
  page) fights that directly.
- **One identity.** "PZ RPG" is one thing to a player — one Workshop page, one
  version number, one settings screen.

Why it's still safe:

- The modular structure is enforced from **day one**: each skill is a
  self-contained folder that only touches Core through the registry seam and
  `PZRPG.addXP`. No skill reaches into another skill's internals.
- Players who want fewer skills get **sandbox-option toggles** per skill.
- If a skill ever genuinely needs to be standalone, extracting a
  cleanly-isolated system into `PZRPG-<Skill>` (with `PZRPG` core as a
  dependency) is a known, bounded job — *because* we kept the seam clean.

So: **modular monolith.** The Google-AI "core + separate skill mods" idea is the
right *architecture* — we're just keeping it inside one mod package until the
Core API has earned a stable version.

---

## 9. Open questions

To resolve as we reach each system:

1. ~~**XP curve** — RuneScape's exact table, or a custom smoother one?~~
   **Decided (2026-09-06):** custom smooth formula `COEFF * (n-1)^EXPONENT`, two
   knobs in Core (`DESIGN.md` §4). Still open: hours-to-100 for a mid skill —
   answered by tuning per-action XP in Phase 2, not by the curve.
2. **Character sheet** — the user will walk through the full vision when we build
   it (first slice). Layout, what each row shows, keybind, whether it's a HUD
   element or a pop-up.
3. **Boulders** — reuse vanilla map rocks, or spawn PZ RPG boulder objects? How
   does a mined-out boulder look / behave (respawn timer? gone for good?).
4. **Combat skills vs. PZ lethality** — how much bonus effective health is "an RPG
   feel" without undermining that PZ is supposed to kill you?
5. **Vanilla cross-links** — which, if any, vanilla perks feed PZ RPG skills and
   vice-versa.
6. **Death** — do PZ RPG levels persist past character death (account-style) or
   die with the character? _(Leaning: die with the character — it's still PZ.)_
