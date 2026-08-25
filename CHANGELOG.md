# Changelog

All notable changes to Gen1Sprint are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this mod uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/wild1walker/Gen1Sprint/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/wild1walker/Gen1Sprint/releases/tag/v0.1.0
