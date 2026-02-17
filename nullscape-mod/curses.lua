---@enum CURSE_ID
CURSE_ID = {
  ICE_TILES = 1,
  HIGHER_GRAVITY = 2,
  BEACON_MIRAGE = 3,
  MART_INFECTION = 4,
}

---@class CurseData
---@field texture_id TEXTURE
---@field max integer
---@field name string?
---@field description string?
---@field min_level integer?
---@field requirement (fun(): boolean)?

local ice_tiles_texture
local lower_gravity_texture
local beacon_mirage_texture
local mart_infection_texture
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 1024, 1024
  tdef.tile_width, tdef.tile_height = 1024, 1024
  tdef.texture_path = "./enemies/assets/icons/ice_tiles.png"
  ice_tiles_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/icons/lower_gravity.png"
  lower_gravity_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/icons/beacon_mirage.png"
  beacon_mirage_texture = define_texture(tdef)
  tdef.texture_path = "./enemies/assets/icons/mart_infection.png"
  mart_infection_texture = define_texture(tdef)
end

local function no_requirement()
  return true
end

local function level_req_fun(min_level)
  return function ()
    return state.level_count >= min_level
  end
end

local function curse_req_fun(curse_id)
  return function ()
    return ModState.run_curses[curse_id]
  end
end

local function enemy_req_fun(curse_id)
  return function ()
    return ModState.run_curses[curse_id]
  end
end

local function and_fun(...)
  return function ()
    for _, fun in ipairs(arg) do
      if fun() == false then return false end
    end
    return true
  end
end

---@type {[CURSE_ID]: CurseData}
CURSE_DATA = {
  [CURSE_ID.ICE_TILES] = {
    texture_id = ice_tiles_texture,
    max = 1,
    name = "ICE_TILES",
  },
  [CURSE_ID.HIGHER_GRAVITY] = {
    texture_id = lower_gravity_texture,
    max = 1,
    name = "HIGHER_GRAVITY",
  },
  [CURSE_ID.BEACON_MIRAGE] = {
    texture_id = beacon_mirage_texture,
    max = 1,
    name = "BEACON_MIRAGE",
  },
  [CURSE_ID.MART_INFECTION] = {
    texture_id = mart_infection_texture,
    max = 1,
    name = "MART_INFECTION",
    requirement = req_
  },
}

require "curses.ice_tiles"
require "curses.higher_gravity"
require "curses.beacon_mirage"
