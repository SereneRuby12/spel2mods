---@diagnostic disable-next-line: lowercase-global
meta = {
  author = "Estebanfer",
  name = "Mini Map",
  description = "Adds a simple mini map",
  version = "0.8",
  online_safe = true
}

local map_size_x, map_size_y = 25, 25
local map_visible = true
local map_alpha = 150

---@enum MAP_TYPE
local MAP_TYPE = {
  FOLLOW_PLAYER = 1,
  FULL_MAP = 2,
}

---@class WindowInfo
---@field x number
---@field y number
---@field w number
---@field h number

---@class ModOptions
---@field map_alpha integer
---@field refresh_modulo integer
---@field all_players boolean
---@field draw_border boolean
---@field window_open boolean
---@field map_type MAP_TYPE
---@field map_size_x integer
---@field map_size_y integer
---@field window_info WindowInfo
local default_options = {
  map_alpha = 120,
  map_size_x = 25,
  map_size_y = 25,
  refresh_modulo = 1,
  all_players = true,
  draw_border = true,
  window_open = true,
  map_type = MAP_TYPE.FOLLOW_PLAYER,
  window_info = { x = -0.96, y = 0.732, w = 0.2, h = 0.0 }
}

---@type ModOptions
---@diagnostic disable-next-line: lowercase-global
options = { table.unpack(default_options) }

register_option_int("map_alpha", "Map Opacity", "", 120, 1, 255)
register_option_int("refresh_modulo", "Refresh map 1/x of the frames", "Try increasing this if you have performance issues", 1, 1, 10)
register_option_bool("all_players", "Reveal map from all players' positions", "Other players will also reveal map tiles. Might have effects on performance", true)
register_option_bool("draw_border", "Draw map border", "", true)
register_option_button("open_window", "Move map", "Open a window that allows to move the map position and change size. You can close it after editing", function ()
	options.window_open = true
end)
register_option_button("reset_options", "Reset settings", "", function ()
  for key, value in pairs(default_options) do
    options[key] = value
  end
end)
register_option_callback("map_type_stuff", false, function (draw_ctx)
	options.map_type = draw_ctx:win_combo("Map type", options.map_type, "Follow player\0Full map\0\0") --[[@as MAP_TYPE]]
  if options.map_type == MAP_TYPE.FOLLOW_PLAYER then
    draw_ctx:win_indent(20.0)
    draw_ctx:win_text("Map size, distance from the center of the camera in tiles")
  	options.map_size_x = draw_ctx:win_drag_int("Horizontal map size", options.map_size_x, 1, 50)
  	options.map_size_y = draw_ctx:win_drag_int("Vertical map size", options.map_size_y, 1, 50)
    draw_ctx:win_indent(-20.0)
  end
end)
-- register_option_combo("map_type", "Map type", "", "Follow player\0Full map\0\0", 2)

set_callback(function(save_ctx)
  local saved_options = json.encode({options})
  save_ctx:save(saved_options)
end, ON.SAVE)

set_callback(function(load_ctx)
  local loaded_options_str= load_ctx:load()
  if loaded_options_str ~= "" then
      options = json.decode(loaded_options_str)[1]
  end
  --Make it work when new options are added
  for key, def_val in pairs(default_options) do
    if options[key] == nil then
      options[key] = def_val
    end
  end
end, ON.LOAD)
-- register_option_callback("", false, function (draw_ctx)
--   options.map_alpha = draw_ctx:win_slider_int("map_type", options.map_alpha, 1, 255)
--   options.map_size_x = draw_ctx:win_slider_int("map_size_x", 25, 1, 50)
--   options.map_size_y = draw_ctx:win_slider_int("map_size_y", 25, 1, 50)
--   options.refresh_modulo = draw_ctx:win_slider_int("refresh_modulo", 1, 1, 10)
--   options.all_players = draw_ctx:win_check("all_players", "Reveal map from all players' positions", "Other players will also reveal map tiles. Might have effects on performance", true)
--   options.draw_border = draw_ctx:win_check("draw_border", "Draw map border", "", true)
-- end)
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
local border_color
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
  border_color = rgba(255, 255, 255, map_alpha)
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

local half_cam_width, half_cam_height
do
  local default_zoom = 13.5
  local width_zoom_factor = 1.47276954
  local height_zoom_factor = 0.82850041
  half_cam_width = (default_zoom * width_zoom_factor / 2.)
  half_cam_height = (default_zoom * height_zoom_factor / 2.)
end

---@return integer left
---@return integer top
---@return integer right
---@return integer bottom
local function get_camera_bounds_grid_pos(cam_x, cam_y)
  local left, top = math.floor(cam_x - half_cam_width + .5), math.floor(cam_y + half_cam_height + .5)
  local right, bottom = math.floor(cam_x + half_cam_width + .5), math.floor(cam_y - half_cam_height + .5)
  return left, top, right, bottom
end

local function is_valid_grid_coord(x, y)
  return x >= 0 and x < CONST.MAX_TILES_HORIZ and y >= 0 and y < CONST.MAX_TILES_VERT
end

local last_time = -1

set_callback(function()
  last_time = -1
  map = {}
  draw_map = {}
  local local_state = get_local_state() --[[@as StateMemory]]
  if options.map_type == MAP_TYPE.FULL_MAP then
    map_size_x = math.floor(((local_state.width * CONST.ROOM_WIDTH + 6) + 0.5) / 2)
    map_size_y = math.floor(((local_state.height * CONST.ROOM_HEIGHT + 6) + 0.5) / 2)
  elseif options.map_type == MAP_TYPE.FOLLOW_PLAYER then
    map_size_x = options.map_size_x
    map_size_y = options.map_size_y
  end
  for y = 0, CONST.MAX_TILES_VERT do
    map_front[y] = {}
    map_back[y] = {}
  end
end, ON.POST_LEVEL_GENERATION)

local function update_map(local_map, layer, left, top, right, bottom)
  local local_state = get_local_state() --[[@as StateMemory]]
  local max_x, max_y = local_state.width * CONST.ROOM_WIDTH, local_state.height * CONST.ROOM_HEIGHT
  local remainder_max_y = 120 - max_y
  for x = left, right do
    for y = top, bottom, -1 do
      if local_state.theme == THEME.COSMIC_OCEAN then
        x, y = ((x - 3) % max_x) + 3, ((y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y
      end
      if is_valid_grid_coord(x, y) then
        local uid = get_grid_entity_at(x, y, layer)
        if uid == -1 then
          local_map[y][x] = TILE_TYPE.AIR
        elseif test_flag(get_entity_flags(uid), ENT_FLAG.SOLID) then
          local_map[y][x] = TILE_TYPE.SOLID
        elseif get_entity_type(uid) == ENT_TYPE.FLOOR_DOOR_EXIT then
          local_map[y][x] = TILE_TYPE.EXIT
        elseif get_entity_type(uid) == ENT_TYPE.FLOOR_DOOR_ENTRANCE then
          local_map[y][x] = TILE_TYPE.ENTRANCE
        else
          local_map[y][x] = TILE_TYPE.NON_SOLID
        end
      end
    end
  end
end

local last_button_time, button_pressed = 0, false
set_callback(function()
  if map_alpha ~= options.map_alpha then
    map_alpha = options.map_alpha
    update_tile_colors()
  end
  local local_state = get_local_state() --[[@as StateMemory]]
  map = local_state.camera_layer == LAYER.FRONT and map_front or map_back
  local player_buttons = local_state.player_inputs.player_slots[online.lobby.local_player_slot].buttons
  if player_buttons & BUTTON.DOOR ~= 0 then
    if button_pressed then
      if local_state.time_startup > last_button_time + 30 then
        last_button_time = math.maxinteger - 30
        map_visible = not map_visible
      end
    else
      button_pressed = true
      last_button_time = local_state.time_startup
    end
  else
    button_pressed = false
  end

  if get_frame() % options.refresh_modulo > 0 or local_state.screen ~= SCREEN.LEVEL or local_state.time_startup == last_time or local_state.pause ~= 0 then return end

  last_time = local_state.time_startup
  update_map(map, local_state.camera_layer, get_camera_bounds_grid())
  if options.all_players then
    local players = get_local_players()
    for _, p in pairs(players) do
      if p.health > 0 and p.uid ~= local_state.camera.focused_entity_uid then
        local x, y, layer = get_position(p.uid)
        local layer_map = p.layer == LAYER.FRONT and map_front or map_back
        update_map(layer_map, layer, get_camera_bounds_grid_pos(x, y))
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
  local focused_uid = local_state.camera.focused_entity_uid
  if focused_uid ~= -1 then
    local x, y = get_position(focused_uid)
    x, y = math.floor(x+.5), math.floor(y+.5)
    if map[y] then
      map[y][x] = TILE_TYPE.PLAYER
    end
  end
  local max_x, max_y = local_state.width * CONST.ROOM_WIDTH, local_state.height * CONST.ROOM_HEIGHT
  local remainder_max_y = 120 - max_y
  local cam_x, cam_y
  if options.map_type == MAP_TYPE.FOLLOW_PLAYER then
    cam_x, cam_y = math.floor(local_state.camera.calculated_focus_x+.5), math.floor(local_state.camera.calculated_focus_y+.5)
  elseif options.map_type == MAP_TYPE.FULL_MAP then
    local left, top, right, bottom = get_bounds()
    cam_x, cam_y = math.floor((left + right) / 2), math.floor((top + bottom) / 2)
  end
  draw_map = {}
  local last_draw_map_index = 1
  for x = -map_size_x, map_size_x do
    local forming_column_start_y = 0
    local forming_column_tile = nil
    for y = map_size_y, -map_size_y, -1 do
      local grid_x, grid_y = cam_x+x, cam_y+y
      if local_state.theme == THEME.COSMIC_OCEAN then
        grid_x, grid_y = ((grid_x - 3) % max_x) + 3, ((grid_y-remainder_max_y - 3) % max_y) + 3 + remainder_max_y
      end
      if map[grid_y] and forming_column_tile ~= map[grid_y][grid_x] then
        if forming_column_tile ~= nil then
          draw_map[last_draw_map_index] = {x = x+map_size_x, y = forming_column_start_y-map_size_y, last_y = y-map_size_y, tile = forming_column_tile}
          last_draw_map_index = last_draw_map_index + 1
        end
        forming_column_start_y = y
        forming_column_tile = map[grid_y] and map[grid_y][grid_x]
      end
    end
    if forming_column_tile ~= nil then
      draw_map[last_draw_map_index] = {x = x+map_size_x, y = forming_column_start_y-map_size_y, last_y = -map_size_y*2, tile = forming_column_tile}
      last_draw_map_index = last_draw_map_index + 1
    end
  end
end, ON.GUIFRAME)


---@param ctx GuiDrawContext
set_callback(function (ctx)
  local win = options.window_info
  if options.window_open then
    ---@param ctx GuiDrawContext
    options.window_open = ctx:window("Move map", win.x, win.y, win.w, win.h, true, function(ctx, pos, size)
      win.x, win.y, win.w, win.h = pos.x, pos.y, size.x, size.y
    end)
  end
  if options.map_type == MAP_TYPE.FOLLOW_PLAYER then
    map_size_x = options.map_size_x
    map_size_y = options.map_size_y
  end
  local local_state = get_local_state() --[[@as StateMemory]]
  if win.w == math.huge or local_state.screen ~= SCREEN.LEVEL or not map_visible then return end -- Prevent infinity error, don't render if not visible
  --render map
  local size_x, size_y = win.w, (win.w * 16) / 9
  local rect = AABB:new(.0, .0, .0, .0) -- Using one AABB variable for better performance
  local sq_size_y = (size_y / (map_size_x * 2 + 1))
  local sq_size_x = (size_x / (map_size_x * 2 + 1))
  for _, line in pairs(draw_map) do
    local color = get_tile_color(line.tile)
    rect.left, rect.top, rect.right, rect.bottom = line.x*sq_size_x, line.y*sq_size_y, line.x*sq_size_x+sq_size_x, line.last_y*sq_size_y
    rect:offset(win.x, win.y)
    ctx:draw_rect_filled(rect, 0, color)
  end
  if options.draw_border then
    local bottom_pos = win.y - (sq_size_y * map_size_y*2)
    ctx:draw_rect(AABB:new(win.x, win.y, win.x+size_x, bottom_pos), 1, 0, border_color)
  end
end, ON.GUIFRAME)