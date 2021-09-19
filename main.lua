meta.name = "portalunky"
meta.author = "Estebanfer"
--I have to remove the steal_input because the player ghosts sometimes don't get input back, maybe use the freezeray with infinite cooldown, and teleport a arrow every frame to it
--I had a crash when setting a portal in the bounds, being in the portal, and placing it in another place
register_option_bool("door_portal", "door button to portal", "Shoot a portal using the door button", false)

local LEFT_DIR = 9 -- 256
local RIGHT_DIR = 10 -- 512
local UP_DIR = 11 -- 1024
local DOWN_DIR = 12 -- 2048

local white = Color:white()
local has_portal_gun = {true, true, true, true}
local actual_texture = {TEXTURE.DATA_TEXTURES_CHAR_YELLOW_0, 270, 270, 270} --all are the same
local touching_portal = {-1, -1, -1, -1} --contains the number of the other portal when you're touching one

local draw_x = {}
local draw_y = {}
--[[local portal_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_SHADOWS_0) --TEXTURE.DATA_TEXTURES_ITEMS_0
    texture_def.texture_path = 'portal_textures.png'
    portal_texture = define_texture(texture_def)
end]]
local portal_items_texture
do
    local texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_ITEMS_0)
    texture_def.texture_path = 'portal_items.png'
    portal_items_texture = define_texture(texture_def)
end

local p_sounds = {}
p_sounds[1] = create_sound('portal_sound1.wav')
p_sounds[2] = create_sound('portal_sound2.wav')

local portal_colors = {
    {
        {{["r"]=0, ["g"]=0.5, ["b"]=1}},
        {{["r"]=1, ["g"]=0.5, ["b"]=0}}
    },
    
    {
        {{["r"]=0, ["g"]=0.25, ["b"]=1}, {["r"]=1, ["g"]=0, ["b"]=0}},
        {{["r"]=0.75, ["g"]=0, ["b"]=0.75}, {["r"]=0.75, ["g"]=0.75, ["b"]=0}}
    },
    
    {
        {{["r"]=1, ["g"]=0, ["b"]=0}, {["r"]=0, ["g"]=1, ["b"]=0}, {["r"]=0, ["g"]=0, ["b"]=1}},
        {{["r"]=0.5, ["g"]=0, ["b"]=0}, {["r"]=0, ["g"]=0.5, ["b"]=0}, {["r"]=0, ["g"]=0, ["b"]=0.5}}
    },
    
    {
        {{["r"]=0, ["g"]=0, ["b"]=1}, {["r"]=1, ["g"]=0.5, ["b"]=0}, {["r"]=0, ["g"]=1, ["b"]=0.5}, {["r"]=1, ["g"]=0, ["b"]=0.5}},
        {{["r"]=0, ["g"]=0, ["b"]=0.5}, {["r"]=0.5, ["g"]=0.25, ["b"]=0}, {["r"]=0, ["g"]=0.5, ["b"]=0.25}, {["r"]=0.5, ["g"]=0, ["b"]=0.25}}
    },
}
local portal_gun_angle = {0, 0, 0, 0}
--changed to multiplayer
local portals

local function reset_portals_new_level()
portals = {
    { --p1
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} },
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} }
    },
    
    { --p2
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} },
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} }
    },

    { --p3
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} },
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} }
    },

    { --p4
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} },
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["hitbox"] = nil, ["b_uid"] = -1, ["positive"]=false, ["horiz"] = false, ["border_uids"] = {} }
    },
}
end
reset_portals_new_level()

local using_colors = portal_colors[1] --use: using_colors[portalnum][playernum].r
local portal_guns = {}

local function sign(num)
    if num < 0 then
        return -1
    else
        return 1
    end
end

local function sign_to_bool(num)
    if num < 0 then
        return false
    else
        return true
    end
end

local function bsign(bool)
    return bool and 1 or -1
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function get_next_block(x, y, ysum, xdir) --probably has unnecesary things, but I was like 10 hours doing this
    local rx, ry = x%1, y%1 --relative x, y
    local xdiff = xdir == 1 and 1-rx or (rx==0 and -1 or -rx)
    local ydiff = math.abs(xdiff)*ysum
    local f
    if ysum > 0 then
        f = ydiff+ry < 1
    else
        f = ry+ydiff > (ry>0 and 0 or -1)
    end
    if f then --if moving to the next x grid is closer
        return true, x+(xdiff), y+ydiff
    else
        ydiff = ysum > 0 and 1-ry or (-ry == 0 and -1 or -ry)
        xdiff = xdir*math.abs(ydiff/ysum)
        return false, x+xdiff, y+ydiff
    end
end

local function get_raycast_collision(x, y, l, xdir, angle)
    local steps = 0
    local ysum = math.tan(angle)
    messpect(x, y, ysum)
    x = x + 0.5
    y = y - 0.5
    repeat
        --Make it work on CO
        local is_horiz, tosum_x, tosum_y = get_next_block(x, y, ysum, xdir, steps < 4)
        x, y = tosum_x, tosum_y
        for sum = -0.01, 0.02, 0.02 do
            --messpect(-0.5-sum, 0.5+sum)
            local g_ent = get_grid_entity_at(x-0.5-sum, y+0.5+sum, l)
            --local g_ent = get_grid_entity_at(x-0.49, y+0.49, l)
            table.insert(draw_x, x-0.51)
            table.insert(draw_y, y+0.51)
            if g_ent ~= -1 and test_flag(get_entity(g_ent).type.properties_flags, 1) then
                return g_ent, x, y, is_horiz
            end
        end
        steps = steps + 1
    until steps == 100
end

local function set_p_detail(uid)
    local det = get_entity(uid)
    det.flags = set_flag(set_flag(det.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING), ENT_FLAG.NO_GRAVITY)
    det.color.r = 0
    det.color.g = 0.5
    det:set_draw_depth(25)
    det:set_texture(portal_items_texture)
end

local function set_add_portal_gun(p_gun_uid, wielder)
    local w_slot, w_type
    if wielder then
        w_slot, w_type = wielder.inventory.player_slot, wielder.type.id
    else
        w_slot, w_type = -1, -1
    end
    get_entity(p_gun_uid):set_texture(portal_items_texture)
    local x, y, l = get_position(p_gun_uid)
    local p_gun_detail = spawn_on_floor(ENT_TYPE.ITEM_ROCK, x, y, l)
    set_p_detail(p_gun_detail)
    portal_guns[p_gun_uid] = { ['detail'] = p_gun_detail, ['wielder_slot'] = -1, ['wielder_type'] = -1 }
end

local just_started

set_callback(function()
    just_started = true
    using_colors = portal_colors[#players]
    portal_guns = {}
    local px, py, pl = get_position(players[1].uid)
    for i = 1, #players do 
        local p_gun_uid = spawn_on_floor(ENT_TYPE.ITEM_FREEZERAY, px, py, pl)
        get_entity(p_gun_uid):set_texture(portal_items_texture)
        local p_gun_detail = spawn_on_floor(ENT_TYPE.ITEM_ROCK, px, py, pl)
        set_p_detail(p_gun_detail)
        portal_guns[p_gun_uid] = { ['detail'] = p_gun_detail, ['wielder_slot'] = -1, ['wielder_type'] = -1 }
    end
end, ON.START)

set_callback(function()
    for i, p in ipairs(players) do -- For option only portal gun¿
        --steal_input(p.uid)
        set_on_kill(p.uid, function(ent)
            messpect('returned')
            if ent:has_powerup(ENT_TYPE.ITEM_POWERUP_ANKH) then
                messpect('has ankh')
            else
                messpect('nope')
                return_input(ent.uid)
            end
        end)
    end
    reset_portals_new_level()
    if just_started then just_started = false return end
    local prev_slots = {}
    for i, p in pairs(portal_guns) do
        prev_slots[i] = p.wielder_slot
    end
    messpect('prev', prev_slots)
    portal_guns = {}
    for i, slot in pairs(prev_slots) do --fix this on multiplayer
        if slot ~= -1 then
            for pi, ply in ipairs(players) do
                messpect(slot, ply.inventory.player_slot)
                if ply.inventory.player_slot == slot then
                    local holding = get_entity(ply.holding_uid)
                    if holding and holding.type.id == ENT_TYPE.ITEM_FREEZERAY then
                        set_add_portal_gun(ply.holding_uid, ply)
                    end
                end
            end
        end
    end
end, ON.LEVEL)

local next_port = {1, 1, 1, 1}

local function other_port(v)
    return v == 1 and 2 or 1
end

local function kill_ents(uids)
    for _, uid in ipairs(uids) do
        get_entity(uid):destroy()
        --move_entity(uid, 8, 0, 0, 0)
        --kill_entity(uid)
    end
end

local function spawn_border(x, y, l, hitboxx, hitboxy, offsetx, offsety, flag)
    hitboxx, hitboxy, offsetx, offsety = hitboxx or 0.5, hitboxy or 0.5, offsetx or 0, offsety or 0
    local border_uid = spawn_grid_entity(ENT_TYPE.ACTIVEFLOOR_PUSHBLOCK, x, y, l)
    local border_ent = get_entity(border_uid)
    border_ent.hitboxx = hitboxx
    border_ent.hitboxy = hitboxy
    border_ent.offsetx = offsetx
    if flag then
        messpect("border ", offsetx)
    end
    border_ent.offsety = offsety
    border_ent.flags = set_flag(set_flag(set_flag(border_ent.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING), ENT_FLAG.INVISIBLE), ENT_FLAG.NO_GRAVITY)
    return border_uid
end

local function spawn_portal_borders(x, y, l, positive, horiz)
    local borders_uids = {}
    if horiz then
        borders_uids[1] = spawn_border(x, y, l, nil, 0.05, nil, 0.45)
        borders_uids[2] = spawn_border(x, y, l, nil, 0.05, nil, -0.55)
        if positive then
            borders_uids[3] = spawn_border(x, y, l, 0.01, nil, -0.5, nil, true)
        else
            borders_uids[3] = spawn_border(x, y, l, 0.01, nil, 0.5, nil, true)
        end
        --[[local border_ent = get_entity(borders_uids[1])
        border_ent.hitboxy = 0
        border_ent.offsety = 0.5
        border_ent.flags = set_flag(set_flag(border_ent.flags, ENT_FLAG.INVISIBLE), ENT_FLAG.NO_GRAVITY)]]
    else
        borders_uids[1] = spawn_border(x, y, l, 0.01, nil, -0.5, nil, true)
        borders_uids[2] = spawn_border(x, y, l, 0.01, nil, 0.5, nil, true)
        messpect("borderPositive", positive)
        if positive then
            borders_uids[3] = spawn_border(x, y, l, nil, 0.05, nil, -0.55)
        else
            borders_uids[3] = spawn_border(x, y, l, nil, 0.05, nil, 0.45)
        end
    end
    return borders_uids
end

local function set_portal(b_uid, ply_n, n, positive, horiz)
    --messpect(ply_n, n)
    --messpect(portals[1][1].left)
    p_sounds[next_port[ply_n]]:play():set_volume(0.5)
    portals[ply_n][n].positive = positive
    portals[ply_n][n].horiz = horiz
    local hitbox = get_hitbox(b_uid)
    portals[ply_n][n].drawbox = hitbox
    local x, y, l = get_position(b_uid)
    set_entity_flags( b_uid, clr_flag(get_entity_flags(b_uid), ENT_FLAG.SOLID) )
    portals[ply_n][n].border_uids = spawn_portal_borders(x, y, l, positive, horiz)
    if horiz then
        portals[ply_n][n].x = positive and hitbox.right-0.01 or hitbox.left+0.01
        portals[ply_n][n].y = (hitbox.bottom+hitbox.top)/2
        hitbox.top, hitbox.bottom = hitbox.top - 0.05, hitbox.bottom + 0.05
        hitbox.left, hitbox.right = hitbox.left+(positive and 0.025 or -0.025), hitbox.right+(positive and 0.025 or -0.025)
    else
        portals[ply_n][n].y = positive and hitbox.top-0.01 or hitbox.bottom+0.01
        portals[ply_n][n].x = (hitbox.left+hitbox.right)/2
        hitbox.top, hitbox.bottom = hitbox.top+(positive and 0.02 or -0.02), hitbox.bottom+(positive and -0.02 or 0.02)
        hitbox.left, hitbox.right = hitbox.left + 0.05, hitbox.right - 0.05
    end
    portals[ply_n][n].l = l
    portals[ply_n][n].hitbox = hitbox
    --messpect(hitbox.left, hitbox.right)
    portals[ply_n][n].b_uid = b_uid
    next_port[ply_n] = n == 1 and 2 or 1
    --messpect(next_port)
end

local just_shot = {true, true, true, true}
local just_pressed_down = {}
set_callback(function()
    for gun, info in pairs(portal_guns) do
        --messpect('weilders', info.wielder_slot)
        if info.wielder_slot == -1 then
            get_entity(info.detail):set_draw_depth(30)
        end
        info.wielder_slot = -1
        local _, _, dl = get_position(info.detail)
        local x, y, l = get_position(gun)
        local vx, vy = get_velocity(gun)
        move_entity(info.detail, x, y, vx, vy)
        if l ~= dl then
            get_entity(info.detail):set_layer(l)
        end
        local gun_ent = get_entity(gun)
        gun_ent.cooldown = 2
        --gun_ent:set_draw_depth(25)
    end

    for noti, p in ipairs(players) do
        local i = p.inventory.player_slot
        if p ~= nil and not test_flag(p.flags, ENT_FLAG.DEAD) then
            local shoot_portal = false
            local buttons = read_input(p.uid)
            --messpect(buttons)
            if portal_guns[p.holding_uid] then
                --messpect('weilders1', portal_guns[p.holding_uid].wielder_slot)
                local holding = get_entity(p.holding_uid)
                holding.special_offsetx = 0.25
                if test_flag(buttons, DOWN_DIR) then
                    just_pressed_down[i] = false
                else
                    just_pressed_down[i] = true
                end
                if test_flag(buttons, 2) then  --whip
                    if not (test_flag(buttons, DOWN_DIR) and p.standing_on_uid ~= -1) then
                        buttons = clr_flag(buttons, 2)
                        if not just_shot[i] then
                            shoot_portal = true
                        end
                    end
                    just_shot[i] = true
                else
                    just_shot[i] = false
                end
                local facing_left = test_flag(holding.flags, ENT_FLAG.FACING_LEFT)
                holding.angle = portal_gun_angle[i] * bsign(not facing_left)

                local detail = get_entity(portal_guns[holding.uid].detail)
                detail.angle = holding.angle
                detail.flags = facing_left and set_flag(detail.flags, ENT_FLAG.FACING_LEFT) or clr_flag(detail.flags, ENT_FLAG.FACING_LEFT)
                detail.color.r = using_colors[next_port[i]][i].r
                detail.color.g = using_colors[next_port[i]][i].g
                detail.color.b = using_colors[next_port[i]][i].b
                if portal_guns[p.holding_uid].wielder_slot == -1 then
                    detail:set_draw_depth(25)
                end
                portal_guns[p.holding_uid].wielder_slot = p.inventory.player_slot
            end
            send_input(p.uid, buttons)
            
            local px, py, pl = get_position(p.uid)
            --actual_texture[i] = p:get_texture()
            --messpect(p.buttons)
            if test_flag(state.player_inputs.player_slots[i].buttons, UP_DIR) then
                portal_gun_angle[i] = lerp(portal_gun_angle[i], math.pi/2-0.01, 0.2)
            elseif test_flag(state.player_inputs.player_slots[i].buttons, DOWN_DIR) then
                portal_gun_angle[i] = lerp(portal_gun_angle[i], math.pi/(-2)+0.01, 0.2)
            else
                portal_gun_angle[i] = lerp(portal_gun_angle[i], 0, 0.25)
            end
            if shoot_portal or ( options.door_portal and p:is_button_pressed(BUTTON.DOOR) ) then
                local prev_portal_b = portals[i][next_port[i]].b_uid
                set_entity_flags(prev_portal_b, set_flag(get_entity_flags(prev_portal_b), ENT_FLAG.SOLID) )
                portals[i][next_port[i]].x = -1
                kill_ents(portals[i][next_port[i]].border_uids)
                portals[i][next_port[i]].border_uids = {}
                local xdir_bool = test_flag(p.flags, ENT_FLAG.FACING_LEFT)
                local xdir = xdir_bool and -1 or 1
                local ent, x, y, aside = get_raycast_collision(px, py, pl, xdir, portal_gun_angle[i])
                messpect(true, "block", ent, aside)
                if ent then
                    local positive
                    if aside then
                        positive = xdir_bool
                    else
                        positive = not sign_to_bool(portal_gun_angle[i])
                    end
                    messpect('positive:', positive, 'aside', aside)
                    messpect(true, x, y)
                    box = get_hitbox(ent)
                    set_portal(ent, i, next_port[i], positive, aside)
                end
            end
        end
    end

    touching_portal[1] = -1
    local moved = {}
    for pl_i, pl_portal in ipairs(portals) do
        for i, p in ipairs(pl_portal) do
            if p.x ~= -1 then
                --change extrude to left, right =
                local uids = get_entities_overlapping_hitbox(0, MASK.PLAYER | MASK.ITEM | MASK.MONSTER | MASK.MOUNT, p.hitbox, p.l)
                local otherP = i==1 and portals[pl_i][2] or portals[pl_i][1]
                if #uids > 0 and otherP.x ~= -1 then
                    for iu, uid in ipairs(uids) do
                        local brk = false
                        messpect(moved)
                        for _, uid1 in ipairs(moved) do
                            messpect(uid, uid1)
                            if uid == uid1 then
                                brk = true
                                break
                            end
                        end
                        if brk then break end
                        local ent = get_entity(uid)
                        local evx, evy = get_velocity(uid)
                        local ex, ey, el = get_position(uid)
                        --messpect(#uids, otherP.x, moved[1])
                        --touching_portal[1] = other_port(i)
                        local f
                        local to_x, to_y, to_vx, to_vy = otherP.x, otherP.y, evx, evy
                        if p.horiz then
                            to_x = otherP.x+0.1*bsign(otherP.positive)
                            to_vx = evx*bsign(not (otherP.positive == p.positive))
                            if p.positive then
                                f = ex < p.x
                            else
                                f = ex > p.x
                            end
                        else
                            to_y = otherP.y+0.2*bsign(otherP.positive)
                            to_vy = evy*bsign(not (otherP.positive == p.positive))
                            if p.positive then
                                f = ey < p.y
                            else
                                f = ey > p.y
                            end
                        end
                        if f and ent:topmost_mount().uid == uid then
                            if p.horiz ~= otherP.horiz then
                                to_vx, to_vy = to_vy, to_vx
                                ent.falling_timer = 1
                            end
                            if ent.layer ~= otherP.l then
                                ent:set_layer(otherP.l)
                            end
                            messpect("teleported", i, p.x, p.y, otherP.x, otherP.y)
                            set_entity_flags( otherP.b_uid, clr_flag(get_entity_flags(p.b_uid), ENT_FLAG.SOLID) )
                            move_entity(uid, to_x, to_y, to_vx, to_vy)
                            moved[#moved+1] = uid
                        end
                    end
                end
            end
        end
    end
end, ON.FRAME)
set_callback(function(d_ctx)
    --[[if box then
        local drawbox = screen_aabb(box)
        d_ctx:draw_rect(drawbox, 4, 0, rgba(255, 255, 255, 255))
    end]]
    for i = #draw_x, 1, -1 do
        local d_x, d_y = screen_position(draw_x[i], draw_y[i])
        d_ctx:draw_rect(d_x, d_y,d_x, d_y, 4, 0, rgba(255, 255, 255, 255))
        table.remove(draw_x, i)
        table.remove(draw_y, i)
    end
end, ON.GUIFRAME)

local function anim_frame_to_grid(num)
    return math.floor((num)/16), (num)%16
end

set_callback(function(render_ctx, draw_depth)
    if #players < 1 then return end
    --[[if draw_depth == players[1].type.draw_depth - 1 then --fix it or remove it
        local px, py = get_position(players[1].uid)
        local draw_aabb = AABB:new(px-0.575, py+0.575, px+0.575, py-0.575)
        --render_ctx:draw_world_texture(portal_items_texture, 4, 0, draw_aabb, white)
        --render_ctx:draw_world_texture(portal_items_texture, 4, 4, draw_aabb, Color:aqua())
        if touching_portal[1] == -1 then return end
        local x, y, l = portals[1][touching_portal[1] ].x, portals[1][touching_portal[1] ].y, portals[1][touching_portal[1] ].l
        x = x - 0.2 - px%1
        y = y + 0.75
        rect = AABB:new(x, y, x + 1.35, y - 1.35)
        local gy, gx = anim_frame_to_grid(players[1].animation_frame)
        render_ctx:draw_world_texture(actual_texture[1], gy, gx, rect, white)
    end]]
    if draw_depth == 2 then
        for pl_i, pl_portal in ipairs(portals) do
            for i, p in ipairs(pl_portal) do
                if p.x ~= -1 and state.camera_layer == p.l then
                    if p.drawbox then
                        local alpha = 0.1
                        local xsum = p.horiz and (p.positive and 1 or -1) or 0
                        local ysum = (not p.horiz) and (p.positive and 1 or -1) or 0
                        local left, top, right, bottom = p.drawbox.left + xsum, p.drawbox.top + ysum, p.drawbox.right + xsum, p.drawbox.bottom + ysum
                        for di = 1, 10 do
                            render_ctx:draw_world_texture(portal_items_texture, p.horiz and 0 or 1, p.positive and 1 or 2, left, top, right, bottom, Color:new(using_colors[i][pl_i].r, using_colors[i][pl_i].g, using_colors[i][pl_i].b, alpha))
                            if xsum == -1 then
                                left = left+0.1
                            elseif xsum == 1 then
                                right = right-0.1
                            elseif ysum == -1 then
                                bottom = bottom + 0.1
                            else
                                top = top - 0.1
                            end
                            alpha = alpha + 0.05
                        end
                    end
                    --render_ctx:draw_world_texture(TEXTURE.DATA_TEXTURES_FLOOR_CAVE_0, 0, 0, p.hitbox, white)
                end
            end
        end
    end
end, ON.RENDER_PRE_DRAW_DEPTH)