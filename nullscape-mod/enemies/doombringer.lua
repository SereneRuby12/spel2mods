local commonlib = require "common"

local module = {}

local scream_sound = create_sound("./enemies/sounds/Doombringer_Scream.ogg") --[[@as CustomSound]]
local explode_sound = create_sound("./enemies/sounds/Doombringer_Explode.ogg") --[[@as CustomSound]]

---@enum DOOMBRINGER_STATE
local DOOMBRINGER_STATE = {
  CALM = 1,
  SCREAMING = 2,
}

---@class DoombringerInfo
---@field state DOOMBRINGER_STATE
---@field timer integer
---@field scream_sound PlayingSound?

local DOOMBRINGER_POINT_OF_NO_RETURN = 60
local DOOMBRINGER_EXPLODE_TIME = 60 * 10
local DOOMBRINGER_MIN_START_SCREAM_TIME = 7 * 60
local DOOMBRINGER_MAX_START_SCREAM_TIME = 14 * 60
local DOOMBRINGER_MIN_SCREAM_TIME = 20 * 60
local DOOMBRINGER_MAX_SCREAM_TIME = 40 * 60

---@type {[integer]: DoombringerInfo}
local target_player_info = {}
local doombringer_in_level = false
---@type {[integer]: true}
local cb_set_entities = {}
local color = Color:new(1, 1, 1, 0.5)

set_callback(function ()
  if not doombringer_in_level then return end
  for i, player in ipairs(get_local_players()) do
    if not target_player_info[player.uid] then
      target_player_info[player.uid] = {
        state = DOOMBRINGER_STATE.CALM,
        timer = prng:random(DOOMBRINGER_MIN_START_SCREAM_TIME, DOOMBRINGER_MAX_START_SCREAM_TIME),
      }
      ---@param other_entity Movable
      player:set_pre_on_collision2(function (self, other_entity)
        if other_entity.type.search_flags & MASK.MONSTER == 0 or cb_set_entities[other_entity.uid] then return end
        local frame = state.time_level
        local stomper_uid = self.uid
        cb_set_entities[other_entity.uid] = true
        other_entity:set_post_stomped_by(function (self, stomper)
          if target_player_info[stomper.uid] then
            local info = target_player_info[stomper.uid]
            if info.state == DOOMBRINGER_STATE.SCREAMING and info.timer > DOOMBRINGER_POINT_OF_NO_RETURN then
              info.state = DOOMBRINGER_STATE.CALM
              info.timer = prng:random(DOOMBRINGER_MIN_SCREAM_TIME, DOOMBRINGER_MAX_SCREAM_TIME)
              info.scream_sound:stop()
              info.scream_sound = nil
            end
          end
          clear_callback()
          cb_set_entities[self.uid] = nil
        end)
      end)
    end
    local info = target_player_info[player.uid]
    if info.state == DOOMBRINGER_STATE.CALM then
      if info.timer <= 0 then
        local enemies_close = get_entities_at(0, MASK.MONSTER, player.abs_x, player.abs_y, player.layer, 9)
        enemies_close = filter_entities(enemies_close, function(enemy)
          return test_flag(enemy.flags, ENT_FLAG.CAN_BE_STOMPED)
            and not test_flag(enemy.flags, ENT_FLAG.DEAD)
            and not test_flag(enemy.flags, ENT_FLAG.PASSES_THROUGH_PLAYER)
            and enemy.abs_y <= player.abs_y + 2
        end)
        messpect(#enemies_close)
        if #enemies_close > 0 then
          info.state = DOOMBRINGER_STATE.SCREAMING
          info.timer = DOOMBRINGER_EXPLODE_TIME
          info.scream_sound = scream_sound:play()
          info.scream_sound:set_volume(commonlib.SOUND_VOLUME)
        else
          info.state = DOOMBRINGER_STATE.CALM
          info.timer = prng:random(math.floor(DOOMBRINGER_MIN_SCREAM_TIME/2))
        end
      end
    elseif info.state == DOOMBRINGER_STATE.SCREAMING then
      if info.timer <= 0 and player.exit_invincibility_timer == 0 and not test_flag(player.flags, ENT_FLAG.PASSES_THROUGH_EVERYTHING) then
        player:damage(nil, 1, 0, Vec2:new(.0, 0.1), 0, 0, 60, false)
        info.state = DOOMBRINGER_STATE.CALM
        info.timer = prng:random(DOOMBRINGER_MIN_SCREAM_TIME, DOOMBRINGER_MAX_SCREAM_TIME)
        info.scream_sound:stop()
        info.scream_sound = nil
        local snd = explode_sound:play()
        snd:set_volume(commonlib.SOUND_VOLUME)
      end
    end
    info.timer = info.timer - 1
  end
end, ON.GAMEFRAME)

set_callback(function ()
  for uid, info in pairs(target_player_info) do
    if info.scream_sound then
      info.scream_sound:stop()
    end
  end
  doombringer_in_level = false
  target_player_info = {}
  cb_set_entities = {}
end, ON.PRE_LEVEL_DESTRUCTION)

function module.spawn_doombringer()
  doombringer_in_level = true
end

return module

