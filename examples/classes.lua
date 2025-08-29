local glib = require("__glib__/glib")
local default_frame = require("__glib__/examples/default_frame")
local handlers = {}

script.on_init(function()
    storage.refs = {}
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local root, refs = glib.add(player.gui.screen, default_frame("glib_example", "Glib Example"))
    root.force_auto_center()

    glib.add(root, {
        args = {type = "flow"},
        children = {{
            args = {type = "button", name = "counter", caption = 0},
            class = "counter",
            _click = handlers.counter_click,
        }}
    }, refs)

    storage.refs[event.player_index] = refs
end)

---@class Counter:LuaGuiElement
local counter = {}

function counter:up()
    self.elem.caption = tonumber(self.elem.caption) + 1
end

function counter:down()
    self.elem.caption = tonumber(self.elem.caption) - 1
end

glib.register_class("counter", counter)

---@param event EventData.on_gui_click
function handlers.counter_click(event)
    if event.button == defines.mouse_button_type.left then
        storage.refs[event.player_index].counter:up()
    elseif event.button == defines.mouse_button_type.right then
        storage.refs[event.player_index].counter:down()
    end
end

glib.register_handlers(handlers)