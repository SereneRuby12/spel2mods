meta.name = "Walls are shifting (online)"
meta.version = "0.8"
meta.description = "Crushblocks spawn everywhere"
meta.author = "Estebanfer"

local function destroy_floor(ent)
    for i=FLOOR_SIDE.TOP, FLOOR_SIDE.RIGHT do
        ent:remove_decoration(i)
    end
    ent:destroy()
end

local function spawn_crushtrap(x, y, l)
    spawn_grid_entity(ENT_TYPE.ACTIVEFLOOR_CRUSH_TRAP, x, y, l)
end
local function is_valid_crushtrap_spawn(x, y, l)
    -- Only spawn where there is floor
    local floor = get_grid_entity_at(x, y, l)
    if floor == -1 then
        --floor = get_entity(floor)
        --local solid = test_flag(floor.flags, 3) 
        if prng:random_float(PRNG_CLASS.PROCEDURAL_SPAWNS) < options.spawn_chance/10 then
            --destroy_floor(floor)
            return true
        end
    end
    return false
end
local crushtrap_chance = define_procedural_spawn("sample_crushtrap", spawn_crushtrap, is_valid_crushtrap_spawn)
set_callback(function(room_gen_ctx)
    --math.randomseed(read_prng()[1])
    local current_crushtrap_chance = get_procedural_spawn_chance(PROCEDURAL_CHANCE.CRUSHER_TRAP_CHANCE)
    current_crushtrap_chance = 1

    prinspect(current_crushtrap_chance)
    room_gen_ctx:set_procedural_spawn_chance(crushtrap_chance, current_crushtrap_chance)
    -- Disable the original crushtrap spawns so we don't get double spawns
    room_gen_ctx:set_procedural_spawn_chance(PROCEDURAL_CHANCE.CRUSHER_TRAP_CHANCE, 0)
end, ON.POST_ROOM_GENERATION)

register_option_int('spawn_chance', 'Crush trap spawn chance', '1 is 10%, 10 is 100%', 1, 0, 10)