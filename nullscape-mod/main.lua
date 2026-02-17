require "mod_state"

require "curses"
local enemieslib = require "enemies"
local lobbylib = require "lobby"

set_callback(function ()
  if test_flag(state.quest_flags, QUEST_FLAG.RESET) and (state.screen == SCREEN.LEVEL or state.screen == SCREEN.TRANSITION) then
    ModState.run_enemies = {}
    ModState.run_curses = {}
  end

  if state.screen ~= SCREEN.LEVEL or test_flag(state.quest_flags, QUEST_FLAG.RESET) then return end
  for _, run_enemy in ipairs(ModState.run_enemies) do
    enemieslib.spawn_enemy(run_enemy.enemy_idx, run_enemy.number)
  end
end, ON.POST_LEVEL_GENERATION)
