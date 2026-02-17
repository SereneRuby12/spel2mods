local commonlib = require "common"
local animationlib = require "animation"

local alarm_sound = create_sound("./enemies/sounds/Baby_Alarm.ogg") --[[@as CustomSound]]
local scream_sound = create_sound("./enemies/sounds/Baby_Scream.ogg") --[[@as CustomSound]]

local voidbound_alarm_sound = create_sound("./enemies/sounds/Shadow_Baby_Alarm.ogg") --[[@as CustomSound]]
local voidbound_scream_sound = create_sound("./enemies/sounds/Shadow_Baby_Scream.ogg") --[[@as CustomSound]]

local baby_idle_texture
local baby_windup_texture
local baby_charge_transition_texture
local baby_charge_texture

local voidbound_baby_idle_texture
local voidbound_baby_windup_texture
local voidbound_baby_charge_texture
local voidbound_baby_charge_transition_texture

local star_fx_texture
local icon_texture
local voidbound_icon_texture

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

  tdef.width, tdef.height = 1024, 600
  tdef.sub_image_width, tdef.sub_image_height = 1000, 600
  tdef.tile_width, tdef.tile_height = 200, 200
  tdef.texture_path = "./enemies/assets/voidbound_baby_idle.png"
  voidbound_baby_idle_texture = define_texture(tdef)
  tdef.width, tdef.height = 1024, 400
  tdef.sub_image_width, tdef.sub_image_height = 1000, 400
  tdef.texture_path = "./enemies/assets/voidbound_baby_windup.png"
  voidbound_baby_windup_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/voidbound_baby_charge.png"
  voidbound_baby_charge_texture = define_texture(tdef)
  tdef.width, tdef.height = 1024, 200
  tdef.sub_image_width, tdef.sub_image_height = 1000, 200
  tdef.texture_path = "./enemies/assets/voidbound_baby_charge_transition.png"
  voidbound_baby_charge_transition_texture = define_texture(tdef)

  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.sub_image_width, tdef.sub_image_height = 0, 0
  tdef.texture_path = "./enemies/assets/icons/baby.png"
  icon_texture = define_texture(tdef)

  tdef.texture_path = "./enemies/assets/icons/voidbound_baby.png"
  voidbound_icon_texture = define_texture(tdef)
end

---@class BabyAnimations
---@field IDLE CustomAnimation
---@field WINDUP CustomAnimation
---@field CHARGE_TRANSITION CustomAnimation
---@field CHARGE CustomAnimation

---@type BabyAnimations
local BABY_ANIMATIONS = {
  IDLE = { 8, 7, 6, 5, 4, 3, 2, 1, 0, frames = 9, frame_time = 4, loop = true, texture_id = baby_idle_texture },
  WINDUP = { 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, frames = 16, frame_time = 4, texture_id = baby_windup_texture },
  CHARGE_TRANSITION = { 3, 2, 1, 0, frames = 4, frame_time = 4, texture_id = baby_charge_transition_texture },
  CHARGE = { 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, frames = 13, frame_time = 4, loop = true, texture_id = baby_charge_texture },
}

---@type BabyAnimations
local VOIDBOUND_BABY_ANIMATIONS = {
  IDLE = { 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, frames = 13, frame_time = 4, loop = true, texture_id = voidbound_baby_idle_texture },
  WINDUP = { 6, 5, 4, 3, 2, 1, 0, frames = 7, frame_time = 4, texture_id = voidbound_baby_windup_texture },
  CHARGE_TRANSITION = { 4, 3, 2, 1, 0, frames = 5, frame_time = 4, texture_id = voidbound_baby_charge_transition_texture },
  CHARGE = { 6, 5, 4, 3, 2, 1, 0, frames = 7, frame_time = 4, loop = true, texture_id = voidbound_baby_charge_texture },
}

---@class BabyType
---@field hitboxx number
---@field hitboxy number
---@field offsety number
---@field min_target_timer integer
---@field max_target_timer integer
---@field attack_time integer
---@field dashing_time integer
---@field dash_velocity number
---@field dash_stop_mult number
---@field fx_color Color
---@field animations BabyAnimations
---@field alarm_sound CustomSound
---@field scream_sound CustomSound

---@type BabyType
local normal_baby = {
  offsety = 0.3,
  hitboxx = 0.25,
  hitboxy = 0.325,
  min_target_timer = 25,
  max_target_timer = 100,
  attack_time = 40,
  dashing_time = 30,
  dash_velocity = 0.25,
  dash_stop_mult = 0.9,
  fx_color = Color:new(1, 0, 0, 0.8),
  animations = BABY_ANIMATIONS,
  alarm_sound = alarm_sound,
  scream_sound = scream_sound,
}

---@type BabyType
local voidbound_baby = {
  offsety = .0,
  hitboxx = 0.325,
  hitboxy = 0.425,
  min_target_timer = 20,
  max_target_timer = 30,
  attack_time = 20,
  dashing_time = 18,
  dash_velocity = 0.5,
  dash_stop_mult = 0.5,
  fx_color = Color:new(1, 0, 1, 0.8),
  animations = VOIDBOUND_BABY_ANIMATIONS,
  alarm_sound = voidbound_alarm_sound,
  scream_sound = voidbound_scream_sound,
}

local START_WAIT_MIN_TIME = 80
local START_WAIT_MAX_TIME = 160

---@enum BABY_STATE
local BABY_STATE = {
  IDLE = 1,
  PREPARING = 2,
  DASHING = 3,
}

---@class BabyData
---@field type BabyType
---@field state BABY_STATE
---@field target_timer integer
---@field attack_timer integer
---@field target_angle number
---@field velocity number
---@field animation_state table
---@field animation_timer integer

---@class Baby : Movable
---@field user_data BabyData

---@param baby Baby
local function update_baby(baby)
  local baby_data = baby.user_data
  if baby_data.state == BABY_STATE.IDLE then
    baby_data.target_timer = baby_data.target_timer - 1
    if baby_data.target_timer <= 0 then
      local target_uid = commonlib.select_target(baby)
      if target_uid ~= -1 then
        local tx, ty = get_position(target_uid)
        local bx, by = get_position(baby.uid)
        bx, by = bx + baby.offsetx, by + baby.offsety
        baby_data.state = BABY_STATE.PREPARING
        baby_data.attack_timer = baby_data.type.attack_time
        baby_data.target_angle = math.atan(ty - by, tx - bx)
        local animation = baby_data.type.animations.WINDUP
        baby:set_texture(animation.texture_id)
        animationlib.set_animation(baby_data, animation)
        local snd = baby_data.type.alarm_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
      else
        baby_data.target_timer = 5
      end
    end
  elseif baby_data.state == BABY_STATE.PREPARING then
    baby_data.attack_timer = baby_data.attack_timer - 1
    if baby_data.attack_timer <= 0 then
      baby_data.state = BABY_STATE.DASHING
      baby_data.velocity = baby_data.type.dash_velocity
      baby_data.attack_timer = baby_data.type.dashing_time
      local animation = baby_data.type.animations.CHARGE_TRANSITION
      baby:set_texture(animation.texture_id)
      animationlib.set_animation(baby_data, animation)
      local snd = baby_data.type.scream_sound:play()
      snd:set_volume(commonlib.SOUND_VOLUME)
    end
  elseif baby_data.state == BABY_STATE.DASHING then
    baby_data.attack_timer = math.max(0, baby_data.attack_timer - 1)
    if baby_data.attack_timer == baby_data.type.dashing_time - 4 then
      local animation = baby_data.type.animations.CHARGE
      baby:set_texture(animation.texture_id)
      animationlib.set_animation(baby_data, animation)
    end
    if baby_data.attack_timer <= 0 then
      baby_data.velocity = baby_data.velocity * baby_data.type.dash_stop_mult
      if baby_data.velocity <= 0.0075 then
        baby_data.state = BABY_STATE.IDLE
        baby_data.target_timer = prng:random(baby_data.type.min_target_timer, baby_data.type.max_target_timer) --[[@as integer]]
        local animation = baby_data.type.animations.IDLE
        baby:set_texture(animation.texture_id)
        animationlib.set_animation(baby_data, animation)
        baby.animation_frame = 0
        baby_data.velocity = 0
      end
    end
  end
  baby.velocityx = 0
  baby.velocityy = 0
  baby.x = baby.x + math.cos(baby_data.target_angle) * baby_data.velocity
  baby.y = baby.y + math.sin(baby_data.target_angle) * baby_data.velocity
  baby.animation_frame = animationlib.get_animation_frame(baby_data)
  animationlib.update_timer(baby_data)
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
        if baby_data.state ~= BABY_STATE.PREPARING then goto continue end

        local attack_time = baby_data.type.attack_time
        local line_width = (baby_data.attack_timer / attack_time) * 20
        local color = baby_data.type.fx_color
        local angle = baby_data.target_angle
        local x, y = baby.rendering_info.x, baby.rendering_info.y
        for i = 0, 9 do
          local start_dist, finish_dist = i, i + 0.5
          local start = Vec2:new(screen_position(x + baby.offsetx + (math.cos(angle) * start_dist), y + baby.offsety + (math.sin(angle) * start_dist)))
          local finish = Vec2:new(screen_position(x + baby.offsetx + (math.cos(angle) * finish_dist), y + baby.offsety + (math.sin(angle) * finish_dist)))
          render:draw_screen_line(start, finish, line_width, color)
        end
        local frames_since_attack = attack_time - baby_data.attack_timer
        local aabb = AABB:new(x, y, x, y):extrude((baby_data.attack_timer / attack_time) * 2)
        render:draw_world_texture(star_fx_texture, math.min(7, math.floor(frames_since_attack/4) + 3), 6, aabb, color)
      end
      ::continue::
    end
  end, ON.RENDER_PRE_DRAW_DEPTH)
end

local baby_type = EntityDB:new(ENT_TYPE.ITEM_ROCK)
baby_type.collision2_mask = MASK.PLAYER

local function spawn_baby(x, y, layer, is_voidbound)
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
  baby.width, baby.height = 2, 2
  baby:set_draw_depth(1)
  local baby_ctype = is_voidbound and voidbound_baby or normal_baby
  baby.offsety = baby_ctype.offsety
  baby.hitboxx, baby.hitboxy = baby_ctype.hitboxx, baby_ctype.hitboxy
  baby:set_texture(baby_ctype.animations.IDLE.texture_id)
  babys[uid] = true
  baby.user_data = {
    type = baby_ctype,
    state = BABY_STATE.IDLE,
    target_timer = prng:random(START_WAIT_MIN_TIME, START_WAIT_MAX_TIME),
    attack_timer = 60,
    target_angle = 0,
    velocity = 0,
    animation_timer = 0,
    animation_state = baby_ctype.animations.IDLE,
  }
  animationlib.set_animation(baby.user_data, baby_ctype.animations.IDLE)
  baby:set_post_update_state_machine(update_baby)
  ---@param player Player
  baby:set_pre_on_collision2(function (baby, player)
    if player.type.search_flags & MASK.PLAYER ~= 0 and player.invincibility_frames_timer == 0 and player.exit_invincibility_timer == 0 then
      local xvel = player.abs_x - baby.abs_x > 0 and 0.1 or -0.1
      player:damage(baby, 1, 0, Vec2:new(xvel, 0.1), 0, 0, 60, false)
    end
    return true
  end)
  ---@param baby Baby
  baby:set_pre_dtor(function (baby)
    babys[baby.uid] = nil
    if next(babys) == nil then
      clear_callback(draw_cb)
      draw_cb = -1
    end
  end)
  if draw_cb == -1 then
    start_baby_warning_draw()
  end
  return uid
end

local function spawn_voidbound_baby(x, y, layer)
  return spawn_baby(x, y, layer, true)
end

---@type EnemyInfo[]
return {
  {
    spawn = commonlib.spawn_default_fun(spawn_baby),
    icon_texture = icon_texture,
    max = 2,
  },
  {
    spawn = commonlib.spawn_default_fun(spawn_voidbound_baby),
    icon_texture = voidbound_icon_texture,
    max = 3,
  }
}
