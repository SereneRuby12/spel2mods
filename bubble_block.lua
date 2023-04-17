define_tile_code("bubble_block")
set_pre_tile_code_callback(function(x, y, layer)
    get_entity( spawn_grid_entity(ENT_TYPE.FLOOR_GENERIC, x, y, layer) ):destroy()
    local ent = get_entity(spawn_grid_entity(ENT_TYPE.MIDBG, x, y, layer))
    ent:set_draw_depth(46)
    ent.width = 1.2
    ent.height = 1.2
    ent.animation_frame = 57
end, "bubble_block")