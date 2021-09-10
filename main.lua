meta.name = "All Chars"

local chars = {}
local actual_texture

--[[local function spawn_coffin_char(x,y,layer, item)
    local uid = spawn_entity(ENT_TYPE.ITEM_COFFIN, x, y, layer, 0, 0)
    local ent = get_entity(uid)
    set_contents(uid, item)
    ent.flags = set_flag(ent.flags, 5)
    ent.flags = set_flag(ent.flags, 10)
    ent.flags = set_flag(ent.flags, 1)
    set_timeout(function()
      cancel_speechbubble()
    end, 1)
    kill_entity(uid)
end]]
local function spawn_coffin_char(x,y,layer, item)
  spawn_companion(item, x, y, layer)
end

set_callback(function()
  chars = {}
  actual_texture = nil
  for i = ENT_TYPE.CHAR_ANA_SPELUNKY, ENT_TYPE.CHAR_CLASSIC_GUY do
    if #get_entities_by_type(i) == 0 then
      chars[#chars+1] = i
    end
  end
end, ON.START)

set_callback(function()
  if actual_texture then
    players[1]:set_texture(actual_texture)
  end
  local plays = get_entities_by_mask(MASK.PLAYER)
  local px, py, pl = get_position(players[1].uid)
  for i = 1, 8-#plays+1 do --solve same chars spawning twice or more
      if #chars == 0 then break end
      local ch_num = math.random(1, #chars)
      spawn_coffin_char(px, py, pl, chars[ch_num])
      table.remove(chars, ch_num)
  end
  local plays = get_entities_by_mask(MASK.PLAYER)
  players[1]:give_powerup(ENT_TYPE.ITEM_POWERUP_ANKH)
end, ON.LEVEL)

set_callback(function()
  if players[1] and test_flag(players[1].flags, 29) then
    players[1]:remove_powerup(ENT_TYPE.ITEM_POWERUP_ANKH)
    if players[1].linked_companion_child ~= -1 then
      local dx, dl, dy = 0, 0, 0
      if state.theme ~= THEME.COSMIC_OCEAN then
        _, dy = get_bounds()
        dy = dy + 3
        dx, dl = 5, players[1].layer
      else
        dx, dy, dl = get_position(get_entities_by_type(ENT_TYPE.FLOOR_DOOR_ENTRANCE)[1])
        players[1].color.a = 0
        players[1].flags = set_flag(players[1].flags, 4)
        players[1].flags = set_flag(players[1].flags, 6)
      end
      local to_uid = players[1].linked_companion_child
      local to_ent = get_entity(to_uid)
      local to_stun_timer = to_ent.stun_timer
      local to_falling_timer = to_ent.falling_timer
      local to_item = to_ent.holding_uid
      local prev_x, prev_y, prev_l = get_position(players[1].uid)
      local prev_vx, prev_vy = get_velocity(players[1].uid)
      local to_x, to_y, to_l = get_position(to_uid)
      local to_vx, to_vy = get_velocity(to_uid)
      move_entity(to_item, to_x, to_y, 0, 0)
      move_entity(to_uid, dx, dy+1, 0, 0)
      spawn(ENT_TYPE.ITEM_SKULLDROPTRAP_SKULL, dx, dy+1, to_ent.layer, 0, 0)

      actual_texture = get_entity(to_uid):get_texture()
      to_ent:set_texture(players[1]:get_texture())
      messpect(actual_texture)
      players[1]:set_texture(actual_texture)
      players[1].flags = clr_flag(players[1].flags, 29)
      players[1].health = to_ent.health
      to_ent.health = 1
      
      players[1].falling_timer = 0
      drop(players[1].uid, players[1].holding_uid)
      --[[if players[1].layer ~= dl then --due that dl is player layer when isn't on CO, and CO has 1 layer, this isn't necessary
        players[1]:set_layer(dl)
      end]]
      state.camera.focused_entity_uid = -1
      players[1].falling_timer = 0
      move_entity(players[1].uid, dx, dy, 0, 0) --do something with camera
      local wait = 1
      if players[1].state == 22 then --if being crushed
        players[1]:stun(2)
        set_timeout(function()
          players[1]:stun(0)
          kill_entity(to_uid) -- if the player got crushed, then no need to preserve the corpse
        end, 1)
        wait = 2
      else
        players[1]:stun(0)
        messpect(false)
      end
      set_timeout(function()
        players[1]:give_powerup(ENT_TYPE.ITEM_POWERUP_ANKH)
        if test_flag(players[1].flags, 4) then
          players[1].color.a = 1
          players[1].flags = clr_flag(players[1].flags, 4)
          players[1].flags = clr_flag(players[1].flags, 6)
        end
        if to_stun_timer > 0 then
          messpect(true)
          players[1]:stun(to_stun_timer)
        end
        if players[1].layer ~= to_l then
          players[1]:set_layer(to_l)
        end
      	move_entity(players[1].uid, to_x, to_y, to_vx, to_vy)
        players[1].falling_timer = to_falling_timer
	      state.camera.focused_entity_uid = players[1].uid
	      pick_up(players[1].uid, to_item)
        
        move_entity(to_uid, prev_x, prev_y, prev_vx, prev_vy)
      end, wait)
    end
  end
end, ON.FRAME)

set_callback(function()
  if actual_texture then
    players[1]:set_texture(actual_texture)
  end
end, ON.TRANSITION)

set_callback(function()
  if state.pause == 32 then
    pause(false)
  end
end, ON.GUIFRAME)

set_post_entity_spawn(function(ent)
  --texture is items texture, wasn't able to figure out how to make this work for hh ropes
  messpect(ent:get_texture(TEXTURE.DATA_TEXTURES_CHAR_BLACK_0), ent.animation_frame)
  ent:set_texture(TEXTURE.DATA_TEXTURES_CHAR_BLACK_0)
end, SPAWN_TYPE.SYSTEMIC, 0, ENT_TYPE.ITEM_ROPE)