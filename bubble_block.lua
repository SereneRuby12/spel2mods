define_tile_code("bubble_block")
set_pre_tile_code_callback(function(x, y, layer)
    local ent_uid = spawn_grid_entity(ENT_TYPE.FLOORSTYLED_MINEWOOD, x, y, layer);
    get_entity(ent_uid):destroy()
    return true
end, "bubble_block")