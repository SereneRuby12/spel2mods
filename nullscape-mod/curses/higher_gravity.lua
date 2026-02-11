
---@param ent Movable
set_post_entity_spawn(function (ent, spawn_flags)
  if state.screen == SCREEN.LEVEL and ModState.run_curses[CURSE_ID.HIGHER_GRAVITY] then
    messpect(ent.uid)
    ent:set_gravity(1.1)
  end
end, SPAWN_TYPE.ANY, MASK.PLAYER)
