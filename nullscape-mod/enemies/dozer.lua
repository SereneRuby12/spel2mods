local commonlib = require "common"

local clock_sound = create_sound("./enemies/sounds/Dozer_Clock.ogg") --[[@as CustomSound]]
local success_sound = create_sound("./enemies/sounds/Dozer_Success.ogg") --[[@as CustomSound]]

local eepy_texture
local wakey_texture
local creepy_texture
local icon_texture
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 1024, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.texture_path = "./enemies/assets/dozer_eepy.png"
  eepy_texture = define_texture(tdef)

  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.texture_path = "./enemies/assets/dozer_wakey.png"
  wakey_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/dozer_creepy.png"
  creepy_texture = define_texture(tdef)

  tdef.width, tdef.height = 500, 500
  tdef.tile_width, tdef.tile_height = 500, 500
  tdef.sub_image_width, tdef.sub_image_height = 0, 0
  tdef.texture_path = "./enemies/assets/icons/dozer.png"
  icon_texture = define_texture(tdef)
end

---@enum DOZER_STATE
local DOZER_STATE = {
  INVISIBLE = 1,
  SLEEPY = 2,
  WAKEY = 3,
}

---@class DozerInfo
---@field state DOZER_STATE
---@field timer integer
---@field player_quiet_time integer
---@field clock_sound PlayingSound?

local DOZER_WAKEY_TIME = math.floor(60 * 3.5)
local DOZER_DISAPPEAR_TIME = 25
local DOZER_GET_CREEPY_TIME = 40
local DOZER_ATTACK_TIME = 80
local DOZER_MIN_START_SHOW_TIME = 7 * 60
local DOZER_MAX_START_SHOW_TIME = 14 * 60
local DOZER_MIN_SHOW_TIME = 20 * 60
local DOZER_MAX_SHOW_TIME = 40 * 60

---@type {[integer]: DozerInfo}
local target_player_info = {}
local dozer_in_level = false
local color = Color:new(1, 1, 1, 0.5)

---@param render VanillaRenderContext
set_callback(function (render)
  if not dozer_in_level then return end
  for uid, info in pairs(target_player_info) do
    if info.state ~= DOZER_STATE.INVISIBLE then
      local texture = eepy_texture
      if info.state == DOZER_STATE.WAKEY then
        texture = info.timer <= DOZER_GET_CREEPY_TIME and creepy_texture or wakey_texture
      end
      local aabb = AABB:new(-0.2, 0.2 * (16/9), 0.2, -0.2 * (16/9))
      render:draw_screen_texture(texture, 0, math.floor(info.timer / 8), aabb, color)
    end
  end
end, ON.RENDER_PRE_HUD)

set_callback(function ()
  if not dozer_in_level then return end
  for i, player in ipairs(get_local_players()) do
    if not target_player_info[player.uid] then
      target_player_info[player.uid] = {
        state = DOZER_STATE.INVISIBLE,
        timer = prng:random(DOZER_MIN_START_SHOW_TIME, DOZER_MAX_START_SHOW_TIME),
        player_quiet_time = 0,
      }
    end
    local info = target_player_info[player.uid]
    if info.state == DOZER_STATE.INVISIBLE and info.timer == 0 then
      info.state = DOZER_STATE.SLEEPY
      info.timer = DOZER_WAKEY_TIME
      info.player_quiet_time = 0
      info.clock_sound = clock_sound:play()
      info.clock_sound:set_volume(commonlib.SOUND_VOLUME)
    elseif info.state == DOZER_STATE.SLEEPY then
      if player.input.buttons_gameplay & (INPUTS.LEFT | INPUTS.RIGHT | INPUTS.UP | INPUTS.DOWN | INPUTS.WHIP) == 0 then
        info.player_quiet_time = info.player_quiet_time + 1
      else
        info.player_quiet_time = math.max(info.player_quiet_time - 1, 0)
      end
      if info.player_quiet_time >= DOZER_DISAPPEAR_TIME then
        info.state = DOZER_STATE.INVISIBLE
        info.timer = prng:random(DOZER_MIN_SHOW_TIME, DOZER_MAX_SHOW_TIME)
        info.clock_sound:stop()
        local snd = success_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
      elseif info.timer <= 0 then
        info.state = DOZER_STATE.WAKEY
        info.timer = DOZER_ATTACK_TIME
        info.clock_sound:stop()
      end
    elseif info.state == DOZER_STATE.WAKEY then
      if info.timer <= 0 and player.exit_invincibility_timer == 0 and not test_flag(player.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING) then
        player:damage(nil, 1, 0, Vec2:new(.0, 0.1), 0, 0, 60, false)
        info.state = DOZER_STATE.INVISIBLE
        info.timer = prng:random(DOZER_MIN_SHOW_TIME, DOZER_MAX_SHOW_TIME)
      end
    end
    info.timer = info.timer - 1
  end
end, ON.GAMEFRAME)

set_callback(function ()
  dozer_in_level = false
  for uid, info in pairs(target_player_info) do
    if info.clock_sound then
      info.clock_sound:stop()
    end
  end
  target_player_info = {}
end, ON.PRE_LEVEL_DESTRUCTION)

local function spawn_dozer()
  dozer_in_level = true
end

---@type EnemyInfo[]
return {{
  spawn = spawn_dozer,
  icon_texture = icon_texture,
  name = "Dozer",
  limit = 1,
  hard_limit = 1,
}}
