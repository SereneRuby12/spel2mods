-- generate_particles(PARTICLEEMITTER.DM_DEATH_MIST, ent[1])
local zones = {}
--local c_ents = require "custom_ents"
--messpect(c_ents)
--local zone_types = {}

local function tile_aabb(x, y)
    return AABB:new(x-0.5, y+0.5, x+0.5, y-0.5)
end

local function spawn_particleemitter_ent(x, y, l)
    local uid = spawn_grid_entity(ENT_TYPE.DECORATION_GENERIC, x, y, l)
    local ent = get_entity(uid)
    ent.flags = set_flag(ent.flags, ENT_FLAG.INVISIBLE)
    ent:set_draw_depth(3)
    return uid, ent
end

-- zones

local function spawn_death_zone(x, y, l)
    --messpect(x, y, l)
    local uid = spawn_particleemitter_ent(x, y, l)
    generate_world_particles(PARTICLEEMITTER.APEP_DUSTWALL, uid)
    return {
        aabb = tile_aabb(x, y),
        layer = l
    }
end

local function update_death_zone(zone)
    for _, player in ipairs(players) do
        if player:overlaps_with(zone.aabb) and zone.layer == player.layer then
            --messpect('overlap')
            player:damage(0, 99, 1, player.velocityx*0.5, player.velocityy*0.5, 1)
        end
    end
end

--local death_zone_id = c_ents.new_ent_type(spawn_death_zone, update_death_zone)


local function spawn_cure_zone(x, y, l)
    local uid = spawn_particleemitter_ent(x, y, l)
    generate_world_particles(PARTICLEEMITTER.LASERBEAM_SPARKLES, uid)
    return  {
        aabb = tile_aabb(x, y),
        layer = l
    }
end

local function update_cure_zone(zone)
    local overlapping = get_entities_overlapping_hitbox(0, MASK.MONSTER | MASK.PLAYER, zone.aabb, zone.layer)
    for _, uid in ipairs(overlapping) do
        --messpect('overlap')
        local ent = get_entity(uid)
        if ent.poison_tick_timer ~= -1 then
            ent:poison(30*60) -- reset timer
            ent.poison_tick_timer = -1
        end
        if test_flag(ent.more_flags, ENT_MORE_FLAG.CURSED_EFFECT) then
            ent:set_cursed(false)
        end
    end
end

--local cure_zone_id = c_ents.new_ent_type(spawn_cure_zone, update_cure_zone)


local function spawn_curse_zone(x, y, l)
    local uid = spawn_particleemitter_ent(x, y, l)
    generate_world_particles(PARTICLEEMITTER.GHOST_MIST, uid)
    return  {
        aabb = tile_aabb(x, y),
        layer = l
    }
end

local function update_curse_zone(zone)
    local overlapping = get_entities_overlapping_hitbox(0, MASK.MONSTER | MASK.PLAYER, zone.aabb, zone.layer)
    for _, uid in ipairs(overlapping) do
        --messpect('overlap')
        local ent = get_entity(uid)
        if not test_flag(ent.more_flags, ENT_MORE_FLAG.CURSED_EFFECT) then
            ent:set_cursed(true)
        end
    end
end

--local curse_zone_id = c_ents.new_ent_type(spawn_curse_zone, update_curse_zone)


local function spawn_poison_zone(x, y, l, time)
    local uid = spawn_particleemitter_ent(x, y, l)
    generate_world_particles(PARTICLEEMITTER.POISONEDEFFECT_BUBBLES_BURST, uid)
    return  {
        aabb = tile_aabb(x, y),
        layer = l,
        time = time
    }
end

local function update_poison_zone(zone)
    local overlapping = get_entities_overlapping_hitbox(0, MASK.MONSTER | MASK.PLAYER, zone.aabb, zone.layer)
    for _, uid in ipairs(overlapping) do
        local ent = get_entity(uid)
        if ent.poison_tick_timer == -1 then
            poison_entity(uid)
            ent:poison(zone.time) -- set timer
        end
    end
end

--local poison_zone_id = c_ents.new_ent_type(spawn_poison_zone, update_poison_zone)
-- /zones
local function req_death_zone()
    define_tile_code("death_zone")
    set_pre_tile_code_callback(function (x, y, l)
        local zone = spawn_death_zone(x, y, l)
        set_interval(function()
            update_death_zone(zone)
        end, 1)
    end, "death_zone")
end

local function req_cure_zone()
    define_tile_code("cure_zone")
    set_pre_tile_code_callback(function (x, y, l)
        local zone = spawn_cure_zone(x, y, l)
        set_interval(function()
            update_cure_zone(zone)
        end, 1)
    end, "cure_zone")
end

local function req_curse_zone()
    define_tile_code("curse_zone")
    set_pre_tile_code_callback(function (x, y, l)
        local zone = spawn_curse_zone(x, y, l)
        set_interval(function()
            update_curse_zone(zone)
        end, 1)
    end, "curse_zone")
end

local function req_poison_zone(time)
    local timestr = tostring(time)
    define_tile_code("poison_zone" .. timestr)
    set_pre_tile_code_callback(function (x, y, l)
        local zone = spawn_poison_zone(x, y, l, time*60)
        set_interval(function()
            update_poison_zone(zone)
        end, 1)
    end, "poison_zone" .. timestr)
end

local function require_zone(zone_name)
    if zone_name == "death_zone" then
        req_death_zone()
    elseif zone_name == "cure_zone" then    
        req_cure_zone()
    elseif zone_name == "curse_zone" then
        req_curse_zone()
    else
        local _, _, num = zone_name:find("poison_zone(%d+)")
        if num then
            req_poison_zone(tonumber(num))
        end
    end
end

function zones.req_zone(zone_name)
    if type(zone_name) == "table" then
        for _, zone in ipairs(zone_name) do
            require_zone(zone)
        end
    else
        require_zone(zone_name)
    end
end

return zones