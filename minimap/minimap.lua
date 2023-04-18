local map_screen_x, map_screen_y = .0, .0
local map_screen_size = .0, .0
local map_size <const> = 25
local map_alpha = 150
register_option_int("map_alpha", "Map Opacity", "", 120, 1, 255)
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

-- local function get_tile_color_old(tile_type)
--   if tile_type == TILE_TYPE.UNEXPLORED then
--     return rgba(50, 50, 50, map_alpha)
--   elseif tile_type == TILE_TYPE.AIR then
--     return rgba(100, 100, 100, map_alpha)
--   elseif tile_type == TILE_TYPE.SOLID then
--     return rgba(255, 255, 255, map_alpha)
--   elseif tile_type == TILE_TYPE.NON_SOLID then
--     return rgba(200, 200, 200, map_alpha)
--   elseif tile_type == TILE_TYPE.ENTRANCE then
--     return rgba(255, 0, 0, map_alpha)
--   elseif tile_type == TILE_TYPE.EXIT then
--     return rgba(0, 255, 0, map_alpha)
--   elseif tile_type == TILE_TYPE.CO_ORB then
--     return rgba(200, 0, 200, map_alpha)
--   else
--     return rgba(0, 0, 0, 0)
--   end
-- end

local detected_entities = {}
local map = {}
local explored_floor_front = {}
local explored_floor_back = {}
for y = 0, CONST.MAX_TILES_VERT do
  map[y] = {}
  explored_floor_front[y] = {}
  explored_floor_back[y] = {}
end
local explored_floor = explored_floor_front

---@return integer left
---@return integer top
---@return integer right
---@return integer bottom
local function get_camera_bounds_grid()
  -- local width_zoom_factor <const> = 1.47276954
  -- local height_zoom_factor <const> = 0.82850041
  -- local half_cam_width = (get_zoom_level() * width_zoom_factor / 2.)
  -- local half_cam_height = (get_zoom_level() * height_zoom_factor / 2.)
  -- local cam_x, cam_y = state.camera.calculated_focus_x, state.camera.calculated_focus_y
  -- local left, top = math.floor(cam_x - half_cam_width + .5), math.floor(cam_y + half_cam_height + .5)
  -- local right, bottom = math.floor(cam_x + half_cam_width + .5), math.floor(cam_y - half_cam_height + .5)
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
    explored_floor = {}
    map = {}
    for y = 0, CONST.MAX_TILES_VERT do
      map[y] = {}
      explored_floor_front[y] = {}
      explored_floor_back[y] = {}
    end
    explored_floor = explored_floor_front
  end
end, ON.PRE_LOAD_SCREEN)

set_callback(function()
  if map_alpha ~= options.map_alpha then
    map_alpha = options.map_alpha
    update_tile_colors()
  end
  explored_floor = state.camera_layer == LAYER.FRONT and explored_floor_front or explored_floor_back
  local vision_rect = AABB:new(get_camera_bounds_grid())
  local max_x, max_y = state.width * CONST.ROOM_WIDTH, state.height * CONST.ROOM_HEIGHT
  local remainder_max_y = 120 - max_y
  for x = vision_rect.left, vision_rect.right do
    for y = vision_rect.top, vision_rect.bottom, -1 do
      if is_valid_grid_coord(x, y) then
        explored_floor[((y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y][((x - 3) % max_x) + 3] = true
        explored_floor[y][x] = true
      end
    end
  end

  local cam_x, cam_y = math.floor(state.camera.calculated_focus_x+.5), math.floor(state.camera.calculated_focus_y+.5)
  for x = -map_size, map_size do
    for y = map_size, -map_size, -1 do
      local grid_x, grid_y = math.floor(cam_x+x+0.5), math.floor(cam_y+y+0.5)
      grid_x, grid_y = ((grid_x - 3) % max_x) + 3, ((grid_y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y
      if is_valid_grid_coord(grid_x, grid_y) then
        if explored_floor[grid_y][grid_x] then
          local uid = get_grid_entity_at(grid_x, grid_y, state.camera_layer)
          if uid == -1 then
            map[grid_y][grid_x] = TILE_TYPE.AIR
          elseif test_flag(get_entity_flags(uid), ENT_FLAG.SOLID) then
            map[grid_y][grid_x] = TILE_TYPE.SOLID
          elseif get_entity_type(uid) == ENT_TYPE.FLOOR_DOOR_EXIT then
            map[grid_y][grid_x] = TILE_TYPE.EXIT
          elseif get_entity_type(uid) == ENT_TYPE.FLOOR_DOOR_ENTRANCE then
            map[grid_y][grid_x] = TILE_TYPE.ENTRANCE
          else
            map[grid_y][grid_x] = TILE_TYPE.NON_SOLID
          end
        elseif grid_x >= 0 then
          map[grid_y][grid_x] = TILE_TYPE.UNEXPLORED
        end
      end
    end
  end
  local orbs = get_entities_by(ENT_TYPE.ITEM_FLOATING_ORB, MASK.ITEM, LAYER.FRONT)
  for _, uid in pairs(orbs) do
    local x, y = get_position(uid)
    x, y = math.floor(x+.5), math.floor(y+.5)
    if explored_floor[y] and explored_floor[y][x] then
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
end, ON.GAMEFRAME)

local window_open = true
register_option_button("open_window", "Move map", "Open a window that allows to move the map position and change size. You can close it after editing it", function ()
	window_open = true
end)
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
  local size_x, size_y = map_screen_size, (map_screen_size * 16) / 9
  local cam_x, cam_y = math.floor(state.camera.calculated_focus_x+.5), math.floor(state.camera.calculated_focus_y+.5)
  local rect = AABB:new(.0, .0, .0, .0) -- Using one AABB variable for better performance
  local sq_size_y = (size_y / (map_size * 2 + 1))
  local sq_size_x = (size_x / (map_size * 2 + 1))
  local render_x = .0
  local max_x, max_y = state.width * CONST.ROOM_WIDTH, state.height * CONST.ROOM_HEIGHT
  local remainder_max_y = 120 - max_y
  for x = -map_size, map_size do
    local render_y = .0
    for y = map_size, -map_size, -1 do
      local grid_x, grid_y = cam_x+x, cam_y+y
      grid_x, grid_y = ((grid_x - 3) % max_x) + 3, ((grid_y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y
      if explored_floor[grid_y] and explored_floor[grid_y][grid_x] then
        local color = get_tile_color(map[grid_y] and map[grid_y][grid_x])
        rect.left, rect.top, rect.right, rect.bottom = render_x, render_y, render_x+sq_size_x, render_y-sq_size_y
        rect:offset(map_screen_x, map_screen_y)
        ctx:draw_rect_filled(rect, 0, color)
      end
      render_y = render_y - sq_size_y
    end
    render_x = render_x + sq_size_x
  end
  ctx:draw_rect(AABB:new(map_screen_x, map_screen_y, map_screen_x+size_x, map_screen_y-size_y), 1, 0, 0xffffffff)
end, ON.GUIFRAME)