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

return {
  select_target = select_target,
  ease_out = ease_out,
  SOUND_VOLUME = 0.35
}
