local map_screen_x, map_screen_y = .0, .0
local map_screen_size = .0, .0
local map_size <const> = 25
local map_alpha = 150

local window_open = true
register_option_int("map_alpha", "Map Opacity", "", 120, 1, 255)
register_option_int("refresh_modulo", "Refresh map 1/x of the frames", "Try increasing to 2-4 if you have performance issues", 1, 1, 10)
register_option_button("open_window", "Move map", "Open a window that allows to move the map position and change size. You can close it after editing it", function ()
	window_open = true
end)
local TILE_TYPE = {
  UNEXPLORED = 0,
  AIR = 1,
  SOLID = 2,
  NON_SOLID = 3,
  EXIT = 4,
  ENTRANCE = 5,
  PLAYER = 6,
  CO_ORB = 7,
}
local TILE_COLOR = {}
local function update_tile_colors()
  TILE_COLOR = {
    [TILE_TYPE.UNEXPLORED] = rgba(50, 50, 50, map_alpha),
    [TILE_TYPE.AIR] = rgba(100, 100, 100, map_alpha),
    [TILE_TYPE.SOLID] = rgba(255, 255, 255, map_alpha),
    [TILE_TYPE.NON_SOLID] = rgba(200, 200, 200, map_alpha),
    [TILE_TYPE.EXIT] = rgba(0, 255, 0, map_alpha),
    [TILE_TYPE.ENTRANCE] = rgba(255, 0, 0, map_alpha),
    [TILE_TYPE.PLAYER] = rgba(255, 200, 0, map_alpha),
    [TILE_TYPE.CO_ORB] = rgba(200, 0, 200, map_alpha),
  }
end
update_tile_colors()

local function get_tile_color(tile_type)
  if tile_type == nil then
    return rgba(0, 0, 0, 0)
  else
    return TILE_COLOR[tile_type]
  end
end

local map_front = {}
local map_back = {}
local draw_map = {}
for y = 0, CONST.MAX_TILES_VERT do
  map_front[y] = {}
  map_back[y] = {}
end
local map = map_front

---@return integer left
---@return integer top
---@return integer right
---@return integer bottom
local function get_camera_bounds_grid()
  local left, top = game_position(-1, 1)
  local right, bottom = game_position(1, -1)
  left, top, right, bottom = math.floor(left+.5), math.floor(top+.5), math.floor(right+.5), math.floor(bottom+.5)
  return left, top, right, bottom
end

local function is_valid_grid_coord(x, y)
  return x >= 0 and x < CONST.MAX_TILES_HORIZ and y >= 0 and y < CONST.MAX_TILES_VERT
end

set_callback(function()
  if (state.screen_next == SCREEN.TRANSITION and state.screen ~= SCREEN.SPACESHIP)
      or state.screen_next == SCREEN.SPACESHIP
      or (state.screen ~= SCREEN.OPTIONS and state.screen_next == SCREEN.LEVEL)
  then
    map = {}
    draw_map = {}
    for y = 0, CONST.MAX_TILES_VERT do
      map_front[y] = {}
      map_back[y] = {}
    end
  end
end, ON.PRE_LOAD_SCREEN)

set_callback(function()
  if map_alpha ~= options.map_alpha then
    map_alpha = options.map_alpha
    update_tile_colors()
  end
  map = state.camera_layer == LAYER.FRONT and map_back or map_front
  if get_frame() % options.refresh_modulo > 0 then return end
  local vision_rect = AABB:new(get_camera_bounds_grid())
  local max_x, max_y = state.width * CONST.ROOM_WIDTH, state.height * CONST.ROOM_HEIGHT
  local remainder_max_y = 120 - max_y
  for x = vision_rect.left, vision_rect.right do
    for y = vision_rect.top, vision_rect.bottom, -1 do
      if state.theme == THEME.COSMIC_OCEAN then
        x, y = ((x - 3) % max_x) + 3, ((y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y
      end
      if is_valid_grid_coord(x, y) then
        local uid = get_grid_entity_at(x, y, state.camera_layer)
        if uid == -1 then
          map[y][x] = TILE_TYPE.AIR
        elseif test_flag(get_entity_flags(uid), ENT_FLAG.SOLID) then
          map[y][x] = TILE_TYPE.SOLID
        elseif get_entity_type(uid) == ENT_TYPE.FLOOR_DOOR_EXIT then
          map[y][x] = TILE_TYPE.EXIT
        elseif get_entity_type(uid) == ENT_TYPE.FLOOR_DOOR_ENTRANCE then
          map[y][x] = TILE_TYPE.ENTRANCE
        else
          map[y][x] = TILE_TYPE.NON_SOLID
        end
      elseif x >= 0 then
        map[y][x] = TILE_TYPE.UNEXPLORED
      end
    end
  end

  local orbs = get_entities_by(ENT_TYPE.ITEM_FLOATING_ORB, MASK.ITEM, LAYER.FRONT)
  for _, uid in pairs(orbs) do
    local x, y = get_position(uid)
    x, y = math.floor(x+.5), math.floor(y+.5)
    if map[y] and map[y][x] then
      map[y][x] = TILE_TYPE.CO_ORB
    end
  end
  local focused_uid = state.camera.focused_entity_uid
  if focused_uid ~= -1 then
    local x, y = get_position(focused_uid)
    x, y = math.floor(x+.5), math.floor(y+.5)
    if map[y] then
      map[y][x] = TILE_TYPE.PLAYER
    end
  end
  local cam_x, cam_y = math.floor(state.camera.calculated_focus_x+.5), math.floor(state.camera.calculated_focus_y+.5)
  draw_map = {}
  local last_draw_map_index = 1
  for x = -map_size, map_size do
    local forming_column_start_y = 0
    local forming_column_tile = -1
    for y = map_size, -map_size, -1 do
      local grid_x, grid_y = math.floor(cam_x+x+0.5), math.floor(cam_y+y+0.5)
      if state.theme == THEME.COSMIC_OCEAN then
        grid_x, grid_y = ((grid_x - 3) % max_x) + 3, ((grid_y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y
      end
      if map[grid_y] and forming_column_tile ~= map[grid_y][grid_x] then
        if forming_column_tile ~= -1 then
          draw_map[last_draw_map_index] = {x = x+map_size, y = forming_column_start_y-map_size, last_y = y-map_size, tile = forming_column_tile}
          last_draw_map_index = last_draw_map_index + 1
        end
        forming_column_start_y = y
        forming_column_tile = map[grid_y] and map[grid_y][grid_x]
      end
    end
    draw_map[last_draw_map_index] = {x = x+map_size, y = forming_column_start_y-map_size, last_y = -map_size*2, tile = forming_column_tile}
    last_draw_map_index = last_draw_map_index + 1
  end
end, ON.GAMEFRAME)

---@param ctx GuiDrawContext
set_callback(function (ctx)
  if window_open then
  ---@param ctx GuiDrawContext
    window_open = ctx:window("Map", -0.95, 0.74, 0.2, 0.2, true, function(ctx, pos, size)
      map_screen_x, map_screen_y = pos.x, pos.y
      map_screen_size = size.x
    end)
  end
  if map_screen_size == math.huge then return end -- Prevent infinity error
  --render map
  local size_x, size_y = map_screen_size, (map_screen_size * 16) / 9
  local rect = AABB:new(.0, .0, .0, .0) -- Using one AABB variable for better performance
  local sq_size_y = (size_y / (map_size * 2 + 1))
  local sq_size_x = (size_x / (map_size * 2 + 1))
  for _, line in pairs(draw_map) do
    local color = get_tile_color(line.tile)
    rect.left, rect.top, rect.right, rect.bottom = line.x*sq_size_x, line.y*sq_size_y, line.x*sq_size_x+sq_size_x, line.last_y*sq_size_y
    rect:offset(map_screen_x, map_screen_y)
    ctx:draw_rect_filled(rect, 0, color)
  end
  ctx:draw_rect(AABB:new(map_screen_x, map_screen_y, map_screen_x+size_x, map_screen_y-size_y), 1, 0, 0xffffffff)
end, ON.GUIFRAME)