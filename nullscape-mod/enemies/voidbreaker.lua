local commonlib = require "common"

local module = {}

local show_sound = create_sound("./enemies/sounds/Voidbreaker_Show.ogg") --[[@as CustomSound]]
local sword_sound = create_sound("./enemies/sounds/Voidbreaker_Sword.ogg") --[[@as CustomSound]]
local sword_go_sound = create_sound("./enemies/sounds/Voidbreaker_Sword_Go.ogg") --[[@as CustomSound]]

local knight_texture = nil
local sword_texture = nil
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 296, 376
  tdef.tile_width, tdef.tile_height = 271, 260
  tdef.sub_image_width, tdef.sub_image_height = 271, 260
  tdef.texture_path = "./enemies/assets/roaring_knight.png"
  knight_texture = define_texture(tdef)

  tdef.tile_width, tdef.tile_height = 296, 116
  tdef.sub_image_width, tdef.sub_image_height = 296, 116
  tdef.sub_image_offset_x, tdef.sub_image_offset_y = 0, 260
  sword_texture = define_texture(tdef)
end

---@enum VOIDBREAKER_STATE
local VOIDBREAKER_STATE = {
  INVISIBLE = 1,
  APPEARED = 2,
  SWORD_APPEARING = 3,
  SWORD_WAITING = 4,
  SWORD_LAUNCHED = 5,
  HIDING = 6,
}

---@class VoidbreakerInfo
---@field state VOIDBREAKER_STATE
---@field timer integer
---@field sword_angle number
---@field swords_remaining integer

local VOIDBREAKER_MIN_START_SHOW_TIME = 7 * 60
local VOIDBREAKER_MAX_START_SHOW_TIME = 14 * 60
local VOIDBREAKER_MIN_SHOW_TIME = 20 * 60
local VOIDBREAKER_MAX_SHOW_TIME = 40 * 60

local VOIDBREAKER_FIRST_ATTACK_TIME = 3 * 60
local VOIDBREAKER_FULL_OPACITY_TIME = 40

local VOIDBREAKER_SWORD_SET_TIME = 40
local VOIDBREAKER_SWORD_LAUNCH_TIME = 40
local VOIDBREAKER_SWORD_END_TIME = 15

local VOIDBREAKER_HIDE_TIME = 60 * 1
local VOIDBREAKER_HIDE_ALPHA_TIME = 60 * 1

local VOIDBREAKER_SWORD_ATTACK_TIME = 4

local MIN_SQ_VEL_TO_DODGE = 0.08*0.08

---@type {[integer]: VoidbreakerInfo}
local target_player_info = {}
local voidbreakers_in_level = 0
local color = Color:new(1, 1, 1, 1)

---@param render VanillaRenderContext
set_callback(function (render)
  if not voidbreakers_in_level then return end
  for uid, info in pairs(target_player_info) do
    local x, y = get_render_position(uid)
    -- local vx, vy = get_velocity(uid)
    -- local pangle = math.atan(vy, vx)
    -- local start = Vec2:new(screen_position(x, y))
    -- local finish = Vec2:new(screen_position(x + math.cos(pangle), y + math.sin(pangle)))
    -- render:draw_screen_line(start, finish, 10, Color:white())
    -- render:draw_text(tostring(pangle), 0, -0.8, 0.0008, 0.0008, Color:white(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
    if info.state >= VOIDBREAKER_STATE.APPEARED then
      color.a = 1.0
      if info.state == VOIDBREAKER_STATE.APPEARED then
        color.a = math.min(1, (VOIDBREAKER_FIRST_ATTACK_TIME - info.timer) / VOIDBREAKER_FULL_OPACITY_TIME)
      elseif info.state == VOIDBREAKER_STATE.HIDING then
        color.a = math.min(1, math.max(0, info.timer / VOIDBREAKER_HIDE_ALPHA_TIME))
      end
      local aabb = screen_aabb(AABB:new(x, y, x, y):offset(2, 0):extrude(1.0))
      render:draw_screen_texture(knight_texture, 0, 0, aabb, color)

      if info.state >= VOIDBREAKER_STATE.SWORD_APPEARING and info.state <= VOIDBREAKER_STATE.SWORD_LAUNCHED then
        local dist = 1
        color.a = 1.
        if info.state == VOIDBREAKER_STATE.SWORD_APPEARING then
          color.a = math.min(1, (VOIDBREAKER_SWORD_SET_TIME - info.timer) / VOIDBREAKER_SWORD_SET_TIME)
          dist = dist + commonlib.ease_out_to_zero((VOIDBREAKER_SWORD_SET_TIME - info.timer) / VOIDBREAKER_SWORD_SET_TIME)
        elseif info.state == VOIDBREAKER_STATE.SWORD_LAUNCHED then
          dist = dist - (((VOIDBREAKER_SWORD_END_TIME - info.timer) / VOIDBREAKER_SWORD_END_TIME) * 2)
          color.a = math.max(0, math.min(1, (info.timer*2) / VOIDBREAKER_SWORD_END_TIME))
        end
        local sx, sy = math.cos(info.sword_angle) * dist, math.sin(info.sword_angle) * dist
        aabb = screen_aabb(AABB:new(x, y, x, y):offset(sx, sy):extrude(0.5, 0.5 * (116/296)))
        render:draw_screen_texture(sword_texture, 0, 0, aabb, color, info.sword_angle + math.pi, 0, 0)
      end
      -- finish = Vec2:new(screen_position(x + math.cos(info.sword_angle), y + math.sin(info.sword_angle)))
      -- render:draw_screen_line(start, finish, 10, Color:red())
      -- render:draw_text(tostring(info.sword_angle), 0, -0.9, 0.0008, 0.0008, Color:red(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
      -- render:draw_text(enum_get_name(VOIDBREAKER_STATE, info.state), 0.5, -0.9, 0.0008, 0.0008, Color:red(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
      -- render:draw_text(tostring(info.timer), 0.9, -0.9, 0.0008, 0.0008, Color:red(), VANILLA_TEXT_ALIGNMENT.CENTER, VANILLA_FONT_STYLE.BOLD)
    end
    -- if info.state == VOIDBREAKER_STATE.INVISIBLE then
    --   goto continue
    -- end
    -- local aabb = AABB:new(-0.2, 0.2 * (16/9), 0.2, -0.2 * (16/9))
    -- render:draw_screen_texture(texture, 0, math.floor(info.timer / 8), aabb, color)
    -- ::continue::
  end
end, ON.RENDER_PRE_HUD)

set_callback(function ()
  if voidbreakers_in_level == 0 then return end
  for i, player in ipairs(get_local_players()) do
    if not target_player_info[player.uid] then
      target_player_info[player.uid] = {
        state = VOIDBREAKER_STATE.INVISIBLE,
        timer = prng:random(VOIDBREAKER_MIN_START_SHOW_TIME, VOIDBREAKER_MAX_START_SHOW_TIME),
        sword_angle = .0,
        swords_remaining = 0,
      }
    end
    local info = target_player_info[player.uid]
    if info.state == VOIDBREAKER_STATE.INVISIBLE and info.timer == 0 then
      info.state = VOIDBREAKER_STATE.APPEARED
      info.timer = VOIDBREAKER_FIRST_ATTACK_TIME
      local snd = show_sound:play()
      snd:set_volume(commonlib.SOUND_VOLUME)
    elseif info.state == VOIDBREAKER_STATE.APPEARED then
      if info.timer <= 0 then
        info.state = VOIDBREAKER_STATE.SWORD_APPEARING
        info.timer = VOIDBREAKER_SWORD_SET_TIME
        info.swords_remaining = voidbreakers_in_level - 1
        info.sword_angle = (prng:random() * math.pi * 2) - math.pi
        local snd = sword_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
      end
    elseif info.state == VOIDBREAKER_STATE.SWORD_APPEARING then
      if info.timer <= 0 then
        info.state = VOIDBREAKER_STATE.SWORD_WAITING
        info.timer = VOIDBREAKER_SWORD_LAUNCH_TIME
      end
    elseif info.state == VOIDBREAKER_STATE.SWORD_WAITING then
      if info.timer <= 0 then
        info.state = VOIDBREAKER_STATE.SWORD_LAUNCHED
        info.timer = VOIDBREAKER_SWORD_END_TIME
        local snd = sword_go_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
      end
    elseif info.state == VOIDBREAKER_STATE.SWORD_LAUNCHED then
      if info.timer == VOIDBREAKER_SWORD_END_TIME - VOIDBREAKER_SWORD_ATTACK_TIME then
        if player.exit_invincibility_timer == 0 and player.invincibility_frames_timer == 0 and not test_flag(player.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING) then
          local vx, vy = get_velocity(player.uid)
          local pangle = math.atan(vy, vx)
          if info.sword_angle - pangle > math.pi then
            pangle = pangle + (math.pi*2)
          elseif info.sword_angle - pangle < -math.pi then
            pangle = pangle - (math.pi*2)
          end
          if math.abs(info.sword_angle - pangle) < math.rad(40) or (vx*vx) + (vy*vy) < MIN_SQ_VEL_TO_DODGE then
            local player_move_direction = info.sword_angle + (math.pi/2) > 0 and -0.1 or 0.1
            player:damage(nil, 1, 0, Vec2:new(player_move_direction, 0.1), 0, 0, 60, false)
          end
        end
      end
      if info.timer <= 0 then
        if info.swords_remaining == 0 then
          info.state = VOIDBREAKER_STATE.HIDING
          info.timer = VOIDBREAKER_HIDE_TIME
        else
          info.state = VOIDBREAKER_STATE.SWORD_APPEARING
          info.timer = VOIDBREAKER_SWORD_SET_TIME
          local snd = sword_sound:play()
          snd:set_volume(commonlib.SOUND_VOLUME)
          info.swords_remaining = info.swords_remaining - 1
          info.sword_angle = (prng:random() * math.pi * 2) - math.pi
        end
      end
    elseif info.state == VOIDBREAKER_STATE.HIDING then
      if info.timer <= 0 then
        info.state = VOIDBREAKER_STATE.INVISIBLE
        info.timer = prng:random(VOIDBREAKER_MIN_SHOW_TIME, VOIDBREAKER_MAX_SHOW_TIME)
      end
    end
    info.timer = info.timer - 1
  end
end, ON.GAMEFRAME)

set_callback(function ()
  voidbreakers_in_level = 0
  target_player_info = {}
end, ON.PRE_LEVEL_DESTRUCTION)

function module.spawn_voidbreaker(num)
  voidbreakers_in_level = num
end

return module

