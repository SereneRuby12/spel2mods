---@enum ENEMY_ID
ENEMY_ID = {
  BABY = 1,
  VOIDBOUND_BABY = 2,
  BELL = 3,
  DOZER = 4,
  ICBM = 5,
  TELEFRAGGER = 6,
  VOIDBREAKER = 7,
  MART = 8,
  RANDOM = -1,
}

---@class EnemyInfo
---@field spawn fun(): integer
---@field icon_texture TEXTURE
---@field limit integer?
---@field hard_limit integer?
---@field name string?
---@field description string?
---@field min_level integer?

---@return EnemyInfo[]
local function load_enemies()
  ---@type {[ENEMY_ID: EnemyInfo}
  local enemies = {}
  local babies = require "enemies.baby"
  enemies[ENEMY_ID.BABY] = babies[1]
  enemies[ENEMY_ID.VOIDBOUND_BABY] = babies[2]

  enemies[ENEMY_ID.BELL] = require "enemies.bell"
  enemies[ENEMY_ID.DOZER] = require "enemies.dozer"
  enemies[ENEMY_ID.ICBM] = require "enemies.icbm"
  enemies[ENEMY_ID.TELEFRAGGER] = require "enemies.telefragger"
  enemies[ENEMY_ID.VOIDBREAKER] = require "enemies.voidbreaker"
  enemies[ENEMY_ID.MART] = require "enemies.mart"

  enemies[-1] = require "enemies.random"
  return enemies
end

local module = {}

---@type {[ENEMY_ID]: EnemyInfo}
ENEMY_DATA = load_enemies()

function module.spawn_enemy(index, amount)
  for i = 1, amount do
    ENEMY_DATA[index].spawn()
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
  for enemy_id, enemy in ipairs(ENEMY_DATA) do
    if not has(ignore_choices, enemy_id) then
      for _, run_enemy in ipairs(ModState.run_enemies) do
        if run_enemy.enemy_idx == enemy_id and enemy.limit and run_enemy.number >= enemy.limit then
          goto continue
        end
      end
      choices_available[#choices_available+1] = enemy_id
      ::continue::
    end
  end
  if #choices_available == 0 then return -1 end
  return choices_available[prng:random(#choices_available)]
end

return module
