local glib = require("__glib__/glib")

local handlers = {}

---@return GuiElemDef
local function thumbnail()
    return {
        args = {type = "frame", name = "glib_thumbnail", direction = "vertical"},
        style_mods = {size = 144},
        children = {{
            args = {type = "flow"},
            drag_target = "glib_thumbnail",
            style_mods = {horizontal_spacing = 8},
            children = {{
                args = {type = "label", caption = "Glib", style = "frame_title", ignored_by_interaction = true},
                style_mods = {top_margin = -3, bottom_margin = 3},
            }, {
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {height = 24, right_margin = 4, horizontally_stretchable = true},
            }, {
                args = {type = "sprite-button", style = "close_button", sprite = "utility/close"},
                _click = handlers.thumbnail_close,
            }}
        }, {
            args = {type = "frame", style = "inside_shallow_frame"},
            style_mods = {horizontal_align = "center", vertical_align = "center", width = 120, height = 92},
            children = {{
                args = {type = "label", name = "code", caption = "{     }"},
                -- the font prototype was edited to increase the size
                -- the book in the thumbnail was edited in post
            }}
        }}
    }
end

function handlers.thumbnail_close(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    player.gui.screen.glib_thumbnail.destroy()
end

glib.register_handlers(handlers)

commands.add_command("glib_thumbnail", nil, function(command)
    local player = game.get_player(command.player_index) --[[@as LuaPlayer]]
    local root = player.gui.screen.glib_thumbnail
    if root then root.destroy() end
    local _, refs = glib.add(player.gui.screen, thumbnail())
    refs.code.style.font = "default-large"
    refs.code.style.font_color = {r=1, g=1, b=1}
end)