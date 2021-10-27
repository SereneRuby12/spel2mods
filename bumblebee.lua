meta = {
    name = "Bumblebee mod",
    version = "0.7?",
    description = "Adds bumblebees",
    author = "Estebanfer"
}
--TODO: add the sticking to walls thing
local JUMP = 1
local WHIP = 2
local LEFT_DIR = 9 -- 256
local RIGHT_DIR = 10 -- 512
local UP_DIR = 11 -- 1024
local DOWN_DIR = 12 -- 2048

local function get_blocks(floors)
    local blocks = {}
    for i, v in ipairs(floors) do
        local flags = get_entity_flags(v)
        if test_flag(flags, ENT_FLAG.SOLID) then
            table.insert(blocks, v)
        end
    end
    return blocks
end

--fix random bug with player not being able to move after level transition while mounting bumblebee?
local bumblebee_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MOUNTS_0)
    texture_def.texture_path = 'bumblebee_mount.png'
    bumblebee_texture = define_texture(texture_def)
end

local prev_destroyed_bumblebees = 0 --for deleting cookedturkey when a bumblebee dies
local bumblebees = {}
local function new_bumblebee(ent) 
    ent:set_texture(bumblebee_texture)
    return {
        ["not_stolen"] = true,
        ["flying"] = false,
        ["flying_timer"] = 300,
        ["rider_uid"] = -1,
        ["rider_jumped"] = false,
        ["rider_jumps"] = 0 --for telepack and vlads, 0 means that has jumped 0 times on air
    }
end

local bumblebees_t_info = {} --transition info
local bumblebees_t_info_hh = {}
local function set_transition_info(slot, mounted) --mounted if false then it's being held
    table.insert(bumblebees_t_info, {["slot"] = slot, ["mounted"] = mounted})
end
local function set_transition_info_hh(e_type, hp, cursed, poisoned)
    table.insert(bumblebees_t_info_hh, {["e_type"] = e_type, ["hp"] = hp, ["cursed"] = cursed, ["poisoned"] = poisoned})
end

local function set_bumblebees_from_previous(companions)
    for i, info in ipairs(bumblebees_t_info) do
        messpect(info)
        for ip,p in ipairs(players) do
            messpect(p.inventory.player_slot, info.slot)
            if p.inventory.player_slot == info.slot then
                messpect('trueslot')
                if info.mounted then
                    local bee = p:topmost_mount()
                    bumblebees[bee.uid] = new_bumblebee(bee)
                else
                    local bee = p:get_held_entity()
                    bumblebees[bee.uid] = new_bumblebee(bee)
                end
            end
        end
    end
    for i, uid in ipairs(companions) do
        messpect(uid)
        local ent = get_entity(uid)
        for _, info in pairs(bumblebees_t_info_hh) do
            messpect(ent.type.id, info.e_type, ent.health, info.hp, test_flag(ent.more_flags, ENT_MORE_FLAG.CURSED_EFFECT), info.cursed, ent:is_poisoned(), info.poisoned)
            if ent.type.id == info.e_type and ent.health == info.hp and test_flag(ent.more_flags, ENT_MORE_FLAG.CURSED_EFFECT) == info.cursed and ent:is_poisoned() == info.poisoned then
                messpect('setBEE')
                local bee = ent:get_held_entity()
                bumblebees[bee.uid] = new_bumblebee(bee)
            end
        end
    end
end

local function spawn_bumblebee(x, y, l)
    local uid = spawn(ENT_TYPE.MOUNT_TURKEY, x, y, l, 0, 0)
    bumblebees[uid] = new_bumblebee(get_entity(uid))
end

local function reset_rider_jumps(rider, backitem, backitem_type, jumps)
    messpect('reload jumps')
    if backitem_type == ENT_TYPE.ITEM_TELEPORTER_BACKPACK then
        backitem.teleport_number = jumps
    elseif backitem_type == ENT_TYPE.ITEM_VLADS_CAPE then
        messpect('vlads ', jumps)
        if jumps == 0 then
            backitem.can_double_jump = true
        end
    end
end

local function spawn_bumblebee(x, y, l)
    local uid = spawn(ENT_TYPE.MOUNT_TURKEY, x, y, l, 0, 0)
    bumblebees[uid] = new_bumblebee(get_entity(uid))
    message('spawned')
    return uid
end

--bee spawn
local function is_valid_bumblebee_spawn(x, y, l)
    local floor = get_grid_entity_at(x, y, l)
    if floor == -1 then
        local top_floor = get_grid_entity_at(x, y+1, l)
        if top_floor == -1 then
            local down_floor = get_entity(get_grid_entity_at(x, y-1, l))
            if down_floor and test_flag(down_floor.flags, ENT_FLAG.SOLID) and down_floor.type.id ~= ENT_TYPE.FLOOR_THORN_VINE and down_floor.type.id ~= ENT_TYPE.FLOOR_JUNGLE_SPEAR_TRAP then
                return true
            end
        end
    end
    return false
end
local bumblebee_chance = define_procedural_spawn("sample_bumblebee", spawn_bumblebee, is_valid_bumblebee_spawn)
set_callback(function(room_gen_ctx)
    bumblebees = {}
    if (state.theme == THEME.JUNGLE) then
        room_gen_ctx:set_procedural_spawn_chance(bumblebee_chance, 150)
    end
end, ON.POST_ROOM_GENERATION)

set_callback(function()
    --[[local turkeys = get_entities_by_type(ENT_TYPE.MOUNT_TURKEY)
    for i, uid in ipairs(turkeys) do
        --get_entity(uid):set_texture(bumblebee_texture)
        bumblebees[uid] = new_bumblebee(uid)
    end]]
    local px, py, pl = get_position(players[1].uid)
    local companions = get_entities_at(0, MASK.PLAYER, px, py, pl, 2)
    set_bumblebees_from_previous(companions)
    bumblebees_t_info = {}
    bumblebees_t_info_hh = {}
    
    --bee spawn on beehives
    local chance = 1
    local beehives = get_entities_by(ENT_TYPE.FLOORSTYLED_BEEHIVE, MASK.ANY, LAYER.FRONT)
    messpect("beehives:", #beehives)
    for _,uid in ipairs(beehives) do
        if math.random() <= chance then
            local x, y, l = get_position(uid)
            if #get_entities_at(0, MASK.FLOOR, x, y+1, LAYER.FRONT, 0.5) == 0 then
                messpect("spawned")
                spawn_bumblebee(x, y+1, l)
                chance = chance/5
            end
        end
    end
end, ON.POST_LEVEL_GENERATION)

set_callback(function()
    do
        local cookedturkeys = get_entities_by_type(ENT_TYPE.ITEM_PICKUP_COOKEDTURKEY)
        if #cookedturkeys > 0 then
            for i = #cookedturkeys, 0, -1 do
                if prev_destroyed_bumblebees > 0 then
                    get_entity(cookedturkeys[i]).y = -10
                    prev_destroyed_bumblebees = prev_destroyed_bumblebees - 1
                end
            end
        end
    end
    prev_destroyed_bumblebees = 0
    for uid,c_ent in pairs(bumblebees) do
        local bumblebee = get_entity(uid)
        if bumblebee then
            if bumblebee.standing_on_uid ~= -1 then
                bumblebee.color.g = 1
                bumblebee.color.b = 1
                c_ent.flying_timer = 60 * (bumblebee.health+1)
                c_ent.rider_jumps = -1
            end
            if bumblebee.rider_uid == -1 then
                if not c_ent.not_stolen then
                    messpect(-1, c_ent.not_stolen)
                    --return_input(c_ent.rider_uid)
                    c_ent.not_stolen = true
                    messpect(c_ent.not_stolen, "c_ent.not_stolen")
                    c_ent.rider_uid = -1
                end
            else
                local rider = get_entity(bumblebee.rider_uid)
                --messpect(true, rider.uid, c_ent.not_stolen)
                c_ent.rider_uid = bumblebee.rider_uid
                if c_ent.not_stolen then
                    messpect('STOLEN')
                    --steal_input(rider.uid)
                    c_ent.not_stolen = false
                    c_ent.flying = false
                end
                local input = read_input(rider.uid)--read_stolen_input(rider.uid)
                --messpect(input)
                if c_ent.flying then
                    bumblebee.velocityy = 0.0001
                    c_ent.flying_timer = c_ent.flying_timer - 1
                    if c_ent.flying_timer < 60 then
                        bumblebee.color.g = c_ent.flying_timer*0.0025 + 0.75
                        bumblebee.color.b = c_ent.flying_timer*0.005 + 0.5
                    end
                    if c_ent.flying_timer == 0 or bumblebee.state ~= 8 and bumblebee.state ~= 9 and (bumblebee.standing_on_uid == -1 or not test_flag(input, UP_DIR)) then
                        messpect(bumblebee.state)
                        c_ent.flying = false
                        local backitem = get_entity(rider:worn_backitem())
                        if backitem then
                            messpect('backitem')
                            reset_rider_jumps(rider, backitem, backitem.type.id, c_ent.rider_jumps)
                        end
                        bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                    end
                    local y = 0
                    
                    if test_flag(input, UP_DIR) then
                        y = 0.1
                    elseif test_flag(input, DOWN_DIR) then
                        y = -0.1
                    end
                    local hitbx = get_hitbox(uid, LAYER.FRONT, 0, 0.15, 0)
                    hitbx.left = hitbx.left + 0.1
                    hitbx.right = hitbx.right - 0.1
                    bumblebee.x = bumblebee.x+(math.random()/10-0.05)
                    if #get_blocks(get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, hitbx, bumblebee.layer)) == 0 then
                        --messpect('notOverlapping')
                        bumblebee.y = bumblebee.y+(math.random()/10-0.05)+y
                    else
                        --messpect('Overlapping')
                        bumblebee.y = bumblebee.y+(math.random()/20-0.05) + (y < 0 and y or 0)
                    end
                end
                if test_flag(input, JUMP) then
                    if not c_ent.rider_jumped and bumblebee.standing_on_uid == -1 and c_ent.flying_timer ~= 0 and bumblebee.some_state == 0 and bumblebee:topmost() == bumblebee then --some_state is for checking if the mount is wet, topmost() is for checking if is in a pipe
                        c_ent.flying = not c_ent.flying
                        local backitem_uid = rider:worn_backitem()
                        if c_ent.flying then
                            messpect('pressed', c_ent.flying)
                            bumblebee.velocityy = 0.01
                            --bumblebee.can_doublejump = true
                            bumblebee.flags = set_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                            if (backitem_uid ~= -1) then
                                local backitem = get_entity(backitem_uid) --ITEM_TELEPORTER_BACKPACK
                                local backitem_type = backitem.type.id
                                if backitem_type == ENT_TYPE.ITEM_HOVERPACK then
                                    backitem.is_on = false
                                elseif c_ent.rider_jumps == -1 then
                                    if backitem_type == ENT_TYPE.ITEM_TELEPORTER_BACKPACK then
                                        --add save teleport number
                                        messpect('jumps reset', c_ent.rider_jumps, backitem.teleport_number)
                                        c_ent.rider_jumps = backitem.teleport_number --done?
                                        backitem.teleport_number = 3
                                    elseif backitem_type == ENT_TYPE.ITEM_VLADS_CAPE then
                                        if backitem.can_double_jump then
                                            c_ent.rider_jumps = 0
                                            backitem.can_double_jump = false
                                        else
                                            c_ent.rider_jumps = 1
                                        end
                                    end
                                end
                            end
                        else
                            if (backitem_uid ~= -1) then
                                local backitem = get_entity(backitem_uid) --ITEM_TELEPORTER_BACKPACK
                                if backitem.type.id == ENT_TYPE.ITEM_HOVERPACK then
                                    backitem.is_on = false
                                end
                            end
                            bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                            --bumblebee.can_doublejump = true
                        end
                    end
                    c_ent.rider_jumped = true
                else
                    c_ent.rider_jumped = false
                    if not c_ent.flying and c_ent.flying_timer ~= 0 then
                        messpect('canDoubleJump')
                        bumblebee.can_doublejump = true
                    end
                end
                if test_flag(input, WHIP) and rider.holding_uid == -1 or bumblebee.state == 5 then
                    input = clr_flag(input, WHIP)
                end
                --messpect(bumblebee.some_state, c_ent.flying, bumblebee.state, c_ent.flying_timer, input)
            end
        else
            bumblebees[uid] = nil
            prev_destroyed_bumblebees = prev_destroyed_bumblebees + 1
        end
    end
end, ON.FRAME)

set_callback(function()
    if state.loading == 2 and state.screen_next == SCREEN.TRANSITION then
        for uid, c_ent in pairs(bumblebees) do
            local bumblebee = get_entity(uid)
            local holder = bumblebee:topmost()
            messpect('bee', uid, holder.uid)
            if bumblebee ~= holder and (holder.type.search_flags == MASK.PLAYER or holder.type.search_flags == MASK.MOUNT) then -- the bumblebee is being held, and the holder is a player
                if holder.type.search_flags == MASK.MOUNT then --when the mount is held and the holder is mounted on another, the topmost becomes the mounted
                    messpect("holder is mount", holder.uid)
                    holder = get_entity(holder.rider_uid)
                    messpect(bumblebee.rider_uid)
                end
                messpect('holding')
                if holder.inventory.player_slot == -1 then
                    messpect('hh')
                    set_transition_info_hh(holder.type.id, holder.health, test_flag(holder.more_flags, ENT_MORE_FLAG.CURSED_EFFECT), holder:is_poisoned())
                else
                    set_transition_info(holder.inventory.player_slot, false) --the bumble
                end
            elseif bumblebee.rider_uid ~= -1 then
                holder = get_entity(bumblebee.rider_uid)
                messpect(holder.uid)
                if holder.type.search_flags == MASK.PLAYER then
                    messpect('mounting')
                    set_transition_info(holder.inventory.player_slot, true)
                end
            end
        end
    end
end, ON.LOADING)

set_callback(function()
    local companions = get_entities_by(0, MASK.PLAYER, LAYER.FRONT)
    set_bumblebees_from_previous(companions)
end, ON.TRANSITION)

register_option_button("spawn", "Spawn bumblebee", function()
    local px, py, pl = get_position(players[1].uid)
    spawn_bumblebee(px, py, pl)
end)

register_option_button("spawntamed", "Spawn tamed bumblebee", function()
    local px, py, pl = get_position(players[1].uid)
    get_entity(spawn_bumblebee(px, py, pl)):tame(true)
end)