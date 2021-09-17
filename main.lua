meta.name = "portalunky"
meta.author = "Estebanfer"

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
            if test_flag(get_entity_flags(g_ent), ENT_FLAG.SOLID) then
                return g_ent, x, y, is_horiz
            end
        end
        steps = steps + 1
    until steps == 100
end

set_post_entity_spawn(function(ent)
    ent:set_texture(portal_items_texture)
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_CROSSBOW)

set_post_entity_spawn(function(ent)
    ent:set_texture(portal_items_texture)
    ent.color.r = 0
    ent.color.g = 0.5
end, SPAWN_TYPE.ANY, 0, ENT_TYPE.ITEM_METAL_ARROW)

set_callback(function()
    using_colors = portal_colors[#players]
    local px, py, pl = get_position(players[1].uid)
    spawn(ENT_TYPE.ITEM_CROSSBOW, px, py, pl, 0, 0)
end, ON.START)

set_callback(function()
    for i, p in ipairs(players) do -- For option only portal gun¿
        steal_input(p.uid)
    end
    reset_portals_new_level()
end, ON.LEVEL)

local next_port = {1, 1, 1, 1}

local function other_port(v)
    return v == 1 and 2 or 1
end

local function kill_ents(uids)
    for _, uid in ipairs(uids) do
        kill_entity(uid)
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
            borders_uids[3] = spawn_border(x, y, l, 0, nil, -0.5, nil, true)
        else
            borders_uids[3] = spawn_border(x, y, l, 0, nil, 0.5, nil, true)
        end
        --[[local border_ent = get_entity(borders_uids[1])
        border_ent.hitboxy = 0
        border_ent.offsety = 0.5
        border_ent.flags = set_flag(set_flag(border_ent.flags, ENT_FLAG.INVISIBLE), ENT_FLAG.NO_GRAVITY)]]
    else
        borders_uids[1] = spawn_border(x, y, l, 0, nil, -0.5, nil, true)
        borders_uids[2] = spawn_border(x, y, l, 0, nil, 0.5, nil, true)
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
    portals[ply_n][n].hitbox = hitbox
    --messpect(hitbox.left, hitbox.right)
    portals[ply_n][n].b_uid = b_uid
    next_port[ply_n] = n == 1 and 2 or 1
    --messpect(next_port)
end

local just_shot = {true, true, true, true}
local just_pressed_down = {}
set_callback(function()
    local shoot_portal = false
    for i, p in ipairs(players) do
        if p ~= nil and not test_flag(p.flags, ENT_FLAG.DEAD) then
            local buttons = read_stolen_input(p.uid)
            --messpect(buttons)
            local holding = get_entity(p.holding_uid)
            if holding and holding.type.id == ENT_TYPE.ITEM_CROSSBOW then
                if test_flag(buttons, 2) then  --whip
                    if not (test_flag(buttons, DOWN_DIR) and p.standing_on_uid ~= -1) and just_pressed_down[i] then
                        buttons = clr_flag(buttons, 2)
                        if not just_shot[i] then
                            shoot_portal = true
                            just_shot[i] = true
                        end
                    end
                    if test_flag(buttons, DOWN_DIR) then
                        just_pressed_down[i] = false
                    else
                        just_pressed_down[i] = true
                    end
                else
                    just_shot[i] = false
                end
                holding.angle = portal_gun_angle[1] * bsign(not test_flag(holding.flags, ENT_FLAG.FACING_LEFT))
                local arrow = get_entity(holding.holding_uid)
                if arrow then
                    arrow.color.r = using_colors[next_port[1]][1].r
                    arrow.color.g = using_colors[next_port[1]][1].g
                    arrow.color.b = using_colors[next_port[1]][1].b
                end
            end
            send_input(p.uid, buttons)
        end
    end
    --code written apart, gotta move this to the players iterations

    local px, py, pl = get_position(players[1].uid)
    actual_texture[1] = players[1]:get_texture()
    --messpect(players[1].buttons)
    if test_flag(state.player_inputs.player_slot_1.buttons, UP_DIR) then
        portal_gun_angle[1] = lerp(portal_gun_angle[1], math.pi/2-0.01, 0.2)
    elseif test_flag(state.player_inputs.player_slot_1.buttons, DOWN_DIR) then
        portal_gun_angle[1] = lerp(portal_gun_angle[1], math.pi/(-2)+0.01, 0.2)
    else
        portal_gun_angle[1] = lerp(portal_gun_angle[1], 0, 0.25)
    end
    if shoot_portal or ( options.door_portal and players[1]:is_button_pressed(BUTTON.DOOR) ) then
        local prev_portal_b = portals[1][next_port[1]].b_uid
        set_entity_flags(prev_portal_b, set_flag(get_entity_flags(prev_portal_b), ENT_FLAG.SOLID) )
        portals[1][next_port[1]].x = -1
        kill_ents(portals[1][next_port[1]].border_uids)
        portals[1][next_port[1]].border_uids = {}
        local xdir_bool = test_flag(players[1].flags, ENT_FLAG.FACING_LEFT)
        local xdir = xdir_bool and -1 or 1
        local ent, x, y, aside = get_raycast_collision(px, py, pl, xdir, portal_gun_angle[1])
        messpect(true, "block", ent, aside)
        if ent then
            local positive
            if aside then
                positive = xdir_bool
            else
                positive = not sign_to_bool(portal_gun_angle[1])
            end
            messpect('positive:', positive, 'aside', aside)
            messpect(true, x, y)
            box = get_hitbox(ent)
            set_portal(ent, 1, next_port[1], positive, aside)
        end
    end
    touching_portal[1] = -1
    local moved = {}
    for i, p in ipairs(portals[1]) do
        if p.x ~= -1 then
            --change extrude to left, right =
            local uids = get_entities_overlapping_hitbox(0, MASK.PLAYER | MASK.ITEM, p.hitbox, p.l)
            local otherP = i==1 and portals[1][2] or portals[1][1]
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
                    touching_portal[1] = other_port(i)
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
                    if p.horiz ~= otherP.horiz then
                        to_vx, to_vy = to_vy, to_vx
                    end
                    if f and ent:topmost_mount().uid == uid then
                        messpect("teleported", i, p.x, p.y, otherP.x, otherP.y)
                        set_entity_flags( otherP.b_uid, clr_flag(get_entity_flags(p.b_uid), ENT_FLAG.SOLID) )
                        move_entity(uid, to_x, to_y, to_vx, to_vy)
                        moved[#moved+1] = uid
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
        for i, p in ipairs(portals[1]) do
            if p.x ~= -1 then
                if p.drawbox then
                    local alpha = 0.1
                    local xsum = p.horiz and (p.positive and 1 or -1) or 0
                    local ysum = (not p.horiz) and (p.positive and 1 or -1) or 0
                    local left, top, right, bottom = p.drawbox.left + xsum, p.drawbox.top + ysum, p.drawbox.right + xsum, p.drawbox.bottom + ysum
                    for di = 1, 10 do
                        render_ctx:draw_world_texture(portal_items_texture, p.horiz and 0 or 1, p.positive and 0 or 1, left, top, right, bottom, Color:new(using_colors[i][1].r, using_colors[i][1].g, using_colors[i][1].b, alpha))
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
end, ON.RENDER_PRE_DRAW_DEPTH)