local commonlib = require "common"

local mart_texture
local icon_texture
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 1000, 1000
  tdef.tile_width, tdef.tile_height = 200, 200
  tdef.texture_path = "./enemies/assets/mart.png"
  mart_texture = define_texture(tdef)

  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.sub_image_width, tdef.sub_image_height = 0, 0
  tdef.texture_path = "./enemies/assets/icons/mart.png"
  icon_texture = define_texture(tdef)
end

local VELOCITY = 0.0075
local CHANGE_TARGET_TIME = 60 * 4
local SPAWN_CHOOSE_TARGET_TIME = 60 * 1
local NO_DAMAGE_TIME = 60 * 1
local MIN_DUPLICATE_TIMER = 60 * 10
local MAX_DUPLICATE_TIMER = 60 * 30
local MAX_DUPLICATE_DISTANCE = 3
local DUPLICATE_PLAYER_DISTANCE = 5

---@type fun(x: number, y: number, layer: LAYER): integer
local spawn_mart

---@param self Mart
local function update_mart(self)
  local sdata = self.user_data
  sdata.anim_timer = sdata.anim_timer + 1
  sdata.target_timer = sdata.target_timer - 1
  sdata.duplicate_timer = sdata.duplicate_timer - 1
  self.animation_frame = math.floor(sdata.anim_timer / 2) % 24

  if sdata.target_timer <= 0 then
    sdata.target_uid = commonlib.select_target(self, false)
    sdata.target_timer = CHANGE_TARGET_TIME
  end

  if ModState.run_curses[CURSE_ID.MART_INFECTION] and sdata.duplicate_timer <= 0 and (sdata.target_uid == -1 or distance(self.uid, sdata.target_uid) >= DUPLICATE_PLAYER_DISTANCE) then
    local x, y, layer = get_position(self.uid)
    spawn_mart(
      x + (prng:random() * MAX_DUPLICATE_DISTANCE) - (MAX_DUPLICATE_DISTANCE/2),
      y + (prng:random() * MAX_DUPLICATE_DISTANCE) - (MAX_DUPLICATE_DISTANCE/2),
      layer)
    sdata.duplicate_timer = prng:random(MIN_DUPLICATE_TIMER, MAX_DUPLICATE_TIMER)
  end

  if sdata.target_uid ~= -1 and get_entity(sdata.target_uid) then
    local tx, ty, tl = get_position(sdata.target_uid)
    local sx, sy, sl = get_position(self.uid)
    local angle = math.atan(ty - sy, tx - sx)
    self.velocityx = math.cos(angle) * VELOCITY
    self.velocityy = math.sin(angle) * VELOCITY
  else
    self.velocityx = self.velocityx * 0.9
    self.velocityy = self.velocityy * 0.9
  end
end


---@class MartData
---@field target_uid integer
---@field target_timer integer
---@field duplicate_timer integer
---@field anim_timer integer

---@class Mart : Movable
---@field user_data MartData

local mart_type = EntityDB:new(ENT_TYPE.ITEM_ROCK)
mart_type.collision2_mask = MASK.PLAYER | MASK.ITEM

function spawn_mart(x, y, layer)
  if not x then
    local left, top, right, bottom = get_bounds()
    x, y = prng:random() * (right - left) + left, prng:random() * (top - bottom) + bottom
    if math.abs(state.level_gen.spawn_x - x) < 5 or math.abs(state.level_gen.spawn_y - y) < 5 then
      local angle = math.atan(y - state.level_gen.spawn_y, x - state.level_gen.spawn_x)
      x, y = x + math.cos(angle) * 5, y + math.sin(angle) * 5
    end
    layer = LAYER.FRONT
  end
  local uid = spawn_entity(ENT_TYPE.ITEM_ROCK, x, y, layer, 0 , 0)
  local mart = get_entity(uid) --[[@as Mart]]
  mart.type = mart_type
  mart.flags = clr_flag(mart.flags, ENT_FLAG.COLLIDES_WALLS)
  mart.flags = clr_flag(mart.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
  mart.flags = clr_flag(mart.flags, ENT_FLAG.INTERACT_WITH_WATER)
  mart.flags = clr_flag(mart.flags, ENT_FLAG.INTERACT_WITH_WEBS)
  mart.flags = clr_flag(mart.flags, ENT_FLAG.PICKUPABLE)
  mart.flags = clr_flag(mart.flags, 22) -- Carriable through exit
  mart.flags = set_flag(mart.flags, ENT_FLAG.NO_GRAVITY)
  -- mart.flags = set_flag(mart.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
  mart.flags = clr_flag(mart.flags, ENT_FLAG.TAKE_NO_DAMAGE)
  mart.offsety = -0.08
  mart.hitboxx, mart.hitboxy = 0.275, 0.225
  mart.width, mart.height = 1.5, 1.5
  mart:set_draw_depth(1)
  mart:set_texture(mart_texture)
  mart.user_data = {
    target_uid = -1,
    target_timer = SPAWN_CHOOSE_TARGET_TIME,
    anim_timer = 0,
    duplicate_timer = prng:random(MIN_DUPLICATE_TIMER, MAX_DUPLICATE_TIMER),
  }
  mart:set_post_update_state_machine(update_mart)
  ---@param other Movable
  mart:set_pre_on_collision2(function (mart, other)
    if other.type.search_flags & MASK.PLAYER ~= 0 and other.invincibility_frames_timer == 0 and other.exit_invincibility_timer == 0 and mart.invincibility_frames_timer == 0 then
      local xvel = other.abs_x - mart.abs_x > 0 and 0.1 or -0.1
      other:damage(mart, 1, 0, Vec2:new(xvel, 0.1), 0, 0, 60, false)
    end
    return true
  end)
  mart:set_pre_damage(function (self, damage_dealer, damage_amount, damage_flags, velocity, unknown_damage_phase, stun_amount, iframes, unknown_is_final)
    self.invincibility_frames_timer = NO_DAMAGE_TIME
  end)
  return uid
end

---@type EnemyInfo
return {
  spawn = commonlib.spawn_default_fun(spawn_mart),
  icon_texture = icon_texture,
  name = "Mart",
  limit = 1,
}

