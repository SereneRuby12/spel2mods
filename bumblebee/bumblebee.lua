meta = {
    name = "Bumblebee mod",
    version = "1.0",
    description = "Adds bumblebee mount",
    author = "SereneRuby12"
}
local JUMP = 1
local LEFT_DIR = 9 -- 256
local RIGHT_DIR = 10 -- 512
local UP_DIR = 11 -- 1024
local DOWN_DIR = 12 -- 2048
local HALF_PI = math.pi/2

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

local bumblebee_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MOUNTS_0)
    texture_def.texture_path = 'bumblebee_mount.png'
    bumblebee_texture = define_texture(texture_def)
end

local prev_destroyed_bumblebees = 0 --for deleting cookedturkey when a bumblebee dies
local prev_cookedturkeys = 0
local bumblebees = {}
local function new_bumblebee(ent) 
    ent:set_texture(bumblebee_texture)
    return {
        ["not_ridden"] = true,
        ["flying"] = false,
        ["flying_timer"] = 300,
        ["rider_jumped"] = false,
        ["rider_jumps"] = 0, --for telepack and vlads, 0 means that has jumped 0 times on air
        ["climb_frame"] = 0,
        ["not_climbing"] = true,
        ["callb"] = -1,
        ["last_rider_uid"] = -1,
        ["last_holder"] = -1
    }
end

local bumblebees_t_info = {} --transition info
local bumblebees_t_info_hh = {}
local function set_transition_info(slot, mounted) --mounted: false = being held
    table.insert(bumblebees_t_info, {["slot"] = slot, ["mounted"] = mounted})
end
local function set_transition_info_hh(e_type, hp, cursed, poisoned)
    table.insert(bumblebees_t_info_hh, {["e_type"] = e_type, ["hp"] = hp, ["cursed"] = cursed, ["poisoned"] = poisoned})
end

local function set_bumblebees_from_previous(companions)
    for i, info in ipairs(bumblebees_t_info) do
        for ip,p in ipairs(players) do
            if p.inventory.player_slot == info.slot then
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
        local ent = get_entity(uid)
        for _, info in pairs(bumblebees_t_info_hh) do
            if ent.type.id == info.e_type and ent.health == info.hp and test_flag(ent.more_flags, ENT_MORE_FLAG.CURSED_EFFECT) == info.cursed and ent:is_poisoned() == info.poisoned then
                local bee = ent:get_held_entity()
                bumblebees[bee.uid] = new_bumblebee(bee)
            end
        end
    end
end

local function get_holder_player(ent) -- or hh
    local holder = ent:topmost()
    if holder == ent then
        return nil
    elseif holder.type.search_flags == MASK.PLAYER or holder.type.search_flags == MASK.MOUNT then
        if holder.type.search_flags == MASK.MOUNT then --if the topmost is a mount, that means the true holder is the one riding it
            holder = get_entity(holder.rider_uid)
        end
        return holder
    end
end

local function update_climbing(bumblebee)
    if bumblebees[bumblebee.uid] then
        bumblebee.animation_frame = bumblebees[bumblebee.uid].climb_frame
    end
end

local function reset_rider_jumps(rider, backitem, backitem_type, jumps)
    if backitem_type == ENT_TYPE.ITEM_TELEPORTER_BACKPACK then
        backitem.teleport_number = jumps
    elseif backitem_type == ENT_TYPE.ITEM_VLADS_CAPE then
        if jumps == 0 then
            backitem.can_double_jump = true
        end
    end
end

local function spawn_bumblebee(x, y, l)
    local uid = spawn(ENT_TYPE.MOUNT_TURKEY, x, y, l, 0, 0)
    bumblebees[uid] = new_bumblebee(get_entity(uid))
    return uid
end

local function spawn_bumblebee_no_return(x, y, l)
    local uid = spawn(ENT_TYPE.MOUNT_TURKEY, x, y, l, 0, 0)
    bumblebees[uid] = new_bumblebee(get_entity(uid))
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

local bumblebee_chance = define_procedural_spawn("sample_bumblebee", spawn_bumblebee_no_return, is_valid_bumblebee_spawn)
set_callback(function(room_gen_ctx)
    bumblebees = {}
    if (state.theme == THEME.JUNGLE) then
        room_gen_ctx:set_procedural_spawn_chance(bumblebee_chance, 120)
    end
end, ON.POST_ROOM_GENERATION)

set_callback(function()
    if state.screen == 12 then
        local px, py, pl = get_position(players[1].uid)
        local companions = get_entities_at(0, MASK.PLAYER, px, py, pl, 2)
        set_bumblebees_from_previous(companions)
        bumblebees_t_info = {} 
        bumblebees_t_info_hh = {}
        
        --bee spawn on beehives
        local chance = 1
        local beehives = get_entities_by(ENT_TYPE.FLOORSTYLED_BEEHIVE, MASK.ANY, LAYER.FRONT)
        for _,uid in ipairs(beehives) do
            if math.random() <= chance then
                local x, y, l = get_position(uid)
                if #get_entities_at(0, MASK.FLOOR, x, y+1, LAYER.FRONT, 0.5) == 0 then
                    spawn_bumblebee(x, y+1, l)
                    chance = chance/5
                end
            end
        end
    end
end, ON.POST_LEVEL_GENERATION)

set_callback(function()
    
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
                if not c_ent.not_ridden then
                    c_ent.not_ridden = true
                    clear_entity_callback(uid, c_ent.callb)
                    bumblebee.angle = 0
                    bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                    c_ent.not_climbing = true
                end
            else
                local climbing = false
                local rider = get_entity(bumblebee.rider_uid)
                if c_ent.not_ridden then
                    c_ent.not_ridden = false
                    c_ent.flying = false
                end
                local input = read_input(rider.uid)
                if c_ent.flying then
                    bumblebee.angle = 0
                    bumblebee.velocityy = 0.0001
                    c_ent.flying_timer = c_ent.flying_timer - 1
                    if c_ent.flying_timer < 60 then
                        bumblebee.color.g = c_ent.flying_timer*0.0025 + 0.75
                        bumblebee.color.b = c_ent.flying_timer*0.005 + 0.5
                    end
                    if c_ent.flying_timer == 0 or bumblebee.state ~= 8 and bumblebee.state ~= 9 and (bumblebee.standing_on_uid == -1 or not test_flag(input, UP_DIR)) then
                        c_ent.flying = false
                        local backitem = get_entity(rider:worn_backitem())
                        if backitem then
                            reset_rider_jumps(rider, backitem, backitem.type.id, c_ent.rider_jumps)
                        end
                        if bumblebee:topmost().type.id ~= ENT_TYPE.FLOOR_PIPE then
                            bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                        end
                    end
                    local y = 0
                    
                    if test_flag(input, UP_DIR) then
                        y = 0.1
                    elseif test_flag(input, DOWN_DIR) then
                        y = -0.1
                    end
                    bumblebee.x = bumblebee.x+(math.random()/10-0.05)
                    local hitbx = get_hitbox(uid, 0, 0, 0.15)
                    hitbx.left, hitbx.right = hitbx.left + 0.1, hitbx.right - 0.1
                    if #get_blocks(get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, hitbx, bumblebee.layer)) == 0 then
                        bumblebee.y = bumblebee.y+(math.random()/10-0.05)+y
                    else
                        bumblebee.y = bumblebee.y+(math.random()/20-0.05) + (y < 0 and y or 0)
                    end
                else --climbing
                    if (bumblebee.velocityy < 0 or not c_ent.not_climbing) and not test_flag(input, JUMP) then
                        if test_flag(input, LEFT_DIR) then
                            local hitbx = get_hitbox(uid, 0, -0.1, 0)
                            hitbx.top, hitbx.bottom = hitbx.top - 0.5, hitbx.bottom + 0.1
                            if #get_blocks(get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, hitbx, bumblebee.layer)) ~= 0 then
                                bumblebee.angle = -HALF_PI
                                climbing = true
                            end
                        elseif test_flag(input, RIGHT_DIR) then
                            local hitbx = get_hitbox(uid, 0, 0.1, 0)
                            hitbx.top, hitbx.bottom = hitbx.top - 0.5, hitbx.bottom + 0.1
                            if #get_blocks(get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, hitbx, bumblebee.layer)) ~= 0 then
                                bumblebee.angle = HALF_PI
                                climbing = true
                            end
                        end
                    end
                end
                if climbing then
                    if c_ent.not_climbing then
                        c_ent.callb = set_post_statemachine(uid, update_climbing)
                        c_ent.not_climbing = false
                        bumblebee.can_doublejump = true
                    end
                    bumblebee.flags = set_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                    if test_flag(input, UP_DIR) then
                        bumblebee.velocityy = 0.05
                        if state.time_level % 2 == 0 then
                            if c_ent.climb_frame > 7 then
                                c_ent.climb_frame = 1
                            else
                                c_ent.climb_frame = c_ent.climb_frame + 1
                            end
                        end
                    elseif test_flag(input, DOWN_DIR) then
                        bumblebee.velocityy = -0.05
                        if state.time_level % 2 == 0 then
                            if c_ent.climb_frame < 2 then
                                c_ent.climb_frame = 8
                            else
                                c_ent.climb_frame = c_ent.climb_frame - 1
                            end
                        end
                    else
                        bumblebee.velocityy = 0
                        c_ent.climb_frame = 0
                    end
                elseif not c_ent.not_climbing then
                    clear_entity_callback(uid, c_ent.callb)
                    bumblebee.angle = 0
                    if bumblebee:topmost().type.id ~= ENT_TYPE.FLOOR_PIPE then
                        bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                    end
                    c_ent.not_climbing = true
                end
                if test_flag(input, JUMP) then
                    if not c_ent.rider_jumped and bumblebee.standing_on_uid == -1 and c_ent.flying_timer ~= 0 and bumblebee:topmost() == bumblebee then --topmost() is for checking if is in a pipe. Doesn't work well in water
                        c_ent.flying = not c_ent.flying
                        local backitem_uid = rider:worn_backitem()
                        if c_ent.flying then
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
                                local backitem = get_entity(backitem_uid)
                                if backitem.type.id == ENT_TYPE.ITEM_HOVERPACK then
                                    backitem.is_on = false
                                end
                            end
                            bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                        end
                    end
                    c_ent.rider_jumped = true
                else
                    c_ent.rider_jumped = false
                    if not c_ent.flying and c_ent.flying_timer ~= 0 then
                        bumblebee.can_doublejump = true
                    end
                end
            end
        else
            prev_destroyed_bumblebees = prev_destroyed_bumblebees + 1
            bumblebees[uid] = nil
        end
    end
    do
        local cookedturkeys = get_entities_by_type(ENT_TYPE.ITEM_PICKUP_COOKEDTURKEY)
        local cookeddiff = #cookedturkeys-prev_cookedturkeys
        local cooked_num = math.min(cookeddiff, prev_destroyed_bumblebees)
        if #cookedturkeys > 0 then
            for i = #cookedturkeys, 0, -1 do
                if cooked_num > 0 then
                    get_entity(cookedturkeys[i]).y = -10
                    cooked_num = cooked_num - 1
                end
            end
        end
        for i, v in ipairs(get_entities_by_type(ENT_TYPE.ITEM_TURKEY_NECK)) do
            local ent = get_entity(v)
            local from_ent = ent:topmost_mount()
            if from_ent ~= ent and bumblebees[from_ent.uid] then
                get_entity(v).y = -1000
            end
        end
        prev_cookedturkeys = #cookedturkeys
    end
    prev_destroyed_bumblebees = 0

    if #get_entities_by_type(ENT_TYPE.FX_PORTAL) > 0 then
        for uid,c_ent in pairs(bumblebees) do
            local bumblebee = get_entity(uid)
            if bumblebee.state ~= 24 and bumblebee.last_state ~= 24 then --24 seems to be the state when entering portal
                c_ent.last_holder = get_holder_player(bumblebee)
                c_ent.last_rider_uid = bumblebee.rider_uid
            end
        end
    end
end, ON.FRAME)

set_callback(function()
    if state.loading == 2 and ((state.screen_next == SCREEN.TRANSITION and state.screen ~= SCREEN.SPACESHIP) or state.screen_next == SCREEN.SPACESHIP) then
        for uid, c_ent in pairs(bumblebees) do
            local bumblebee = get_entity(uid)
            local holder, rider_uid
            if not bumblebee or bumblebee.state == 24 or bumblebee.last_state == 24 then
                holder = c_ent.last_holder
                rider_uid = c_ent.last_rider_uid
            else
                holder = get_holder_player(bumblebee)
                rider_uid = bumblebee.rider_uid
            end
            if holder then
                if holder.inventory.player_slot == -1 then
                    set_transition_info_hh(holder.type.id, holder.health, test_flag(holder.more_flags, ENT_MORE_FLAG.CURSED_EFFECT), holder:is_poisoned())
                else
                    set_transition_info(holder.inventory.player_slot, false) --the bumble
                end
            elseif rider_uid ~= -1 then
                holder = get_entity(rider_uid)
                if holder.type.search_flags == MASK.PLAYER then
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
    if players[1] then
        local px, py, pl = get_position(players[1].uid)
        spawn_bumblebee(px, py, pl)
    end
end)

register_option_button("spawntamed", "Spawn tamed bumblebee", function()
    if players[1] then
        local px, py, pl = get_position(players[1].uid)
        get_entity(spawn_bumblebee(px, py, pl)):tame(true)
    end
end)
