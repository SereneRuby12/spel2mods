local commonlib = require "common"

local tp_sound = create_sound("./enemies/sounds/Teleport.mp3") --[[@as CustomSound]]

local telefragger_texture
local telefragger_fx_texture
local icon_texture
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 200, 100
  tdef.tile_width, tdef.tile_height = 100, 100
  tdef.texture_path = "./enemies/assets/telefragger.png"
  telefragger_texture = define_texture(tdef)

  tdef.width, tdef.height = 1024, 1024
  tdef.tile_width, tdef.tile_height = 256, 256
  tdef.texture_path = "./enemies/assets/telefragger_fx.png"
  telefragger_fx_texture = define_texture(tdef)

  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.sub_image_width, tdef.sub_image_height = 0, 0
  tdef.texture_path = "./enemies/assets/icons/telefragger.png"
  icon_texture = define_texture(tdef)
end

local TELEPORT_TIMER = 60 * 7
local FX_TIMER = 60 * 4
local VELOCITY = 0.01
local TP_PLAYER_DIST = 5

---@param self Telefragger
local function update_telefragger(self)
  local sdata = self.user_data
  sdata.fx_timer = math.max(sdata.fx_timer - 1, 0)
  sdata.anim_timer = sdata.anim_timer + 1
  self.animation_frame = math.floor(sdata.anim_timer / 8) % 2

  sdata.teleport_timer = sdata.teleport_timer - 1
  if sdata.teleport_timer == 55 then
    local snd = tp_sound:play()
    snd:set_volume(commonlib.SOUND_VOLUME + 0.3)
  end
  if sdata.teleport_timer <= 0 then
    local target_uid = commonlib.select_target(self, true)
    if target_uid ~= -1 then
      local tx, ty, tl = get_position(target_uid)
      local off_x = test_flag(get_entity_flags(target_uid), ENT_FLAG.FACING_LEFT) and -TP_PLAYER_DIST or TP_PLAYER_DIST
      local tele_x = tx + off_x
      if not state.theme_info:get_loop() then
        local left, _, right = get_bounds()
        left, right = left - 1.5, right + 1.5
        tele_x = math.min(right, math.max(left, tele_x))
      end
      move_entity(self.uid, tele_x, ty, 0, 0, tl)
      sdata.teleport_timer = TELEPORT_TIMER
      sdata.fx_timer = FX_TIMER
      sdata.target_uid = target_uid
    end
  end

  if sdata.target_uid ~= -1 and get_entity(sdata.target_uid) then
    local tx, ty, tl = get_position(sdata.target_uid)
    local sx, sy, sl = get_position(self.uid)
    local angle = math.atan(ty - sy, tx - sx)
    self.velocityx = math.cos(angle) * VELOCITY
    self.velocityy = math.sin(angle) * VELOCITY
    if tx - sx > 0 then
      self.flags = set_flag(self.flags, ENT_FLAG.FACING_LEFT)
    else
      self.flags = clr_flag(self.flags, ENT_FLAG.FACING_LEFT)
    end
  end
end


---@class TelefraggerData
---@field teleport_timer integer
---@field fx_timer integer
---@field anim_timer integer
---@field target_uid integer

---@class Telefragger : Movable
---@field user_data TelefraggerData

local telefragger_type = EntityDB:new(ENT_TYPE.ITEM_ROCK)
telefragger_type.collision2_mask = MASK.PLAYER

local function spawn_telefragger(x, y, layer)
  local uid = spawn_entity(ENT_TYPE.ITEM_ROCK, x, y, layer, 0 , 0)
  local telefragger = get_entity(uid) --[[@as Telefragger]]
  telefragger.type = telefragger_type
  telefragger.flags = clr_flag(telefragger.flags, ENT_FLAG.COLLIDES_WALLS)
  telefragger.flags = clr_flag(telefragger.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
  telefragger.flags = clr_flag(telefragger.flags, ENT_FLAG.INTERACT_WITH_WATER)
  telefragger.flags = clr_flag(telefragger.flags, ENT_FLAG.INTERACT_WITH_WEBS)
  telefragger.flags = clr_flag(telefragger.flags, ENT_FLAG.PICKUPABLE)
  telefragger.flags = clr_flag(telefragger.flags, 22) -- Carriable through exit
  telefragger.flags = set_flag(telefragger.flags, ENT_FLAG.NO_GRAVITY)
  telefragger.flags = set_flag(telefragger.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
  telefragger.offsety = 0
  telefragger.hitboxx, telefragger.hitboxy = 0.25, 0.325
  telefragger.width, telefragger.height = 1, 1
  telefragger:set_draw_depth(1)
  telefragger:set_texture(telefragger_texture)
  telefragger.user_data = {
    teleport_timer = math.floor(TELEPORT_TIMER * (2/3)) + prng:random(TELEPORT_TIMER),
    fx_timer = FX_TIMER,
    anim_timer = 0,
    target_uid = -1,
  }
  telefragger:set_post_update_state_machine(update_telefragger)
  ---@param player Player
  telefragger:set_pre_on_collision2(function (telefragger, player)
    if player.type.search_flags & MASK.PLAYER ~= 0 and player.invincibility_frames_timer == 0 and player.exit_invincibility_timer == 0 then
      local xvel = player.abs_x - telefragger.abs_x > 0 and 0.1 or -0.1
      player:damage(telefragger, 1, 0, Vec2:new(xvel, 0.1), 0, 0, 60, false)
    end
    return true
  end)
  telefragger.rendering_info:set_pre_render(function (rinfo, offset, render)
    local telefragger = rinfo:get_entity() --[[@as Telefragger]]
    local sdata = telefragger.user_data
    if sdata.fx_timer <= 0 then return end

    local increasing_timer = FX_TIMER - sdata.fx_timer
    local anim_frame = math.min(15, math.floor(increasing_timer / 10))
    local slow_timer = increasing_timer * 0.15
    local width = (math.cos(slow_timer) * 1.5) + 2
    local height = (math.cos(slow_timer + math.pi) * 1.5) + 2
    local aabb = AABB:new(rinfo.x - (width/2), rinfo.y + (height/2), rinfo.x + (width/2), rinfo.y - (height/2))
    -- render:draw_world_texture(TEXTURE.DATA_TEXTURES_PLACEHOLDER_0, 1, 1, AABB:new(), Color:white(), math.pi, 0, 0)
    render:draw_world_texture(telefragger_fx_texture, math.floor(anim_frame / 4), anim_frame % 4, aabb, Color:white(), 0.0, 0.0, 0.0)
    render:draw_world_texture(telefragger_fx_texture, math.floor(anim_frame / 4), anim_frame % 4, aabb, Color:yellow(), math.pi/4, .0, .0)
  end)
  return uid
end

---@type EnemyInfo[]
return {{
  spawn = spawn_telefragger,
  icon_texture = icon_texture,
  name = "Telefragger",
  limit = 3,
}}
