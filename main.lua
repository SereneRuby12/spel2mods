meta.name = "portalunky1"
meta.author = "Estebanfer"

local has_portal_gun = {true, true, true, true}
local portal_colors = {
    {
        {{[r]=0, [g]=0, [b]=1}},
        {{[r]=1, [g]=0.5, [b]=0}}
    }
    
    {
        {{[r]=0, [g]=0.25, [b]=1}, {[r]=1, [g]=0, [b]=0}},
        {{[r]=0.75, [g]=0, [b]=0.75}, {[r]=0.75, [g]=0.75, [b]=0}}
    }
    
    {
        {{[r]=1, [g]=0, [b]=0}, {[r]=0, [g]=1, [b]=0}, {[r]=0, [g]=0, [b]=1}},
        {{[r]=0.5, [g]=0, [b]=0}, {[r]=0, [g]=0.5, [b]=0}, {[r]=0, [g]=0, [b]=0.5}}
    }
    
    {
        {{[r]=0, [g]=0, [b]=1}, {[r]=1, [g]=0.5, [b]=0}, {[r]=0, [g]=1, [b]=0.5}, {[r]=1, [g]=0, [b]=0.5}},
        {{[r]=0, [g]=0, [b]=0.5}, {[r]=0.5, [g]=0.25, [b]=0}, {[r]=0, [g]=0.5, [b]=0.25}, {[r]=0.5, [g]=0, [b]=0.25}}
    }
}
local portal_gun_angle = {0, 0, 0, 0}
--change to multiplayer
local portals = {
    { --p1
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    }
    
    { --p2
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    }

    { --p3
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    }

    { --p4
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false},
    {["x"] = -1, ["y"]= -1, ["l"] = -1, ["b_uid"] = -1, ["left"]=false, ["down"] = false}
    }
}

local using_colors = portal_colors[1]

local function get_next_block(x, y, ysum, xdir)
    local rx, ry = x%1, y%1 --relative x, y
    local xdiff = xdir == 1 and b-rx or (rx==0 and -1 or -rx)
    local ydiff = math.abs(xdiff)*ysum;
    if ysum > 0 and ydiff+ry < b or ry+ydiff > (ry>0 and 0 or -b) then
        return true, x+(xdiff), y+ydiff
    else
        ydiff = ysum > 0 and b-ry or -ry;
        xdiff = xdir*math.abs(ydiff/ysum);
        return false, x+xdiff, y+ydiff
    end
end

local function get_raycast_collision(x, y, l, angle)
    local steps = 0
    local ysum = math.tan(angle) --maybe will have to make it negt because of spel inverted y coordinates
    repeat
        --TODO: check if the tile border is like 0 or 0.5, maybe the horiz flag isn't needed
        --Make it work on CO
        local is_aside, tosum_x, tosum_y = is_get_next_block(x, y, ysum)
        x, y = x + tosum_x, y + tosum_y
        local g_ent = get_grid_entity_at(x, y, l)
        if test_flag(get_entity_flags(g_ent), ENT_FLAG.SOLID) then
            return g_ent, x, y, is_horiz
        end
        steps = steps + 1
    until steps = 100
end

set_callback(function()
    using_colors = portal_colors[#players]
    for i, p in ipairs(players) do -- For option only portal gun
        steal_input(p.uid)
    end
end, ON.START)

local moved = {[1] = 0}
local next_port = {1, 1, 1, 1}

local function set_portal(b_uid, ply_n, n, left, down)
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
    if players[1]:is_button_pressed(BUTTON.WHIP) then
        local ent, x, y, aside = get_raycast_collision(px, py, pl, 0)
        if ent then
            box = get_hitbox(ent)
            set_portal(ent, next_port, aside, false)
        end
    end
    for i, p in ipairs(portals[1]) do
        if p.x ~= -1 then
            --change extrude to left, right =
            local ents = get_entities_overlapping_hitbox(0, MASK.PLAYER, get_hitbox(p.b_uid):extrude(0.01), p.l)
            local otherP = i==1 and portals[1][2] or portals[1][1] 
            --messpect(#ents, otherP.x, moved[1])
            if #ents > 0 and otherP.x ~= -1 and moved[1] <= 0 then
                set_entity_flags( p.b_uid, clr_flag(p.b_uid, ENT_FLAG.SOLID) )
                if math.abs(p.x-px) < 0.05 then
                    move_entity(ents[1], otherP.x, otherP.y,-pxv, pyv)
                    moved[1] = 20
                end
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