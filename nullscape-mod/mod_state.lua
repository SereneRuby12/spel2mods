---@class ModState
---@field run_enemies {enemy_idx: integer, number: integer}[]
---@field run_curses {[CURSE_ID]: integer}
ModState = {
  run_enemies = {},
  run_curses = {},
}

function ModState.add_enemy_to_run(enemy_idx)
  for i, run_enemy in ipairs(ModState.run_enemies) do
    if run_enemy.enemy_idx == enemy_idx then
      run_enemy.number = run_enemy.number + 1
      return
    end
  end
  ModState.run_enemies[#ModState.run_enemies+1] = {
    enemy_idx = enemy_idx,
    number = 1,
  }
end

function ModState.add_curse_to_run(curse_id)
  if ModState.run_curses[curse_id] then
    ModState.run_curses[curse_id] = ModState.run_curses[curse_id] + 1
    return
  end
  ModState.run_curses[curse_id] = 1
end

function ModState.get_enemies_in_run(enemy_idx)
  for i, enemy in pairs(ModState.run_enemies) do
    if enemy_idx == enemy.enemy_idx then return enemy.number end
  end
  return 0
end

function ModState.get_curses_in_run(curse_id)
  return ModState.run_curses[curse_id] or 0
end

