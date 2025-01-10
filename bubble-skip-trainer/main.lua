meta = {
    name = "Bubble skip helper",
    version = "0.10.1",
    author = "SereneRuby12, Nitroxy",
    description = "Helps with practicing bubble skip, use the door button to teleport back to start. \nchanging settings will require a restart"
}

local global_cb = -1
local velocity = 0.035003662109375
local counter = 120

set_callback(function()
    clear_callback(global_cb)
    if options.godmode_default then
        god(true)
    else
        god(false)
    end
    if state.theme ~= THEME.TIAMAT then
        return
    end
    
    if options.spawn_springshoes then
        players[1]:give_powerup(ENT_TYPE.ITEM_POWERUP_SPRING_SHOES)
    end

    move_entity(players[1].uid, 15, 86, 0, 0)
    spawn_grid_entity(ENT_TYPE.FLOOR_DOOR_PLATFORM, 15, 85, LAYER.FRONT)
    spawn_grid_entity(ENT_TYPE.ITEM_UNROLLED_ROPE, 15, 91, LAYER.FRONT)
    
    if options.random_bubbles_start and not options.spawn_bubbles then
        for i=1, 5 do
            spawn(ENT_TYPE.ACTIVEFLOOR_BUBBLE_PLATFORM, math.random()+17, math.random()*20+60, LAYER.FRONT, 0, 0)
        end
    end

    if options.spawn_bubbles then
        set_timeout(function()
            spawn(ENT_TYPE.ACTIVEFLOOR_BUBBLE_PLATFORM, math.random()+17, 83.5 + math.random()/1.67, LAYER.FRONT, 0, 0)
        end, 1)
        set_interval(function()
            spawn(ENT_TYPE.ACTIVEFLOOR_BUBBLE_PLATFORM, math.random()+17, 83.45 + math.random()/1.67, LAYER.FRONT, 0, 0)
        end, 122)
    else
        -- Spawn the guide lines for the line up
        if options.guide_lines then
            get_entity(spawn(ENT_TYPE.MIDBG, 17.5, 87, LAYER.FRONT, 0, 0)).height = 0.025
            get_entity(spawn(ENT_TYPE.MIDBG, 17.5, 88.5, LAYER.FRONT, 0, 0)).height = 0.025
        end
        
        local floors_hitbx = AABB:new(16, 53, 19, 52)
        local floors = get_entities_overlapping_hitbox(0, MASK.FLOOR, floors_hitbx, LAYER.FRONT)
        for _, uid in ipairs(floors) do
            kill_entity(uid)
        end
        if options.tiamine then
            floors_hitbx = AABB:new(17, 52, 18, 51)
        else
            floors_hitbx = AABB:new(16, 52, 19, 51)
        end
        floors = get_entities_overlapping_hitbox(0, MASK.FLOOR, floors_hitbx, LAYER.FRONT)
        for _, uid in ipairs(floors) do
            kill_entity(uid)
        end
    end
    global_cb = set_global_interval(function()
        if state.logic.tiamat_cutscene ~= nil then
            state.logic.tiamat_cutscene.timer = 379
            return false
        end
    end, 1)
    
    --Teleport player on button and refill ropes
    set_interval(function()
        if players[1]:is_button_pressed(BUTTON.DOOR) then
            move_entity(players[1].uid, 15, 86, 0, 0)
            if options.no_bad_ropes then
                local bropes = get_entities_by_type(ENT_TYPE.ITEM_ROPE, ENT_TYPE.ITEM_PICKUP_ROPE)
                for _, uid in ipairs(bropes) do
                    kill_entity(uid)
                end
            end
        end

        if players[1].inventory.ropes and options.refill_ropes then
            players[1].inventory.ropes = 4
        end
    end, 1)
    
    set_interval(function()
        if options.enable_tint and players[1].standing_on_uid ~= -1 and get_entity(players[1].standing_on_uid).type.id == ENT_TYPE.ACTIVEFLOOR_BUBBLE_PLATFORM then
            local x, y, l = get_position(players[1].standing_on_uid)
            if y > 88 then
                local relative_y = (y-1)%4
                local asd = (y-1)%8
                local to_y = relative_y + ( (121 - state.time_level%122) * velocity )
                local maxx, minn
                if asd > 4 then
                    maxx, minn = 5.12, 4.5
                else
                    maxx, minn = 2.99, 2.3407
                end
                
                if to_y < maxx then
                    if to_y > minn then
                        players[1].color.r = 0
                        players[1].color.b = 0
                    else
                        players[1].color.r = 1
                        players[1].color.b = 0
                        
                    end
                else
                    players[1].color.r = 0
                    players[1].color.b = 1
                end
                
                counter = 120
            end
        end
        counter = counter - 1
        if counter == 0 then
            players[1].color.r = 1
            players[1].color.b = 1
        end
    end, 1)
end, ON.POST_LEVEL_GENERATION)

register_option_bool('enable_tint', 'enable tint', 'enable character tint that indicates when you are correctly aligned', true)
register_option_bool('spawn_bubbles', 'spawn aligned bubbles', 'spawn aligned bubbles by the script and don\'t destroy blocks on tiamat', false)
register_option_bool('tiamine', 'tiamat landmine hole', 'creates a hole to be similar to a landmine. Only works with aligned bubbles off', false)
register_option_bool('random_bubbles_start', 'spawn random bubbles on start', 'Automatically off when aligned ropes are on', true)
register_option_bool('godmode_default', 'start with godmode enabled', '', true)
register_option_bool('spawn_springshoes', 'start with spring shoes', '', false)
register_option_bool('no_bad_ropes', 'remove bad ropes', 'removes all thrown ropes when teleporting to the platform', true)
register_option_bool('guide_lines', 'enable guide lines', 'Only with aligned bubbles off', true)
register_option_bool('refill_ropes', 'refill ropes', 'automaticly refill ropes when you ran out', true)
register_option_button('A_tiamat_warp', 'Warp to Tiamat\'s Throne', '', function() warp(6, 4, THEME.TIAMAT) end)
register_option_button('B_remove_ropes', 'remove all placed ropes', '', function()
    local ropes = get_entities_by_type(ENT_TYPE.ITEM_CLIMBABLE_ROPE)
    for _, uid in ipairs(ropes) do
        kill_entity(uid)
    end
end)
