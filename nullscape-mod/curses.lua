---@enum CURSE_ID
CURSE_ID = {
  ICE_TILES = 1,
  HIGHER_GRAVITY = 2,
  BEACON_MIRAGE = 3,
  MART_INFECTION = 4,
}

CURSE_NUM = 4

---@class CurseData
---@field texture_id TEXTURE
---@field max integer
---@field name string?
---@field description string?

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

---@type CurseData[]
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
  },
}

require "curses.ice_tiles"
require "curses.higher_gravity"
require "curses.beacon_mirage"
