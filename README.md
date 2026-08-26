<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/banner.png" alt="Gen1Wild" width="400"></a>
</p>

<h1 align="center">Gen1Sprint</h1>

<p align="center">
  <a href="https://wild1walker.github.io/Gen1Wild/"><img src="docs/lineup.png" alt="Check out my other mods!" width="880"></a>
</p>

Hold **B** to run, for [Gen1Recomp](https://github.com/bryanthaboi/gen1recomp).
The same speed FireRed's running shoes give you: twice walking pace.

Works on Red, Blue, Yellow and Gold/Silver (mod api 2). It requests no
permissions, adds no item to find and no flag to set — the ability is just
there from the first step out of your bedroom. Every knob is a row in
**MODS → Gen1Sprint → OPTIONS**, including `SPRINT: OFF`, which puts the
original game back exactly.

## Install

1. Download `gen1_sprint-<version>.zip` from
   [Releases](https://github.com/wild1walker/Gen1Sprint/releases).
2. In the game: **MODS → Import mod .zip**, pick the file, enable Gen1Sprint.

The manifest already carries `"github": "wild1walker/Gen1Sprint"`, so the
launcher offers updates and other versions on its own.

## Hold B to run

Walking in Gen 1 is 16 frames per tile. FireRed's running shoes halve that to
8, and that is what holding B does here.

Eight frames per tile is not a number picked to feel right — it is a pace this
engine has drawn since the day it booted, because it is exactly what the
**BICYCLE** rides at (`bikeStepFrames = 8`, "the bicycle doubles walking
speed"). So the sprint is not a new motion the game has to learn: it is the
bike's motion, on foot, on a button.

Everything else about a step is untouched. Encounters still roll per step, so
running does not change how often you meet anything. Ledges, warps, collision,
Cycling Road, the boulder push, the turn-in-place delay — all vanilla. Your
follower keeps up on its own, because the engine already copies the player's
live step length onto it every step.

Nothing else in the overworld reads B, so nothing is being taken away: the only
two things that touch it are the Cycling Road brake and the Pikachu-emote skip,
and neither can be running while you are holding a direction. If you would
still rather keep B clear, `HOLD` moves the sprint to `SELECT`, which the
overworld reads nowhere at all.

| Row | Values | Default | What it does |
| --- | --- | --- | --- |
| `SPRINT` | on / off | on | `OFF` unsubscribes the hook — the untouched game, see below |
| `HOLD` | `B` / `SELECT` | `B` | which button to hold |
| `SPRINT SPEED` | `2x` / `1.5x` / `3x` | `2x` | `2x` is FireRed's running shoes, and the BICYCLE's own speed |
| `SPRINT SURFING` | on / off | off | apply it on water too |
| `SPRINT ON BIKE` | on / off | off | apply it *on top of* the bike, making 8 frames into 4 |

The two `off` rows are the FireRed answer: running shoes are a thing you do on
foot. Leave them alone and surfing and cycling are exactly the speeds they have
always been.

`SPRINT SPEED` is stored as a multiplier on the step the engine was about to
take, not as a frame count, so it composes: `2x` means 2x whatever you were
already doing, and a mod that changes walking speed keeps its ratio.

## It does not cost you frames

A movement mod is an easy place to make a game stutter, so this one is built to
sit on the engine's own seam rather than beside it.

Gen1Recomp already asks the question. `Player:stepLength` decides how long a
step lasts and then offers that number to mods through the `movement.speed`
hook, with the comment *"lets a mod multiply or replace that (running shoes,
dash, etc.)"* next to it. Running shoes is precisely what this is, so there is
nothing to patch, override, poll or re-implement — the mod just answers.

That seam is a cold path, which is the whole point:

- **Once per step, not once per frame.** `stepLength` is called from
  `tryMove` as a step *begins*. Walking, that is once every 16 frames;
  sprinting, once every 8. Four to eight calls a second while you are actually
  moving, and none at all while you stand still, sit in a menu, or fight a
  battle. Compare the alternative — checking the pad in an update handler —
  which is 60 calls a second forever.
- **Nothing allocates.** The link reads a settings table it already owns, runs
  one comparison per gate and one divide. The context table is the engine's,
  forwarded rather than copied. No garbage per step means nothing for the
  collector to come back for.
- **The options are read from a snapshot, not from disk.** The rows are
  flattened to four plain values once and rebuilt only when the manager
  broadcasts `mod.options_changed`. Changing a row takes effect on your next
  step; nothing polls in between.
- **`SPRINT: OFF` unsubscribes.** It does not return early inside the hook —
  it removes the link from the chain. The engine guards its call site with
  `Runtime.wantsHook("movement.speed")` and only builds the context table when
  some mod is listening, so with the chain empty the game is left doing one
  table lookup per step and nothing else. Switched off, this mod costs exactly
  what it costs uninstalled.

## Building and testing

From a Gen1Recomp checkout with this repo at `mods/gen1_sprint`:

```sh
python3 tools/modkit.py validate gen1_sprint       # manifest + real merge
python3 tools/modkit.py lint gen1_sprint           # no ROM-derived content
python3 tools/modkit.py gen2check mods/gen1_sprint
luajit mods/gen1_sprint/tests/gen1_sprint_test.lua
```

The suite is ROM-free: it merges into the engine's fixture dataset, so it runs
anywhere the engine checks out. It drives the wrapper directly for the speed
maths and the stand-down cases, then loads the whole mod through the real
headless loader and calls `movement.speed` on the live hook bus — including the
assertion that `SPRINT: OFF` really does leave the chain empty.
`.github/workflows/ci.yml` runs exactly those four commands on every push and
pull request.

For the 10-minute loop, run the engine with `POKEPORT_DEV=1 love .` and press
`F5` to hot-reload after an edit.

## Releasing

Releases are cut by CI. To ship a version:

1. Bump `version` in `manifest.json`.
2. Add the matching `## <version>` section to `CHANGELOG.md` (CI fails if the
   two disagree).
3. Merge to `main`.

`.github/workflows/release.yml` then runs CI, resolves the version, packs every
mod file into `gen1_sprint-<version>.zip` with `manifest.json` at the archive
root, and publishes a GitHub Release with the zip and a `sha256sums.txt`.
Version resolution, first rule that applies:

1. the `version` input of a manual **Run workflow**,
2. `[release X.Y.Z]` anywhere in the commit message,
3. `manifest.json`'s own version, when it is ahead of every existing tag.

If none of the three apply — a push that changes code or artwork but not the
version — the run stops after CI and publishes nothing, noting so in the run
summary. **A release is always a deliberate version bump.**

Whichever rule wins is written into the `manifest.json` inside the archive, so
a shipped mod never reports a different version than the release it came from.
An existing tag or release is never clobbered — the run fails instead.

## Credits

By **Wild**.

Built on the `movement.speed` seam of
[Pokemon Gen1Recomp](https://github.com/bryanthaboi/gen1recomp), which was put
there for this and says so, and on the [pret](https://github.com/pret)
disassembly of Pokemon Red, Blue and Yellow: `home/overworld.asm`'s
`DoBikeSpeedup` is where the 8-frame step and the mid-ledge-hop exception both
come from.

The idea is Game Freak's — running shoes are Ruby/Sapphire's, and FireRed is
where they landed in Kanto.

## Licence

MIT. See [LICENSE](LICENSE).
