---@class ModState
---@field run_enemies {enemy_idx: integer, number: integer}[]
---@field run_curses integer[]
ModState = {
  run_enemies = {},
  run_curses = {},
}

local enemieslib = require "enemies"
local lobbylib = require "lobby"

set_callback(function ()
  if state.screen ~= SCREEN.LEVEL or test_flag(state.quest_flags, QUEST_FLAG.RESET) then return end
  for _, run_enemy in ipairs(ModState.run_enemies) do
    enemieslib.spawn_enemy(run_enemy.enemy_idx, run_enemy.number)
  end
  -- local uid = babylib.spawn_baby(state.level_gen.spawn_x, state.level_gen.spawn_y + 3, LAYER.FRONT)
  -- babylib.spawn_baby(state.level_gen.spawn_x, state.level_gen.spawn_y + 4, LAYER.FRONT, true)
  -- telefraggerlib.spawn_telefragger(state.level_gen.spawn_x+2, state.level_gen.spawn_y + 4, LAYER.FRONT)
  -- icbmlib.spawn_icbm(state.level_gen.spawn_x-2, state.level_gen.spawn_y + 4, LAYER.FRONT)
  -- spawn_random(babylib.spawn_baby, 2, true)
  -- spawn_random(telefraggerlib.spawn_telefragger, 3)
  -- spawn_random(icbmlib.spawn_icbm, 3)
  -- spawn_random(babylib.spawn_baby, 3)
  -- dozerlib.spawn_dozer()
  -- doombringerlib.spawn_doombringer()
  -- voidbreakerlib.spawn_voidbreaker(3)
  -- spawn_random(belllib.spawn_bell, 2)
end, ON.POST_LEVEL_GENERATION)
