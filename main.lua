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
local portal_gun_shot = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}

local using_colors = portal_colors[1]

local function get_next_block(x, y, ysum)
    local rx, ry = x%1, y%1 --relative x, y
    local sx, sy = sign(x, y)
    local ydiff = (1-x)*ysum
    if ydiff+ry < 1 then
        return true, x+(1-x), y+ydiff
    else
        ydiff = 1-y
        local xdiff = ydiff/ysum
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

set_callback(function()
    for i, p in ipairs(players) do
        if p ~= nil and test_flag(p.flags, ENT_FLAGS.DEAD) then
            local buttons = read_stolen_input(p.uid)
            if test_flag(buttons, 2) then  --whip
                buttons = clr_flag(buttons, 2)
            end
        end
    end
    --code written apart, gotta move this to the players iterations
    local px, py, pl = get_position(players[1].uid)
    local angle = test_flag(players[1].player_slot.buttons_gameplay, 2) and math.pi/4 or 0
    local to_draw_ent = get_raycast_collision(px, py, pl, angle)
    drawbox = get_render_hitbox(to_draw_ent)
end, ON.FRAME)

set_callback(function(d_ctx)
    if drawbox then
        d_ctx:draw_rect(drawbox, 5, 5, rgba(255, 255, 255, 255))
    end
end, ON.GUIFRAME)