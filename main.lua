meta = {
    name = "Walls are shifting",
    version = "1.0",
    description = "Crushblocks spawn everywhere",
    author = "Estebanfer"
}
local floor_types = {ENT_TYPE.FLOOR_GENERIC, ENT_TYPE.FLOOR_JUNGLE, ENT_TYPE.FLOORSTYLED_MINEWOOD, ENT_TYPE.FLOORSTYLED_STONE, ENT_TYPE.FLOORSTYLED_TEMPLE, ENT_TYPE.FLOORSTYLED_PAGODA, ENT_TYPE.FLOORSTYLED_BABYLON, ENT_TYPE.FLOORSTYLED_SUNKEN, ENT_TYPE.FLOORSTYLED_BEEHIVE, ENT_TYPE.FLOORSTYLED_VLAD, ENT_TYPE.FLOORSTYLED_COG, ENT_TYPE.FLOORSTYLED_MOTHERSHIP, ENT_TYPE.FLOORSTYLED_DUAT, ENT_TYPE.FLOORSTYLED_PALACE, ENT_TYPE.FLOORSTYLED_GUTS}
local zones, tofix, used = {}, {}, {}

local function is_not_on_safe_zone(x, y)
    for i,zone in ipairs(zones) do
        local xdiff, ydiff = x-zone.x, y-zone.y
        if math.sqrt(xdiff*xdiff+ydiff*ydiff) < options.f_safe_zone_radius+0.5 then
            return false
        end
    end
    return true
end

local function insert_to_used(x, y)
    if used[x] then
        used[x][y] = true
    else
        used[x] = { [y] = true }
    end
end

local function valid_crushblock_spawn(ent, uid, x, y, l)
    local top_e_type = get_grid_entity_at(x, y+1, l)
    top_e_type = top_e_type == -1 or get_entity(top_e_type).type.id
    return not test_flag(ent.flags, ENT_FLAG.SHOP_FLOOR) and is_not_on_safe_zone(x, y) and top_e_type ~= ENT_TYPE.FLOOR_ALTAR and top_e_type ~= ENT_TYPE.FLOOR_EGGPLANT_ALTAR
end

local function valid_crushblock_l_spawn(ent, uid, x, y, l) --made for large crushblock
    local top_e_type = get_grid_entity_at(x, y+1, l)
    top_e_type = top_e_type == -1 or get_entity(top_e_type).type.id
    return not test_flag(ent.flags, ENT_FLAG.SHOP_FLOOR) and is_not_on_safe_zone(x, y) and not (used[x] and used[x][y]) and ent.type.id > ENT_TYPE.FLOOR_BORDERTILE_OCTOPUS and ent.type.id ~= ENT_TYPE.FLOOR_PIPE and top_e_type ~= ENT_TYPE.FLOOR_ALTAR and top_e_type ~= ENT_TYPE.FLOOR_EGGPLANT_ALTAR
end

local function destroy_floor(ent)
    for i=FLOOR_SIDE.TOP, FLOOR_SIDE.RIGHT do
        ent:remove_decoration(i)
    end
    ent:destroy()
end

local function replace_with_crushtrap(ent, x, y, l)
    destroy_floor(ent)
    spawn_grid_entity(ENT_TYPE.ACTIVEFLOOR_CRUSH_TRAP, x, y, l)
end

set_callback(function()
    if state.theme == THEME.BASE_CAMP then return end
    zones = {}; used = {}; tofix = {}
    if options.d_spawn_safe_zones then
        local max_x = state.width*10+2
        local max_y = state.height*8+90
        for i=1, state.width*state.height/options.e_safe_zone_divisor do
            zones[i] = {['x'] = prng:random_int(2, max_x, PRNG_CLASS.PROCEDURAL_SPAWNS), ['y'] = prng:random_int(90, max_y, PRNG_CLASS.PROCEDURAL_SPAWNS)}--math.random(2, state.width*10+2), ['y'] = math.random(90, state.height*8+90)}
        end
    end
    local entrance_doors = get_entities_by_type(ENT_TYPE.FLOOR_DOOR_ENTRANCE)
    for _,uid in ipairs(entrance_doors) do
        local dx, dy, _ = get_position(uid)
        zones[#zones+1] = {['x'] = dx, ['y'] = dy}
    end
    local floors = get_entities_by(floor_types, 0, LAYER.FRONT)
    local spawn_chance = options.a1_spawn_chance / 20
    local large_spawn_chance = options.a2_large_spawn_chance / 20
    
    for _,uid in ipairs(floors) do
        local ent = get_entity(uid)
        local x, y, l = get_position(uid)
        if prng:random_float(PRNG_CLASS.PROCEDURAL_SPAWNS) < spawn_chance and valid_crushblock_spawn(ent, uid, x, y, l) then
            if not (used[x] and used[x][y]) then
                if prng:random_float(PRNG_CLASS.PROCEDURAL_SPAWNS) < large_spawn_chance then
                    local right_uid = get_grid_entity_at(x+1, y, l)
                    local down_uid =  get_grid_entity_at(x, y-1, l)
                    local down_right_uid = get_grid_entity_at(x+1, y-1, l)
                    if right_uid ~= -1 and down_uid ~= -1 and down_right_uid ~= -1 then
                        local right, down, down_right = get_entity(right_uid), get_entity(down_uid), get_entity(down_right_uid)
                        if test_flag(right.flags, ENT_FLAG.SOLID) and valid_crushblock_l_spawn(right, right_uid, x+1, y, l) and
                        test_flag(down.flags, ENT_FLAG.SOLID) and valid_crushblock_l_spawn(down, down_uid, x, y-1, l) and
                        test_flag(down_right.flags, ENT_FLAG.SOLID) and valid_crushblock_l_spawn(down_right, down_right_uid, x+1, y-1, l) then
                            destroy_floor(ent); destroy_floor(right); destroy_floor(down); destroy_floor(down_right)
                            spawn(ENT_TYPE.ACTIVEFLOOR_CRUSH_TRAP_LARGE, x+0.5, y-0.5, l, 0, 0)
                            insert_to_used(x, y); insert_to_used(x+1, y); insert_to_used(x, y-1) insert_to_used(x+1, y-1)
                        else
                            replace_with_crushtrap(ent, x, y, l)
                        end
                    else
                        replace_with_crushtrap(ent, x, y, l)
                    end
                else
                    replace_with_crushtrap(ent, x, y, l)
                end
            end
        elseif options.g_fix_floors then
            tofix[#tofix+1] = uid
        end
    end
    if options.g_fix_floors then
        set_timeout(function()
            for _,uid in ipairs(tofix) do
                local ent = get_entity(uid)
                if ent then
                    if ent.type.id < ENT_TYPE.FLOORSTYLED_MINEWOOD then
                        ent:fix_decorations(false, true)
                    else
                        ent:decorate_internal()
                    end
                end
            end
        end, 1)
    end
end, ON.POST_LEVEL_GENERATION)

register_option_int('a1_spawn_chance', 'Crush trap spawn chance', '0 is 0%, 20 is 100%', 15, 0, 20)
register_option_int('a2_large_spawn_chance', 'Large crush trap chance', '0 is 0%, 20 is 100%', 5, 0, 20)
register_option_bool('d_spawn_safe_zones', 'enable safe zones', '(won\'t disable spawn safe zone)', true)
register_option_int('e_safe_zone_divisor', 'Safe zones divisor', 'the number of safe zones is the amount of rooms, divided by this number', 6, 1, 10)
register_option_int('f_safe_zone_radius', 'safe zones radius', '', 5, 0, 12)
register_option_bool('g_fix_floors', 'Fix floors deco', '', true)