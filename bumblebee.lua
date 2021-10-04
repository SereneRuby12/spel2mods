meta.name = "Bumblebee mod"
meta.version = "0.5?"
meta.description = "Adds bumblebees"
meta.author = "Estebanfer"

local JUMP = 1
local WHIP = 2
local LEFT_DIR = 9 -- 256
local RIGHT_DIR = 10 -- 512
local UP_DIR = 11 -- 1024
local DOWN_DIR = 12 -- 2048

--fix random bug with player not being able to move after level transition while mounting bumblebee?
--add better transitions and not make all turkeys to be bumblebees
local bumblebee_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MOUNTS_0)
    texture_def.texture_path = 'bumblebee_mount.png'
    bumblebee_texture = define_texture(texture_def)
end

local bumblebees = {}
local function new_bumblebee(uid) 
    get_entity(uid):set_texture(bumblebee_texture)
    return {
        ["not_stolen"] = true,
        ["flying"] = false,
        ["flying_timer"] = 300,
        ["rider_uid"] = -1,
        ["rider_jumped"] = false
    }
end

set_callback(function()
    not_stolen = {true, true, true, true}
    mount_flying = {false, false, false, false}
    mount_pos = {{['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}}
end, ON.LEVEL)

set_callback(function()
    bumblebees = {}
    local turkeys = get_entities_by_type(ENT_TYPE.MOUNT_TURKEY)
    for i, uid in ipairs(turkeys) do
        --get_entity(uid):set_texture(bumblebee_texture)
        bumblebees[uid] = new_bumblebee(uid)
    end
end, ON.POST_LEVEL_GENERATION)

set_callback(function()
    --for _,uid in ipairs(get_entities_by_type(ENT_TYPE.ITEM_PICKUP_COOKEDTURKEY)) do
    --    get_entity(uid).y = -10
    --end
    for uid,c_ent in pairs(bumblebees) do
        local bumblebee = get_entity(uid)
        if bumblebee then
            messpect(true)
            if bumblebee.standing_on_uid ~= -1 then
                bumblebee.color.g = 1
                bumblebee.color.b = 1
                c_ent.flying_timer = 60 * (bumblebee.health+1)
            end
            if bumblebee.rider_uid == -1 then
                messpect(-1)
                if not c_ent.not_stolen then
                    return_input(c_ent.rider_uid)
                    c_ent.not_stolen = true
                end
            else
                messpect(true, 1)
                local rider = get_entity(bumblebee.rider_uid)
                c_ent.rider_uid = bumblebee.rider_uid
                if c_ent.not_stolen then
                    steal_input(rider.uid)
                    c_ent.not_stolen = false
                end
                local input = read_stolen_input(rider.uid)
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
                        bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                    end
                    local y = 0
                    
                    if test_flag(input, UP_DIR) then
                        y = 0.1
                    elseif test_flag(input, DOWN_DIR) then
                        y = -0.1
                    end
                    bumblebee.x = bumblebee.x+(math.random()/10-0.05)
                    bumblebee.y = bumblebee.y+(math.random()/10-0.05)+y
                end
                if test_flag(input, JUMP) then
                    if not c_ent.rider_jumped and bumblebee.standing_on_uid == -1 and c_ent.flying_timer ~= 0 and bumblebee.some_state == 0 and bumblebee:topmost() == bumblebee then --some_state is for checking if the mount is wet, topmost() is for checking if is in a pipe
                        c_ent.flying = not c_ent.flying
                        if c_ent.flying then
                            messpect('pressed', c_ent.flying)
                            bumblebee.velocityy = 0.01
                            bumblebee.can_doublejump = true
                            bumblebee.flags = set_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                        else
                            bumblebee.flags = clr_flag(bumblebee.flags, ENT_FLAG.NO_GRAVITY)
                        end
                    end
                    c_ent.rider_jumped = true
                else
                    c_ent.rider_jumped = false
                end
                if test_flag(input, WHIP) and rider.holding_uid == -1 or bumblebee.state == 5 then
                    input = clr_flag(input, WHIP)
                end
                messpect(bumblebee.some_state, c_ent.flying, bumblebee.state, c_ent.flying_timer)
                if c_ent.flying then
                    send_input(rider.uid, set_flag(input, JUMP) )
                else
                    send_input(rider.uid, input )
                end
            else
                bumblebees[uid] = nil
            end
        end
    end
end, ON.FRAME)

register_option_button("spawn", "Spawn bumblebee", function()
    local px, py, pl = get_position(players[1].uid)
    local uid = spawn(ENT_TYPE.MOUNT_TURKEY, px, py, pl, 0, 0)
    bumblebees[uid] = new_bumblebee(uid)
end)