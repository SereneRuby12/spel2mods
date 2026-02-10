---@class EnemyInfo
---@field spawn fun(x: number, y: number, l: number): integer
---@field icon_texture TEXTURE
---@field limit integer?
---@field hard_limit integer?
---@field name string?
---@field description string?

---@return EnemyInfo[]
local function load_enemies()
  ---@type EnemyInfo[][]
  local enemies_arrays = {}
  enemies_arrays[#enemies_arrays+1] = require "enemies.baby"
  enemies_arrays[#enemies_arrays+1] = require "enemies.bell"
  enemies_arrays[#enemies_arrays+1] = require "enemies.dozer"
  enemies_arrays[#enemies_arrays+1] = require "enemies.icbm"
  enemies_arrays[#enemies_arrays+1] = require "enemies.telefragger"
  enemies_arrays[#enemies_arrays+1] = require "enemies.voidbreaker"

  ---@type EnemyInfo[]
  local enemies = {}
  for _, i_enemies in ipairs(enemies_arrays) do
    for _, enemy in ipairs(i_enemies) do
      enemies[#enemies+1] = enemy
    end
  end
  enemies[-1] = require "enemies.random"
  return enemies
end

local module = {}

local enemies = load_enemies()

Enemies = enemies

function module.spawn_enemy(index, amount)
  for i = 1, amount do
    local off_x, off_y = (prng:random() * 6) - 3, (prng:random() * 1.5) + 3.5
    enemies[index].spawn(state.level_gen.spawn_x + off_x, state.level_gen.spawn_y + 4, LAYER.FRONT)
  end
end

local function has(table, value)
  for i, item in pairs(table) do
    if item == value then return true end
  end
  return false
end

---@param ignore_choices integer[]
function module.get_enemy_choice(ignore_choices)
  local choices_available = {}
  for i, enemy in ipairs(enemies) do
    if not has(ignore_choices, i) then
      for _, run_enemy in ipairs(ModState.run_enemies) do
        if run_enemy.enemy_idx == i and enemy.limit and run_enemy.number >= enemy.limit then
          goto continue
        end
      end
      choices_available[#choices_available+1] = i
      ::continue::
    end
  end
  if #choices_available == 0 then return -1 end
  return choices_available[prng:random(#choices_available)]
end

return module
