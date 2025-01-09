meta.name = "Slowmo"
meta.version = "1.2"
meta.description = "The game goes slower when close to being hit, after hit or when RUN + DOOR are pressed"
meta.author = "SereneRuby12"

--[[
Possible stuff to add to dangers slowmo:
- [ ] still not enough time to react on some cases???
- [ ] Maybe try adding a check if the entity is gonna get stopped by floors and prevent slowmo
]]

---@class ModOptions
---@field enable_hit_slowmo boolean
---@field slow_time number
---@field max_hp number
---@field hit_slowness number
---@field enable_trigger_slowmo boolean
---@field trigger_slowness number
---@field enable_danger_slowmo boolean
---@field danger_normal_slowness number
---@field danger_extra_slowness number
---@field danger_extra_player_stats boolean
---@field danger_extra_player_max_speed number
---@field danger_extra_player_acceleration number
local default_options = {
  enable_hit_slowmo = true,
  slow_time = 3,
  max_hp = 4,
  hit_slowness = 0.75,
  enable_trigger_slowmo = true,
  trigger_slowness = 0.5,
  enable_danger_slowmo = true,
  danger_normal_slowness = 0.2,
  danger_extra_slowness = 0.125,
  danger_extra_player_stats = true,
  danger_extra_player_max_speed = 0.025,
  danger_extra_player_acceleration = 0.025,
}
---@type ModOptions
---@diagnostic disable-next-line: missing-fields
options = { table.unpack(default_options) }

---@class TrackedObject
---@field x integer
---@field y integer
---@field time integer
---@field in_slowmo_range boolean

---@type TrackedObject[]
local tracked_objects = {}
---@type table<integer, boolean>
local objects_in_range = {}

local IGNORED_ENTITIES = {
  [ENT_TYPE.ITEM_BLOOD] = true,
  [ENT_TYPE.ITEM_DEPLOYED_PARACHUTE] = true,
  [ENT_TYPE.ITEM_GOLDBAR] = true,
  [ENT_TYPE.ITEM_GOLDBARS] = true,
  [ENT_TYPE.ITEM_DIAMOND] = true,
  [ENT_TYPE.ITEM_EMERALD] = true,
  [ENT_TYPE.ITEM_SAPPHIRE] = true,
  [ENT_TYPE.ITEM_RUBY] = true,
  [ENT_TYPE.ITEM_NUGGET] = true,
  [ENT_TYPE.ITEM_GOLDCOIN] = true,
  [ENT_TYPE.ITEM_EMERALD_SMALL] = true,
  [ENT_TYPE.ITEM_SAPPHIRE_SMALL] = true,
  [ENT_TYPE.ITEM_RUBY_SMALL] = true,
  [ENT_TYPE.ITEM_NUGGET_SMALL] = true,
  [ENT_TYPE.MONS_MEGAJELLYFISH_BACKGROUND] = true,
}
for str, type_id in pairs(ENT_TYPE) do
  if str:find("MONS_CRITTER") == 1
    or str:find("ITEM_PICKUP") == 1
  then
    IGNORED_ENTITIES[type_id] = true
  end
end

local custom_player_types = {}

-- register_option_bool("only_offscreen_entities", "Enable slowmo only on fast entities from offscreen", "", true)

local function get_angles_diff(a1, a2)
  local diff = math.abs(a1 - a2)
  if diff > math.pi then
    diff = (math.pi * 2) - diff
  end
  return diff
end

-- get the discriminant of the intersection of line and circle
local function get_discriminant_relative(x, y, vx, vy, radius)
  --[[
dr = math.sqrt(vx*vx + vy*vy)
D = x1*y2 - x2*y1
disc = (r*r)(dr*dr)-(D*D)
  ]]
  local dr = math.sqrt((vx*vx) + (vy*vy))
  local D = (x * (y+vy)) - ((x+vx) * y)
  return ((radius*radius)*(dr*dr)) - (D*D)
end

---@enum SpeedHackSource
local SPEEDHACK_SOURCE = {
  DANGER_CLOSE = 1,
  DANGER_VERY_CLOSE = 2,
  GOT_HIT = 3,
  TOGGLED = 4,
}

---@class SpeedHackSourceInfo
---@field enabled boolean
---@field value number
---@field default_value number?

---@type table<SpeedHackSource, SpeedHackSourceInfo>
local speedhack_source_info = {
  [SPEEDHACK_SOURCE.DANGER_CLOSE] = {
    enabled = false,
    value = 0.2,
    default_value = 0.2
  },
  [SPEEDHACK_SOURCE.GOT_HIT] = {
    enabled = false,
    value = 0.5,
  },
  [SPEEDHACK_SOURCE.TOGGLED] = {
    enabled = false,
    value = 0.5,
  },
}

local set_speedhack_og = set_speedhack
local current_speedhack = 1.0
local target_speedhack = 1.0
---@param source SpeedHackSource
---@param val number?
local function set_speedhack(source, val)
  local cur_speedhack_info = speedhack_source_info[source]
  cur_speedhack_info.enabled = true
  if val then
    if val > target_speedhack then return end
    cur_speedhack_info.value = val
  end
  target_speedhack = cur_speedhack_info.value
end

---@param source SpeedHackSource
local function reset_speedhack(source)
  local cur_speedhack = speedhack_source_info[source]
  cur_speedhack.enabled = false
  if cur_speedhack.default_value then
    cur_speedhack.value = cur_speedhack.default_value
  end

  local to_set_speedhack = 1.0
  for _, source_info in pairs(speedhack_source_info) do
    if source_info.enabled and source_info.value < to_set_speedhack then
      to_set_speedhack = source_info.value
    end
  end
  target_speedhack = to_set_speedhack
end

local function update_speedhack()
  local vel = target_speedhack > current_speedhack and 0.05 or 0.25
  local sign = target_speedhack > current_speedhack and 1.0 or -1.0
  if math.abs(current_speedhack - target_speedhack) < vel then
    current_speedhack = target_speedhack
  else
    current_speedhack = current_speedhack + (vel * sign)
  end
  set_speedhack_og(current_speedhack)
end

local function track_entity(player_uid, aabb_shrink, uid, ex, ey)
  if IGNORED_ENTITIES[get_entity_type(uid)] or uid == state.camera.focused_entity_uid then return end
  local tracked_object = tracked_objects[uid]
  if not tracked_object then
    local time = aabb_shrink:is_point_inside(ex, ey) and 30 or 0
    tracked_object = { time = time, in_slowmo_range = false, x = ex, y = ey}
    tracked_objects[uid] = tracked_object
  end
  tracked_object.x, tracked_object.y = ex, ey
  if tracked_object.time < 30 or tracked_object.in_slowmo_range then
    local ent = get_entity(uid) --[[@as Movable]]
    local px, py = get_position(player_uid)
    local pvx, pvy = get_velocity(player_uid)
    local evx, evy = get_velocity(uid)
    local rvx, rvy = evx-pvx, evy-pvy
    local dist_x, dist_y = ex-px, ey-py
    local disc = get_discriminant_relative(dist_x, dist_y, rvx, rvy, 1.75)
    local sq_dist = (dist_x*dist_x) + (dist_y*dist_y)
    local velocity_angle = math.atan(rvy, rvx)
    local entities_angle = math.atan(py-ey, px-ex)
    if (
        get_angles_diff(velocity_angle, entities_angle) <= math.pi / 2
        or ent:overlaps_with(get_hitbox(player_uid):extrude(1.5))
      ) and disc >= 0
      and (math.abs(ent.velocityx) > 0.2 or math.abs(ent.velocityy) > 0.2)
    then
      -- local dist = distance(player_uid, uid)
      -- set_speedhack(math.max(dist * 0.1, 0.25))
      set_speedhack(SPEEDHACK_SOURCE.DANGER_CLOSE, (rvy < -0.3 or sq_dist < 25) and options.danger_extra_slowness or options.danger_normal_slowness) -- 0.125 or 0.2) --High vertical speed or 5 blocks of dist
      tracked_object.in_slowmo_range = true
      objects_in_range[uid] = true
    elseif tracked_object.in_slowmo_range then
      objects_in_range[uid] = nil
      tracked_object.in_slowmo_range = false
      if next(objects_in_range) == nil then
        reset_speedhack(SPEEDHACK_SOURCE.DANGER_CLOSE)
      end
    end
  end
  tracked_object.time = tracked_object.time + 1
end

local function track_entities(player_uid, aabb_shrink, uids, convert_pos)
  for _, uid in pairs(uids) do
    local x, y = get_position(uid)
    x, y = convert_pos(x, y)
    track_entity(player_uid, aabb_shrink, uid, x, y)
  end
end

---@return AABB
local function get_screen_aabb()
  local left, top = game_position(-1, 1)
  local right, bottom = game_position(1, -1)
  return AABB:new(left, top, right, bottom)
end

local TRACKED_MASK = MASK.PLAYER | MASK.MOUNT | MASK.MONSTER | MASK.ITEM | MASK.ACTIVEFLOOR

---@type integer, integer, integer, integer
local level_bottom, level_top, level_xsize, level_ysize = .0, .0, .0, .0

---@param cam AABB
---@param player_uid integer
---@param aabb_shrink AABB
local function track_bottom_n_top_entities(cam, player_uid, aabb_shrink, level_side_sign)
  if cam.top > level_top then
    local actual_top = cam.top - level_ysize
    local entities_loop = get_entities_overlapping_hitbox(0, TRACKED_MASK, AABB:new(cam.left, actual_top, cam.right, level_bottom), LAYER.PLAYER)
    track_entities(player_uid, aabb_shrink, entities_loop, function (x, y)
      return x + (level_xsize * level_side_sign), y + level_ysize
    end)
  elseif cam.bottom < level_bottom then
    local actual_bottom = cam.bottom + level_ysize
    local entities_loop = get_entities_overlapping_hitbox(0, TRACKED_MASK, AABB:new(cam.right, actual_bottom, cam.right, level_top), LAYER.PLAYER)
    track_entities(player_uid, aabb_shrink, entities_loop, function (x, y)
      return x + (level_xsize * level_side_sign), y - level_ysize
    end)
  end
end

set_callback(function()
  local player_uid = state.camera.focused_entity_uid
  local player_type_id = get_entity_type(player_uid)
  if player_type_id == 0xFFFFFFFF or get_type(player_type_id).search_flags & MASK.PLAYER == 0 then return end
  local player = get_entity(player_uid)
  local aabb = get_screen_aabb()
  local aabb_shrink = AABB:new(aabb):extrude(-0.75)
  local entities = get_entities_overlapping_hitbox(0, TRACKED_MASK, aabb, LAYER.PLAYER)
  do
    local left, top, right, bottom = get_bounds()
    level_top, level_bottom = top, bottom
    level_xsize, level_ysize = right - left, top - bottom
    if aabb.left < left then
      local actual_left = aabb.left + level_xsize
      local actual_aabb = AABB:new(actual_left, aabb.top, right, aabb.bottom)
      track_bottom_n_top_entities(actual_aabb, player_uid, aabb_shrink, -1.)
      local entities_loop = get_entities_overlapping_hitbox(0, TRACKED_MASK, actual_aabb, LAYER.PLAYER)
      track_entities(player_uid, aabb_shrink, entities_loop, function (x, y)
        return x - level_xsize, y
      end)
    end
    if aabb.right > right then
      local actual_right = aabb.right - level_xsize
      local actual_aabb = AABB:new(left, aabb.top, actual_right, aabb.bottom)
      track_bottom_n_top_entities(aabb, player_uid, aabb_shrink, 1.)
      local entities_loop = get_entities_overlapping_hitbox(0, TRACKED_MASK, actual_aabb, LAYER.PLAYER)
      track_entities(player_uid, aabb_shrink, entities_loop, function (x, y)
        return x + level_xsize, y
      end)
    end
    track_bottom_n_top_entities(aabb, player_uid, aabb_shrink, 0.)
  end
  for _, uid in pairs(entities) do
    local x, y = get_position(uid)
    track_entity(player_uid, aabb_shrink, uid, x, y)
  end
  for uid, obj in pairs(tracked_objects) do
    if get_entity(uid) == nil or not aabb:is_point_inside(obj.x, obj.y) then
      objects_in_range[uid] = nil
      tracked_objects[uid] = nil
    end
  end
  if next(objects_in_range) == nil then
    reset_speedhack(SPEEDHACK_SOURCE.DANGER_CLOSE)
  end
  update_speedhack()

  -- Add a bit more of speed to players when the game is slower
  if speedhack_source_info[SPEEDHACK_SOURCE.DANGER_CLOSE].enabled then
    local custom_type = custom_player_types[player.type.id]
    if not custom_player_types[player.type.id] then
      custom_type = EntityDB:new(player.type.id)
      custom_player_types[player.type.id] = custom_type
    end
    local player_type = get_type(player_type_id)
    custom_type.acceleration = player_type.acceleration + options.danger_extra_player_acceleration-- 0.025
    custom_type.max_speed = player_type.max_speed + options.danger_extra_player_max_speed-- 0.0125
    if player.type ~= custom_type then
      player.type = custom_type
    end
  elseif player.type ~= get_type(player.type.id) then
    player.type = get_type(player.type.id)
  end
end, ON.GAMEFRAME)

-- SEEDHACK PAUSE MANAGEMENT --
local was_just_paused = false
local was_just_on_level = true
set_callback(function ()
  if state.pause ~= 0 or not game_manager.game_props.game_has_focus then
    if not was_just_paused then
      set_speedhack_og(1.0)
      was_just_paused = true
    end
  elseif was_just_paused then
    set_speedhack_og(current_speedhack)
    was_just_paused = false
  end
  if state.screen ~= SCREEN.LEVEL and state.screen ~= SCREEN.OPTIONS and was_just_on_level then
    set_speedhack_og(1.0)
    current_speedhack = 1.0
    was_just_on_level = true
  else
    was_just_on_level = false
  end
end, ON.GUIFRAME)
-- / SEEDHACK PAUSE MANAGEMENT --

-- SPEEDHACK BY HIT AND TOGGLE --
local hit_slowmo_frames = 0.0
local prev_health = {4, 4, 4, 4}
local toggled_slowmo, not_just_toggled = false, true
local RUN_BUTTON = 5 --16
local DOOR_BUTTON = 6 --32

set_callback(function()
  for i, p in ipairs(players) do
    local slot = p.inventory.player_slot
    if options.enable_trigger_slowmo and test_flag(state.player_inputs.player_slots[slot].buttons, DOOR_BUTTON) and
    (state.player_inputs.player_settings[slot].auto_run_enabled ~= test_flag(state.player_inputs.player_slots[slot].buttons, RUN_BUTTON)) then
      if not_just_toggled then
        toggled_slowmo = not toggled_slowmo
        if toggled_slowmo == false then
          reset_speedhack(SPEEDHACK_SOURCE.TOGGLED)
        else
          set_speedhack(SPEEDHACK_SOURCE.TOGGLED)
        end
        not_just_toggled = false
      end
    else
      not_just_toggled = true
    end
    if options.enable_hit_slowmo and p.health < prev_health[i] and p.stun_timer == 0 and p.health <= options.max_hp and p.health > 0 then
      hit_slowmo_frames = options.slow_time*60
      set_speedhack(SPEEDHACK_SOURCE.GOT_HIT)
    end
    prev_health[i] = p.health
  end
  if hit_slowmo_frames > 0.0 then
    hit_slowmo_frames = hit_slowmo_frames - (1.0 / options.hit_slowness) --If it's 0.5, the time per frame will be double, and 1.0 / 0.5 = 2.0
    if hit_slowmo_frames <= 0.0 then
      reset_speedhack(SPEEDHACK_SOURCE.GOT_HIT)
    end
  end
end, ON.GAMEFRAME)
-- / SPEEDHACK BY HIT AND TOGGLE --

-- SETTINGS --
set_callback(function(save_ctx)
  local saved_options = json.encode(options)
  save_ctx:save(saved_options)
end, ON.SAVE)

set_callback(function(load_ctx)
  local loaded_options_str= load_ctx:load()
  if loaded_options_str ~= "" then
      options = json.decode(loaded_options_str)
  end
  --Make it work when new options are added
  for key, def_val in pairs(default_options) do
    if options[key] == nil then
      options[key] = def_val
    end
  end
end, ON.LOAD)

local last_hit_slowness, last_trigger_slowness = options.hit_slowness, options.trigger_slowness
register_option_callback("_", nil, function (draw_ctx)
  draw_ctx:win_text("Use CTRL+CLICK to write decimal number settings\nGame speed: 1.0 is normal speed, 0.5 is half")

  draw_ctx:win_separator_text("Danger incoming slowmo")
  draw_ctx:win_pushid(2)
  options.enable_danger_slowmo = draw_ctx:win_check("Enable", options.enable_danger_slowmo)
  if options.enable_danger_slowmo then
    draw_ctx:win_indent(10.0)
    draw_ctx:win_text("Triggers slowmo when entities from offscreen enter rapidly towards the player, giving a fairer time to react")
    options.danger_normal_slowness = draw_ctx:win_slider_float("Game speed when slowmo is triggered", options.danger_normal_slowness, 0.025, 1.0)
    options.danger_extra_slowness = draw_ctx:win_slider_float("Game speed when danger is closer", options.danger_extra_slowness, 0.025, 1.0)
    options.danger_extra_player_stats = draw_ctx:win_check("Extra player stats on slowmo", options.danger_extra_player_stats)
    if options.danger_extra_player_stats then
      draw_ctx:win_indent(10.0)
      options.danger_extra_player_max_speed = draw_ctx:win_slider_float("Extra player speed", options.danger_extra_player_max_speed, .0, 0.2)
      options.danger_extra_player_acceleration = draw_ctx:win_slider_float("Extra player acceleration", options.danger_extra_player_acceleration, .0, 0.2)
      draw_ctx:win_indent(-10.0)
    end
    draw_ctx:win_indent(-10.0)
  end
  draw_ctx:win_popid()

  draw_ctx:win_separator_text("Toggleable slowmo")
  draw_ctx:win_pushid(1)
  options.enable_trigger_slowmo = draw_ctx:win_check("Enable", options.enable_trigger_slowmo)
  draw_ctx:win_indent(10.0)
  if options.enable_trigger_slowmo then
    options.trigger_slowness = draw_ctx:win_slider_float("Game speed on toggle", options.trigger_slowness, 0.01, 1.0)
    if options.trigger_slowness ~= last_trigger_slowness then
      last_trigger_slowness = options.trigger_slowness
      speedhack_source_info[SPEEDHACK_SOURCE.TOGGLED].value = last_trigger_slowness
    end
    draw_ctx:win_text("Toggle with RUN + DOOR (interact) button")
  end
  draw_ctx:win_indent(-10.0)
  draw_ctx:win_popid()

  draw_ctx:win_separator_text("Hit slowmo")
  draw_ctx:win_pushid(3)
  options.enable_hit_slowmo = draw_ctx:win_check("Enable", options.enable_hit_slowmo)
  if options.enable_hit_slowmo then
    draw_ctx:win_indent(10.0)
    options.slow_time = draw_ctx:win_input_int("Seconds of slowmo", options.slow_time)
    options.max_hp = draw_ctx:win_input_int("Max hp that can trigger slowmo", options.max_hp)
    options.hit_slowness = draw_ctx:win_slider_float("Game speed on hit", options.hit_slowness, 0.01, 1.0)
    if options.hit_slowness ~= last_hit_slowness then
      last_hit_slowness = options.hit_slowness
      speedhack_source_info[SPEEDHACK_SOURCE.GOT_HIT].value = last_hit_slowness
    end
    draw_ctx:win_indent(-10.0)
  end
  draw_ctx:win_popid()

  draw_ctx:win_separator_text("Settings management")
  if draw_ctx:win_button("Reset settings") then
    for k, v in pairs(default_options) do
      options[k] = v
    end
  end
  draw_ctx:win_inline()
  if draw_ctx:win_button("Save settings now") then
      save_script()
  end
end)
-- / SETTINGS --
