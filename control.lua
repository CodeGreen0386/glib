local gui = require("gui")

do return end

local function close_button(event)
    local player = game.get_player(event.player_index)
    player.opened = nil
end

local function window_closed(event)
    event.element.destroy()
end

local handlers = {
    close_button = close_button,
    window_closed = window_closed,
}

gui.add_handlers(handlers)

script.on_init(function()
    global.guis = {}
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index) ---@cast player LuaPlayer
    local def = {
        args = {type = "frame", name = "glib_demo_frame", direction = "vertical", tags = {a = 1}},
        handlers = {on_gui_closed = handlers.window_closed},
        children = {{
            args = {type = "flow", name = "titlebar_flow"},
            drag_target = "glib_demo_frame",
            {
                args = {type = "label", style = "frame_title", caption = "Glib GUI Demo", ignored_by_interaction = true},
            },{
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {height = 24, right_margin = 4, horizontally_stretchable = true},
            },{
                args = {
                    type = "sprite-button", style = "frame_action_button",
                    sprite = "utility/close_white",
                    hovered_sprite = "utility/close_black",
                    clicked_sprite = "utility/close_black",
                },
                handlers = handlers.close_button,
            }
        },{
            args = {type = "tabbed-pane"},
            {
                tab = {args = {type = "tab", caption = "burg"}},
                content = {
                    args = {type = "frame", style = "inside_shallow_frame_with_padding"},
                    style_mods = {width = 400, height = 200},
                }
            }
        }}
    }

    local def_copy = table.deepcopy(def)

    local refs, demo_frame = gui.add(player.gui.screen, def) --- @cast demo_frame LuaGuiElement

    if not table.compare(def, def_copy) then
        error("def table has been modified")
    end

    demo_frame.force_auto_center()
    player.opened = demo_frame

    global.guis[event.player_index] = {
        player = player,
        refs = refs,
    }
end)