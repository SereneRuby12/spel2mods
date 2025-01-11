meta.author = "SereneRuby12"
meta.name = "Online Shortcuts"
meta.description = "Adds a shortcut level with various items. Compatible with online multiplayer and level gen mods"
meta.version = "1.1"
meta.online_safe = true

do
    local is_shortcut_level = false

    set_callback(function(ctx)
        local state = get_local_state() --[[@as StateMemory]]
        if state.screen == SCREEN.LEVEL and state.level_count == 0 then
            ctx:override_level_files({"starting_level.lvl"})
            is_shortcut_level = true
        end
    end, ON.PRE_LOAD_LEVEL_FILES)

    set_callback(function(room_gen_ctx)
        if not is_shortcut_level then return end
        local state = get_local_state() --[[@as StateMemory]]
        for x = 0, state.width-1 do
            for y = 0, state.height-1 do
                room_gen_ctx:mark_as_set_room(x, y, LAYER.FRONT)
            end
        end
        is_shortcut_level = false
    end, ON.POST_ROOM_GENERATION)
end

local function spawn_shortcut_door(x, y, world, level, theme, texture)
    spawn_door(x, y, LAYER.FRONT, world, level, theme)
    local entity = get_entity(spawn(ENT_TYPE.BG_DOOR, x, y, LAYER.FRONT, 0, 0))
    if entity then
        entity:set_texture(texture)
        unlock_door_at(x, y)
    end
end

define_tile_code("dwelling_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 1, 1, THEME.DWELLING,      TEXTURE.DATA_TEXTURES_FLOOR_CAVE_2)
end, "dwelling_door")

define_tile_code("jungle_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 2, 1, THEME.JUNGLE,        TEXTURE.DATA_TEXTURES_FLOOR_JUNGLE_1)
end, "jungle_door")

define_tile_code("volcana_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 2, 1, THEME.VOLCANA,       TEXTURE.DATA_TEXTURES_FLOOR_VOLCANO_2)
end, "volcana_door")

define_tile_code("olmec_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 3, 1, THEME.OLMEC,         TEXTURE.DATA_TEXTURES_DECO_JUNGLE_2)
end, "olmec_door")

define_tile_code("tidepool_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 4, 1, THEME.TIDE_POOL,     TEXTURE.DATA_TEXTURES_FLOOR_TIDEPOOL_3)
end, "tidepool_door")

define_tile_code("temple_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 4, 1, THEME.TEMPLE,        TEXTURE.DATA_TEXTURES_FLOOR_TEMPLE_1)
end, "temple_door")

define_tile_code("icecaves_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 5, 1, THEME.ICE_CAVES,     TEXTURE.DATA_TEXTURES_FLOOR_ICE_1)
end, "icecaves_door")

define_tile_code("neobab_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 6, 1, THEME.NEO_BABYLON,   TEXTURE.DATA_TEXTURES_FLOOR_BABYLON_1)
end, "neobab_door")

define_tile_code("tiamat_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 6, 4, THEME.TIAMAT,        TEXTURE.DATA_TEXTURES_FLOOR_BABYLON_1)
end, "tiamat_door")

define_tile_code("sunkencity_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 7, 1, THEME.SUNKEN_CITY,   TEXTURE.DATA_TEXTURES_FLOOR_SUNKEN_3)
end, "sunkencity_door")

define_tile_code("hundun_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 7, 4, THEME.HUNDUN,        TEXTURE.DATA_TEXTURES_FLOOR_SUNKEN_3)
end, "hundun_door")

define_tile_code("duat_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 4, 4, THEME.DUAT,        TEXTURE.DATA_TEXTURES_FLOOR_TEMPLE_1)
end, "duat_door")

define_tile_code("abzu_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_shortcut_door(x, y, 4, 4, THEME.ABZU,        TEXTURE.DATA_TEXTURES_FLOOR_TIDEPOOL_3)
end, "abzu_door")

define_tile_code("co_door")
set_pre_tile_code_callback(function(x, y, layer)
    spawn_door(x, y, LAYER.FRONT, 7, 5, THEME.COSMIC_OCEAN)
    spawn(ENT_TYPE.BG_SHOP_BACKDOOR, x, y, LAYER.FRONT, 0, 0)
end, "co_door")
