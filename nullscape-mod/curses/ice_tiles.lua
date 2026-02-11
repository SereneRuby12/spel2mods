local floors = {
  ENT_TYPE.FLOOR_GENERIC,
  ENT_TYPE.FLOORSTYLED_BABYLON,
  ENT_TYPE.FLOORSTYLED_BEEHIVE,
  ENT_TYPE.FLOORSTYLED_COG,
  ENT_TYPE.FLOORSTYLED_DUAT,
  ENT_TYPE.FLOORSTYLED_GUTS,
  ENT_TYPE.FLOORSTYLED_MINEWOOD,
  ENT_TYPE.FLOORSTYLED_MOTHERSHIP,
  ENT_TYPE.FLOORSTYLED_PAGODA,
  ENT_TYPE.FLOORSTYLED_PALACE,
  ENT_TYPE.FLOORSTYLED_STONE,
  ENT_TYPE.FLOORSTYLED_SUNKEN,
  ENT_TYPE.FLOORSTYLED_TEMPLE,
  ENT_TYPE.FLOORSTYLED_VLAD
}

local floors_map = {}
for _, type_id in ipairs(floors) do
  floors_map[type_id] = true
end

local function get_solid_grid_at(x, y, layer)
  local uid = get_grid_entity_at(x, y, layer)
  if uid == -1 then return uid end
  return test_flag(get_entity_flags(uid), ENT_FLAG.SOLID) and uid or -1
end

local function pre_valid(x, y, layer)
  if get_solid_grid_at(x, y+1, layer) ~= -1 then return false end
  local _, lava_right = get_liquids_at(x+1, y, layer)
  local _, lava_left = get_liquids_at(x-1, y, layer)
  local _, lava_top = get_liquids_at(x, y+1, layer)
  return lava_right == 0
    and lava_left == 0
    and lava_top == 0
end

local function spawn_ice_floor(x, y, layer)
  local floor_uid = get_grid_entity_at(x, y, layer)
  local floor_type = get_entity_type(floor_uid)
  destroy_grid(floor_uid)
  spawn(ENT_TYPE.FLOOR_ICE, x, y, layer, 0, 0)
  update_liquid_collision_at(x, y, true)
  for sign = -1, 1 do
    for offx = 1, 8 do
      local ix = x + (offx*sign)
      if get_entity_type(get_grid_entity_at(ix, y, layer)) == floor_type and pre_valid(ix, y, layer) then
        destroy_grid(ix, y, layer)
        spawn(ENT_TYPE.FLOOR_ICE, ix, y, layer, 0, 0)
        update_liquid_collision_at(ix, y, true)
      else
        goto continue
      end
    end
    ::continue::
  end
end

local function is_valid_for_replacement(x, y, layer)
  local uid = get_grid_entity_at(x, y, layer)
  if uid == -1 then return false end
  return floors_map[get_entity_type(uid)] ~= nil and pre_valid(x, y, layer)
end

local ice_id = define_procedural_spawn("random_ice", spawn_ice_floor, is_valid_for_replacement)

---@param ctx PostRoomGenerationContext
set_callback(function (ctx)
  if state.screen == SCREEN.LEVEL and ModState.run_curses[CURSE_ID.ICE_TILES] then
    ctx:set_procedural_spawn_chance(ice_id, 10)
  end
end, ON.POST_ROOM_GENERATION)
