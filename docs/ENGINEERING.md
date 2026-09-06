# Engineering guide

How we build **PZ RPG**. Read this before writing code.

---

## 1. How we work — small vertical slices

We ship one **vertical slice** at a time: a single thin capability, wired end to
end (data → logic → UI → in-game), verified in the running game, committed, and
only *then* do we start the next one.

- A slice is **one or two controls**, or **one behaviour**. Not "an attribute
  screen plus an XP system plus a perk tree plus a HUD."
- **No wide changes.** Never touch a new system, the HUD, and persistence in the
  same slice. If a change spans more than ~3 files for more than one reason,
  it's too big — split it.
- Every slice is small enough to hold in your head and to bisect if it breaks.
- If a slice turns out bigger than it looked, stop and re-slice rather than
  pushing through.

This is deliberate. The scarce resource is careful attention, not typing speed.
One correct, tested slice beats five half-working ones. **This is a huge mod; the
only way it ships is one honest slice at a time.**

### The loop

```
edit  ->  deploy.ps1  ->  restart PZ (or hot-reload in -debug)
      ->  verify the one thing  ->  commit  ->  next slice
```

Restart PZ (not just reload) when you change: `mod.info`, keybinding
registration, sandbox options, anything read only at game start, or after a
Java-level crash.

---

## 2. Definition of Done

A slice is done when **all** of these are true:

1. The game loads it with **no Lua error** — no red error box, `console.txt`
   clean of new stack traces.
2. The **one capability the slice was about** works in-game, confirmed by a human
   actually doing it.
3. **No regression** — earlier slices still work, and **a save from before the
   slice still loads** (persistence changes are migrations, not resets).
4. `CHANGELOG.md` has an entry; committed with a Conventional Commit message.
5. If the architecture or a data shape changed, `docs/ARCHITECTURE.md` /
   `docs/DESIGN.md` are updated in the same commit.

If any point fails, the slice isn't done — fix it before moving on, don't stack
the next slice on top.

---

## 3. Versioning, commits, changelog

- **SemVer** (`MAJOR.MINOR.PATCH`). We're `0.x` — anything may change; `MINOR`
  bumps on a new capability, `PATCH` on fixes.
- **Conventional Commits**: `type(scope): summary`.
  Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`.
  Scope is the system: `core`, `stats`, `xp`, `perks`, `hud`, `save`, `deploy`, …
  e.g. `feat(xp): award XP on zombie kill, scaled by weapon`
- **Keep a Changelog** format in `CHANGELOG.md`; an `## [Unreleased]` section
  collects entries until we tag a version.
- One logical change per commit.

---

## 4. Project Zomboid modding reference

> **Read this section before writing any Lua.** Work like an engineer who knows
> Kahlua/Lua/Java and PZ modding — verify API names and object types against the
> game files *first*, don't "deploy and see". Every broken in-game test is a full
> Steam launch + new game + spawn.

### The four things that keep biting us

1. **Java object ≠ Lua table.** PZ passes Java objects straight into Lua —
   `IsoPlayer`, `IsoGameCharacter`, `InventoryItem`, `SurvivorDesc`, Java
   `ArrayList`/`List`. `getSpecificPlayer(0)`, `player:getDescriptor()`,
   `:getCharacterTraits()` etc. all return Java. On a Java object:
   - No Lua string/table methods, no metatable tricks.
   - Iterate Java lists with `:size()` + `:get(i)` (**0-based**), never
     `ipairs`/`pairs`.
   - `obj.methodName and obj:methodName()` existence-checks are unreliable —
     just call it, inside `pcall` if it can legitimately be absent/nil.
   - Know the type of every variable you hold.

2. **Build 41 ≠ Build 42.** B42 (this project targets **42.20.4**) restructured
   item scripts, `media/` layout, `common/` mod discovery, and API hooks. Most
   online snippets are B41 and wrong. Confirm against the real install:
   - `C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\lua\**`
     (grep vanilla for the pattern you want).
   - `javap -cp projectzomboid.jar zombie.<pkg>.<Class>` for exact method
     signatures (JDK: `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot\bin`).

3. **Kahlua is a sandbox** — Lua 5.1 with the standard library stripped:
   **no `io.*`, no `os.*`**, partial `string`/`table`/`math`. So:
   - Persistence → `getModData()` (see §Persistence), never file I/O.
   - Time → `getGameTime()`, `getTimestampMs()`, `Calendar` — never `os.time`
     / `os.clock`.
   - `math.pow` may be missing — use the `^` operator.

4. **Lua/OO footguns:**
   - Defining `Foo:method` (colon) **and** `Foo.method` (dot) on the same table
     — the second silently shadows the first. Caused a `close`→`close` stack
     overflow. Pick distinct names for instance methods vs. static helpers.
   - A full-screen `ISUIElement` defaults to `wantMouseEvents = true` — it will
     **eat every click** behind it. A "purely visual" overlay must
     `setWantMouseEvents(false)`, or just don't add one.
   - The game runs the copy in `C:\Users\conov\Zomboid\mods\PZRPG\` — always
     `deploy.ps1` before testing; a lua-reload alone reads the deployed copy,
     not the repo.

### Runtime & structure

| Term | Meaning |
| --- | --- |
| **Kahlua** | The Java-hosted Lua 5.1 VM PZ runs. No build step; `.lua` is read directly. |
| **Lua context** | `media/lua/shared`, `.../client`, `.../server`. In single-player one process runs client + server; in MP they're separate. `shared` loads first, then the context tree, each **alphabetically**. |
| **`common/` wrapper** | B42 only discovers a local mod (`<user>/Zomboid/mods/<x>/`) if it has `common/mod.info` or `<version>/mod.info`. Our whole payload lives in `common/`. |
| **`mod.info`** | Mod manifest (`id`, `name`, `poster`, …). Line-based parser — must be **CRLF** (`.gitattributes` pins it; `deploy.ps1` re-forces it). |

### Events / hooks

- `Events.<Name>.Add(fn)` attaches a handler; `.Remove(fn)` detaches.
- Progression-relevant: `OnGameStart`, `OnCreatePlayer(playerIndex)`,
  `OnPlayerUpdate(player)`, `OnPlayerDeath`, `OnZombieDead(zombie)`,
  `OnWeaponHitCharacter`, `OnPlayerGetDamage`, `LevelPerk(player, perk, level)`,
  `AddXP(player, perk, amount)`, `OnTick`, `EveryOneMinute`, `EveryHours`.
- **Keybinds: prefer `OnKeyStartPressed` over `OnKeyPressed`** — the engine skips
  it while a text field has keyboard focus, so a keybind won't fire mid-typing.
- **Register a keybind by appending to the global `keyBinding` table** at client
  load (not `getCore():addKeyBinding`, which doesn't give it a category):
  `table.insert(keyBinding, { value = "[PZ RPG]", key = nil })` for the section
  header, then `{ value = "PZ RPG: <action>", key = Keyboard.KEY_X }` for each
  bind. Guard against duplicates by scanning for the `value` first. Read the
  live key with `getCore():getKey("PZ RPG: <action>")`. Read at startup — a
  restart is needed to pick up a changed default.
- **Hot-reload hazard:** re-running a file calls `.Add` again and stacks a
  duplicate handler. Always register through `PZRPG.hookEvent` (see §6).

### Character, stats, XP

| Term | Meaning |
| --- | --- |
| **`getPlayer()` / `getSpecificPlayer(n)`** | Local player / split-screen player `n`. |
| **`IsoPlayer` : `IsoGameCharacter`** | The player. Has `getXp()` (an `Xp` object), `getPerkLevel(perk)`, `LevelPerk`, `getStats()`, `getBodyDamage()`, `getNutrition()`, `getModData()`. |
| **`Perks`** | Enum of vanilla skills (`Perks.Strength`, `Perks.Fitness`, `Perks.Sprinting`, `Perks.Axe`, …). |
| **`player:getXp():AddXP(Perks.X, amount)`** | Grant skill XP (fires `AddXP`, may fire `LevelPerk`). |
| **`player:getModData()`** | Per-character key/value table, saved with the game. **This is where PZ RPG's own numbers live.** |
| **`player:getStats()`** | Engine stats: endurance, fatigue, stress, panic, … (runtime, not all saved). |
| **Traits / `player:HasTrait(name)`** | Character-creation traits. |

Whatever custom progression PZ RPG defines (levels, attributes, resource pools)
is **our data in `getModData()`**, not engine fields — see `docs/ARCHITECTURE.md`
for the schema and the save/migrate rules.

### UI — ISUI

- Widget classes are Lua tables via `Parent:derive("Name")`; instances via
  `Class:new(...)`.
- Lifecycle: `new` → `initialise` → (`instantiate` → `createChildren` via
  `addToUIManager`) → `prerender`/`render` each frame → `removeFromUIManager`.
- A persistent on-screen HUD element derives `ISUIElement` and is added once at
  `OnCreatePlayer`; a pop-up panel derives `ISCollapsableWindow` or
  `ISPanelJoypad`.
- Common widgets: `ISButton`, `ISLabel`, `ISScrollingListBox`, `ISProgressBar`,
  `ISTickBox`, `ISContextMenu`.

### Persistence & config

| Term | Meaning |
| --- | --- |
| **`ModData`** | Per-save store. `player:getModData()` for per-character; `ModData.getOrCreate("PZRPG")` for a save-global table. Auto-saved with the game; must be transmitted in MP. |
| **Save/load hooks** | `OnGameStart` / `OnCreatePlayer` to read + migrate; `OnSave` if we need an explicit flush. Never assume our keys exist — default + version them. |
| **Sandbox options** | Player-set knobs in `common/sandbox-options.txt`, read via `SandboxVars.PZRPG.*`. Use these for XP rates, difficulty toggles. |
| **Translations** | `common/media/lua/shared/Translate/<lang>/*.txt`; `getText("IGUI_PZRPG_...")`. |
| **`-debug` / `getDebug()`** | Launch flag; unlocks the debug menu, `reloadLuaFile`, spawn tools. Gate dev-only UI on `getDebug()`. |

---

## 5. Code standards

- **One file, one responsibility.** Top-of-file block comment stating what the
  file owns.
- **Load order is explicit.** Lua files carry a `_NN_` prefix
  (`PZRPG_00_Core`, `PZRPG_10_...`). The game loads a context alphabetically; the
  prefix makes "Core first" a fact, not a coincidence. Leave gaps.
- **Namespace everything.** Lua globals are shared across *all* installed mods.
  Every global we define is `PZRPG` or `PZRPG_Prefixed`. No bare globals, ever.
- **`local` by default.** File-private helpers are `local function`.
- **No magic numbers.** Named `local` consts at the top, or a tuning table in one
  place (so values can move to sandbox options later without a hunt).
- **Guard clauses over nesting.** Bail early.
- **Model / view separation.** State lives on `PZRPG.*` / `getModData()`. Widgets
  read and render; they don't own domain state.
- **Defensive at the engine boundary.** Nil-check `getPlayer()`, perks, squares,
  any Java object that can be absent.
- **`PZRPG.log()` the transitions that matter** — level up, save migrated, panel
  opened — prefixed so `console.txt` tells a story. Not every line.
- **YAGNI / DRY / SRP.** No abstraction until the second real use.
- **Comments explain _why_,** matching the density of the surrounding code.

---

## 6. Hot-reload contract

`-debug` sessions can re-run every PZ RPG file live. For that to be safe, **every
file must be idempotent** — running it twice must not double anything.

- **Event handlers:** register with `PZRPG.hookEvent(eventName, key, fn)`. It
  removes the previously registered function for `key` before adding the new one.
  Never call `Events.X.Add` directly.
- **Keybindings:** the keybind file checks for an existing row before inserting.
- **Namespace / state:** `PZRPG = PZRPG or {}`, `PZRPG.state = PZRPG.state or {}`
  — keep existing state across the reload.
- **One-time side effects:** guard with a flag, `if not PZRPG.didX then ... end`.
- **HUD / windows:** teardown and rebuild on reload; don't rely on a live
  instance surviving.

If a change can't be made reload-safe (new `mod.info`, new keybind, sandbox
option, load-order change), that's fine — it needs a real restart. Note it in the
commit.

---

## 7. Lessons carried in from *A Little Help*

- **B42 local-mod discovery:** payload must be under `common/` with
  `common/mod.info`; a flat `media/` is invisible for local (non-Workshop) mods.
- **`mod.info` must be CRLF** or PZ's line parser produces no `id`.
- **`_NN_` load-order prefixes** — the file that owns the namespace loads first;
  everything else calls into it at load time.
- **`hookEvent` wrapper** for reload-safe event registration.
- **Never let `ISLayoutManager` manage a window's visibility** if you drive its
  open/close yourself — it restores a stale `visible=false`.
- **`-debug` "Break On Error"** halts on *caught* errors too; a `pcall` isn't
  enough to keep the debugger quiet — avoid the throw.
- Disassemble `projectzomboid.jar` with `javap` (full JDK at
  `C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot\bin`) when an API name is
  uncertain — B41 tutorials are often wrong for B42.
