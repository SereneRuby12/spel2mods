local not_stolen = {true, true, true, true}
local mount_flying = {false, false, false, false}
local mount_flying_timer = {240, 240, 240, 240}
--local mount_pos = {{['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}}
local wait_frames = {5, 5, 5, 5}
local jumped = {false, false, false, false}

--TODO: use this table instead the previous ones?
local bumblebees = {}
local function new_bumblebee() {
    return {["not_stolen"] = true, ["flying"] = false, ["flying_timer"] = 300, ["wait_frames"] = 5, ["rider_jumped"] = false}
}

local JUMP = 1
local WHIP = 2
local LEFT_DIR = 9 -- 256
local RIGHT_DIR = 10 -- 512
local UP_DIR = 11 -- 1024
local DOWN_DIR = 12 -- 2048

local bumblebee_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MOUNTS_0)
    texture_def.texture_path = 'bumblebee_mount.png'
    bumblebee_texture = define_texture(texture_def)
end

set_callback(function()
    not_stolen = {true, true, true, true}
    mount_flying = {false, false, false, false}
    mount_pos = {{['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}, {['x'] = -1, ['y'] = -1}}
end, ON.LEVEL)

set_callback(function()
    local turkeys = get_entities_by_type(ENT_TYPE.MOUNT_TURKEY)
    for i, uid in ipairs(turkeys) do
        get_entity(uid):set_texture(bumblebee_texture)
    end
end, ON.POST_LEVEL_GENERATION)

set_callback(function()
    local topmost_mount = players[1]:topmost_mount()
    --messpect(topmost_mount.type.id)
    if topmost_mount.type.id == ENT_TYPE.MOUNT_TURKEY then
        if not_stolen[1] then
            steal_input(players[1].uid)
        end
        local input = read_stolen_input(players[1].uid)
        --messpect(input)
        if mount_flying[1] then
            topmost_mount.velocityy = 0.0001
            mount_flying_timer[1] = mount_flying_timer[1] - 1
            if mount_flying_timer[1] < 60 then
                topmost_mount.color.g = mount_flying_timer[1]*0.0025 + 0.75
                topmost_mount.color.b = mount_flying_timer[1]*0.005 + 0.5
            end
            if mount_flying_timer[1] == 0 or topmost_mount.state ~= 8 and topmost_mount.state ~= 9 and (topmost_mount.standing_on_uid == -1 or not test_flag(input, UP_DIR)) then
                messpect(topmost_mount.state)
                mount_flying[1] = false
                topmost_mount.flags = clr_flag(topmost_mount.flags, ENT_FLAG.NO_GRAVITY)
            end
            --[[local x, y = 0, 0
            if test_flag(input, LEFT_DIR) then
                x = -0.1
            elseif test_flag(input, RIGHT_DIR) then
                x = 0.1
            end]]
            
            if test_flag(input, UP_DIR) then
                y = 0.1
            elseif test_flag(input, DOWN_DIR) then
                y = -0.1
            end
            --mount_pos[1].x = topmost_mount.x --mount_pos[1].x + x
            --mount_pos[1].y = topmost_mount.y+y --mount_pos[1].y + y
            --messpect(mount_pos[1].x, mount_pos[1].y)
            --messpect(math.min(topmost_mount.x-0.1, mount_pos[1].x-0.2), math.max(topmost_mount.x+0.1, mount_pos[1].x+0.2))
            topmost_mount.x = topmost_mount.x+(math.random()/10-0.05)
            topmost_mount.y = topmost_mount.y+(math.random()/10-0.05)+y
            
            --mount_pos[1].x = topmost_mount.x
            --mount_pos[1].y = topmost_mount.y
            --end
        end
        if test_flag(input, JUMP) then --or (mount_flying[1] and topmost_mount.state ~= 8) then
            if not jumped[1] and topmost_mount.standing_on_uid == -1 and mount_flying_timer[1] ~= 0 and topmost_mount.some_state == 0 and topmost_mount:topmost() == topmost_mount then --some_state is for checking if the mount is wet, topmost() is for checking if is in a pipe
                mount_flying[1] = not mount_flying[1]
                --mount_flying[1] = true
                if mount_flying[1] then
                    wait_frames[1] = 5
                    messpect('pressed', mount_flying[1])
                    topmost_mount.velocityy = 0.01
                    --mount_pos[1].x = topmost_mount.x
                    --mount_pos[1].y = topmost_mount.y
                    --messpect(topmost_mount.x)
                    topmost_mount.can_doublejump = true
                    topmost_mount.flags = set_flag(topmost_mount.flags, ENT_FLAG.NO_GRAVITY)
                else
                    topmost_mount.flags = clr_flag(topmost_mount.flags, ENT_FLAG.NO_GRAVITY)
                end
            end
            jumped[1] = true
        else
            jumped[1] = false
        end
        if topmost_mount.standing_on_uid ~= -1 then
            topmost_mount.color.g = 1
            topmost_mount.color.b = 1
            mount_flying_timer[1] = 60 * (topmost_mount.health+1)
        end
        if test_flag(input, WHIP) and players[1].holding_uid == -1 or topmost_mount.state == 5 then
            input = clr_flag(input, WHIP)
        end
        messpect(players[1]:topmost_mount().some_state, mount_flying[1], topmost_mount.state, mount_flying_timer[1])
        if mount_flying[1] then
            send_input(players[1].uid, set_flag(input, JUMP) )
        else
            send_input(players[1].uid, input )
        end
    elseif not_stolen[1] then
        return_input(players[1].uid)
    end
end, ON.FRAME)