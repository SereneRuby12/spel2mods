local module = {}

---@param entity Entity
---@param any_layer boolean?
function module.select_target(entity, any_layer)
  local players = get_entities_by(0, MASK.PLAYER, any_layer and LAYER.ANY or entity.layer)
  local selected = -1
  local dist = math.maxinteger
  for index, player_uid in ipairs(players) do
    local idist = distance(entity.uid, player_uid)
    if idist < dist then
      selected = player_uid
      dist = idist
    end
  end
  return selected
end

---@param spawn_fun fun(x: number, y: number, layer: number): integer
---@return fun(): integer
function module.spawn_default_fun(spawn_fun)
  return function ()
    local off_x, off_y = (prng:random() * 6) - 3, (prng:random() * 1.5) + 3.5
    return spawn_fun(state.level_gen.spawn_x + off_x, state.level_gen.spawn_y + 4, LAYER.FRONT)
  end
end

function module.ease_out(x)
  return (-((x-1)*(x-1))) + 1
end

function module.ease_out_to_zero(x)
  return ((x-1)*(x-1))
end

function module.ease_in(x)
  return x*x
end

function module.ease_in_to_zero(x)
  return (-(x*x)) + 1
end

function module.maxmin(min, x, max)
  return math.max(min, math.min(max, x))
end

module.SOUND_VOLUME = 0.35

return module
