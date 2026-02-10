local commonlib = require "common"

local icbm_sound = create_sound("./enemies/sounds/ICBMStrike.mp3") --[[@as CustomSound]]

local icbm_texture
local icbm_fx_texture
local explosion_texture
local icon_texture
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 1000, 400
  tdef.tile_width, tdef.tile_height = 200, 200
  tdef.texture_path = "./enemies/assets/icbm.png"
  icbm_texture = define_texture(tdef)

  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.texture_path = "./enemies/assets/icbm_fx.png"
  icbm_fx_texture = define_texture(tdef)
  tdef.width, tdef.height = 768, 192
  tdef.tile_width, tdef.tile_height = 96, 96
  tdef.texture_path = "./enemies/assets/explosion.png"
  explosion_texture = define_texture(tdef)

  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.sub_image_width, tdef.sub_image_height = 0, 0
  tdef.texture_path = "./enemies/assets/icons/icbm.png"
  icon_texture = define_texture(tdef)
end

---@enum ICBM_STATE
local ICBM_STATE = {
  IDLE = 1,
  TRACKING_TARGET = 2,
  LOCKED_POSITION = 3,
  EXPLODING = 4,
  EXPLODED = 5
}

local MIN_SELECT_TARGET_TIMER = 60 * 4
local MAX_SELECT_TARGET_TIMER = 60 * 5
local LOCK_POS_TIMER = 60 * 3
local LAND_TIMER = 60 * 1
local EXPLODE_TIMER = 60 * 1
local START_DISTANCE = 8
local TARGETING_RADIUS = 1.5
local EXPLOSION_RADIUS = 2.5
local WIDTH, HEIGHT = 3, 3
local EXPLOSION_WIDTH, EXPLOSION_HEIGHT = 6, 6

---@class IcbmData
---@field attack_timer integer
---@field fx_timer integer
---@field anim_timer integer
---@field target_uid integer
---@field target_x number
---@field target_y number
---@field target_l integer
---@field state ICBM_STATE
---@field sound PlayingSound?

---@class Icbm : Movable
---@field user_data IcbmData

---@type {[integer]: boolean}
local icbms = {}

local draw_cb = -1
local function start_icbm_warning_draw()
  draw_cb = set_callback(function (render, depth)
    if depth ~= 1 then return end
    for icbm_uid, _ in pairs(icbms) do
      local icbm = get_entity(icbm_uid) --[[@as Icbm]]
      if icbm then
        local idata = icbm.user_data
        if idata.state == ICBM_STATE.TRACKING_TARGET then
          local target_uid = idata.target_uid
          local x, y, l = get_render_position(target_uid)
          local size_mult = commonlib.ease_out(math.min(1, (LOCK_POS_TIMER - idata.attack_timer) / (LOCK_POS_TIMER/3)))
          local aabb = AABB:new(x, y, x, y):extrude(TARGETING_RADIUS * size_mult)
          render:draw_world_texture(icbm_fx_texture, 0, 0, aabb, Color:red())
        elseif idata.state == ICBM_STATE.LOCKED_POSITION then
          local x, y, l = idata.target_x, idata.target_y, idata.target_l
          local extra_radius = EXPLOSION_RADIUS - TARGETING_RADIUS
          local size_mult = commonlib.ease_out(math.min(1, (LAND_TIMER - idata.attack_timer) / (LAND_TIMER/3)))
          local aabb = AABB:new(x, y, x, y):extrude(TARGETING_RADIUS + (extra_radius * size_mult))
          render:draw_world_texture(icbm_fx_texture, 0, 0, aabb, Color:red())
        end
      end
    end
  end, ON.RENDER_PRE_DRAW_DEPTH)
end

---@param icbm Icbm
local function update_icbm(icbm)
  local idata = icbm.user_data
  if idata.target_uid ~= -1 and not get_entity(idata.target_uid) then
    idata.attack_timer = prng:random(MIN_SELECT_TARGET_TIMER, MAX_SELECT_TARGET_TIMER)
    idata.state = ICBM_STATE.IDLE
    idata.target_uid = -1
    icbm.flags = set_flag(icbm.flags, ENT_FLAG.INVISIBLE)
  end

  if idata.state == ICBM_STATE.IDLE then
    idata.anim_timer = idata.anim_timer + 1
    icbm.animation_frame = math.floor(idata.anim_timer / 4) % 7
    idata.attack_timer = idata.attack_timer - 1
    if idata.attack_timer <= 0 then
      local target_uid = commonlib.select_target(icbm, true)
      if target_uid ~= -1 then
        idata.state = ICBM_STATE.TRACKING_TARGET
        idata.target_uid = target_uid
        idata.attack_timer = LOCK_POS_TIMER
        icbm.flags = set_flag(icbm.flags, ENT_FLAG.INVISIBLE)

        local snd = icbm_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
        idata.sound = snd
      end
    end
  elseif idata.state == ICBM_STATE.TRACKING_TARGET then
    idata.attack_timer = idata.attack_timer - 1
    if idata.attack_timer <= 0 then
      idata.state = ICBM_STATE.LOCKED_POSITION
      idata.attack_timer = LAND_TIMER
      local tx, ty, tl = get_position(idata.target_uid)
      move_entity(icbm.uid, tx, ty + START_DISTANCE, 0, 0, tl)
      icbm.velocityy = -START_DISTANCE/LAND_TIMER
      icbm.flags = clr_flag(icbm.flags, ENT_FLAG.INVISIBLE)
      idata.anim_timer = 0
      idata.target_x, idata.target_y, idata.target_l = tx, ty, tl
    end
  elseif idata.state == ICBM_STATE.LOCKED_POSITION then
    idata.attack_timer = idata.attack_timer - 1
    idata.anim_timer = idata.anim_timer + 1
    icbm.animation_frame = math.floor(idata.anim_timer / 4) % 7
    if idata.attack_timer <= 0 then
      idata.state = ICBM_STATE.EXPLODING
      idata.attack_timer = EXPLODE_TIMER
      icbm.flags = clr_flag(icbm.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING)
      icbm:set_texture(explosion_texture)
      icbm.width, icbm.height = EXPLOSION_WIDTH, EXPLOSION_HEIGHT
      icbm.velocityy = 0
      idata.anim_timer = 0
    end
  elseif idata.state == ICBM_STATE.EXPLODING then
    idata.anim_timer = idata.anim_timer + 1
    icbm.animation_frame = math.floor(idata.anim_timer / 4)
    if icbm.animation_frame >= 16 then
      icbm.flags = set_flag(icbm.flags, ENT_FLAG.INVISIBLE)
    end
    idata.attack_timer = idata.attack_timer - 1
    if idata.attack_timer <= EXPLODE_TIMER - 2 then
      icbm.flags = set_flag(icbm.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING)
    end
    if idata.attack_timer <= 0 then
      idata.state = ICBM_STATE.IDLE
      idata.attack_timer = prng:random(MIN_SELECT_TARGET_TIMER, MAX_SELECT_TARGET_TIMER)
      icbm.flags = set_flag(icbm.flags, ENT_FLAG.INVISIBLE)
      icbm:set_texture(icbm_texture)
      idata.sound = nil
    end
  end
end

local icbm_type = EntityDB:new(ENT_TYPE.ITEM_ROCK)
icbm_type.collision2_mask = MASK.PLAYER

local function spawn_icbm(x, y, layer)
  local uid = spawn_entity(ENT_TYPE.ITEM_ROCK, x, y, layer, 0 , 0)
  local icbm = get_entity(uid) --[[@as Icbm]]
  icbm.type = icbm_type
  icbm.flags = clr_flag(icbm.flags, ENT_FLAG.COLLIDES_WALLS)
  icbm.flags = clr_flag(icbm.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
  icbm.flags = clr_flag(icbm.flags, ENT_FLAG.INTERACT_WITH_WATER)
  icbm.flags = clr_flag(icbm.flags, ENT_FLAG.INTERACT_WITH_WEBS)
  icbm.flags = clr_flag(icbm.flags, ENT_FLAG.PICKUPABLE)
  icbm.flags = clr_flag(icbm.flags, 22) -- Carriable through exit
  icbm.flags = set_flag(icbm.flags, ENT_FLAG.NO_GRAVITY)
  icbm.flags = set_flag(icbm.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
  icbm.flags = set_flag(icbm.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING)
  icbm.shape = SHAPE.CIRCLE
  icbm.offsety = 0
  icbm.hitboxx, icbm.hitboxy = EXPLOSION_RADIUS, EXPLOSION_RADIUS
  icbm.width, icbm.height = WIDTH, HEIGHT
  icbm:set_draw_depth(1)
  icbm:set_texture(icbm_texture)
  icbm.user_data = {
    state = ICBM_STATE.IDLE,
    attack_timer = MIN_SELECT_TARGET_TIMER + prng:random(MAX_SELECT_TARGET_TIMER),
    fx_timer = 0,
    anim_timer = 0,
    target_uid = -1,
    target_x = -1,
    target_y = -1,
    target_l = -1,
    sound = nil,
  }
  icbms[uid] = true
  icbm:set_post_update_state_machine(update_icbm)
  ---@param player Player
  icbm:set_pre_on_collision2(function (icbm, player)
    if player.type.search_flags & MASK.PLAYER ~= 0 and player.invincibility_frames_timer == 0 and player.exit_invincibility_timer == 0 then
      local xvel = player.abs_x - icbm.abs_x > 0 and 0.1 or -0.1
      player:damage(icbm, 1, 0, Vec2:new(xvel, 0.1), 0, 0, 60, false)
    end
    return true
  end)
  ---@param icbm Icbm
  icbm:set_pre_dtor(function (icbm)
    icbms[icbm.uid] = nil
    if next(icbms) == nil then
      clear_callback(draw_cb)
      draw_cb = -1
    end
  end)
  if draw_cb == -1 then
    start_icbm_warning_draw()
  end
  return uid
end

set_callback(function ()
  for uid, _ in pairs(icbms) do
    local icbm = get_entity(uid) --[[@as Icbm]]
    if icbm and icbm.user_data.sound then
      icbm.user_data.sound:stop()
    end
  end
end, ON.PRE_LEVEL_DESTRUCTION)

---@type EnemyInfo[]
return {{
  spawn = spawn_icbm,
  icon_texture = icon_texture,
  limit = 2,
}}
