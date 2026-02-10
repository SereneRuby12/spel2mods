---@param entity Entity
---@param any_layer boolean?
local function select_target(entity, any_layer)
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

local function ease_out(x)
  return (-((x-1)*(x-1))) + 1
end

local function ease_out_to_zero(x)
  return ((x-1)*(x-1))
end

local function ease_in(x)
  return x*x
end

local function ease_in_to_zero(x)
  return (-(x*x)) + 1
end

local function maxmin(min, x, max)
  return math.max(min, math.min(max, x))
end

return {
  select_target = select_target,
  ease_out = ease_out,
  ease_out_to_zero = ease_out_to_zero,
  ease_in = ease_in,
  ease_in_to_zero = ease_in_to_zero,
  maxmin = maxmin,
  SOUND_VOLUME = 0.35
}
