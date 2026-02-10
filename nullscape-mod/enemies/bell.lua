
local lut_textures = {}
local LUT_TEXTURE_NUM = 80
do
  local tdef = get_texture_definition(TEXTURE.DATA_TEXTURES_LUT_ORIGINAL_0) --[[@as TextureDefinition]]
  for i = 1, LUT_TEXTURE_NUM do
    tdef.texture_path = string.format("./enemies/luts/output_levels/lut_original_%02d.png", i)
    lut_textures[i] = define_texture(tdef)
  end
end

local commonlib = require "common"

local bell_sound = create_sound("./enemies/sounds/Bell_Ring.ogg") --[[@as CustomSound]]

local bell_texture = nil
local bell_fx_texture = nil
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.texture_path = "./enemies/assets/bell.png"
  bell_texture = define_texture(tdef)

  tdef.width, tdef.height = 1024, 1024
  tdef.tile_width, tdef.tile_height = 256, 256
  tdef.texture_path = "./enemies/assets/bell_fx.png"
  bell_fx_texture = define_texture(tdef)
end

local MIN_TELEPORT_TIMER = 60 * 7
local MAX_TELEPORT_TIMER = 60 * 10
local ROTATION_TIME = 60 * 2
local FX_TIMER = 60 * 1
local COLOR_FX_TIME = 60 * 2
local TP_PLAYER_MIN_DIST = 5
local TP_PLAYER_MAX_DIST = 7
local TP_ANGLE_MAX_OFFSET = math.rad(20)
local BELL_IFRAMES = 30

---@param self Bell
local function update_bell(self)
  local sdata = self.user_data
  sdata.fx_timer = math.max(sdata.fx_timer - 1, 0)

  sdata.teleport_timer = sdata.teleport_timer - 1
  if sdata.teleport_timer <= 0 then
    local target_uid = commonlib.select_target(self, true)
    if target_uid ~= -1 then
      local tx, ty, tl = get_position(target_uid)
      local tvx, tvy = get_velocity(target_uid)
      local player_move_angle = 0
      if tvx == 0 and tvy == 0 then
        player_move_angle = test_flag(get_entity_flags(target_uid), ENT_FLAG.FACING_LEFT) and math.pi or 0
      else
        player_move_angle = math.atan(tvy, tvx) + (prng:random() * TP_ANGLE_MAX_OFFSET*2) - TP_ANGLE_MAX_OFFSET
      end
      local dist = TP_PLAYER_MIN_DIST + (prng:random() * (TP_PLAYER_MAX_DIST - TP_PLAYER_MIN_DIST))
      local off_x, off_y = math.cos(player_move_angle) * dist, math.sin(player_move_angle) * dist
      local tele_x, tele_y = tx + off_x, ty + off_y
      if not state.theme_info:get_loop() then
        local left, top, right, bottom = get_bounds()
        tele_x = math.min(right, math.max(left, tele_x))
        tele_y = math.min(top, math.max(bottom, tele_y))
      end
      move_entity(self.uid, tele_x, tele_y, 0, 0, tl)
      sdata.teleport_timer = prng:random(MIN_TELEPORT_TIMER, MAX_TELEPORT_TIMER)
      sdata.fx_timer = FX_TIMER
    end
  end
  sdata.rotation_timer = sdata.rotation_timer - 1
  if sdata.rotation_timer > 0 then
    local mult =  commonlib.ease_in(sdata.rotation_timer / ROTATION_TIME)
    local x = ((ROTATION_TIME - sdata.rotation_timer) / ROTATION_TIME) * 16
    self.angle = math.sin(x) * mult
  else
    self.angle = .0
  end
end


---@class BellData
---@field teleport_timer integer
---@field fx_timer integer
---@field rotation_timer integer

---@class Bell : Movable
---@field user_data BellData

local bell_type = EntityDB:new(ENT_TYPE.ITEM_ROCK)
bell_type.collision2_mask = MASK.PLAYER

local color_fx_timer = 0
local fx_color = Color:white()

local function spawn_bell(x, y, layer)
  local uid = spawn_entity(ENT_TYPE.ITEM_ROCK, x, y, layer, 0 , 0)
  local bell = get_entity(uid) --[[@as Bell]]
  bell.type = bell_type
  bell.flags = clr_flag(bell.flags, ENT_FLAG.COLLIDES_WALLS)
  bell.flags = clr_flag(bell.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
  bell.flags = clr_flag(bell.flags, ENT_FLAG.INTERACT_WITH_WATER)
  bell.flags = clr_flag(bell.flags, ENT_FLAG.INTERACT_WITH_WEBS)
  bell.flags = clr_flag(bell.flags, ENT_FLAG.PICKUPABLE)
  bell.flags = clr_flag(bell.flags, 22) -- Carriable through exit
  bell.flags = set_flag(bell.flags, ENT_FLAG.NO_GRAVITY)
  bell.flags = set_flag(bell.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
  bell.offsety = -0.1
  bell.hitboxx, bell.hitboxy = 0.375, 0.5
  bell.width, bell.height = 2.25, 2.25
  bell:set_draw_depth(1)
  bell:set_texture(bell_texture)
  bell.user_data = {
    teleport_timer = prng:random(MIN_TELEPORT_TIMER, MAX_TELEPORT_TIMER),
    fx_timer = FX_TIMER,
    rotation_timer = 0,
  }
  bell:set_post_update_state_machine(update_bell)
  ---@param bell Bell
  ---@param player Player
  bell:set_pre_on_collision2(function (bell, player)
    if player.type.search_flags & MASK.PLAYER ~= 0 and player.exit_invincibility_timer == 0
    and bell.user_data.rotation_timer < ROTATION_TIME - BELL_IFRAMES then
      local vx, vy = get_velocity(player.uid)
      player:apply_velocity(Vec2:new(.0, commonlib.maxmin(-0.02, 0.3 + ((vy+0.05)*3), 0.3)), false)
      player.falling_timer = 0
      color_fx_timer = COLOR_FX_TIME
      bell.user_data.rotation_timer = ROTATION_TIME
      local snd = bell_sound:play()
      snd:set_volume(commonlib.SOUND_VOLUME)
    end
    return true
  end)
  bell.rendering_info:set_post_render(function (rinfo, offset, render)
    local bell = rinfo:get_entity() --[[@as Bell]]
    local sdata = bell.user_data
    if sdata.fx_timer <= 0 then return end

    local increasing_timer = FX_TIMER - sdata.fx_timer
    local zero_to_one = (increasing_timer / FX_TIMER)
    local anim_frame = math.min(15, math.floor(zero_to_one * 15))
    local width = commonlib.ease_in_to_zero(zero_to_one) * bell.width
    local height = commonlib.ease_in_to_zero(zero_to_one) * bell.height
    fx_color.a = commonlib.ease_in_to_zero(zero_to_one)
    local aabb = AABB:new(rinfo.x - (width/2), rinfo.y + (height/2), rinfo.x + (width/2), rinfo.y - (height/2))
    render:draw_world_texture(bell_fx_texture, math.floor(anim_frame / 4), anim_frame % 4, aabb, Color:white())
  end)
  return uid
end

set_callback(function ()
  if color_fx_timer > 0 then
    local lut_i = math.max(0.0, math.min(1.0, (COLOR_FX_TIME - (color_fx_timer * 2)) / COLOR_FX_TIME))
    lut_i = math.floor(commonlib.ease_in_to_zero(lut_i) * 79) + 1
    set_lut(lut_textures[lut_i], LAYER.FRONT)
    set_lut(lut_textures[lut_i], LAYER.BACK)
  elseif color_fx_timer == 0 then
    set_lut(nil, LAYER.FRONT)
    set_lut(nil, LAYER.BACK)
  end
  color_fx_timer = color_fx_timer - 1
end, ON.GAMEFRAME)

set_callback(function ()
  color_fx_timer = -1
  set_lut(nil, LAYER.FRONT)
  set_lut(nil, LAYER.BACK)
end, ON.PRE_LEVEL_DESTRUCTION)

return {
  spawn_bell = spawn_bell
}
