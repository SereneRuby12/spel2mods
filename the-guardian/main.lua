meta = {
    name = "The Guardian",
    version = "1.1",
    description = "Protect the eggplant child",
    author = "SereneRuby12"
}

local px, py, pl = 0, 0, 0
local child_x, child_y, child_l = 0, 0, 0
local prev_health = 4
local cog_sac_timer = 0
local poisoned = false
local cursed = false
local is_reviving = false
local spawn_dx, spawn_dy = 10, 10

local child_uid = -1
local child = -1
local child_item = -1
local holding_t = 0
local god_callback = -1

local max_dist, max_dist_enabled, max_time, child_health, kill_items, stun_on_attack, follow_child
local function default_settings()
    max_dist = 7
    max_dist_enabled = true
    max_time = 2
    child_health = 4
    kill_items = true
    stun_on_attack = true
    follow_child = true
end
default_settings()
local child_hp = child_health

local function spawn_child(x,y,layer)
    local t_child_uid = spawn_companion(ENT_TYPE.CHAR_EGGPLANT_CHILD, x, y, layer, 0, 0)
    local t_child = get_entity(t_child_uid)
    t_child.ai.trust = 3
    return t_child_uid, t_child
end

local function get_blocks(floors)
    local blocks = {}
    for i, v in ipairs(floors) do
        local ent = get_entity(v)
        if test_flag(ent.flags, ENT_FLAG.SOLID) then
            table.insert(blocks, v)
        end
    end
    return blocks
end

local function tele_to_player(px, py)
    move_entity(child_uid, px, py+0.2, 0, 0)
    child.airtime = 0
    child.color.a = 0.5
    child.flags = set_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
    if pl ~= child_l then
        child:set_layer(pl)
    end
end

local function god_mod()
    god_callback = set_on_player_instagib(players[1].uid, function(player)
        move_entity(player.uid, child_x, child_y, child_l, 0, 0)
        return true
    end)
end

local function disable_god()
    clear_entity_callback(players[1].uid, god_callback)
end

set_callback(function()
    poisoned = false
    cursed = false
    child_hp = child_health
    prev_health = child_health
    players[1].health = child_health
end, ON.START)

set_callback(function()
    cog_sac_timer = 0
    holding_t = max_time*60
    px, py, pl = get_position(players[1].uid)
    local possible = get_entities_at(ENT_TYPE.CHAR_EGGPLANT_CHILD, 0, px, py, pl, 1)
    if #possible == 0 then
        child_uid, child = spawn_child(px, py, pl)
        child.health = child_hp
        if poisoned then
            child:poison(1800)
        end
        if cursed then
            child:set_cursed(true)
        end
    else
        local ents = get_entities_at(ENT_TYPE.CHAR_EGGPLANT_CHILD, 0, px, py, pl, 1)
        if #ents == 1 then
            child_uid = ents[1]
            child = get_entity(child_uid)
        else
            for i, v in ipairs(ents) do
                local tchild = get_entity(v)
                if tchild.health == child_hp and tchild.holding_uid == child_item then
                    child_uid = v
                    child = get_entity(child_uid)
                    break
                end
            end
        end
        if child:is_poisoned() and not poisoned then
            child:poison(-1)
        end
        child.health = players[1].health
    end
    players[1].flags = set_flag(players[1].flags, ENT_FLAG.TAKE_NO_DAMAGE)
    god_mod()
    possible = get_entities_by_type(ENT_TYPE.CHAR_EGGPLANT_CHILD)
    if #possible > 1 then
        for i, v in ipairs(possible) do
            local tx, ty, tl = get_position(v)
            if tl == 1 then --LAYER.BACK
                kill_entity(v)
            end
        end
    end
    if follow_child then 
        state.camera.focused_entity_uid = child_uid
    end
    
    spawn_dx, spawn_dy = px, py
    child_x, child_y, child_l = get_position(child_uid)
    
    if state.theme == THEME.CITY_OF_GOLD then
        set_interval(function()
            if players[1] == nil then return false end
            if child == nil then return end
            if get_entity_type(child.standing_on_uid) == ENT_TYPE.FLOOR_ALTAR and child.stun_timer > 0 then
                cog_sac_timer = cog_sac_timer + 1
                if cog_sac_timer == 18 then 
                    move_entity(child_uid, child_x, child_y+0.5, 0, 0.05)
                    move_entity(players[1].uid, child_x, child_y, 0, 0)
                    players[1].stun_timer = 30
                    disable_god()
                end
            elseif cog_sac_timer < 18 then cog_sac_timer = 0 end
        end, 1)
    elseif state.theme == THEME.OLMEC then
        set_interval(function()
            if players[1] == nil then return false end
            if child == nil then return end
            if pl ~= child_l then
                move_entity(child_uid, px, py+0.2, 0, 0)
                child:set_layer(pl)
                child.flags = clr_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
            elseif pl == LAYER.BACK then
                move_entity(child_uid, px, py+0.2, 0, 0)
                child.airtime = 0
                child.flags = set_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
            end 
        end, 1)
    elseif state.theme == THEME.HUNDUN then
        spawn_dx, spawn_dy = get_position(get_entities_by_type(ENT_TYPE.FLOOR_DOOR_EXIT)[1])
    elseif state.theme == THEME.TIAMAT then
        set_interval(function()
            if players[1] == nil then return false end
            if child == nil then return end
            if py > 75 or players[1]:topmost_mount().type.id == ENT_TYPE.MOUNT_QILIN then
                tele_to_player(px, py)
            elseif test_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS) then
                child.color.a = 1
                child.flags = clr_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
            end
        end, 1)
    elseif test_flag(state.presence_flags, 9) or test_flag(state.presence_flags, 10) or test_flag(state.presence_flags, 11) then --Tun challenges
        set_interval(function()
            if players[1] == nil then return false end
            if child == nil then return end
    	    local ix, iy = get_room_index(px, py)
            local room_template = get_room_template(ix, iy, LAYER.FRONT)
            if room_template == ROOM_TEMPLATE.CHALLENGE_ENTRANCE or room_template == ROOM_TEMPLATE.CHALLENGE_ENTRANCE_LEFT then
                tele_to_player(px, py)
            elseif test_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS) then
                child.color.a = 1
                child.flags = clr_flag(child.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
            end
        end, 1)
    end
end, ON.LEVEL)

set_callback(function ()
    local ents = get_entities_by_mask(MASK.MONSTER)
    for i, v in ipairs(ents) do
        local ent = get_entity(v)
        if ent.type.id == ENT_TYPE.MONS_PET_DOG or ent.type.id == ENT_TYPE.MONS_PET_CAT or ent.type.id == ENT_TYPE.MONS_PET_HAMSTER then
            poisoned = false
        end
    end
end, ON.TRANSITION)

set_callback(function()
    if players[1] == nil then
        return
    end
    child = get_entity(child_uid)
    local p = players[1] --just to make code shorter
    if child == nil or test_flag(child.flags, 29) or child.health == 0 then
        if is_reviving or p:topmost().type.id == ENT_TYPE.FLOOR_PIPE then return end
        if p:has_powerup(ENT_TYPE.ITEM_POWERUP_ANKH) then
            disable_god()
            kill_entity(p.uid)

            set_timeout(function()
                god_mod()
                kill_entity(child_uid)
                child_uid, child = spawn_child(spawn_dx, spawn_dy, LAYER.FRONT)
                is_reviving = false
            end, 4)
            is_reviving = true
        else
            disable_god()
            kill_entity(players[1].uid)
        end
        return
    end
    if follow_child and state.camera.focused_entity_uid ~= child_uid then 
        state.camera.focused_entity_uid = child_uid
    end

    px, py, pl = get_position(p.uid)
    child_x, child_y, child_l = get_position(child_uid)
    if max_dist_enabled then
        local xdist, ydist = child_x - px, child_y - py
        local dist = math.sqrt((xdist*xdist) + (ydist*ydist))
        local to_x, to_y
        local angle = math.atan(ydist, xdist)
        to_x = (math.cos(angle)*max_dist)
        to_y = (math.sin(angle)*max_dist)
        if dist > max_dist and p:topmost().type.id ~= ENT_TYPE.FLOOR_PIPE and child:topmost().type.id ~= ENT_TYPE.FLOOR_PIPE then
            local hitbx = get_hitbox(child_uid)
            hitbx.left, hitbx.top = to_x+px-child.hitboxx+child.offsetx-0.08, to_y+py+child.hitboxy+child.offsety
            hitbx.right, hitbx.bottom = to_x+px+child.hitboxx+child.offsetx+0.08, to_y+py-child.hitboxy+child.offsety+0.1
            
            local ents = get_entities_overlapping_hitbox(0, MASK.FLOOR, hitbx, child_l)
            ents = get_blocks(ents)
            child.airtime = 1
            if #ents == 0 and #get_entities_overlapping_hitbox(0, MASK.ACTIVEFLOOR, hitbx, child_l) == 0 then
                move_entity(child_uid, to_x+px, to_y+py, child.velocityx/1.1, child.velocityy/1.1)
            else
                move_entity(players[1].uid, px, py, to_x/15, to_y/15)
                move_entity(child_uid, child_x, child_y, -to_x/5, -to_y/10)
                --[[for i, v in ipairs(ents) do -- like ball_and_chain
                    messpect(names[get_entity(v).type.id])
                    kill_entity(v)
                end
                move_entity(child_uid, to_x+px, to_y+py, child.velocityx, child.velocityy)--]]
            end
        end
    end

    if child:is_poisoned() and not poisoned then
        p:poison(1277951)
        poisoned = true
    elseif not p:is_poisoned() and child:is_poisoned() then
        child:poison(-1)
        poisoned = false
    end

    if test_flag(child.more_flags, 15) and not cursed then
        p:set_cursed(true)
        cursed = true
    elseif not test_flag(p.more_flags, 15) and test_flag(child.more_flags, 15) then
        child:set_cursed(false)
        cursed = false
    end

    if p.health > prev_health then
        child.health = p.health
    end
    prev_health = p.health
    child_hp = child.health
    if p.health > 0 then --to prevent a ankh bug
        p.health = child_hp 
    end
    local max_frames = max_time*60
    if child.holding_uid ~= -1 then
        child_item = get_entity(child.holding_uid).type.id
        if kill_items and (child_item == ENT_TYPE.ITEM_WOODEN_ARROW or child_item == ENT_TYPE.ITEM_POT or child_item == ENT_TYPE.ITEM_ROCK or child_item == ENT_TYPE.ITEM_SKULL) then
            kill_entity(child.holding_uid)
        end
    else child_item = -1 end
    if p.holding_uid == child_uid then
        if holding_t < 60 then
            entity_remove_item(p.uid, child_uid)
            holding_t = 0
        end
        holding_t = holding_t - 1
    elseif holding_t < max_frames then
        holding_t = holding_t + 1
    end
    child.color.b = holding_t/(max_frames*2+61)+0.5
    child.color.g = holding_t/(max_frames*2+61)+0.5
    local flag = test_flag(child.buttons, BUTTON.WHIP)
    if flag and stun_on_attack then
        child.stun_timer = 15
    end
end, ON.FRAME)

local widgetOpen = false
register_option_button('open', 'The Guardian settings', function ()
    widgetOpen = true
end)

set_callback(function(draw_ctx)
    if state.screen == SCREEN.LEVEL and max_dist_enabled then
        local sx, sy = screen_position(px, py)
        local radius = screen_distance(max_dist + 0.6)
        for i = 0, 5, 1 do
            draw_circle(sx, sy, radius, 11-i*2, rgba(i*50, i*50, i*50, i*50))
        end
    end
    if widgetOpen then
        widgetOpen = draw_ctx:window("The Guardian settings", -0.2, 1, 0.7, 0.7, true, function()
            max_dist = draw_ctx:win_slider_int('Max distance', max_dist, 1, 20)
            max_dist_enabled = draw_ctx:win_check('Max distance enabled', max_dist_enabled)
            max_time = draw_ctx:win_slider_int('Max time holding', max_time, 1, 10)
            child_health = draw_ctx:win_slider_int('Child spawn health', child_health, 1, 20)
            stun_on_attack = draw_ctx:win_check('Child stuns when tries to whip or grab item', stun_on_attack)
            kill_items = draw_ctx:win_check('Destroy common items the child tries to grab', kill_items)
            follow_child = draw_ctx:win_check('Camera follows the child', follow_child)
            if draw_ctx:win_button('Reset settings') then
                default_settings()
            end
        end)
    end
end, ON.GUIFRAME)

set_callback(function()
    if players[1] then
        disable_god()
        players[1].flags = clr_flag(players[1].flags, ENT_FLAG.TAKE_NO_DAMAGE)
    end
end, ON.SCRIPT_DISABLE)
