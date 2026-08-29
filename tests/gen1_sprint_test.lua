-- Standalone:
--   luajit mods/gen1_sprint/tests/gen1_sprint_test.lua
-- from a Gen1Recomp checkout with this mod under mods/gen1_sprint.
--
-- Two tiers: the wrapper is unit-driven with a fake options reader and a
-- fake pad, and the whole mod is then loaded through the real headless
-- loader so the manifest, the schema and the hook wiring are asserted the
-- way the game would see them.  No ROM is needed -- the loader merges into
-- the fixture dataset.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")

local script = (arg and arg[0]) or ""
local MOD_DIR = script:match("^(.*)/tests/[^/]+%.lua$") or "mods/gen1_sprint"

local Options = dofile(MOD_DIR .. "/src/options.lua")
local Sprint = dofile(MOD_DIR .. "/src/sprint.lua")

-- The numbers the whole mod is about: what the engine walks at, what
-- FireRed's running shoes turn that into, what Gen 1's bicycle rides at
-- (the same 8), and where the shipped BIKE SPEED puts it.
local WALK, RUN = 16, 8
local BIKE, FAST_BIKE = 8, 4

-- an options reader over a plain table, falling back to the shipped default
local function reader(overrides)
  overrides = overrides or {}
  local defaults = {}
  for _, row in ipairs(Options.schema) do defaults[row.key] = row.default end
  return function(key)
    local value = overrides[key]
    if value == nil then return defaults[key] end
    return value
  end
end

-- a pad holding exactly the buttons named
local function pad(...)
  local held = {}
  for _, btn in ipairs({ ... }) do held[btn] = true end
  return { isDown = function(_, btn) return held[btn] or false end }
end

-- Drive the wrapper the way Player:stepLength does, and report both the
-- frame count it settled on and the ctx the next link was handed.
local function drive(overrides, frames, ctx, world)
  local opt = reader(overrides)
  local wrapper = Sprint.newWrapper(function()
    return Sprint.snapshot(opt, Options.MULTIPLIERS)
  end, world)
  local sawCtx, calls = nil, 0
  local got = wrapper(function(value, forwarded)
    calls = calls + 1
    sawCtx = forwarded
    return value
  end, frames, ctx)
  return got, sawCtx, calls
end

-- ------- the schema itself

do
  local seen = {}
  for _, row in ipairs(Options.schema) do
    T.check(type(row.key) == "string" and row.key ~= "", "every row has a key")
    T.check(not seen[row.key], "row key " .. tostring(row.key) .. " is unique")
    seen[row.key] = true
    T.check(row.type == "toggle" or row.type == "choice"
      or row.type == "number" or row.type == "text",
      row.key .. " uses a renderable row type")
    if row.type == "choice" then
      local legal = false
      for _, choice in ipairs(row.choices) do
        T.check(type(choice[1]) == "string", row.key .. " choice has a label")
        if choice[2] == row.default then legal = true end
      end
      T.check(legal, row.key .. "'s default is one of its own choices")
    end
    if row.visible_if then
      T.check(seen[row.visible_if.key] ~= nil,
        row.key .. "'s visible_if names a row declared before it")
    end
  end
  T.check(seen.enabled, "the sprint has an on/off row")
  T.check(seen.button, "and a row naming the button")
end

do -- every SPRINT SPEED choice resolves to a real multiplier
  local speed
  for _, row in ipairs(Options.schema) do
    if row.key == "speed" then speed = row end
  end
  for _, choice in ipairs(speed.choices) do
    T.check(type(Options.MULTIPLIERS[choice[2]]) == "number",
      choice[1] .. " is a multiplier the wrapper understands")
  end
end

-- ------- the sprint, held and not held

do -- the headline: hold B and a 16-frame walk becomes an 8-frame run
  T.eq(drive(nil, WALK, { input = pad("b") }), RUN,
    "holding B runs at FireRed's running-shoes speed")
end

do -- and nothing changes when it is not held
  T.eq(drive(nil, WALK, { input = pad() }), WALK,
    "an empty pad walks at the vanilla 16 frames")
  T.eq(drive(nil, WALK, { input = pad("a", "start") }), WALK,
    "other buttons are not the sprint button")
end

do -- SELECT is the alternative binding, and it is exclusive
  T.eq(drive({ button = "select" }, WALK, { input = pad("select") }), RUN,
    "SELECT sprints once it is the bound button")
  T.eq(drive({ button = "select" }, WALK, { input = pad("b") }), WALK,
    "and B goes back to doing nothing when SELECT is bound")
end

do -- the other two speeds
  T.eq(drive({ speed = "1_5" }, WALK, { input = pad("b") }), 10,
    "1.5x is 10 frames a tile")
  T.eq(drive({ speed = "3" }, WALK, { input = pad("b") }), 5,
    "3x is 5 frames a tile")
end

do -- a step can never reach zero frames, however the rows are set
  T.eq(drive({ speed = "3", bike = true }, 1, { input = pad("b"), onBike = true }), 1,
    "one frame per tile is the floor")
end

-- ------- where the sprint stands down

do -- surfing: off out of the box, and a row away
  T.eq(drive(nil, WALK, { input = pad("b"), surfing = true }), WALK,
    "surfing keeps vanilla speed by default")
  T.eq(drive({ surf = true }, WALK, { input = pad("b"), surfing = true }), RUN,
    "SPRINT SURFING: ON applies the same multiplier on water")
end

do -- the bike: SPRINT ON BIKE is still off out of the box, so holding the
   -- button adds nothing on top of whatever BIKE SPEED already did
  T.eq(drive({ bike_speed = "1" }, BIKE, { input = pad("b"), onBike = true }),
    BIKE, "with BIKE SPEED: VANILLA a held button adds nothing on the bike")
  T.eq(drive({ bike_speed = "1", bike = true }, BIKE,
    { input = pad("b"), onBike = true }), 4,
    "SPRINT ON BIKE: ON halves the vanilla bike")
end

-- ------- BIKE SPEED, which is not a sprint row

do -- the shipped default: the bicycle is faster with nothing held at all
  T.eq(drive(nil, BIKE, { input = pad(), onBike = true }), FAST_BIKE,
    "out of the box the bicycle rides at 4 frames a tile, held or not")
  T.eq(drive(nil, BIKE, { input = pad(), onBike = true }),
    drive(nil, BIKE, { input = pad("b"), onBike = true }),
    "and holding the sprint button changes nothing while SPRINT ON BIKE is off")
end

do -- the ladder the default restores
  T.eq(drive(nil, WALK, { input = pad() }), WALK, "walking is 16")
  T.eq(drive(nil, WALK, { input = pad("b") }), RUN, "sprinting is 8")
  T.eq(drive(nil, BIKE, { input = pad(), onBike = true }), FAST_BIKE,
    "riding is 4 -- each rung twice the one before it")
end

do -- VANILLA puts Gen 1's bicycle back exactly
  T.eq(drive({ bike_speed = "1" }, BIKE, { input = pad(), onBike = true }), BIKE,
    "BIKE SPEED: VANILLA is the engine's own 8, untouched")
end

do -- the other rungs
  T.eq(drive({ bike_speed = "1_5" }, BIKE, { input = pad(), onBike = true }), 5,
    "1.5x on the bike is 5 frames a tile")
  T.eq(drive({ bike_speed = "3" }, BIKE, { input = pad(), onBike = true }), 2,
    "3x is 2")
end

do -- it is the BICYCLE's row and nothing else's
  T.eq(drive(nil, WALK, { input = pad() }), WALK,
    "BIKE SPEED leaves walking alone")
  T.eq(drive(nil, WALK, { input = pad(), surfing = true }), WALK,
    "and surfing")
end

do -- BIKE SPEED works with the sprint switched off entirely
  T.eq(drive({ enabled = false }, BIKE, { input = pad(), onBike = true }),
    FAST_BIKE, "the bicycle is still faster with SPRINT: OFF")
  T.eq(drive({ enabled = false }, WALK, { input = pad("b") }), WALK,
    "and the button does nothing on foot with SPRINT: OFF")
end

do -- both rows stacking, which is opt-in on top of a default
  T.eq(drive({ bike = true }, BIKE, { input = pad("b"), onBike = true }), 2,
    "SPRINT ON BIKE stacks on the faster bike: 8 -> 4 -> 2")
  T.eq(drive({ bike = true, bike_speed = "1_5", speed = "1_5" }, BIKE,
    { input = pad("b"), onBike = true }), 3, "1.5x under 1.5x on an 8 is 3")

  -- Floored once at the end, not after each divide.  Of every bike/sprint
  -- pair the mod can be set to, this is the ONE that tells the two rules
  -- apart: 16/2.25 is 7.11 and floors to 7, while rounding as it goes gives
  -- floor(16/1.5) = 10 and then floor(10/1.5) = 6.  A step is not handed in
  -- at 16 on the bicycle by this engine, but the hook takes whatever it is
  -- given -- Gen 2's slopes and any mod that has already moved the bike both
  -- reach it -- so the arithmetic is pinned here rather than assumed.
  T.eq(drive({ bike = true, bike_speed = "1_5", speed = "1_5" }, 16,
    { input = pad("b"), onBike = true }), 7,
    "compounding roundings would give 6 here; flooring once gives 7")
end

do -- everything inert is a genuine no-op
  T.eq(drive({ enabled = false, bike_speed = "1" }, BIKE,
    { input = pad("b"), onBike = true }), BIKE, "all off changes nothing")
end

do -- mid-ledge-hop, exactly where vanilla refuses the bike's speedup
  local ctx = { input = pad("b"), player = { ledgeHop = true } }
  T.eq(drive(nil, WALK, ctx), WALK, "a ledge hop is never shortened")
  T.eq(drive({ bike = true }, BIKE, { input = pad("b"), onBike = true,
    player = { ledgeHop = true } }), BIKE, "not on the bike either")
  -- BIKE SPEED is unconditional everywhere else, so this is the one gate it
  -- has to honour too -- and the one a restructure would quietly drop
  T.eq(drive(nil, BIKE, { input = pad(), onBike = true,
    player = { ledgeHop = true } }), BIKE,
    "and BIKE SPEED does not shorten a hop either, with nothing held")
end

-- ------- chain manners

do -- ctx reaches the next link on every path, changed or not
  local ctx = { input = pad("b") }
  local _, forwarded = drive(nil, WALK, ctx)
  T.eq(forwarded, ctx, "a sprinting step forwards the engine's own ctx")

  local idle = { input = pad() }
  local _, alsoForwarded = drive(nil, WALK, idle)
  T.eq(alsoForwarded, idle, "a walking step forwards it too")
end

do -- vanilla runs exactly once per call on every path
  local _, _, calls = drive(nil, WALK, { input = pad("b") })
  T.eq(calls, 1, "the sprinting path calls next() once")
  local _, _, idleCalls = drive(nil, WALK, { input = pad() })
  T.eq(idleCalls, 1, "and so does the untouched path")
end

do -- a ctx the mod does not recognise is passed through untouched
  local got, forwarded = drive(nil, WALK, "not a table")
  T.eq(got, WALK, "a non-table ctx reaches vanilla unchanged")
  T.eq(forwarded, "not a table", "and is forwarded as it arrived")
  T.eq(drive(nil, WALK, { }), WALK, "a ctx with no input is left alone")
  T.eq(drive(nil, "not a number", { input = pad("b") }), "not a number",
    "so is a frame count that is not a number")
end

do -- a garbage stored value falls back to the shipped default
  T.eq(drive({ speed = "banana" }, WALK, { input = pad("b") }), RUN,
    "an unknown SPRINT SPEED still runs at 2x")
end

-- ------- the whole mod through the real loader

local run = T.sdk.loadMod(MOD_DIR)
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local loader = run.loader
T.eq(run.mod.manifest.id, "gen1_sprint", "the manifest id is the mod id")

local schema = loader.optionSchemas.gen1_sprint
T.check(type(schema) == "table" and #schema == #Options.schema,
  "the entry chunk defined the option schema")

-- the sprint really is on the live bus.  Driven through the loader's own
-- hook bus rather than src.mods.Runtime, so this suite needs no engine
-- require -- and the shipped mod needs no permissions at all.
local function ask(frames, ctx)
  return loader.hooks:call(Sprint.HOOK, function(value) return value end,
    frames, ctx)
end

do
  T.eq(ask(WALK, { input = pad("b") }), RUN,
    "the loaded mod runs when B is held")
  T.eq(ask(WALK, { input = pad() }), WALK,
    "and walks when it is not")
end

-- set one stored option and tell the mod, the way the manager does
local function setOption(key, value)
  loader.modOptions = loader.modOptions or {}
  loader.modOptions.gen1_sprint = loader.modOptions.gen1_sprint or {}
  loader.modOptions.gen1_sprint[key] = value
  loader.events:emit("mod.options_changed",
    { mod = "gen1_sprint", key = key, value = value })
end

local function chainLength()
  local chain = loader.hooks.chains[Sprint.HOOK]
  return chain and #chain or 0
end

do -- the loaded mod rides faster out of the box, with nothing held
  T.eq(ask(BIKE, { input = pad(), onBike = true }), FAST_BIKE,
    "the loaded mod puts the bicycle at 4 frames a tile")
end

do -- SPRINT: OFF alone does NOT leave the chain any more: BIKE SPEED still
   -- has something to say, and dropping the link would silently take the
   -- shipped default with it
  setOption("enabled", false)
  T.check(chainLength() > 0,
    "SPRINT: OFF keeps the link while BIKE SPEED is non-vanilla")
  T.eq(ask(WALK, { input = pad("b") }), WALK, "B does nothing on foot")
  T.eq(ask(BIKE, { input = pad(), onBike = true }), FAST_BIKE,
    "but the bicycle is still faster")

  -- both inert is what empties the chain now
  setOption("bike_speed", "1")
  T.eq(chainLength(), 0,
    "both rows inert unsubscribes rather than short-circuiting")
  T.eq(ask(BIKE, { input = pad(), onBike = true }), BIKE,
    "and the bicycle is the engine's own 8 again")

  -- BIKE SPEED alone is enough to bring the link back, with SPRINT still off
  setOption("bike_speed", "2")
  T.check(chainLength() > 0, "BIKE SPEED alone re-subscribes")
  T.eq(ask(BIKE, { input = pad(), onBike = true }), FAST_BIKE,
    "and rides fast again with SPRINT still off")

  setOption("enabled", true)
  T.eq(ask(WALK, { input = pad("b") }), RUN, "switching SPRINT back on re-arms it")
end

do -- a changed row is picked up without a reboot
  setOption("speed", "3")
  T.eq(ask(WALK, { input = pad("b") }), 5, "the new SPRINT SPEED took effect live")

  -- and another mod's broadcast does not disturb this one
  loader.modOptions.gen1_sprint.speed = "2"
  loader.events:emit("mod.options_changed", { mod = "somebody_else", key = "x" })
  T.eq(ask(WALK, { input = pad("b") }), 5,
    "another mod's change does not re-read our rows")
  loader.events:emit("mod.options_changed", { mod = "gen1_sprint", key = "speed" })
  T.eq(ask(WALK, { input = pad("b") }), RUN, "ours does")
end

do -- the exports neighbouring mods get
  local sprint = loader.exports.gen1_sprint and loader.exports.gen1_sprint.sprint
  T.check(type(sprint) == "table", "the mod publishes a sprint export")
  T.eq(sprint.active({ input = pad("b") }), true, "active() sees the held button")
  T.eq(sprint.active({ input = pad() }), false, "and an empty pad")
  T.eq(sprint.settings().mult, 2, "settings() reports the live multiplier")
  T.eq(sprint.settings().bikeMult, 2, "and the bicycle's")
  T.eq(sprint.stepFrames(WALK, { input = pad("b") }), RUN,
    "stepFrames() answers what a step would become")
end

-- ------- a script walking you is not you walking
--
-- The engine drives a cutscene walk through scriptMoves and asks stepLength
-- for its duration exactly as it does for a real step, so a held B used to
-- shorten those too.  That desynchronised the Oak escort, which pins his walk
-- to the player's live speed once and then drives the pair off the player's
-- completion: Oak could be left running at double the speed the player was
-- actually walking, finishing each step early and standing waiting for them.

do
  local function worldWith(moves)
    return { overworld = function() return { scriptMoves = moves } end }
  end

  local player = {}
  local ctx = { player = player, input = pad("b"), onBike = false }
  local sprinting = { enabled = true, button = "b", speed = "2" }

  T.eq(drive(sprinting, 16, ctx, worldWith({})), 8,
    "with nothing scripted, a held B still sprints")
  T.eq(drive(sprinting, 16, ctx, worldWith({ { entity = {} } })), 8,
    "an NPC's scripted move is not the player's")
  T.eq(drive(sprinting, 16, ctx, worldWith({ { entity = player } })), 16,
    "a script walking the PLAYER refuses the sprint")

  local _, sawCtx = drive(sprinting, 16, ctx, worldWith({ { entity = player } }))
  T.eq(sawCtx, ctx, "and the next link is still handed the context")

  T.eq(drive(sprinting, 16, ctx, nil), 8,
    "no world to ask: sprint applies as before")
  T.eq(drive(sprinting, 16, ctx, { overworld = function() return nil end }), 8,
    "no overworld up: sprint applies as before")
  T.eq(drive(sprinting, 16, ctx, { overworld = function() error("boom") end }), 8,
    "a world that throws is survived, not propagated")
end

run.release()
T.finish("gen1_sprint")
