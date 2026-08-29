# Changelog

All notable changes to Gen1Sprint are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this mod uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-08-29

### Fixed
- **Professor Oak no longer hops his way to the lab.** Sprinting applied to
  cutscene walking as well as your own, because the engine drives a scripted
  walk through `scriptMoves` and asks `stepLength` for its duration exactly as
  it does for a real step. A held sprint button shortened those too.

  That was not only unfaithful, it desynchronised the one cutscene that reads
  your live speed. `story2.lua`'s Oak escort pins his walk to yours **once**,
  at the top — `oak.stepFrames = ow.player.stepFramesCur` — and then drives the
  pair off *your* completion. So Oak could be left running at double the speed
  you were actually walking: he finished each step in half the time and then
  stood waiting for you. Step, pause, step, pause, the whole way to the lab.

  A step a script is walking you through is now the game's speed, never yours.
  Only the **player's** own scripted moves count — an NPC walking elsewhere on
  the map is not this — and with no overworld to ask (title screen, battle, a
  test stub) the answer is simply "not scripted", so nothing else changes.

## [0.2.0] - 2026-08-26

### Added

- **`BIKE SPEED`**, a row of its own: the BICYCLE rides at **4 frames per
  tile** instead of 8. `VANILLA` / `1.5x` / `2x` / `3x`, and it applies with
  nothing held — it is not a sprint modifier.

### Changed

- **`BIKE SPEED` ships at `2x`, so an update makes your bicycle faster
  without being asked.** It is the one row in this mod whose default departs
  from vanilla rather than preserving it, and the reason is that Gen 1's
  bicycle is 8 frames per tile — exactly what a 2x sprint already gives you
  on foot. With the sprint installed and the bike left alone, riding was no
  longer a faster way to travel than walking-with-B. 2x restores the ladder:
  16 walking, 8 sprinting, 4 riding. `BIKE SPEED: VANILLA` puts Gen 1's 8
  back exactly.
- The hook now stays subscribed when `SPRINT` is off but `BIKE SPEED` is not
  `VANILLA`. Previously `SPRINT: OFF` always left the chain; doing that now
  would silently take the bicycle's speed with it. Both rows inert is what
  empties the chain, and that is still a genuine no-op.
- `SPRINT SPEED`'s choices are listed in ascending order (`1.5x` / `2x` /
  `3x`) to match the new row. Stored values are unchanged.

### Notes

- **This is a game-feel change, not a FireRed-parity one, and the difference
  is worth stating.** FireRed's bicycle is `MOVE_SPEED_FAST_1` — 8 frames per
  tile, the *same constant* its running shoes use — so in FireRed the two are
  genuinely the same speed, and the bike is the poorer deal: of 425 maps, 85
  allow running but not cycling and none allow cycling but not running. 4 is
  not FireRed's ordinary bike speed; it is FireRed's Cycling Road roll
  (`MOVE_SPEED_FASTER`), borrowed because it is the speed that game does
  reach on a bicycle.
- A step already under way keeps the duration it started with, and a ledge
  hop is still never shortened — by either row.

## [0.1.0] - 2026-08-25

### Added

- **Hold B to run.** A step in the overworld drops from 16 frames per tile to
  8 while the button is held — FireRed's running-shoes speed, and the speed
  this engine's own BICYCLE already rides at. Nothing gates it: no item, no
  flag, no NPC to talk to.
- Rows under **MODS → Gen1Sprint → OPTIONS**: `SPRINT` (on/off), `HOLD`
  (`B` / `SELECT`), `SPRINT SPEED` (`2x` / `1.5x` / `3x`), `SPRINT SURFING`
  and `SPRINT ON BIKE`. The last two default off, which leaves surfing and
  cycling at exactly their vanilla speeds.
- A `sprint` export — `active(game)`, `settings()` and
  `stepFrames(frames, ctx)` — for a neighbouring mod that wants to know when
  the player is running.
- A ROM-free headless test suite, and CI that runs `modkit validate`, `lint`,
  `gen2check` and the suite on every push.

### Notes

- Implemented as a single link on the engine's `movement.speed` hook, which
  exists for this and names running shoes in its own comment. The hook is a
  cold path — the engine calls it once per *step*, from `Player:tryMove`, not
  once per frame — and the link allocates nothing, so the mod does not cost
  frames.
- `SPRINT: OFF` unsubscribes the link rather than short-circuiting inside it.
  The engine guards its call site with `Runtime.wantsHook("movement.speed")`
  and only builds a context table when a mod is listening, so switched off the
  mod costs what it costs uninstalled.
- Requests no permissions, and runs on Red, Blue, Yellow, Gold, Silver and
  Crystal: `movement.speed` carries the same name and the same context keys on
  both generations, so there is no per-game branch in the mod at all.

[Unreleased]: https://github.com/wild1walker/Gen1Sprint/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/wild1walker/Gen1Sprint/releases/tag/v0.2.0
[0.1.0]: https://github.com/wild1walker/Gen1Sprint/releases/tag/v0.1.0
