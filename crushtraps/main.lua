meta = {
    name = "Walls are shifting",
    version = "1.1a",
    description = "Crush traps spawn anywhere",
    author = "SereneRuby12",
    online_safe = true
}

local function has(arr, item)
    for _, v in pairs(arr) do
        if v == item then
            return true
        end
    end
    return false
end

local floor_types = {ENT_TYPE.FLOOR_GENERIC, ENT_TYPE.FLOOR_JUNGLE, ENT_TYPE.FLOORSTYLED_MINEWOOD, ENT_TYPE.FLOORSTYLED_STONE, ENT_TYPE.FLOORSTYLED_TEMPLE, ENT_TYPE.FLOORSTYLED_PAGODA, ENT_TYPE.FLOORSTYLED_BABYLON, ENT_TYPE.FLOORSTYLED_SUNKEN, ENT_TYPE.FLOORSTYLED_BEEHIVE, ENT_TYPE.FLOORSTYLED_VLAD, ENT_TYPE.FLOORSTYLED_COG, ENT_TYPE.FLOORSTYLED_MOTHERSHIP, ENT_TYPE.FLOORSTYLED_DUAT, ENT_TYPE.FLOORSTYLED_PALACE, ENT_TYPE.FLOORSTYLED_GUTS}
local zones, tofix, used = {}, {}, {}

local function is_not_on_safe_zone(x, y)
    for _,zone in ipairs(zones) do
        local xdiff, ydiff = x-zone.x, y-zone.y
        if math.sqrt(xdiff*xdiff+ydiff*ydiff) < options.f_safe_zone_radius+0.5 then
            return false
        end
    end
    return true
end

local function insert_to_used(uid)
    used[uid] = true
end

local invalid_crushblock_tops = {
    ENT_TYPE.FLOOR_TREE_BASE,
    ENT_TYPE.FLOOR_MUSHROOM_BASE,
    ENT_TYPE.FLOOR_CLIMBING_POLE,
    ENT_TYPE.FLOOR_LION_TRAP,
    ENT_TYPE.FLOOR_SPRING_TRAP,
    ENT_TYPE.FLOOR_TOTEM_TRAP,
    ENT_TYPE.FLOOR_ALTAR,
    ENT_TYPE.FLOOR_EGGPLANT_ALTAR,
}
local invalid_crushblock_bottoms = {
    ENT_TYPE.FLOOR_VINE,
    ENT_TYPE.FLOOR_GROWABLE_VINE,
}

local function valid_crushblock_spawn(uid, x, y, l)
    local top_uid = get_grid_entity_at(x, y+1, l)
    local top_type = top_uid ~= -1 and get_entity_type(top_uid) or -1
    local bottom_uid = get_grid_entity_at(x, y-1, l)
    local bottom_type = bottom_uid ~= -1 and get_entity_type(bottom_uid) or -1
    local flags = get_entity_flags(uid)
    return not test_flag(flags, ENT_FLAG.SHOP_FLOOR)
        and not test_flag(flags, ENT_FLAG.INDESTRUCTIBLE_OR_SPECIAL_FLOOR)
        and is_not_on_safe_zone(x, y)
        and (
            top_type == -1
            or not has(invalid_crushblock_tops, top_type)
        )
        and (
            bottom_type == -1
            or not has(invalid_crushblock_bottoms, bottom_type)
        )
end

---Spawn a liquid hitbox for the entity, adjusts the hitbox width by setting the width of the entity to the double of it, then setting it back.
---It's due to that the ACTIVEFLOOR_SHIELD hitboxx seems to be set to half of the entity's hitboxx, and changing it later doesn't affect liquid collision
---@param overlay_uid integer 
local function spawn_liquid_hitbox(overlay_uid)
    if not options.h_liquid_collisions or get_entities_by(0, MASK.LIQUID, LAYER.FRONT)[1] == nil then
        return
    end
    local ent = get_entity(overlay_uid)
    local old_hitboxx = ent.hitboxx
    ent.hitboxx = old_hitboxx * 2
    local shield = get_entity(spawn_over(ENT_TYPE.ACTIVEFLOOR_SHIELD, overlay_uid, 0, 0))
    shield.flags = set_flag(shield.flags, ENT_FLAG.DEAD)
    shield.x = 0
    ent.hitboxx = old_hitboxx
end

local function replace_with_crushtrap(x, y, l)
    destroy_grid(x, y, l)
    local uid = spawn_grid_entity(ENT_TYPE.ACTIVEFLOOR_CRUSH_TRAP, x, y, l)
    spawn_liquid_hitbox(uid)
end

---Create an array that loops through the border side of a rectangle of given size, starting at 0,0 and ending at width-1,height-1 (in spelunky coordinates)
---@param width integer
---@param height integer
---@return integer[][]
local function create_border_positions_array(width, height)
    width, height = width-1, height-1
    local tbl, i = {}, 1
    for y = 0, height do
        for x = 0, width do
            if x == 0 or y == 0 or x == width or y == height then
                tbl[i] = {x, -y}
                i = i + 1
            end
        end
    end
    return tbl
end

---@param neighbor_positions integer[][]
---@param x integer
---@param y integer
---@param l LAYER
local function add_tofix_neighbors(neighbor_positions, x, y, l)
    local start_x, start_y = x-1, y+1
    for _, pos_off in pairs(neighbor_positions) do
        local xoff, yoff = pos_off[1], pos_off[2]
        local floor_uid = get_grid_entity_at(start_x + xoff, start_y + yoff, l)
        tofix[floor_uid] = true
    end
end

local onetile_neighbor_positions = create_border_positions_array(3, 3)
local twotile_neighbor_positions = create_border_positions_array(4, 4)

set_callback(function()
    local state = get_local_state() --[[@as StateMemory]]
    local prng = get_local_prng() --[[@as PRNG]]
    if state.screen ~= SCREEN.LEVEL then return end
    zones = {}; used = {}; tofix = {}
    if options.d_spawn_safe_zones then
        local max_x = state.width*10
        local min_y = (122 - (state.height * 8)) + 3
        for i=1, state.width*state.height/options.e_safe_zone_divisor do
            zones[i] = {['x'] = prng:random_int(5, max_x, PRNG_CLASS.LEVEL_GEN), ['y'] = prng:random_int(min_y, 120, PRNG_CLASS.LEVEL_GEN)}--math.random(2, state.width*10+2), ['y'] = math.random(90, state.height*8+90)}
        end
    end
    local entrance_doors = get_entities_by(ENT_TYPE.FLOOR_DOOR_ENTRANCE, MASK.FLOOR, LAYER.FRONT)
    for _,uid in ipairs(entrance_doors) do
        local dx, dy, _ = get_position(uid)
        zones[#zones+1] = {['x'] = dx, ['y'] = dy}
    end
    if state.theme == THEME.OLMEC then
        for x = 21, 24 do
            insert_to_used(get_grid_entity_at(x, 110, LAYER.FRONT))
        end
    end
    local floors = get_entities_by(floor_types, MASK.FLOOR, LAYER.FRONT)
    local spawn_chance = options.a1_spawn_chance / 100
    local large_spawn_chance = options.a2_large_spawn_chance / 100

    for _,uid in ipairs(floors) do
        local x, y, l = get_position(uid)
        if prng:random_float(PRNG_CLASS.LEVEL_GEN) < spawn_chance and valid_crushblock_spawn(uid, x, y, l) and not used[uid] then
            if prng:random_float(PRNG_CLASS.LEVEL_GEN) < large_spawn_chance then
                local floors_uids = {
                    uid,
                    get_grid_entity_at(x+1, y, l),
                    get_grid_entity_at(x, y-1, l),
                    get_grid_entity_at(x+1, y-1, l)
                }
                local is_valid_large_spawn = true
                for _, floor_uid in pairs(floors_uids) do
                    if (
                        floor_uid == -1
                        or used[floor_uid]
                        or not test_flag(get_entity_flags(floor_uid), ENT_FLAG.SOLID)
                        or not has(floor_types, get_entity_type(floor_uid))
                        or not valid_crushblock_spawn(floor_uid, get_position(floor_uid))
                    ) then
                        is_valid_large_spawn = false
                        break
                    end
                end
                if is_valid_large_spawn then
                    for _, floor_uid in pairs(floors_uids) do
                        destroy_grid(floor_uid)
                        insert_to_used(floor_uid)
                        tofix[floor_uid] = nil
                    end
                    add_tofix_neighbors(twotile_neighbor_positions, x, y, l)
                    local crushtrap_uid = spawn(ENT_TYPE.ACTIVEFLOOR_CRUSH_TRAP_LARGE, x+0.5, y-0.5, l, 0, 0)
                    spawn_liquid_hitbox(crushtrap_uid)
                else
                    add_tofix_neighbors(onetile_neighbor_positions, x, y, l)
                    replace_with_crushtrap(x, y, l)
                    tofix[uid] = nil
                end
            else
                add_tofix_neighbors(onetile_neighbor_positions, x, y, l)
                replace_with_crushtrap(x, y, l)
                tofix[uid] = nil
            end
        end
    end
    tofix[-1] = nil
    for uid, _ in pairs(tofix) do
        local ent = get_entity(uid) --[[@as Floor]]
        if ent then
            if ent.type.id < ENT_TYPE.FLOORSTYLED_MINEWOOD then
                ent:fix_decorations(false, true)
            else
                ent:decorate_internal()
            end
        end
    end
end, ON.POST_LEVEL_GENERATION)

-- Remove shield entities from crushtraps that give them liquid collisions
set_callback(function ()
    local state = get_local_state() --[[@as StateMemory]]
    -- basically a GAMEFRAME callback that works online
    if state.pause == 0 and ((state.screen >= ON.CAMP and state.screen <= ON.DEATH) or state.screen == ON.ARENA_MATCH) then
        for _, uid in ipairs(get_entities_by(ENT_TYPE.ACTIVEFLOOR_SHIELD, MASK.ACTIVEFLOOR, LAYER.FRONT)) do
            local ent = get_entity(uid)
            if ent.overlay == nil then ent:destroy() end
        end
    end
end, ON.POST_UPDATE)

---@class ModOptions
---@field a1_spawn_chance integer
---@field a2_large_spawn_chance integer
---@field d_spawn_safe_zones boolean
---@field e_safe_zone_divisor integer
---@field f_safe_zone_radius integer
---@field h_liquid_collisions boolean
local default_options = {
    a1_spawn_chance = 5,
    a2_large_spawn_chance = 25,
    d_spawn_safe_zones = false,
    e_safe_zone_divisor = 6,
    f_safe_zone_radius = 5,
    h_liquid_collisions = true,
}
local difficult_options = {
    a1_spawn_chance = 75,
    d_spawn_safe_zones = true,
}

local moderate_options = {
    a1_spawn_chance = 15,
    d_spawn_safe_zones = true,
}
---@type ModOptions
---@diagnostic disable-next-line: lowercase-global, missing-fields
options = { table.unpack(default_options) }

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

register_option_int('a1_spawn_chance', 'Crush trap spawn chance %', '', 5, 0, 100)
register_option_int('a2_large_spawn_chance', 'Large crush trap chance %', 'chance of replacing one with the large type', 25, 0, 100)
register_option_bool('d_spawn_safe_zones', 'enable safe zones', '(won\'t disable spawn safe zone)', false)
register_option_int('e_safe_zone_divisor', 'Safe zones divisor', 'the number of safe zones is the amount of rooms, divided by this number', 6, 1, 10)
register_option_int('f_safe_zone_radius', 'safe zones radius', '', 5, 0, 12)
register_option_bool('h_liquid_collisions', 'Enable crushtraps liquid collision', '', true)

local function load_settings(settings)
    if settings ~= default_options then
        load_settings(default_options)
    end
    for key, value in pairs(settings) do
        options[key] = value
    end
end
local settings_copy_text = ""
local import_settings_text = ""
register_option_callback("z_manage_settings", nil, function (draw_ctx)
    draw_ctx:win_text("Difficulty presets, on which level you want to get stuck?")
    if draw_ctx:win_button("6-4 (default)") then load_settings(default_options) end
    draw_ctx:win_inline()
    if draw_ctx:win_button("3-1") then load_settings(moderate_options) end
    draw_ctx:win_inline()
    if draw_ctx:win_button("1-1 (classic)") then load_settings(difficult_options) end
    draw_ctx:win_separator()
    if draw_ctx:win_button("Save settings now") then
        save_script()
    end
    if draw_ctx:win_button("Export settings") and type(options) == "table" then
        settings_copy_text = json.encode(options)
    end
    draw_ctx:win_inline()
    draw_ctx:win_input_text("##export_text", settings_copy_text)
    if draw_ctx:win_button("Import settings") then
        if import_settings_text and import_settings_text ~= "" then
            options = json.decode(import_settings_text)
        end
    end
    draw_ctx:win_inline()
    import_settings_text = draw_ctx:win_input_text("##import_input", import_settings_text)
    draw_ctx:win_text("Click export and copy the text to share")
    draw_ctx:win_text("Paste text in the import field and click the button to load settings")
    draw_ctx:win_text("Online multi: Make sure everyone has the same settings, you can change them ingame, as long as everyone else does too before the next level. Not having the same settings cause desync")
end)
