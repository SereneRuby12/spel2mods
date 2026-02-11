local exit_templates = {
  [ROOM_TEMPLATE.EXIT] = true,
  [ROOM_TEMPLATE.EXIT_NOTOP] = true,
}

local path_templates = {
  [ROOM_TEMPLATE.PATH_DROP] = true,
  [ROOM_TEMPLATE.PATH_DROP_NOTOP] = true,
  [ROOM_TEMPLATE.PATH_NOTOP] = true,
  [ROOM_TEMPLATE.PATH_NORMAL] = true,
  [ROOM_TEMPLATE.PEN_ROOM] = true,
  [ROOM_TEMPLATE.EXIT] = true,
  [ROOM_TEMPLATE.EXIT_NOTOP] = true,
  [ROOM_TEMPLATE.ENTRANCE] = true,
  [ROOM_TEMPLATE.ENTRANCE_DROP] = true,
}

local path_vertical_templates = {
  [ROOM_TEMPLATE.PATH_DROP] = true,
  [ROOM_TEMPLATE.PATH_DROP_NOTOP] = true,
  [ROOM_TEMPLATE.PATH_NOTOP] = true,
  [ROOM_TEMPLATE.EXIT_NOTOP] = true,
  [ROOM_TEMPLATE.ENTRANCE_DROP] = true,
}

local skip_themes = {
  [THEME.OLMEC] = true,
  [THEME.ABZU] = true,
  [THEME.DUAT] = true,
  [THEME.TIAMAT] = true,
  [THEME.EGGPLANT_WORLD] = true,
  [THEME.HUNDUN] = true,
  [THEME.COSMIC_OCEAN] = true,
}

local function find_exit_room()
  for ry = 0, state.height-1 do
    for rx = 0, state.width-1 do
      if exit_templates[get_room_template(rx, ry, LAYER.FRONT)] then
        return rx, ry
      end
    end
  end
end

local exit_rx, exit_ry

for _, theme_info in pairs(state.level_gen.themes) do
  theme_info:set_post_generate_path(function (self, reset)
    exit_rx, exit_ry = nil, nil
    if state.screen ~= SCREEN.LEVEL
      or not ModState.run_curses[CURSE_ID.BEACON_MIRAGE]
      or (state.level == 4 and state.theme == THEME.DWELLING)
      or skip_themes[state.theme]
    then
      return
    end
    exit_rx, exit_ry = find_exit_room()
    if exit_ry then
      local new_exit_x = prng:random(state.width)-1
      if new_exit_x == exit_rx then
        if new_exit_x == state.width - 1 then
          new_exit_x = new_exit_x - 1
        elseif new_exit_x == 0 then
          new_exit_x = new_exit_x + 1
        else
          new_exit_x = new_exit_x + (prng:random() > 0.5 and -1 or 1)
        end
      end
      local new_template = ROOM_TEMPLATE.EXIT
      if path_vertical_templates[get_room_template(new_exit_x, exit_ry, LAYER.FRONT)] then
        new_template = ROOM_TEMPLATE.EXIT_NOTOP
      end
      local room_gen_ctx = PostRoomGenerationContext:new() --[[@as PostRoomGenerationContext]]
      room_gen_ctx:set_room_template(new_exit_x, exit_ry, LAYER.FRONT, new_template)
      local og_exit_dir = exit_rx - new_exit_x > 0 and 1 or -1
      if not path_templates[get_room_template(new_exit_x + og_exit_dir, exit_ry, LAYER.FRONT)] then
        for x = new_exit_x + og_exit_dir, exit_rx - og_exit_dir, og_exit_dir do
          room_gen_ctx:set_room_template(x, exit_ry, LAYER.FRONT, ROOM_TEMPLATE.PATH_NORMAL)
        end
      end
    end
  end)
end

set_callback(function ()
  if exit_ry then
    local left, _, right, _ = get_bounds()
    local _, top = get_room_pos(0, exit_ry)
    local bottom = top - CONST.ROOM_HEIGHT
    local exits = get_entities_overlapping_hitbox(ENT_TYPE.FLOOR_DOOR_EXIT, MASK.FLOOR, AABB:new(left, top, right, bottom), LAYER.FRONT)
    local num_exits = #exits
    for i = 1, num_exits - 1 do
      local erase_idx = prng:random(#exits)
      get_entity(exits[erase_idx]):destroy()
      exits:erase(erase_idx)
    end
  end
end, ON.POST_LEVEL_GENERATION)
