local random_texture
do
  local tdef = TextureDefinition:new() --[[@as TextureDefinition]]
  tdef.width, tdef.height = 512, 512
  tdef.tile_width, tdef.tile_height = 512, 512
  tdef.texture_path = "./enemies/assets/icons/random.png"
  random_texture = define_texture(tdef)
end

local function spawn_random()
  local choices_available = {}
  for enemy_idx, enemy in ipairs(ENEMY_DATA) do
    for _, run_enemy in ipairs(ModState.run_enemies) do
      if run_enemy.enemy_idx == enemy_idx and enemy.hard_limit and run_enemy.number >= enemy.hard_limit then
        goto continue
      end
    end
    choices_available[#choices_available+1] = enemy_idx
    ::continue::
  end
  local enemy_idx = choices_available[prng:random(#choices_available)]
  ENEMY_DATA[enemy_idx].spawn()
end

---@type EnemyInfo
return {
  spawn = spawn_random,
  icon_texture = random_texture,
}
