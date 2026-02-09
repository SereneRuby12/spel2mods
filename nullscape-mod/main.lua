local babylib = require "enemies.baby"
local telefraggerlib = require "enemies.telefragger"
local icbmlib = require "enemies.icbm"

local function spawn_random(spawn_func, num, last_param)
  for i = 1, num do
    local off_x, off_y = (prng:random() * 6) - 3, (prng:random() * 1.5) + 3.5
    spawn_func(state.level_gen.spawn_x + off_x, state.level_gen.spawn_y + 4, LAYER.FRONT, last_param)
  end
end

set_callback(function ()
  -- local uid = babylib.spawn_baby(state.level_gen.spawn_x, state.level_gen.spawn_y + 3, LAYER.FRONT)
  -- babylib.spawn_baby(state.level_gen.spawn_x, state.level_gen.spawn_y + 4, LAYER.FRONT, true)
  -- telefraggerlib.spawn_telefragger(state.level_gen.spawn_x+2, state.level_gen.spawn_y + 4, LAYER.FRONT)
  -- icbmlib.spawn_icbm(state.level_gen.spawn_x-2, state.level_gen.spawn_y + 4, LAYER.FRONT)
  spawn_random(babylib.spawn_baby, 2, true)
  spawn_random(telefraggerlib.spawn_telefragger, 3)
  spawn_random(icbmlib.spawn_icbm, 3)
  spawn_random(babylib.spawn_baby, 3)
end, ON.POST_LEVEL_GENERATION)

