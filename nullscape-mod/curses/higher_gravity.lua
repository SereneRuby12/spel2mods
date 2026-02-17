
---@param ent Movable
set_post_entity_spawn(function (ent, spawn_flags)
  if state.screen == SCREEN.LEVEL and ModState.run_curses[CURSE_ID.HIGHER_GRAVITY] then
    ent:set_post_update_state_machine(function (self)
      ---@cast self Player
      if test_flag(self.more_flags, ENT_MORE_FLAG.SWIMMING) then
        self:reset_gravity()
      else
        self:set_gravity(1.1)
      end
    end)
    -- ent:set_gravity(1.1)
  end
end, SPAWN_TYPE.ANY, MASK.PLAYER)
