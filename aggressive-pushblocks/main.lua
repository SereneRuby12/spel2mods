meta.name = "Aggressive pushblocks"
meta.version = "1.2"
meta.description = "Pushblocks now try to crush you, Olmec spawns pushblocks instead of UFOs"
meta.author = "SereneRuby12, Omeletttte"
meta.online_safe = true
local babyolmec_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_ITEMS_0)
    texture_def.height = 128
    texture_def.width = 128
    texture_def.texture_path = "babyolmec.png"
    babyolmec_texture = define_texture(texture_def)
end

---@class ModOptions
---@field time_olmec integer
---@field time integer
---@field olmec_only boolean
---@field olmec_spawns boolean
---@field pushblock_chance_val integer
---@field pushblock_chance_override boolean
local default_options = {
    time_olmec = 90,
    time = 60,
    olmec_only = false,
    olmec_spawns = true,
    pushblock_chance_val = 32,
    pushblock_chance_override = true,
}
---@type ModOptions
---@diagnostic disable-next-line: lowercase-global, missing-fields
options = { table.unpack(default_options) }

register_option_int("time_olmec", "Pushblock attack cooldown in olmec lvl", "", 90, 0, 300)
register_option_int("time", "Pushblock attack cooldown", "", 60, 0, 300)
register_option_bool("olmec_only", "Aggressive pushblocks only spawned by olmec", "", false)
register_option_bool("olmec_spawns", "Olmec spawns aggressive pushblocks", "", true)
register_option_int("pushblock_chance_val", "Pushblock spawn chance (1/x chance)", "", 32, 1, 100)
register_option_bool("pushblock_chance_override", "Override pushblock chances", "", true)

local jump_time = 60

-- pushblock state
local P_STATE = {
    IDLE = 0,
    JUMPING1 = 1,
    JUMPING2 = 2,
    TO_CRUSH = 3,
    CRUSHING = 4
}

---@enum DATA_IDX
local DATA_IDX = {
    STATE = 0,
    TIMER = 1,
}

local function closest_player(uid, l)
    local dist, p_uid = 10000, -1
    local players = get_local_players() --[==[@as Player[]]==]
    for _, p in ipairs(players) do
        if l == p.layer then
            local tdist = distance(p.uid, uid)
            if tdist < dist then
                dist = tdist
                p_uid = p.uid
            end
        end
    end
    return dist, p_uid
end

local function read_8bit(val, idx)
    return (val >> (idx * 8)) & 0xff
end

local function write_8bit(val, v8, idx)
    v8 = v8 & 0xff
    local shiftval = idx * 8
    local converted_val = v8 << shiftval
    return (val & ~(0xff << shiftval)) | converted_val
end

---@param ent Movable
---@param idx DATA_IDX
---@param v8 integer
local function set_ent_data(ent, idx, v8)
    ent.price = write_8bit(ent.price, v8, idx)
end

---@param ent Movable
---@param idx DATA_IDX
local function get_ent_data(ent, idx)
    return read_8bit(ent.price, idx)
end

local function new_pushblock(uid)
    local state = get_local_state() --[[@as StateMemory]]
    local e = get_entity(uid) --[[@as Movable]]
    e:set_texture(babyolmec_texture)
    if test_flag(state.level_flags, 18) then --Dark level
        spawn_entity_over(ENT_TYPE.FX_SMALLFLAME, uid, -0.16406, 0.066406)
        spawn_entity_over(ENT_TYPE.FX_SMALLFLAME, uid, 0.199218, 0.0703125)
    end
    e.price = 0
    set_ent_data(e, DATA_IDX.STATE, P_STATE.IDLE)
    set_ent_data(e, DATA_IDX.TIMER, 0)
end

local function sum_vel(uid, svx, svy)
    -- local x, y, l = get_position(uid)
    -- local vx, vy = get_velocity(uid)
    local e = get_entity(uid) --[[@as Movable]]
    e.velocityx = e.velocityx + svx
    e.velocityy = e.velocityy + svy
    --move_entity(uid, x, y+0.01, vx+svx, vy+svy)
end

local function not_are_solid_floors(x, y, l)
    local ents = get_entities_at(0, MASK.FLOOR, x, y, l, 1)
    for _, uid in ipairs(ents) do
        if test_flag(get_entity_flags(uid), ENT_FLAG.SOLID) then
            return false
        end
    end
    return true
end

local function sign(num)
    if num < 0 then
        return -1
    else
        return 1
    end
end

local function olmec_onframe()
    local ufos = get_entities_by(ENT_TYPE.MONS_UFO, MASK.MONSTER, LAYER.BOTH)
    if ufos then
        for _, uid in ipairs(ufos) do
            local x, y, l = get_position(uid)
            get_entity(uid):destroy()
            move_entity(uid, x, 1000, 0, 0)
            local pushb_uid = spawn(ENT_TYPE.ACTIVEFLOOR_PUSHBLOCK, x, y, l, 0, 0)
            new_pushblock(pushb_uid)
            -- pushblocks[pushb_uid] = new_pushblock()
        end
    end
end

local function pushblocks_onframe()
    local ents = get_entities_by(ENT_TYPE.ACTIVEFLOOR_PUSHBLOCK, MASK.ACTIVEFLOOR, LAYER.FRONT)
    local players = get_local_players() --[==[@as Player[]]==]
    --local ents = get_entities_at(ENT_TYPE.ACTIVEFLOOR_PUSHBLOCK, 0, px, py, pl, 6)
    for _, eu in ipairs(ents) do
        local x, y, l = get_position(eu)
        local e = get_entity(eu) --[[@as Movable]]
        if e.overlay and e.overlay.type.id == ENT_TYPE.MONS_HERMITCRAB then goto continue end

        local state, timer = get_ent_data(e, DATA_IDX.STATE), get_ent_data(e, DATA_IDX.TIMER)
        if state == P_STATE.IDLE then
            if not players[1] then goto continue end
            if e.standing_on_uid == -1 then goto continue end
            local closest_dist = closest_player(eu, l)
            if closest_dist < 6 and entity_get_items_by(eu, 0, MASK.ACTIVEFLOOR)[1] == nil then
                if not_are_solid_floors(x, y+1, l) then
                    if timer >= jump_time then
                        sum_vel(eu, 0, 0.2)
                        state = P_STATE.JUMPING1
                        set_ent_data(e, DATA_IDX.STATE, state)
                        timer = 0
                    end
                elseif e.velocityy == 0.0 then
                    local _, p_uid = closest_player(eu, l)
                    local px = get_position(p_uid)
                    e.x = e.x+sign(px-x)*0.01
                    timer = 0
                    --move_entity(eu, x+sign(px-x)*0.25, y, 0, 0.05)
                end
            end
            timer = timer + 1
            set_ent_data(e, DATA_IDX.TIMER, timer)
        elseif state == P_STATE.JUMPING1 then
            if e.standing_on_uid ~= -1 then
                state = P_STATE.IDLE
                timer = 0
                set_ent_data(e, DATA_IDX.STATE, state)
            elseif timer > 2 then
                if not players[1] then goto continue end
                local _, p_uid = closest_player(eu, l)
                local px = get_position(p_uid)
                sum_vel(eu, sign(px-x)*0.125, 0)
                state = P_STATE.JUMPING2
                set_ent_data(e, DATA_IDX.STATE, state)
            end
            timer = timer + 1
            set_ent_data(e, DATA_IDX.TIMER, timer)
        elseif state == P_STATE.JUMPING2 then
            if not players[1] then goto continue end
            if e.standing_on_uid == -1 then
                local _, p_uid = closest_player(eu, l)
                local px, py = get_position(p_uid)
                if math.abs(x - px) < 0.65 and py - y < -0.75 then
                    e.velocityx = 0
                    e.velocityy = 0
                    e.flags = set_flag(e.flags, ENT_FLAG.NO_GRAVITY)
                    state = P_STATE.TO_CRUSH
                    timer = 0
                    set_ent_data(e, DATA_IDX.STATE, state)
                    set_ent_data(e, DATA_IDX.TIMER, timer)
                end
            else
                state = P_STATE.IDLE
                timer = 0
                set_ent_data(e, DATA_IDX.STATE, state)
                set_ent_data(e, DATA_IDX.TIMER, timer)
            end
        elseif state == P_STATE.TO_CRUSH then
            if timer == 30 then
                e.flags = clr_flag(e.flags, ENT_FLAG.NO_GRAVITY)
                sum_vel(eu, 0, -0.2)
                state = P_STATE.CRUSHING
                set_ent_data(e, DATA_IDX.STATE, state)
            end
            timer = timer + 1
            set_ent_data(e, DATA_IDX.TIMER, timer)
        else --CRUSHING
            if e.standing_on_uid ~= -1 then
                --[[local blocks = get_entities_at(0, MASK.FLOOR | MASK.ACTIVEFLOOR, x, y-1, l, 1)
                for i, bl_uid in ipairs(blocks) do
                    local b = get_entity(bl_uid)
                    b.y = -50
                end]]
                state = P_STATE.IDLE
                timer = 0
                set_ent_data(e, DATA_IDX.STATE, state)
                set_ent_data(e, DATA_IDX.TIMER, timer)
            end
        end
        ::continue::
    end
end

set_callback(function ()
    local state = get_local_state() --[[@as StateMemory]]
    if state.pause == 0 and ((state.screen >= ON.CAMP and state.screen <= ON.DEATH) or state.screen == ON.ARENA_MATCH) then
        if state.theme == 4 and options.olmec_spawns then
            olmec_onframe()
        end
        pushblocks_onframe()
    end
end, ON.POST_UPDATE)

set_callback(function()
    local state = get_local_state() --[[@as StateMemory]]
    if state.theme == 4 then--olmec
        jump_time = options.time_olmec
    else
        jump_time = options.time
    end
    if not options.olmec_only then
        local ents = get_entities_by(ENT_TYPE.ACTIVEFLOOR_PUSHBLOCK, MASK.ACTIVEFLOOR, LAYER.FRONT)
        for _, uid in ipairs(ents) do
            new_pushblock(uid)
        end
    end
end, ON.POST_LEVEL_GENERATION)

local function has(arr, item)
    for _, v in pairs(arr) do
        if v == item then
            return true
        end
    end
    return false
end

local function is_solid(uid)
    return test_flag(get_entity_flags(uid), ENT_FLAG.SOLID)
end

local floor_types = {ENT_TYPE.FLOOR_GENERIC, ENT_TYPE.FLOOR_JUNGLE, ENT_TYPE.FLOORSTYLED_MINEWOOD, ENT_TYPE.FLOORSTYLED_STONE, ENT_TYPE.FLOORSTYLED_TEMPLE, ENT_TYPE.FLOORSTYLED_PAGODA, ENT_TYPE.FLOORSTYLED_BABYLON, ENT_TYPE.FLOORSTYLED_SUNKEN, ENT_TYPE.FLOORSTYLED_BEEHIVE, ENT_TYPE.FLOORSTYLED_VLAD, ENT_TYPE.FLOORSTYLED_COG, ENT_TYPE.FLOORSTYLED_MOTHERSHIP, ENT_TYPE.FLOORSTYLED_DUAT, ENT_TYPE.FLOORSTYLED_PALACE, ENT_TYPE.FLOORSTYLED_GUTS}
local invalid_tops = {
    ENT_TYPE.FLOOR_TREE_BASE,
    ENT_TYPE.FLOOR_MUSHROOM_BASE,
    ENT_TYPE.FLOOR_CLIMBING_POLE,
    ENT_TYPE.FLOOR_GROWABLE_CLIMBING_POLE,
    ENT_TYPE.FLOOR_LION_TRAP,
    ENT_TYPE.FLOOR_SPRING_TRAP,
    ENT_TYPE.FLOOR_TOTEM_TRAP,
    ENT_TYPE.FLOOR_ALTAR,
    ENT_TYPE.FLOOR_EGGPLANT_ALTAR,
}

local function valid_spawn(uid, x, y, l)
    local below_uid = get_grid_entity_at(x, y-1, l)
    if not is_solid(uid) or not is_solid(below_uid) then return false end
    if state.theme == THEME.OLMEC and y == 110 and x >= 21 and x <= 24 then return false end

    local top_uid = get_grid_entity_at(x, y+1, l)
    local top_type = top_uid ~= -1 and get_entity_type(top_uid) or -1
    local flags = get_entity_flags(uid)
    return not test_flag(flags, ENT_FLAG.SHOP_FLOOR)
        and not test_flag(flags, ENT_FLAG.INDESTRUCTIBLE_OR_SPECIAL_FLOOR)
        and (
            top_type == -1
            or not has(invalid_tops, top_type)
        )
end

local tofix = {}

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

local function is_close_to_spawn_door(doors, x, y, l)
    for _, uid in ipairs(doors) do
        local dx, dy, dl = get_position(uid)
        local dist_x, dist_y = x-dx, y-dy
        if l == dl and (dist_x*dist_x + dist_y*dist_y) <= 6*6 then
            return true
        end
    end
    return false
end

local function spawn_pushblocks_custom()
    local state = get_local_state() --[[@as StateMemory]]
    local prng = get_local_prng() --[[@as PRNG]]
    if state.screen ~= SCREEN.LEVEL
        or get_procedural_spawn_chance(PROCEDURAL_CHANCE.PUSHBLOCK_CHANCE) ~= 0
        or not options.pushblock_chance_override
    then
        return
    end
    tofix = {}
    local entrance_doors = get_entities_by(ENT_TYPE.FLOOR_DOOR_ENTRANCE, MASK.FLOOR, LAYER.FRONT)

    local floors = get_entities_by(floor_types, MASK.FLOOR, LAYER.FRONT)
    local spawn_chance = options.pushblock_chance_val

    for _,uid in ipairs(floors) do
        local x, y, l = get_position(uid)
        if prng:random_chance(spawn_chance, PRNG_CLASS.LEVEL_GEN) and valid_spawn(uid, x, y, l) and not is_close_to_spawn_door(entrance_doors, x, y, l) then
            destroy_grid(x, y, l)
            local pushblock_uid = spawn_grid_entity(ENT_TYPE.ACTIVEFLOOR_PUSHBLOCK, x, y, l)
            new_pushblock(pushblock_uid)
            add_tofix_neighbors(onetile_neighbor_positions, x, y, l)
            tofix[uid] = nil
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
end

set_callback(spawn_pushblocks_custom, ON.POST_LEVEL_GENERATION)
---@param ctx PostRoomGenerationContext
set_callback(function (ctx)
    if options.pushblock_chance_override and get_procedural_spawn_chance(PROCEDURAL_CHANCE.PUSHBLOCK_CHANCE) ~= 0 then
        ctx:set_procedural_spawn_chance(PROCEDURAL_CHANCE.PUSHBLOCK_CHANCE, options.pushblock_chance_val)
    end
end, ON.POST_ROOM_GENERATION)

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

local settings_copy_text = ""
local import_settings_text = ""
register_option_callback("z_manage_settings", nil, function (draw_ctx)
    draw_ctx:win_separator()
    if draw_ctx:win_button("Reset settings") then
      for key, value in pairs(default_options) do
        options[key] = value
      end
    end
    draw_ctx:win_inline()
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
