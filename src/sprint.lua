-- The whole mod: one link on the engine's `movement.speed` hook.
--
-- Gen1Recomp already has the seam this needs.  Player:stepLength picks the
-- duration of a step -- 16 frames walking, 8 on the BICYCLE -- and then
-- offers that number to mods before returning it, with the comment
-- "movement.speed lets a mod multiply or replace that (running shoes, dash,
-- etc.)".  Running shoes is exactly what this is, so there is nothing to
-- patch, override or re-implement: the mod answers a question the engine
-- was already asking.
--
-- WHY THIS DOES NOT COST FRAMES, since a speed mod is an easy place to make
-- the game stutter:
--
--   * stepLength is called once per STEP, from Player:tryMove as the step
--     begins -- never per frame.  Walking, that is once every 16 frames;
--     sprinting, once every 8.  Roughly four to eight calls a second while
--     the player is moving, and none at all while they stand still, sit in
--     a menu, or fight a battle.
--   * The call site is guarded by Runtime.wantsHook("movement.speed"), which
--     is one table lookup, and the ctx table is only built when some mod is
--     subscribed.  So SPRINT: OFF unsubscribes (see Sprint.install) instead
--     of returning early: with the chain empty the engine allocates nothing
--     and the mod switched off costs precisely what the mod uninstalled does.
--   * The link itself does a few table reads, one comparison per gate and
--     one divide.  It allocates nothing: the settings table is one this
--     closure already owns, and the ctx is the engine's, forwarded rather
--     than copied.
--
-- The follower comes along on its own -- PikachuFollower copies the player's
-- live stepFramesCur onto itself every step -- and the walk-cycle clock is
-- deliberately independent of step length in Player:update, so legs keep a
-- constant cadence and the sprint reads as covering more ground per stride
-- rather than as an animation played at double speed.  That is the same
-- thing the BICYCLE has always done here.

local Sprint = {}

Sprint.HOOK = "movement.speed"

-- The five option rows, flattened to the four plain values the hot path
-- reads.  Rebuilt only when mod.options_changed says something moved.
function Sprint.snapshot(opt, multipliers)
  return {
    button = opt("button"),
    mult = multipliers[opt("speed")] or 2,
    surf = opt("surf") and true or false,
    bike = opt("bike") and true or false,
  }
end

-- `read` is a zero-argument function returning the current snapshot.
function Sprint.newWrapper(read)
  return function(next, frames, ctx)
    -- Whatever this hands `next` REPLACES the argument list for the whole
    -- rest of the chain (src/mods/Hooks.lua nextFn), so ctx is passed along
    -- on every path including the ones that change nothing.  Returning
    -- `next(frames)` alone would hand the mod after this one a nil context.
    if type(frames) ~= "number" or type(ctx) ~= "table" then
      return next(frames, ctx)
    end

    local input = ctx.input
    if not input or not input.isDown then return next(frames, ctx) end

    local cfg = read()
    if not input:isDown(cfg.button) then return next(frames, ctx) end

    -- Where the sprint stands down.  Both rows default OFF, which is the
    -- FireRed answer: running shoes are a thing you do on foot, and an
    -- untouched install keeps vanilla surf and vanilla bike speeds.
    if ctx.surfing and not cfg.surf then return next(frames, ctx) end
    if ctx.onBike and not cfg.bike then return next(frames, ctx) end

    -- Mid-ledge-hop the engine already refuses the bike's speedup: pokered
    -- skips DoBikeSpeedup while BIT_LEDGE_OR_FISHING is set, and
    -- Player:stepLength ports that by forcing onBike false during a hop.
    -- The hop arc is drawn against the step's own progress, so shortening
    -- the step mid-air lands the sprite early and reads as a teleport.
    -- Stand down on exactly the frames vanilla does.
    local player = ctx.player
    if player and player.ledgeHop then return next(frames, ctx) end

    -- Fewer frames per tile is more speed: 16 -> 8 is FireRed's running
    -- shoes, and 8 is what this engine's BICYCLE already rides at.  A
    -- divisor rather than a frame count, so the ratio survives any other
    -- mod that has already changed the walk it is dividing.
    return next(math.max(1, math.floor(frames / cfg.mult)), ctx)
  end
end

-- Wire the link to the live game.  Returns the handle published as
-- mod.exports.sprint.
function Sprint.install(mod, opt, multipliers)
  local cached = nil
  local function read()
    if not cached then cached = Sprint.snapshot(opt, multipliers) end
    return cached
  end

  local wrapper = Sprint.newWrapper(read)
  local unwrap = nil

  -- SPRINT: OFF leaves the chain rather than short-circuiting inside it;
  -- see the note at the top of this file for why that is worth the eight
  -- lines.
  local function sync()
    cached = nil
    local on = opt("enabled") and true or false
    if on and not unwrap then
      unwrap = mod.hooks:wrap(Sprint.HOOK, wrapper)
    elseif not on and unwrap then
      unwrap()
      unwrap = nil
    end
  end

  sync()

  -- The manager writes an option and broadcasts; nothing polls.  A payload
  -- naming another mod is ignored, and one naming nothing at all is taken
  -- as "something changed", which is the safe reading.
  mod.events:on("mod.options_changed", function(ev)
    if type(ev) == "table" and ev.mod ~= nil and ev.mod ~= mod.id then return end
    sync()
  end)

  return {
    -- Is the sprint engaged right now?  For a neighbouring mod that wants
    -- to draw or sound something while the player is running.
    active = function(game)
      if not unwrap then return false end
      local input = game and game.input
      if not input or not input.isDown then return false end
      return input:isDown(read().button) and true or false
    end,
    -- The live settings, copied: a caller cannot reach in and edit them.
    settings = function()
      local cfg, out = read(), {}
      for key, value in pairs(cfg) do out[key] = value end
      return out
    end,
    -- What this mod would turn `frames` into for that ctx.  The suite drives
    -- it, and it is the honest answer to "how fast am I actually going".
    stepFrames = function(frames, ctx)
      local seen
      wrapper(function(value) seen = value end, frames, ctx)
      return seen
    end,
  }
end

return Sprint
