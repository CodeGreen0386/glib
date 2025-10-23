---@class Glib
local glib = {}
local mod_name = "__" .. script.mod_name .. "__/handlers"

---@class Glib.Config
---@field register_events? boolean defaults to true
---@field use_event_handler? boolean defaults to false

---@type Glib.Config
local config = GLIB_CONFIG or {} ---@diagnostic disable-line: undefined-global
if config.register_events == nil then config.register_events = true end
if config.use_event_handler == nil then config.use_event_handler = false end

---@type table<string, function>
local handler_funcs = {}
---@type table<function, string>
local handler_names = {}
local classes = {}

---@param event GuiEventData
local function main_handler(event)
    local element = event.element
    if not element then return end
    local tags = element.tags
    local handlers = tags[mod_name]
    if not handlers then return end
    local handler_name = handlers[tostring(event.name)]
    if not handler_name then return end
    local handler = handler_funcs[handler_name]
    if not handler then return end
    handler(event)
end

--- Returns the event handler Glib uses for all gui events, if one was overwritten or if auto registering for events was disabled.
---@return fun(event: GuiEventData)
function glib.get_main_handler()
    return main_handler
end

local gui_events = {
    _checked_state_changed   = defines.events.on_gui_checked_state_changed,
    _click                   = defines.events.on_gui_click,
    _closed                  = defines.events.on_gui_closed,
    _confirmed               = defines.events.on_gui_confirmed,
    _elem_changed            = defines.events.on_gui_elem_changed,
    _hover                   = defines.events.on_gui_hover,
    _leave                   = defines.events.on_gui_leave,
    _location_changed        = defines.events.on_gui_location_changed,
    _opened                  = defines.events.on_gui_opened,
    _selected_tab_changed    = defines.events.on_gui_selected_tab_changed,
    _selection_state_changed = defines.events.on_gui_selection_state_changed,
    _switch_state_changed    = defines.events.on_gui_switch_state_changed,
    _text_changed            = defines.events.on_gui_text_changed,
    _value_changed           = defines.events.on_gui_value_changed,
}

---@type table<defines.events, GuiEventHandler>
local events = {}
for _, event in pairs(gui_events) do
    events[event] = main_handler
end

---The events glib needs to subscribe to in order for event handling to function
glib.events = events

if config.register_events then
    if config.use_event_handler then
        local event_handler = require("event_handler")
        event_handler.add_lib{events = events}
    else
        for _, id in pairs(gui_events) do
            script.on_event(id, main_handler)
        end
    end
end

local function error_def(def, s)
    return s .. "\n" .. serpent.block(def, {maxlevel = 3, sortkeys = false})
end

--- Adds one or more GUI elements to a parent GUI element.
---@param parent LuaGuiElement The parent element to add new elements to.
---@param def GuiElemDef The element definition to add to the parent.
---@param refs? table<string, LuaGuiElement> The table to add new element references to.
---@return LuaGuiElement elem The topmost element added to the parent.
---@return table<string, LuaGuiElement> refs The table of element references, indexed by element name.
local function add(parent, def, refs)
    refs = refs or {}
    local elem
    if def.args then
        local args = def.args
        local children = def.children
        if def[1] then
            assert(not children, error_def(def, "Cannot have children in array and key value pair simultaneously."))
            children = def
        end

        local tags = args.tags
        assert(not (tags and tags[mod_name]), error_def("Cannot use tag key " .. mod_name .. "as it is reserved for GUI Library."))

        ---@type table<string, GuiEventHandler>?
        local handlers
        for k, v in pairs(def) do
            if gui_events[k] then
                handlers = handlers or {}
                handlers[tostring(gui_events[k])] = v
            end
        end
        if handlers then
            local handler_tags = {}
            for event, handler in pairs(handlers) do
                local handler_name = handler_names[handler]
                assert(handler_name, error_def(def, "Unregistered handler:\nPlease register it with glib.add_handlers() in the root scope of your script."))
                handler_tags[event] = handler_name -- maybe tostring event
            end
            args.tags = tags or {}
            args.tags[mod_name] = handler_tags
        end

        elem = parent.add(args) --[[@as LuaGuiElement]]

        if tags then
            args.tags[mod_name] = nil
        else
            args.tags = nil
        end

        local _elem = elem
        if def.class then
            _elem = setmetatable({elem = elem}, classes[def.class])
        end

        if args.name and def.ref ~= false then
            local ref = def.ref or args.name --[[@as string]]
            refs[ref] = _elem
        end

        if def.elem_mods then
            for k, v in pairs(def.elem_mods) do
                assert(k ~= "tags", error_def(def, "Cannot set tags inside elem_mods. This would otherwise overwrite handlers."))
                elem[k] = v
            end
        end

        if def.style_mods then
            for k, v in pairs(def.style_mods) do
                elem.style[k] = v
            end
        end

        if def.drag_target then
            local target = refs[def.drag_target]
            assert(target, error_def(def, "Drag target \"" .. def.drag_target .. "\" not present in refs table."))
            elem.drag_target = type(target) == "userdata" and target or target.elem
        end

        if children then
            for _, child in ipairs(children) do
                add(elem, child, refs)
            end
        end

        elem = _elem

    elseif def.tab and def.content then
        refs = refs or {}
        local tab = add(parent, def.tab, refs) ---@cast tab LuaGuiElement
        local content = add(parent, def.content, refs) ---@cast content LuaGuiElement
        if type(tab) == "table" then tab = tab.elem end
        if type(content) == "table" then content = content.elem end
        parent.add_tab(tab, content)
    else
        error(error_def(def, "Invalid GUI element definition:\nMust contain either args or tab and content."))
    end
    return elem, refs
end
glib.add = add

---Adds event handlers for glib to call when an element has one or more handlers specified.
---@param handlers table<string, fun(event: GuiEventData)> The table of handlers for glib to call.
---@param wrapper? fun(event:GuiEventData, handler:function) (Optional) The wrapper function to call instead of the event handler directly.
---@param namespace? string (Optional) The namespace for the handler, so multiple handlers from the same mod can share names and not overwrite each other.
function glib.register_handlers(handlers, wrapper, namespace)
    namespace = namespace and namespace .. "."
    for name, handler in pairs(handlers) do
        if namespace then
            name = namespace .. name
        end
        if handler_funcs[name] then
            error(string.format("Attempt to register handler function with duplicate name \"%s\".", name))
        end
        if handler_names[handler] then
            error(string.format("Attempt to register duplicate handler function \"%s\" over \"%s\".", name, handler_names[handler]))
        end
        handler_names[handler] = name
        if wrapper then
            handler_funcs[name] = function(event) wrapper(event, handler) end
        else
            handler_funcs[name] = handler
        end
    end
end

---@class GuiClass : LuaGuiElement
---@field class string
---@field methods table<string, function>

---@param name string
---@param methods table<string, function>
function glib.register_class(name, methods)
    local metatable = {__index = function(table, index) return methods[index] or table.elem[index] end}
    classes[name] = metatable
    script.register_metatable(name, metatable)
end

---@param element LuaGuiElement
---@param k string
---@param v AnyBasic
function glib.set_tag(element, k, v)
    local tags = element.tags
    tags[k] = v
    element.tags = tags
end

return glib

---@class GuiElemDef
---@field args LuaGuiElement.add_param
---@field class? string
---@field ref? string|false
---@field drag_target? string
---@field elem_mods? ElemMods
---@field style_mods? StyleMods
---@field children? GuiElemDef[]
---@field tab? GuiElemDef
---@field content? GuiElemDef
---@field _checked_state_changed? GuiEventHandler|EventData.on_gui_checked_state_changed
---@field _click? GuiEventHandler|EventData.on_gui_click
---@field _closed? GuiEventHandler|EventData.on_gui_closed
---@field _confirmed? GuiEventHandler|EventData.on_gui_confirmed
---@field _elem_changed? GuiEventHandler|EventData.on_gui_elem_changed
---@field _hover? GuiEventHandler|EventData.on_gui_hover
---@field _leave? GuiEventHandler|EventData.on_gui_leave
---@field _location_changed? GuiEventHandler|EventData.on_gui_location_changed
---@field _opened? GuiEventHandler|EventData.on_gui_opened
---@field _selected_tab_changed? GuiEventHandler|EventData.on_gui_selected_tab_changed
---@field _selection_state_changed? GuiEventHandler|EventData.on_gui_selection_state_changed
---@field _switch_state_changed? GuiEventHandler|EventData.on_gui_switch_state_changed
---@field _text_changed? GuiEventHandler|EventData.on_gui_text_changed
---@field _value_changed? GuiEventHandler|EventData.on_gui_value_changed

---@alias GuiEventHandler fun(e:GuiEventData)|table<string|defines.events, fun(event:GuiEventData)>
---@alias GuiEventData
---|EventData.on_gui_checked_state_changed
---|EventData.on_gui_click
---|EventData.on_gui_closed
---|EventData.on_gui_confirmed
---|EventData.on_gui_elem_changed
---|EventData.on_gui_hover
---|EventData.on_gui_leave
---|EventData.on_gui_location_changed
---|EventData.on_gui_opened
---|EventData.on_gui_selected_tab_changed
---|EventData.on_gui_selection_state_changed
---|EventData.on_gui_switch_state_changed
---|EventData.on_gui_text_changed
---|EventData.on_gui_value_changed

---@class ElemMods
---@field name? string
---@field caption? LocalisedString
---@field value? double
---@field style? string
---@field visible? boolean
---@field text? string
---@field state? boolean
---@field sprite? SpritePath
---@field resize_to_sprite? boolean
---@field hovered_sprite? SpritePath
---@field clicked_sprite? SpritePath
---@field tooltip? LocalisedString
---@field horizontal_scroll_policy? string
---@field vertical_scroll_policy? string
---@field items? LocalisedString[]
---@field selected_index? uint
---@field number? double
---@field show_percent_for_small_numbers? boolean
---@field location? GuiLocation
---@field auto_center? boolean
---@field badge_text? LocalisedString
---@field auto_toggle? boolean
---@field toggled? boolean
---@field game_controller_interaction? defines.game_controller_interaction
---@field position? MapPosition
---@field surface_index? uint
---@field zoom? double
---@field minimap_player_index? uint
---@field force? string
---@field elem_value? string|SignalID|PrototypeWithQuality
---@field elem_filters? PrototypeFilter
---@field selectable? boolean
---@field word_wrap? boolean
---@field read_only? boolean
---@field enabled? boolean
---@field ignored_by_interaction? boolean
---@field locked? boolean
---@field draw_vertical_lines? boolean
---@field draw_horizontal_lines? boolean
---@field draw_horizontal_line_after_headers? boolean
---@field vertical_centering? boolean
---@field slider_value? double
---@field mouse_button_filter? MouseButtonFlags
---@field numeric? boolean
---@field allow_decimal? boolean
---@field allow_negative? boolean
---@field is_password? boolean
---@field lose_focus_on_confirm? boolean
---@field clear_and_focus_on_right_click? boolean
---@field drag_target? LuaGuiElement
---@field selected_tab_index? uint
---@field entity? LuaEntity
---@field anchor? GuiAnchor
---@field tags? Tags
---@field raise_hover_events? boolean
---@field switch_state? string
---@field allow_none_state? boolean
---@field left_label_caption? LocalisedString
---@field left_label_tooltip? LocalisedString
---@field right_label_caption? LocalisedString
---@field right_label_tooltip? LocalisedString

---@class StyleMods
---@field minimal_width? int
---@field maximal_width? int
---@field minimal_height? int
---@field maximal_height? int
---@field natural_width? int
---@field natural_height? int
---@field top_padding? int
---@field right_padding? int
---@field bottom_padding? int
---@field left_padding? int
---@field top_margin? int
---@field right_margin? int
---@field bottom_margin? int
---@field left_margin? int
---@field horizontal_align? "left"|"center"|"right"?
---@field vertical_align? "top"|"center"|"bottom"?
---@field font_color? Color
---@field font? string
---@field top_cell_padding? int
---@field right_cell_padding? int
---@field bottom_cell_padding? int
---@field left_cell_padding? int
---@field horizontally_stretchable? boolean
---@field vertically_stretchable? boolean
---@field horizontally_squashable? boolean
---@field vertically_squashable? boolean
---@field rich_text_setting? defines.rich_text_setting
---@field hovered_font_color? Color
---@field clicked_font_color? Color
---@field disabled_font_color? Color
---@field pie_progress_color? Color
---@field clicked_vertical_offset? int
---@field selected_font_color? Color
---@field selected_hovered_font_color? Color
---@field selected_clicked_font_color? Color
---@field strikethrough_color? Color
---@field draw_grayscale_picture? boolean
---@field horizontal_spacing? int
---@field vertical_spacing? int
---@field use_header_filler? boolean
---@field bar_width? uint
---@field color? Color
---@field single_line? boolean
---@field extra_top_padding_when_activated? int
---@field extra_bottom_padding_when_activated? int
---@field extra_left_padding_when_activated? int
---@field extra_right_padding_when_activated? int
---@field extra_top_margin_when_activated? int
---@field extra_bottom_margin_when_activated? int
---@field extra_left_margin_when_activated? int
---@field extra_right_margin_when_activated? int
---@field extra_padding_when_activated? int|int[]
---@field extra_margin_when_activated? int|int[]
---@field stretch_image_to_widget_size? boolean
---@field badge_font? string
---@field badge_horizontal_spacing? int
---@field default_badge_font_color? Color
---@field selected_badge_font_color? Color
---@field disabled_badge_font_color? Color
---@field width? int
---@field height? int
---@field size? int|int[]
---@field padding? int|int[]
---@field margin? int|int[]
---@field cell_padding? int