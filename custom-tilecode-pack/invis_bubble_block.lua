define_tile_code("invis_bubble_block")
set_pre_tile_code_callback(function(x, y, layer)
    get_entity( spawn_grid_entity(ENT_TYPE.FLOOR_GENERIC, x, y, layer) ):destroy()
end, "invis_bubble_block")