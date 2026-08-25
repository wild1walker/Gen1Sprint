-- Every Gen1Sprint behaviour is a row here, and every row ships with the
-- vanilla-preserving default spelled out next to it.  The schema is handed
-- to mod.options:define, which is what draws the rows in MODS > OPTIONS and
-- what the launcher's mod_option_schemas.json snapshot is built from
-- (docs/mod-option-schema.md).
--
-- Row shapes are the four the engine renders: toggle, choice, number, text.
-- `choices` are { label, value } pairs; `visible_if` only hides a menu row,
-- it never changes the stored value, so a hidden row still reads back the
-- value the player last chose.

local Options = {}

-- SPRINT SPEED is stored as a divisor on the step the engine was about to
-- take, not as a frame count, so it composes: a mod that slows walking down
-- keeps its ratio, and the same "2x" means 2x on foot and 2x on the bike.
--
-- 2x is the shipped default because that is what FireRed's running shoes
-- are -- 16 frames per tile walking, 8 running -- and 8 is also what
-- Gen 1's own BICYCLE rides at (src/world/FieldDefaults.lua bikeStepFrames),
-- so sprinting on foot lands on a speed the engine already animates cleanly.
Options.MULTIPLIERS = {
  ["1_5"] = 1.5,
  ["2"] = 2,
  ["3"] = 3,
}

Options.schema = {
  -- ------- the sprint itself

  { key = "enabled", type = "toggle", label = "SPRINT", default = true },

  -- B is free in the overworld: the only two things that read it there are
  -- the Cycling Road brake and the pikapic skip, and neither can be running
  -- while a direction is held (src/world/OverworldController.lua).  SELECT
  -- is read nowhere in the overworld at all, so it is offered for players
  -- who would rather keep B clear out of habit.
  { key = "button", type = "choice", label = "HOLD", default = "b",
    choices = {
      { "B", "b" },
      { "SELECT", "select" },
    },
    visible_if = { key = "enabled", equals = true } },

  { key = "speed", type = "choice", label = "SPRINT SPEED", default = "2",
    choices = {
      { "2x", "2" },
      { "1.5x", "1_5" },
      { "3x", "3" },
    },
    visible_if = { key = "enabled", equals = true } },

  -- ------- where it applies
  -- Both default OFF, which is the FireRed answer: running shoes are a
  -- thing you do on foot.  Vanilla surf and vanilla bike speeds are what an
  -- untouched row leaves you with.

  { key = "surf", type = "toggle", label = "SPRINT SURFING", default = false,
    visible_if = { key = "enabled", equals = true } },

  { key = "bike", type = "toggle", label = "SPRINT ON BIKE", default = false,
    visible_if = { key = "enabled", equals = true } },
}

-- key -> row, so the reader can fall back to a default and validate a choice
-- against the values the schema actually offers.
local byKey = {}
for _, row in ipairs(Options.schema) do byKey[row.key] = row end

local function legal(row, value)
  if row.type == "toggle" then return type(value) == "boolean" end
  if row.type == "number" then return type(value) == "number" end
  if row.type == "choice" then
    for _, choice in ipairs(row.choices) do
      if choice[2] == value then return true end
    end
    return false
  end
  return true
end

-- A reader rather than raw mod.options:get calls: a stored value can be
-- anything -- an older version's vocabulary, a hand-edited options.lua --
-- and a mod that divided a step length by a garbage string would be a
-- crash in the middle of the overworld.  Anything out of vocabulary falls
-- back to the row default, which is always the vanilla-preserving answer.
function Options.reader(mod)
  return function(key)
    local row = byKey[key]
    if not row then return nil end
    local value = mod.options:get(key)
    if value == nil or not legal(row, value) then return row.default end
    if row.type == "number" then
      if row.min then value = math.max(row.min, value) end
      if row.max then value = math.min(row.max, value) end
    end
    return value
  end
end

return Options
