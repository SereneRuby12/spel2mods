meta.name = "portalunky1"
meta.author = "Estebanfer"

local has_portal_gun = {true, true, true, true}
local actual_texture = {TEXTURE.DATA_TEXTURES_CHAR_YELLOW_0, 270, 270, 270} --all are the same
local touching_portal = {-1, -1, -1, -1}
local portal_colors = {
    {
        {{["r"]=0, ["g"]=0, ["b"]=1}},
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
local portals = {
    { --p1
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    },
    
    { --p2
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    },

    { --p3
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    },

    { --p4
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    },
}

local using_colors = portal_colors[1]

local function get_next_block(x, y, ysum, xdir, flag)
    local rx, ry = x%1, y%1 --relative x, y
    local xdiff = xdir == 1 and 1-rx or (rx==0 and -1 or -rx)
    local ydiff = math.abs(xdiff)*ysum;
    if ysum > 0 and ydiff+ry < 1 or ry+ydiff > (ry>0 and 0 or -1) then
        if flag then messpect(1, xdiff, ydiff, x, y) end
        return true, x+(xdiff), y+ydiff
    else
        if flag then messpect(2, xdiff, ydiff, x, y) end
        ydiff = ysum > 0 and 1-ry or -ry;
        xdiff = xdir*math.abs(ydiff/ysum);
        return false, x+xdiff, y+ydiff
    end
end

local function get_raycast_collision(x, y, l, xdir, angle)
    local steps = 0
    local ysum = math.tan(angle) --maybe will have to make it negt because of spel inverted y coordinates
    messpect(x, y, ysum)
    repeat
        --TODO: check if the tile border is like 0 or 0.5, maybe the horiz flag isn't needed
        --Make it work on CO
        local is_aside, tosum_x, tosum_y = get_next_block(x, y, ysum, 1, steps < 4)
        x, y = tosum_x, tosum_y
        local g_ent = get_grid_entity_at(x, y, l)
        if test_flag(get_entity_flags(g_ent), ENT_FLAG.SOLID) then
            return g_ent, x, y, is_horiz
        end
        steps = steps + 1
    until steps == 100
end

set_callback(function()
    using_colors = portal_colors[#players]
    for i, p in ipairs(players) do -- For option only portal gun
        --steal_input(p.uid)
    end
end, ON.START)

local moved = {[1] = 0}
local next_port = {1, 1, 1, 1}

local function other_port(v)
    return v == 1 and 2 or 1
end

local function set_portal(b_uid, ply_n, n, left, down)
    messpect(ply_n, n)
    messpect(portals[1][1].left)
    portals[ply_n][n].left = left
    local hitbox = get_hitbox(b_uid)
    portals[ply_n][n].x = hitbox.left
    portals[ply_n][n].y = (hitbox.bottom+hitbox.top)/2
    portals[ply_n][n].b_uid = b_uid
    next_port[ply_n] = n == 1 and 2 or 1
    messpect(next_port)
end

set_callback(function()
    --[[for i, p in ipairs(players) do
        if p ~= nil and test_flag(p.flags, ENT_FLAGS.DEAD) then
            local buttons = read_stolen_input(p.uid)
            if test_flag(buttons, 2) then  --whip
                buttons = clr_flag(buttons, 2)
            end
        end
    end]]
    --code written apart, gotta move this to the players iterations
    local px, py, pl = get_position(players[1].uid)
    local pxv, pyv = get_velocity(players[1].uid)
    actual_texture[1] = players[1]:get_texture()
    if players[1]:is_button_pressed(BUTTON.DOOR) then
        local prev_portal_b = portals[1][next_port[1]].b_uid
        set_entity_flags(prev_portal_b, set_flag(get_entity_flags(prev_portal_b), ENT_FLAG.SOLID) )
        portals[1][next_port[1]].x = -1
        local ent, x, y, aside = get_raycast_collision(px, py, pl, 1, 0)
        messpect(true, "block", ent)
        if ent then
            messpect(true, x, y)
            box = get_hitbox(ent)
            set_portal(ent, 1, next_port[1], aside, false)
        end
    end
    touching_portal[1] = -1
    for i, p in ipairs(portals[1]) do
        if p.x ~= -1 then
            --change extrude to left, right =
            local hitbox =  get_hitbox(p.b_uid)--:extrude(0.02)
            hitbox.top, hitbox.bottom = hitbox.top - 0.1, hitbox.bottom
            hitbox.left, hitbox.right = hitbox.left-0.02, hitbox.right+0.02
            local ents = get_entities_overlapping_hitbox(0, MASK.PLAYER, hitbox, p.l)
            local otherP = i==1 and portals[1][2] or portals[1][1] 
            --messpect(#ents, otherP.x, moved[1])
            if #ents > 0 and otherP.x ~= -1 and moved[1] <= 0 then
                set_entity_flags( p.b_uid, clr_flag(get_entity_flags(p.b_uid), ENT_FLAG.SOLID) )
                touching_portal[1] = other_port(i)
                if math.abs(p.x-px) < 0.05 then
                    move_entity(ents[1], otherP.x-0.025, otherP.y,-pxv, pyv)
                    moved[1] = 1
                end
            elseif not test_flag(get_entity_flags(p.b_uid), ENT_FLAG.SOLID) then
                set_entity_flags( p.b_uid, set_flag(get_entity_flags(p.b_uid), ENT_FLAG.SOLID) )
            end
        end
    end
    moved[1] = moved[1] - 1
end, ON.FRAME)

set_callback(function(d_ctx)
    if box then
        local drawbox = screen_aabb(box)
        d_ctx:draw_rect(drawbox, 4, 0, rgba(255, 255, 255, 255))
    end

end, ON.GUIFRAME)

local function anim_frame_to_grid(num)
    return math.floor((num)/16), (num)%12
end

set_callback(function(render_ctx, draw_depth)
    if #players < 1 then return end
    if draw_depth == players[1].type.draw_depth then
        if touching_portal[1] == -1 then return end
        local x, y, l = portals[1][touching_portal[1]].x, portals[1][touching_portal[1]].y, portals[1][touching_portal[1]].l
        local px, py = get_position(players[1].uid)
        x = x - 0.2 - px%1
        y = y + 0.75
        rect = AABB:new(x, y, x + 1.35, y - 1.35)
        local gy, gx = anim_frame_to_grid(players[1].animation_frame)
        messpect(players[1].animation_frame, gx, gy)
        render_ctx:draw_world_texture(actual_texture[1], gy, gx, rect, Color:white())
    end
end, ON.RENDER_PRE_DRAW_DEPTH)