local babylib = require "enemies.baby"
local telefraggerlib = require "enemies.telefragger"
local icbmlib = require "enemies.icbm"

set_callback(function ()
  local uid = babylib.spawn_baby(state.level_gen.spawn_x, state.level_gen.spawn_y + 3, LAYER.FRONT)
  local uid = telefraggerlib.spawn_telefragger(state.level_gen.spawn_x+2, state.level_gen.spawn_y + 4, LAYER.FRONT)
  local uid = icbmlib.spawn_icbm(state.level_gen.spawn_x-2, state.level_gen.spawn_y + 4, LAYER.FRONT)
end, ON.POST_LEVEL_GENERATION)

