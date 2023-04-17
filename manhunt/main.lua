meta.name = 'Spelunky Manhunt'
meta.version = '1.2'
meta.description = 'Spawns an angry hired hand at every level'
meta.author = 'Estebanfer'

local reviving = false
local count = 0

local hh_uid = 0
local hh = nil
local pl_layer = 0
local door_cycle = 0
local DEFAULT_ACCELERATION = 0.032
local DEFAULT_MAX_SPEED = 0.0725

local bx1, by1, bx2, by2 --bounds
local ghost = 0
local lastspos = {0, 0, 0} --last second position
local lastpos = {0, 0, 0}
local door_x = 0
local door_y = 0
local layer_flag = true
local can_go_door = true
local platform_nspawned = true
local char_type = ENT_TYPE.CHAR_HIREDHAND
local closest_player = -1

local hh_health, hh_ghost_check, hh_revive_check, hh_angry_ghost_check, hh_revive_time, hh_revive_stun_time, hh_stun_start, hh_take_no_damage_check, hh_speed, kill_hhs_check, hh_no_corpse_revive_check, gh_velocity
local function default_settings() 
  hh_health = 4
  hh_ghost_check = true
  hh_revive_check = true
  hh_angry_ghost_check = false
  hh_revive_time = 3
  hh_revive_stun_time = 60
  hh_stun_start = 2
  hh_take_no_damage_check = false
  hh_speed = 1
  kill_hhs_check = false
  hh_no_corpse_revive_check = true
  gh_velocity = 4
end
default_settings()

local function closest(num)
  return math.floor(num+0.5)
end

local function get_blocks(floors)
  local blocks = {}
  for i, v in ipairs(floors) do
      local flags = get_entity_flags(v)
      if test_flag(flags, ENT_FLAG.SOLID) then
        table.insert(blocks, v)
      end
  end
  return blocks
end

local function set_hh_values(hh_uid)
  hh = get_entity(hh_uid)
  if hh_take_no_damage_check then hh.flags = set_flag(hh.flags, 6) end --take no damage
  hh.flags = set_flag(hh.flags, 4)
  hh.more_flags = set_flag(hh.more_flags, 2)
  hh.color.r = 0.9
  hh.color.g = 0.5
  hh.color.b = 0.5
  hh:stun(hh_stun_start*60)
  local hht = get_type(char_type)
  hht.acceleration = DEFAULT_ACCELERATION*hh_speed
  hht.max_speed = DEFAULT_MAX_SPEED*hh_speed
  set_timeout(function() hh.flags = clr_flag(hh.flags, 4) end, hh_stun_start*60)
  hh.health = hh_health
  --[[if state.theme ~= COSMIC_OCEAN then
    move_entity(hh_uid, 20, 300, 0, 0)
  end
  hh.flags = set_flag(hh.flags, 5)
  hh.flags = set_flag(hh.flags, 10)
  hh.stun_timer = hh_revive_time*60-1
  set_timeout(function()
    move_entity(hh_uid, lastpos[1], lastpos[2], 0, 0)
    spawn_hh_ghost()
    to_ghost_intv = set_interval(to_ghost, 60)
  end, hh_revive_time*60)]]
end

local function spawn_necro_hh(char_type, x, y, l)
  hh_uid = spawn_companion(char_type, x, y, l)
  set_hh_values(hh_uid)
end

local function spawn_new_hh_apart()
  local tospawn_x, tospawn_y
  if state.theme == THEME.OLMEC then
    tospawn_x, tospawn_y = 4, 118
  elseif state.theme == THEME.HUNDUN then
    local doors = get_entities_by_type(ENT_TYPE.FLOOR_DOOR_EXIT)
    tospawn_x, tospawn_y = get_position(doors[1])
  else
    tospawn_x, tospawn_y = spawn_x, spawn_y
  end
  spawn_necro_hh(char_type, tospawn_x, tospawn_x, LAYER.FRONT)
  if state.theme ~= COSMIC_OCEAN then
    move_entity(hh_uid, 20, 300, 0, 0)
  end
  hh.flags = set_flag(hh.flags, 5)
  hh.flags = set_flag(hh.flags, 10)
  hh.stun_timer = hh_revive_time*60-1
  set_timeout(function()
    move_entity(hh_uid, lastpos[1], lastpos[2], 0, 0)
    spawn_hh_ghost()
    to_ghost_intv = set_interval(to_ghost, 60)
  end, hh_revive_time*60)
  reviving = false
end

local function layer_changed()
  local time = math.floor(distance(players[1].uid, hh_uid) * 15)
  can_go_door = false
  set_timeout(function() can_go_door = true end, time)
  door_x, door_y = get_position(players[1].uid)
end

local function goto_door()
  if hh.health == 0 and not hh_revive_check then
    return
  end
  local px, py, pl = get_position(players[1].uid)
  local hhx, hhy, hhl = get_position(hh_uid)
  if hh.stun_timer == 0 and hh.state ~= 12 and #get_entities_at(0, MASK.LAVA, door_x, door_y, hhl, 0.5) == 0 and ghost == 0 then
    if hhx ~= door_x then
      move_entity(hh_uid, door_x, door_y, 0, 0)
    end
    steal_input(hh_uid)
    send_input(hh_uid, 32)
  end
end

local function frame_interval()
  if ghost ~= 0 then ghostf() end
  if players[1] == nil or hh == nil then return end
  local hhx, hhy, hhl = get_position(hh_uid)
  if hhy < 0 then
    move_entity(hh_uid, hhx, 2, 0, 0)
    spawn_hh_ghost()
  end
  if get_entity_type(hh_uid) == ENT_TYPE.CHAR_HIREDHAND and hhy < 200 then
    lastpos[1], lastpos[2], lastpos[3] = get_position(hh_uid)
  end
  local px, py, pl = get_position(players[1].uid)
  if players[1].state == 21 and pl_layer ~= pl then
    if layer_flag and hhl ~= pl then
      layer_changed()
      layer_flag = false
    end
  else layer_flag = true end
  if hhl ~= pl and can_go_door and ghost == 0 and not test_flag(hh.flags, 29) and door_cycle == 0 then
    goto_door()
  else
    return_input(hh_uid)
  end
  if door_cycle >= 5 then
    door_cycle = 0
  else
    door_cycle = door_cycle + 1
  end
  pl_layer = pl
  local hhvx, hhvy = get_velocity(hh_uid)
  local ent = get_entity(hh.standing_on_uid)
  if ent ~= nil then
    if type(ent.type) == 'number' then
      ent = ent.type
    else
      ent = ent.type.id
    end
  end
  if ent == ENT_TYPE.FLOOR_ALTAR and (hh.state == CHAR_STATE.STUNNED or hh.state == CHAR_STATE.DYING) and hhvy == 0 and math.abs(hhvx) < 0.1 then
    if sacd then
      move_entity(hh_uid, hhx, hhy, math.random()/2-0.25, math.random()/10+0.15)
    else
      set_timeout(function()
        sacd = true
      end, 90)
    end
  end
end

set_callback(function()
  sacd = false
  platform_nspawned = true
  count = 0
  hh = nil
  hh_uid = 0
  door_x = 0
  door_y = 0
  ghost = 0
  can_go_door = false
  layer_flag = true
  reviving = false
  bx1, by1, bx2, by2 = get_bounds()
  if to_ghost_intv ~= nil then clear_callback(to_ghost_intv) end
  if toClear ~= nil then clear_callback(toClear) end
  set_timeout(function()
    to_ghost_intv = set_interval(to_ghost, 60) 
    set_interval(frame_interval, 1)
  end, 5)
  local x, y, layer = get_position(players[1].uid)
  if players[1]:topmost_mount().uid ~= players[1].uid then
    y = y - 0.5
  end
  spawn_x = closest(x)
  spawn_y = closest(y)
  
  spawn_necro_hh(char_type, x, y, layer)
  
  lastspos[1], lastspos[2], lastspos[3] = get_position(hh_uid)
  lastpos[1], lastpos[2], lastpos[3] = get_position(hh_uid)
end, ON.LEVEL)

set_callback(function()
  clear_callback(to_ghost_intv)
  ghost = 0
end, ON.TRANSITION)

function spawn_hh_ghost()
  local g
  if hh_uid ~= 0 then
    hh.flags = set_flag(hh.flags, 1)
    hh.stun_timer = 2
    if state.theme == THEME.COSMIC_OCEAN then
      move_entity(hh_uid, spawn_x, spawn_y+0.2, 0, 0, 0)
    else
      move_entity(hh_uid, 0, 300, 0, 0, 0)
    end
    hh.flags = set_flag(hh.flags, 5)
    hh.flags = set_flag(hh.flags, 10)
    hh.more_flags = set_flag(hh.more_flags, 16)
    ghost = spawn_entity(ENT_TYPE.MONS_GHOST_SMALL_SAD, lastpos[1], lastpos[2], lastpos[3], 0, 0)
    g = get_entity(ghost)
    g.flags = set_flag(g.flags, 5)
    g.color.g = 0.9
    g.color.b = 0.4
  else
    ghost = spawn_entity(ENT_TYPE.MONS_GHOST_SMALL_ANGRY, lastpos[1], lastpos[2]-0.5, lastpos[3], 0, 0)
    g = get_entity(ghost)
    g.flags = set_flag(g.flags, 5)
    g.velocity_multiplier = 0.8
    g.color.g = 0.5
    g.color.b = 0.2
    set_timeout(function()
      g.flags = clr_flag(g.flags, 5)
      g.color.g = 0
      g.color.b = 0
    end, 60)
  end
  g.color.r = 1
end

function to_ghost()
  if players[1] == nil then return end
  if get_entity_type(hh_uid) ~= char_type then
    if hh_uid == 0 then return end
    clear_callback(to_ghost_intv)
    hh = nil
    hh_uid = 0
    if hh_angry_ghost_check and hh_revive_check then set_timeout(spawn_hh_ghost, 60) end
    if hh_no_corpse_revive_check and hh_revive_check then spawn_new_hh_apart() end--set_timeout(spawn_hh_ghost, 60) end
    return
  end
  local hhx, hhy, hhl = get_position(hh_uid)
  local px, py, pl = get_position(players[1].uid)
  if hh_ghost_check and ghost == 0 and ( math.abs(py-hhy) > 4 or distance(players[1].uid, hh_uid) > 8 ) and ( math.abs(py-hhy) > 4 or math.abs(lastspos[1]-hhx) < 2 ) and math.abs(lastspos[2]-hhy) < 2 and hhl == pl then --distance(players[1].uid, hh_uid) > 8 and (hh_revive_check or not test_flag(hh.flags, 29))
    if ( not test_flag(hh.flags, 29) and count > 2 ) then --or ( test_flag(hh.flags, 29) and count >= hh_revive_time ) then
      spawn_hh_ghost()
    end
    count = count + 1
  else count = 0 end
  hh.color.g = 0.5+math.min(count/10, 0.4)
  hh.color.b = 0.5+math.min(count/10, 0.4)
  --extra
  lastspos[1] = hhx
  lastspos[2] = hhy
  lastspos[3] = hhl
  if hh_revive_check and test_flag(hh.flags, 29) and not reviving then
    reviving = true
    set_timeout(function()
      if hh == nil then
        return
      end
      count = 1
      local hhx, hhy, hhl = get_position(hh_uid)
      hh.flags = clr_flag(hh.flags, 29)
      hh.health = hh_health
      if #get_entities_at(0, MASK.LAVA, hhx, hhy, hhl, 0.8) == 0 then
        hh:stun(hh_revive_stun_time)
      else
        spawn_hh_ghost()
      end
      reviving = false
    end, hh_revive_time*60)
  end
end

function ghostf()
  local gh = get_entity(ghost)
  if players[1] == nil or hh_uid == 0 then
    if get_entity_type(ghost) == ENT_TYPE.MONS_GHOST_SMALL_SAD then
      kill_entity(ghost)
      ghost = 0
    end
    return
  end
  if get_entity_type(ghost) ~= ENT_TYPE.MONS_GHOST_SMALL_SAD and get_entity_type(ghost) ~= ENT_TYPE.MONS_GHOST_SMALL_ANGRY then return end
  local gh_vel = distance(players[1].uid, ghost) / 40 + 1
  gh.velocity_multiplier = gh_vel*gh_vel*(gh_velocity/2)
  local px, py, pl = get_position(players[1].uid)
  local gx, gy, gl = get_position(ghost)

  --CO fixes
  if gx > bx2 then move_entity(ghost, bx1, gy, 0, 0)
  elseif gx < bx1 then move_entity(ghost, bx2, gy, 0, 0) end
  if gy > by1 then move_entity(ghost, gx, by2, 0, 0)
  elseif gy < by2 then move_entity(ghost, gx, by1, 0, 0) end

  local hhx, hhy, hhl = get_position(hh_uid)
  local hitbox = get_hitbox(ghost)
  local ents = get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, hitbox, gl)
  ents = get_blocks(ents)
  if math.abs(px-gx) < 3.5 and math.abs(py-gy) < 2 and gl == hhl and #ents == 0 and #get_entities_at(0, MASK.LAVA, gx, gy, gl, 0.8) == 0 or pl ~= hhl then
    if pl == hhl then
      move_entity(hh_uid, gx, gy, 0, 0)
    else
      move_entity(hh_uid, px, py, 0, 0)
    end
    hh.flags = clr_flag(hh.flags, 5)
    hh.flags = clr_flag(hh.flags, 10)
    hh.flags = clr_flag(hh.flags, 4)
    hh.flags = clr_flag(hh.flags, 1)
    hh.more_flags = clr_flag(hh.more_flags, 16)
    hh.stun_timer = 0
    hh.health = hh_health
    hh.color.g = 0.5+count/10
    hh.color.b = 0.5
    return_input(hh_uid)
    kill_entity(ghost)
    ghost = 0
    return
  end
  local close_chars = get_entities_at(0, MASK.PLAYER, gx, gy, gl, 0.9)
  for _, uid in ipairs(close_chars) do
    if uid ~= hh_uid then
      local will_kill = true
      for i,p in ipairs(players) do
        if p.uid == uid then
          will_kill = false
        end
      end

      if will_kill then
        kill_entity(uid)
      end

    end
  end
end

--GUI
widgetOpen = false
register_option_button("open", "Edit additional features", function()
    widgetOpen = true
end)

set_callback(function(draw_ctx)
  if widgetOpen then
    widgetOpen = draw_ctx:window("Spelunky Manhunt additional features and settings", -0.2, 1, 1, 0.9, true, function()
      hh_health = draw_ctx:win_slider_int("HH health", hh_health, 1, 20)
      draw_ctx:win_sameline(0, -2)
      if draw_ctx:win_button("Reset settings") then
        default_settings()
      end
      hh_stun_start = draw_ctx:win_slider_int("Seconds a HH is stunned at start", hh_stun_start, 0, 10)
      hh_ghost_check = draw_ctx:win_check("Hired hand can become a ghost when is far", hh_ghost_check)
      hh_revive_check = draw_ctx:win_check("Hired hand can revive", hh_revive_check)
      hh_angry_ghost_check = draw_ctx:win_check("Hired hand can become angry ghost when no corpse", hh_angry_ghost_check)
      hh_no_corpse_revive_check = draw_ctx:win_check("Hired hand revives even when no corpse", hh_no_corpse_revive_check)
      hh_angry_ghost_check = hh_revive_check and hh_angry_ghost_check
      hh_no_corpse_revive_check = hh_revive_check and hh_no_corpse_revive_check
      hh_angry_ghost_check = hh_angry_ghost_check and not hh_no_corpse_revive_check
      hh_revive_time = draw_ctx:win_slider_int("Seconds for a hired hand to revive", hh_revive_time, 0, 60)
      gh_velocity = draw_ctx:win_slider_int("Hired hand ghost velocity", gh_velocity, 2, 10)
      hh_revive_stun_time = draw_ctx:win_slider_int("Frames a hh is stunned after reviving 60=1s", hh_revive_stun_time, 2, 300)
      hh_speed = draw_ctx:win_slider_float("Hired hands speed (of all hhs)", hh_speed, 0.01, 4.0)
      hh_take_no_damage_check = draw_ctx:win_check("Hired hand can't take damage", hh_take_no_damage_check)
      kill_hhs_check = draw_ctx:win_check("Kill all other hired hands", kill_hhs_check)
    end)
  end
end, ON.GUIFRAME)