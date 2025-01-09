meta.name = "Monkey Hell"
meta.version = "1.1a"
meta.description = "Special monkeys, on every level"
meta.author = "SereneRuby12"

thrower_items = {
    ENT_TYPE.ITEM_POT, ENT_TYPE.ITEM_ROCK, ENT_TYPE.ITEM_BROKEN_ARROW,
    ENT_TYPE.ITEM_FLY, ENT_TYPE.ITEM_DIE, ENT_TYPE.ITEM_NUGGET,
    ENT_TYPE.ITEM_BROKEN_MATTOCK, ENT_TYPE.ITEM_BOMB, ENT_TYPE.ITEM_PICKUP_CLOVER,
    ENT_TYPE.ITEM_PICKUP_SKELETON_KEY, ENT_TYPE.ITEM_EGGPLANT
}

local JUMPING = 2
local IDLING = 0
local spawned_monkeys = {}
local function default_settings()
    m_spawn_chance = 33

    normal_chance = 5
    kamikaze_chance = 5
    shield_chance = 5
    shotgun_chance = 5
    thrower_chance = 5
    jumper_chance = 20
    split_chance = 20
    kill_items = true
    stun_on_attack = true
    follow_child = true
end
default_settings()
local total_chances = kamikaze_chance + shield_chance + shotgun_chance + thrower_chance + jumper_chance + split_chance + normal_chance
local function set_all_zero()
    normal_chance = 0
    kamikaze_chance = 0
    shield_chance = 0
    shotgun_chance = 0
    thrower_chance = 0
    jumper_chance = 0
    split_chance = 0
end

local kamikaze_mkys = {}
local shield_mkys = {}
local shotgun_mkys = {}
local thrower_mkys = {}
local jumper_mkys = {}
local split_mkys = {}
local shotgun_sound = get_sound(VANILLA_SOUND.ITEMS_SHOTGUN_FIRE)

local function signum(number)
    if number > 0 then
        return 1
    elseif number < 0 then
        return -1
    else
        return 0
    end
end

local function is_dead(ent)
    return ent == nil or test_flag(ent.flags, 29)
end

local function is_block(uid)
    local ent = get_entity(uid)
    if ent == nil then return false end
    local flags = get_entity_flags(uid)
    if test_flag(flags, ENT_FLAG.SOLID) then
        return true
    end
    return false
end

local function set_special_monkey(m_uid)
    local mx, my, ml = get_position(m_uid)
    local m = get_entity(m_uid)
    if total_chances < 1 then return end
    local rand = math.random(1, total_chances)
    if rand <= normal_chance then return
    elseif rand <= normal_chance + kamikaze_chance then --math.random(1, 100) <= kamikaze_chance
        table.insert(kamikaze_mkys, {uid = m_uid, has_mounted = false})
        m.color.g = 0.6
        m.color.b = 0.6
    elseif rand <= normal_chance + kamikaze_chance + shield_chance then
        local shield_uid = spawn_entity(ENT_TYPE.ITEM_METAL_SHIELD, mx, my, ml, 0, 0)
        local shield = get_entity(shield_uid)
        shield.color.a = 0.8
        m.color.r = 0.8
        m.color.g = 0.8
        m.color.b = 0.8
        table.insert(shield_mkys, {uid = m_uid, shield_uid = shield_uid})
        pick_up(m_uid, shield_uid)
    elseif rand <= normal_chance + kamikaze_chance + shield_chance + shotgun_chance then
        local shotgun_uid1 = spawn(ENT_TYPE.ITEM_SHOTGUN, mx, my, ml, 0, 0)
        local shotgun = get_entity(shotgun_uid1)
        shotgun.flags = set_flag(shotgun.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING)
        shotgun.flags = set_flag(shotgun.flags, ENT_FLAG.NO_GRAVITY)
        shotgun:set_draw_depth(m.type.draw_depth-1)
        m.color.g = 0.6
        m.color.b = 0
        table.insert(shotgun_mkys, {uid = m_uid, shotgun_uid = shotgun_uid1, standing = false, timer = 20})
        move_entity(shotgun_uid1, mx, my, 0, 0)
        --pick_up(m_uid, shotgun_uid)
    elseif rand <= normal_chance + kamikaze_chance + shield_chance + shotgun_chance + thrower_chance then
        m.color.r = 0.35
        m.color.g = 0.9
        m.color.b = 0.6
        table.insert(thrower_mkys, {uid = m_uid, standing = false})
    elseif rand <= normal_chance + kamikaze_chance + shield_chance + shotgun_chance + thrower_chance + jumper_chance then
        m.color.b = 0
        table.insert(jumper_mkys, {uid = m_uid})
    elseif  rand <= normal_chance + kamikaze_chance + shield_chance + shotgun_chance + thrower_chance + jumper_chance + split_chance then
        m.color.g = 0.2
        table.insert(split_mkys, {uid = m_uid})
    end
end

local function spawn_monkey(x, y, l)
    local m_uid = spawn_entity_snapped_to_floor(ENT_TYPE.MONS_MONKEY, x, y, l)
    set_special_monkey(m_uid)
end

local function is_valid_monkey_spawn(x, y, l)
    local not_entity_here = not is_block(get_grid_entity_at(x, y, l) ) and (#get_entities_at(0, MASK.LAVA, x, y, l, 1) == 0)
    if not_entity_here then
        local entity_below = is_block( get_grid_entity_at(x, y - 1, l) )
        if entity_below then
            return true
        end
    end
    return false
end

local monkey_chance = define_procedural_spawn("sample_monkey", spawn_monkey, is_valid_monkey_spawn)

set_callback(function(room_gen_ctx)
    kamikaze_mkys = {}
    shield_mkys = {}
    shotgun_mkys = {}
    thrower_mkys = {}
    jumper_mkys = {}
    split_mkys = {}
    local current_monkey_chance = get_procedural_spawn_chance(PROCEDURAL_CHANCE.MONKEY)
    
    current_monkey_chance = math.floor(1/(m_spawn_chance*0.01))
    room_gen_ctx:set_procedural_spawn_chance(monkey_chance, current_monkey_chance)
    room_gen_ctx:set_procedural_spawn_chance(PROCEDURAL_CHANCE.MONKEY, current_monkey_chance)
end, ON.POST_ROOM_GENERATION)

set_callback(function()
    frame1 = true
    local monkys = get_entities_by_type(ENT_TYPE.MONS_MONKEY)
    for _, v in ipairs(monkys) do
        local mx, my, _ = get_position(v)
        _, mvy = get_velocity(v)
        if mvy > 0.1 then
            move_entity(v, mx, my, 0, 0) -- so monkeys don't jump at start
        end
    end
end, ON.LEVEL)

local function updateJumperMonkeys()
    for i = #jumper_mkys, 1, -1 do
        local m = get_entity(jumper_mkys[i].uid)
        if is_dead(m) then
            table.remove(jumper_mkys, i)
        else
            local ai = get_entity_ai_state(jumper_mkys[i].uid)
            if ai == IDLING and m.jump_timer > 10 then
                m.jump_timer = 10
            end
        end
    end
end

local function updateKamikaze()
    for i = #kamikaze_mkys, 1, -1 do
        local m = get_entity(kamikaze_mkys[i].uid)
        if is_dead(m) then
            table.remove(kamikaze_mkys, i)
        else 
            if m:topmost_mount().uid ~= kamikaze_mkys[i].uid then
                kamikaze_mkys[i].has_mounted = true    
                m.color.g = m.color.g-0.006
                m.color.b = m.color.b-0.006
            elseif kamikaze_mkys[i].has_mounted then
                local mx, my, ml = get_position(kamikaze_mkys[i].uid)
                spawn_entity(ENT_TYPE.FX_EXPLOSION, mx, my, ml, 0, 0)
            end
        end
    end
end

local function facing_to_sign(bool)
    if bool then
        return -1
    else
        return 1
    end
end

local function get_thrower_item()
    for _, v in pairs(thrower_items) do
        if math.random(2) == 2 then
            return v
        end
    end
    return ENT_TYPE.ITEM_JETPACK
end

local function updateThrowingMonkeys()
    for i = #thrower_mkys, 1, -1 do
        local m = get_entity(thrower_mkys[i].uid)
        if is_dead(m) then
            table.remove(thrower_mkys, i)
        else
            local mx, my, ml = get_position(thrower_mkys[i].uid)
            local ai = get_entity_ai_state(thrower_mkys[i].uid)
            if ai == JUMPING then --and distance(thrower_mkys[i].uid, players[1].uid) < 10
                if thrower_mkys[i].standing then
                    local facing = facing_to_sign(test_flag(m.flags, ENT_FLAG.FACING_LEFT))
                    local item = get_thrower_item()
                    spawn(item, mx+0.5*facing, my, ml, (math.random()*0.1+0.15)*facing, math.random()*0.03+0.05 )
                    thrower_mkys[i].standing = false
                end
            elseif ai == IDLING then
                if thrower_mkys[i].standing == false then
                    thrower_mkys[i].standing = true
                    m.jump_timer = 140
                end
            end
        end
    end
end

local function spawn_bullets(mx, my, ml, facing)
    local dir = facing_to_sign(facing)
    local spawnx = mx+0.5*dir
    for i=1, 4 do
        spawn(ENT_TYPE.ITEM_BULLET, spawnx, my, ml, dir*(math.random()*0.2+0.15), math.random()*0.05-0.025)
    end
    local fx = spawn(ENT_TYPE.FX_SHOTGUNBLAST, spawnx+dir/2, my, ml, 0, 0)
    if facing then
        fx = get_entity(fx)
        fx.flags = set_flag(fx.flags, ENT_FLAG.FACING_LEFT)
    end
    shotgun_sound:play()
end

local function updateShotgunMonkeys()
    for i = #shotgun_mkys, 1, -1 do
        local m = get_entity(shotgun_mkys[i].uid)
        local shotgun_destroyed = (get_entity(shotgun_mkys[i].shotgun_uid) == nil)
        if is_dead(m) or shotgun_destroyed then
            kill_entity(shotgun_mkys[i].shotgun_uid)
            table.remove(shotgun_mkys, i)
        else
            local mx, my, ml = get_position(shotgun_mkys[i].uid)
            local shotgun = get_entity(shotgun_mkys[i].shotgun_uid)
            if test_flag(m.flags, ENT_FLAG.FACING_LEFT) then
                shotgun.flags = set_flag(shotgun.flags, ENT_FLAG.FACING_LEFT)
                move_entity(shotgun_mkys[i].shotgun_uid, mx-0.35, my-0.1, 0, 0)
            else
                shotgun.flags = clr_flag(shotgun.flags, ENT_FLAG.FACING_LEFT)
                move_entity(shotgun_mkys[i].shotgun_uid, mx+0.35, my-0.1, 0, 0)
            end

            local ai = get_entity_ai_state(shotgun_mkys[i].uid)
            if ai == JUMPING then
                if shotgun_mkys[i].standing then
                    shotgun_mkys[i].timer = -1
                    spawn_bullets(mx, my, ml, test_flag(m.flags, ENT_FLAG.FACING_LEFT) )
                    shotgun_mkys[i].standing = false
                    m.color.g = 0.6
                end
            elseif ai == IDLING then
                if shotgun_mkys[i].standing == false then
                    shotgun_mkys[i].standing = true
                    m.jump_timer = 160
                elseif distance(shotgun_mkys[i].uid, m.chased_target_uid) < 4.1 and m.jump_timer <= 30 then
                    m.color.g = m.jump_timer/50
                else
                    if m.jump_timer < 30 then
                        m.jump_timer = 30
                        m.color.g = 0.6
                    end
                end
            end
        end
    end
end

local function updateShieldMonkeys() 
    for i = #shield_mkys, 1, -1 do
        local m = get_entity(shield_mkys[i].uid)
        local shield = get_entity(shield_mkys[i].shield_uid)
        local shield_destroyed = (get_entity(shield_mkys[i].shield_uid) == nil)
        if is_dead(m) or shield_destroyed then
            if not shield_destroyed then
                kill_entity(shield_mkys[i].shield_uid)
            end
            table.remove(shield_mkys, i)
        else
            local shields = entity_get_items_by(shield_mkys[i].uid, ENT_TYPE.ITEM_METAL_SHIELD, 0)
            if shields == nil then
                pick_up(shield_mkys[i].uid, shield_mkys[i].shield_uid)
            end
            local mx, my = get_position(m:topmost_mount().uid) --shield_mkys[i].uid
            if m.state == 12 then
                move_entity(shield_mkys[i].uid, mx, my+0.01, 0, 0)
            end
        end
    end
end

local function updateSplitMonkeys()
    for i = #split_mkys, 1, -1 do
        local m = get_entity(split_mkys[i].uid)
        if is_dead(m) then
            local mx, my, ml = get_position(split_mkys[i].uid)
            for j = -0.1, 0.1, 0.2 do
                local sm_uid = spawn(ENT_TYPE.MONS_MONKEY, mx+j, my+0.2, ml, 0, 0)
                local sm = get_entity(sm_uid)
                sm.invincibility_frames_timer = 20
                sm.color.g = 0.5
                sm.color.r = 0.8
                table.insert(spawned_monkeys, sm_uid)
            end
            table.remove(split_mkys, i)
        end
    end
end

set_callback(function()

    updateKamikaze()
    updateShieldMonkeys()
    updateShotgunMonkeys()
    updateThrowingMonkeys()
    updateJumperMonkeys()

    if #spawned_monkeys ~= 0 then
        for i,v in ipairs(spawned_monkeys) do
            local mx, my = get_position(v)
            move_entity(v, mx, my, math.random()*0.2-0.1, math.random()*0.1+0.05)
        end
        spawned_monkeys = {}
    end
    local spiders = get_entities_by_type(ENT_TYPE.MONS_GIANTSPIDER)
    for _, v in ipairs(spiders) do
        local s = get_entity(v)
        if test_flag(s.flags, 29) then
            local sx, sy, sl = get_position(v)
            local monkey_num = math.random(4, 10)
            for i=1, monkey_num do
                local m_uid = spawn(ENT_TYPE.MONS_MONKEY, sx + math.random()*2 - 1, sy, sl, 0, 0)
                set_special_monkey(m_uid)
                table.insert(spawned_monkeys, m_uid)
            end
        end
    end
    updateSplitMonkeys() --placed after so the spawned_monkeys code is executed one frame after
end, ON.FRAME)

local function draw_percent(draw_ctx, value)
    if total_chances ~= 0 then
        draw_ctx:win_inline()
        draw_ctx:win_text(string.format("(%.1f%%)", (value / total_chances)*100))
    end
end

widgetOpen = false

register_option_button('open', 'Monkey Hell settings', function ()
    widgetOpen = true
end)

local spawn_values = {}
for i=1, 100 do
    local v = math.floor(100/i)
    if v ~= spawn_values[#spawn_values] then
        spawn_values[#spawn_values+1] = math.floor(100/i)
    end
end

set_callback(function(draw_ctx)
    if widgetOpen then
        --messpect(m_spawn_chance)
        for i, v in ipairs(spawn_values) do
            if v <= m_spawn_chance then
                --messpect(v, m_spawn_chance)
                if spawn_values[i-1] ~= nil then
                    local v1diff = math.abs(m_spawn_chance-v)
                    local v2diff = math.abs(m_spawn_chance-spawn_values[i-1])
                    if v1diff < v2diff then
                        m_spawn_chance = v
                    else
                        m_spawn_chance = spawn_values[i-1]
                    end
                else
                    m_spawn_chance = v
                end
                break
            end
        end
        total_chances = kamikaze_chance + shield_chance + shotgun_chance + thrower_chance + jumper_chance + split_chance + normal_chance
        widgetOpen = draw_ctx:window("Monkey Hell settings", -0.2, 1, 0.7, 0.8, true, function()
            m_spawn_chance = draw_ctx:win_slider_int('Monkey spawn chance', m_spawn_chance, 1, 100)
            normal_chance = draw_ctx:win_slider_int('Normal monkey chance', normal_chance, 0, 20)
            draw_percent(draw_ctx, normal_chance)
            kamikaze_chance = draw_ctx:win_slider_int('Kamikaze monkey chance', kamikaze_chance, 0, 20)
            draw_percent(draw_ctx, kamikaze_chance)
            shield_chance = draw_ctx:win_slider_int('Shield monkey chance', shield_chance, 0, 20)
            draw_percent(draw_ctx, shield_chance)
            shotgun_chance = draw_ctx:win_slider_int('Shotgun monkey chance', shotgun_chance, 0, 20)
            draw_percent(draw_ctx, shotgun_chance)
            thrower_chance = draw_ctx:win_slider_int('Thrower monkey chance', thrower_chance, 0, 20)
            draw_percent(draw_ctx, thrower_chance)
            jumper_chance = draw_ctx:win_slider_int('Jumper monkey chance', jumper_chance, 0, 20)
            draw_percent(draw_ctx, jumper_chance)
            split_chance = draw_ctx:win_slider_int('Split monkey chance', split_chance, 0, 20)
            draw_percent(draw_ctx, split_chance)
            if draw_ctx:win_button('Reset settings') then
                default_settings()
            end
            draw_ctx:win_inline()
            if draw_ctx:win_button('Set all chances to zero') then
                set_all_zero()
            end
        end)
    end
end, ON.GUIFRAME)
