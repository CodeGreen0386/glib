local glib = require("__glib__/glib")

local handlers = {}

---@param name string
---@param caption LocalisedString
---@param events? {frame: GuiEventHandler?, button: GuiEventHandler?}
local function default_frame(name, caption, events)
    return {
        args = {type = "frame", name = name, direction = "vertical"},
        _closed = events and events.frame or handlers.default_close,
        children = {{
            args = {type = "flow"},
            style_mods = {horizontal_spacing = 8},
            drag_target = name,
            children = {{
                args = {type = "label", caption = caption, style = "frame_title", ignored_by_interaction = true},
                style_mods = {top_margin = -3, bottom_margin = 3},
            }, {
                args = {type = "empty-widget", style = "draggable_space_header", ignored_by_interaction = true},
                style_mods = {height = 24, right_margin = 4, horizontally_stretchable = true},
            }, {
                args = {type = "sprite-button", style = "close_button", sprite = "utility/close"},
                _click = events and events.button or handlers.default_close_button,
            }}
        }}
    }
end

function handlers.default_close(event)
    event.element.destroy()
end

function handlers.default_close_button(event)
    event.element.parent.parent.destroy()
end

glib.add_handlers(handlers)

return default_frame