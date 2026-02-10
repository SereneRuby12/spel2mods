local enemieslib = require "enemies"
local choice_entlib = require "choice_entity"
local inputs = 0

set_callback(function ()
  if state.screen ~= SCREEN.TRANSITION then return end
  for _, player in ipairs(get_local_players()) do
    if player.cutscene then
      player:clear_cutscene()
      player:set_pre_process_input(function (self)
        player.input.buttons = inputs
        player.input.buttons_gameplay = inputs
      end)
    end
  end
end, ON.GAMEFRAME)

local GAME_PROPS_INPUT = {
  JUMP = 1,
  BOMB = 1 << 1,
  WHIP = 1 << 2,
  ROPE = 1 << 3,
  DOOR = 1 << 5,
  RUN = 1 << 7,
  LEFT = 1 << 16,
  RIGHT = 1 << 17,
  UP = 1 << 18,
  DOWN = 1 << 19,
}

local GAME_PROPS_TO_INPUTS = {
  [GAME_PROPS_INPUT.JUMP]  = INPUTS.JUMP,
  [GAME_PROPS_INPUT.BOMB]  = INPUTS.BOMB,
  [GAME_PROPS_INPUT.WHIP]  = INPUTS.WHIP,
  [GAME_PROPS_INPUT.ROPE]  = INPUTS.ROPE,
  [GAME_PROPS_INPUT.DOOR]  = INPUTS.DOOR,
  [GAME_PROPS_INPUT.RUN]   = INPUTS.RUN,
  [GAME_PROPS_INPUT.LEFT]  = INPUTS.LEFT,
  [GAME_PROPS_INPUT.RIGHT] = INPUTS.RIGHT,
  [GAME_PROPS_INPUT.UP]    = INPUTS.UP,
  [GAME_PROPS_INPUT.DOWN]  = INPUTS.DOWN,
}

set_callback(function ()
  if state.screen ~= SCREEN.TRANSITION then return end
  local new_inputs = 0
  local gprops_inputs = game_manager.game_props.input[1]
  for game_prop_bit, inputs_bit in pairs(GAME_PROPS_TO_INPUTS) do
    if gprops_inputs & game_prop_bit ~= 0 then
      new_inputs = new_inputs | inputs_bit
    end
  end
  if state.player_inputs.player_settings[1].auto_run_enabled then new_inputs = INPUTS.RUN ~ new_inputs end
  inputs = new_inputs
  game_manager.game_props.input[1] = 0
end, ON.POST_PROCESS_INPUT)

local function add_enemy_to_run(enemy_idx)
  for i, run_enemy in ipairs(ModState.run_enemies) do
    if run_enemy.enemy_idx == enemy_idx then
      run_enemy.number = run_enemy.number + 1
      return
    end
  end
  ModState.run_enemies[#ModState.run_enemies+1] = {
    enemy_idx = enemy_idx,
    number = 1,
  }
end

set_callback(function ()
  if state.screen ~= SCREEN.TRANSITION then return end
  if test_flag(state.quest_flags, QUEST_FLAG.RESET) then
    ModState.run_enemies = {}
  end

  local gotten_choices = {}
  for x = -1, 1 do
    local enemy_idx = enemieslib.get_enemy_choice(gotten_choices)
    choice_entlib.spawn_choice(14+(x*1.5), 112, LAYER.FRONT, Enemies[enemy_idx].icon_texture, 0, function ()
      add_enemy_to_run(enemy_idx)
      state.theme_info:post_transition()
    end)
    gotten_choices[#gotten_choices+1] = enemy_idx
  end
end, ON.POST_LEVEL_GENERATION)

-- Code to force transition on the first level

local is_custom_transition = false

local function pre_spawn_level (themeinfo)
  if not is_custom_transition then return end
  themeinfo:spawn_transition()
  state.screen = SCREEN.TRANSITION
  state.level_gen.spawn_x = 11.0
  return true
end
local function pre_spawn_players(themeinfo)
  if not is_custom_transition then return end
  state.camera.focused_entity_uid = -1
  state.camera.focus_x, state.camera.focus_y = 14, 115.5
  state.camera.adjusted_focus_x, state.camera.adjusted_focus_y = 14, 115.5
  state.camera.bounds_left = 2.5
  state.camera.bounds_top = 122.5
  state.camera.bounds_right = 25.5
  state.camera.bounds_bottom = 108.5
  return true
end

for i, theme_info in pairs(state.level_gen.themes) do
  theme_info:set_pre_spawn_level(pre_spawn_level)
  theme_info:set_pre_spawn_players(pre_spawn_players)
end

set_callback(function(ctx)
  if not (test_flag(state.quest_flags, QUEST_FLAG.RESET) and state.screen == SCREEN.LEVEL) then
    is_custom_transition = false
    return
  end
  is_custom_transition = true
  ctx:override_level_files({})
end, ON.PRE_LOAD_LEVEL_FILES)
