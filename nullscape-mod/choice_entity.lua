local module = {}

---@param x number
---@param y number
---@param layer integer
---@param icon_texture TEXTURE
---@param animation_frame integer
---@param on_chosen fun()
---@return integer
function module.spawn_choice(x, y, layer, icon_texture, animation_frame, on_chosen)
  local uid = spawn_entity(ENT_TYPE.ITEM_ROCK, x, y+0.3, layer, 0 , 0)
  local choice_ent = get_entity(uid)
  choice_ent.flags = clr_flag(choice_ent.flags, ENT_FLAG.COLLIDES_WALLS)
  choice_ent.flags = clr_flag(choice_ent.flags, ENT_FLAG.THROWABLE_OR_KNOCKBACKABLE)
  choice_ent.flags = clr_flag(choice_ent.flags, ENT_FLAG.INTERACT_WITH_WATER)
  choice_ent.flags = clr_flag(choice_ent.flags, ENT_FLAG.INTERACT_WITH_WEBS)
  choice_ent.flags = clr_flag(choice_ent.flags, ENT_FLAG.PICKUPABLE)
  choice_ent.flags = clr_flag(choice_ent.flags, 22) -- Carriable through exit
  choice_ent.flags = set_flag(choice_ent.flags, ENT_FLAG.NO_GRAVITY)
  choice_ent.flags = set_flag(choice_ent.flags, ENT_FLAG.PASSES_THROUGH_OBJECTS)
  choice_ent.offsety = 0
  choice_ent.hitboxx, choice_ent.hitboxy = 0.275, 0.4
  choice_ent.width, choice_ent.height = 1.5, 1.5
  choice_ent:set_texture(icon_texture)

  ---@param player Player
  choice_ent:set_pre_on_collision2(function (choice_ent, player)
    if player.type.search_flags & MASK.PLAYER ~= 0 then
      if player.buttons & BUTTON.DOOR ~= 0 and player.buttons_previous & BUTTON.DOOR == 0 then
        on_chosen()
      end
    end
    return true
  end)
  return uid
end

return module
