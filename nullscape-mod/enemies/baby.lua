local commonlib = require "common"

local alarm_sound = create_sound("./enemies/sounds/Baby_Alarm.ogg") --[[@as CustomSound]]
local scream_sound = create_sound("./enemies/sounds/Baby_Scream.ogg") --[[@as CustomSound]]

local baby_idle_texture = nil
local baby_windup_texture = nil
local baby_charge_transition_texture = nil
local baby_charge_texture = nil
local star_fx_texture = nil
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 1024, 1024
  tdef.tile_width, tdef.tile_height = 256, 256
  tdef.texture_path = "./enemies/assets/baby_idle.png"
  baby_idle_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/baby_windup.png"
  baby_windup_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/baby_charge_transition.png"
  baby_charge_transition_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/baby_charge.png"
  baby_charge_texture = define_texture(tdef)

  tdef.tile_width, tdef.tile_height = 128, 128
  tdef.texture_path = "./enemies/assets/star_fx.png"
  star_fx_texture = define_texture(tdef) -- I couldn't find a more precise texture to what is used ingame
end

-- local frames_to_target_again = (27.666 - 26.066) * 60
-- local frames_to_target_again = (13.833 - 13.400) * 60
-- local frames_to_dash_after_warning = (14.500 - 13.833) * 60

local MIN_TARGET_TIMER = 25 -- Timer until baby targets someone
local MAX_TARGET_TIMER = 100 -- Timer until baby targets someone
local ATTACK_TIMER = 40 -- Timer until baby dashes towards someone
local DASHING_TIMER = 30 -- Timer for how long the baby will move at constant speed
local ATTACK_VELOCITY = 0.25

---@enum BABY_STATE
local BABY_STATE = {
  IDLE = 1,
  PREPARING = 2,
  DASHING = 3,
}

---@class BabyData
---@field state BABY_STATE
---@field target_timer integer
---@field attack_timer integer
---@field target_angle number
---@field anim_timer integer
---@field velocity number

---@class Baby : Movable
---@field user_data BabyData

---@param baby Baby
local function update_baby(baby)
  local baby_data = baby.user_data
  if baby_data.state == BABY_STATE.IDLE then
    baby_data.anim_timer = baby_data.anim_timer + 1
    baby.animation_frame = math.floor(baby_data.anim_timer / 4) % 9
    baby_data.target_timer = baby_data.target_timer - 1
    if baby_data.target_timer <= 0 then
      local target_uid = commonlib.select_target(baby)
      if target_uid ~= -1 then
        local tx, ty = get_position(target_uid)
        local bx, by = get_position(baby.uid)
        baby_data.state = BABY_STATE.PREPARING
        baby_data.attack_timer = ATTACK_TIMER
        baby_data.target_angle = math.atan(ty - by, tx - bx)
        baby_data.anim_timer = 0
        baby:set_texture(baby_windup_texture)
        baby.animation_frame = 0
        local snd = alarm_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
      else
        baby_data.target_timer = 5
      end
    end
  elseif baby_data.state == BABY_STATE.PREPARING then
    baby_data.anim_timer = baby_data.anim_timer + 1
    baby.animation_frame = math.min(math.floor(baby_data.anim_timer / 4), 15)
    baby_data.attack_timer = baby_data.attack_timer - 1
    if baby_data.attack_timer <= 0 then
      baby_data.state = BABY_STATE.DASHING
      baby_data.velocity = ATTACK_VELOCITY
      baby.velocityx = math.cos(baby_data.target_angle) * baby_data.velocity
      baby.velocityy = math.sin(baby_data.target_angle) * baby_data.velocity
      baby_data.anim_timer = 0
      baby.animation_frame = 0
      baby_data.attack_timer = DASHING_TIMER
      baby:set_texture(baby_charge_transition_texture)
      local snd = scream_sound:play()
      snd:set_volume(commonlib.SOUND_VOLUME)
    end
  elseif baby_data.state == BABY_STATE.DASHING then
    baby_data.anim_timer = baby_data.anim_timer + 1
    baby.animation_frame = math.floor(baby_data.anim_timer / 4) % 13
    baby_data.attack_timer = math.max(0, baby_data.attack_timer - 1)
    if baby_data.attack_timer == DASHING_TIMER - 4 then
      baby:set_texture(baby_charge_texture)
      baby_data.anim_timer = 0
      baby.animation_frame = 0
    end
    if baby_data.attack_timer <= 0 then
      baby_data.velocity = baby_data.velocity * 0.9
      baby.velocityx = math.cos(baby_data.target_angle) * baby_data.velocity
      baby.velocityy = math.sin(baby_data.target_angle) * baby_data.velocity
    end
    if math.abs(baby.velocityx) <= 0.005 and math.abs(baby.velocityy) <= 0.005 then
      baby_data.state = BABY_STATE.IDLE
      baby_data.target_timer = prng:random(MIN_TARGET_TIMER, MAX_TARGET_TIMER) --[[@as integer]]
      baby:set_texture(baby_idle_texture)
      baby_data.anim_timer = 0
      baby.animation_frame = 0
      baby.velocityx = 0
      baby.velocityy = 0
    end
  end
end

---@type {[integer]: boolean}
local babys = {}
local draw_cb = -1
local function start_baby_warning_draw()
  ---@param render VanillaRenderContext
  ---@param depth integer
  draw_cb = set_callback(function (render, depth)
    if depth ~= 1 then return end
    for baby_uid, _ in pairs(babys) do
      local baby = get_entity(baby_uid) --[[@as Baby]]
      if baby then
        local baby_data = baby.user_data
        if baby_data.state ~= BABY_STATE.PREPARING then return end

        local line_width = (baby_data.attack_timer / ATTACK_TIMER) * 20
        local color = Color:new(1, 0, 0, 0.8)
        local angle = baby_data.target_angle
        local x, y = baby.rendering_info.x, baby.rendering_info.y
        for i = 0, 9 do
          local start_dist, finish_dist = i, i + 0.5
          local start = Vec2:new(screen_position(x + baby.offsetx + (math.cos(angle) * start_dist), y + baby.offsety + (math.sin(angle) * start_dist)))
          local finish = Vec2:new(screen_position(x + baby.offsetx + (math.cos(angle) * finish_dist), y + baby.offsety + (math.sin(angle) * finish_dist)))
          render:draw_screen_line(start, finish, line_width, color)
        end
        local frames_since_attack = ATTACK_TIMER - baby_data.attack_timer
        local aabb = AABB:new(x, y, x, y):extrude((baby_data.attack_timer / ATTACK_TIMER) * 2)
        render:draw_world_texture(star_fx_texture, math.min(7, math.floor(frames_since_attack/4) + 3), 6, aabb, color)
      end
    end
  end, ON.RENDER_PRE_DRAW_DEPTH)
end

local baby_type = EntityDB:new(ENT_TYPE.ITEM_ROCK)
baby_type.collision2_mask = MASK.PLAYER

local function spawn_baby(x, y, layer)
  local uid = spawn_entity(ENT_TYPE.ITEM_ROCK, x, y, layer, 0 , 0)
  local baby = get_entity(uid) --[[@as Baby]]
  baby.type = baby_type
  baby.flags = clr_flag(baby.flags, ENT_FLAG.COLLIDES_WALLS)
  baby.flags = clr_flag(baby.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
  baby.flags = clr_flag(baby.flags, ENT_FLAG.INTERACT_WITH_WATER)
  baby.flags = clr_flag(baby.flags, ENT_FLAG.INTERACT_WITH_WEBS)
  baby.flags = clr_flag(baby.flags, ENT_FLAG.PICKUPABLE)
  baby.flags = clr_flag(baby.flags, 22) -- Carriable through exit
  baby.flags = set_flag(baby.flags, ENT_FLAG.NO_GRAVITY)
  baby.flags = set_flag(baby.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
  baby.offsety = 0.35
  baby.hitboxx, baby.hitboxy = 0.25, 0.325
  baby.width, baby.height = 2, 2
  baby:set_draw_depth(1)
  -- baby.rendering_info.shader = WORLD_SHADER.DEFERRED_TEXTURE_COLOR_TRANSPARENT
  baby:set_texture(baby_idle_texture)
  babys[uid] = true
  baby.user_data = {
    state = BABY_STATE.IDLE,
    target_timer = MAX_TARGET_TIMER + prng:random(MIN_TARGET_TIMER, MAX_TARGET_TIMER),
    attack_timer = 60,
    target_angle = 0,
    anim_timer = 0,
    velocity = 0,
  }
  baby:set_post_update_state_machine(update_baby)
  ---@param player Player
  baby:set_pre_on_collision2(function (baby, player)
    if player.type.search_flags & MASK.PLAYER ~= 0 and player.invincibility_frames_timer == 0 and player.exit_invincibility_timer == 0 then
      local xvel = player.abs_x - baby.abs_x > 0 and 0.1 or -0.1
      player:damage(baby, 1, 0, Vec2:new(xvel, 0.1), 0, 0, 60, false)
    end
    return true
  end)
  ---@param icbm Icbm
  baby:set_pre_dtor(function (baby)
    babys[baby.uid] = nil
    if next(babys) == nil then
      clear_callback(draw_cb)
      draw_cb = -1
    end
  end)
  -- baby.rendering_info:set_pre_render(function (self, offset, render)
  --   local baby = self:get_entity() --[[@as Baby]]
  --   local baby_data = baby.user_data
  --   if baby_data.state ~= BABY_STATE.PREPARING then return end

  --   local line_width = (baby_data.attack_timer / ATTACK_TIMER) * 20
  --   local color = Color:new(1, 0, 0, 0.8)
  --   local angle = baby_data.target_angle
  --   for i = 0, 9 do
  --     local start_dist, finish_dist = i, i + 0.5
  --     local start = Vec2:new(self.x + baby.offsetx + (math.cos(angle) * start_dist), self.y + baby.offsety + (math.sin(angle) * start_dist))
  --     local finish = Vec2:new(self.x + baby.offsetx + (math.cos(angle) * finish_dist), self.y + baby.offsety + (math.sin(angle) * finish_dist))
  --     render:draw_world_line(start, finish, line_width, color)
  --   end
  -- end)
  if draw_cb == -1 then
    start_baby_warning_draw()
  end
  return uid
end


return {
  spawn_baby = spawn_baby
}
