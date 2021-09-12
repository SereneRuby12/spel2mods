
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

set_callback(function()
    using_colors = portal_colors[#players]
    for i, p in ipairs(players) do
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
end, ON.FRAME)