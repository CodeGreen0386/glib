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
---@type table<string, table>
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
    _inventory_action        = defines.events.on_gui_inventory_action,
    _leave                   = defines.events.on_gui_leave,
    _location_changed        = defines.events.on_gui_location_changed,
    _opened                  = defines.events.on_gui_opened,
    _selected_tab_changed    = defines.events.on_gui_selected_tab_changed,
    _selection_state_changed = defines.events.on_gui_selection_state_changed,
    _switch_state_changed    = defines.events.on_gui_switch_state_changed,
    _text_changed            = defines.events.on_gui_text_changed,
    _value_changed           = defines.events.on_gui_value_changed,
}

---@type table<defines.events, fun(event: GuiEventData)>
local events = {}
for _, event in pairs(gui_events) do
    events[event] = main_handler
end

---The events glib needs to subscribe to in order for event handling to function
glib.events = events

if config.register_events then
    if config.use_event_handler then
        local event_handler = require("event_handler")
        event_handler.add_lib{events = events --[[@as event_handler.events]]}
    else
        for _, id in pairs(gui_events) do
            script.on_event(id, main_handler)
        end
    end
end

local function error_def(def, message)
    error(message .. "\n" .. serpent.block(def, {maxlevel = 3, sortkeys = false}))
end

---@param style LuaStyle
---@param t table<string, StyleMods>
local function substyles(style, t)
    for style_name, style_mods in pairs(t) do
        local substyle = style.get_style(style_name, true)
        if substyle then
            for k, v in pairs(style_mods) do
                if k == "substyle" then
                    ---@cast v table<string, StyleMods>
                    substyles(substyle, v)
                else
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    substyle[k] = v
                end
            end
        else
            error("Style \"" .. style.name .. "\" does not contain sub-style \"" .. style_name .. "\"")
        end
    end
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

        local tags = args.tags
        if tags and tags[mod_name] then
            error_def(def, "Cannot use tag key " .. mod_name .. "as it is reserved for GUI Library.")
        end

        ---@type table<string, fun(event: GuiEventData)>?
        local handlers
        for k, v in pairs(def) do
            if gui_events[k] then
                handlers = handlers or {}
                handlers[tostring(gui_events[k])] = v --[[@as function]]
            end
        end
        if handlers then
            local handler_tags = {}
            for event, handler in pairs(handlers) do
                local handler_name = handler_names[handler]
                if not handler_name then
                    error_def(def, "Unregistered handler:\nPlease register it with glib.register_handlers() in the root scope of your script.")
                end
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

        if def.elem_mods then
            if def.elem_mods.tags then
                error_def(def, "Cannot set tags inside elem_mods. This would otherwise overwrite handlers.")
            end
            for k, v in pairs(def.elem_mods) do
                elem[k] = v
            end
        end

        if def.style_mods then
            for k, v in pairs(def.style_mods) do
                if k == "substyle" then
                    ---@cast v table<string, StyleMods>
                    substyles(elem.style --[[@as LuaStyle]], v)
                else
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    elem.style[k] = v
                end
            end
        end

        if def.drag_target then
            local target = refs[def.drag_target]
            if not target then
                error_def(def, "Drag target \"" .. def.drag_target .. "\" not present in refs table.")
            end
            elem.drag_target = type(target) == "userdata" and target or target.elem
        end

        local _elem = elem
        if def.class then
            _elem = setmetatable({elem = elem}, classes[def.class])
        end

        if args.name and def.ref ~= false then
            local ref = def.ref or args.name --[[@as string]]
            refs[ref] = _elem
        end

        local children = def.children
        if def[1] then
            if children then
                error_def(def, "Cannot have children in array and key value pair simultaneously.")
            end
            children = def --[[@as GuiElemDef[] ]]
        end
        if children then
            for _, child in ipairs(children) do
                add(elem, child, refs)
            end
        end

        if def.callback then
            def.callback(_elem)
        end

        return _elem, refs

    elseif def.tab and def.content then
        local tab = add(parent, def.tab, refs)
        local content = add(parent, def.content, refs)
        local _tab = type(tab) == "table" and tab.elem or tab
        local _content = type(content) == "table" and content.elem or content
        parent.add_tab(_tab, _content)

        return content, refs
    else
        error_def(def, "Invalid GUI element definition:\nMust contain either args or tab and content.")
    end
    ---@diagnostic disable-next-line: missing-return
end
glib.add = add

---Adds event handlers for glib to call when an element has one or more handlers specified.
---@param handlers table<string, function> The table of handlers for glib to call.
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

---@param element LuaGuiElement
---@param new_tags table<string, AnyBasic>
function glib.set_tags(element, new_tags)
    local tags = element.tags
    for k, v in pairs(new_tags) do
        tags[k] = v
    end
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
---@field callback? fun(element: LuaGuiElement) called immediately after element and children are created
---@field tab? GuiElemDef
---@field content? GuiElemDef
---@field _checked_state_changed? function
---@field _click? function
---@field _closed? function
---@field _confirmed? function
---@field _elem_changed? function
---@field _hover? function
---@field _inventory_action? function
---@field _leave? function
---@field _location_changed? function
---@field _opened? function
---@field _selected_tab_changed? function
---@field _selection_state_changed? function
---@field _switch_state_changed? function
---@field _text_changed? function
---@field _value_changed? function

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
---@field elem_tooltip? ElemID
---@field horizontal_scroll_policy? ScrollPolicy
---@field vertical_scroll_policy? ScrollPolicy
---@field items? LocalisedString[]
---@field selected_index? uint32
---@field number? double
---@field show_percent_for_small_numbers? boolean
---@field location? GuiLocation
---@field auto_center? boolean
---@field badge_text? LocalisedString
---@field auto_toggle? boolean
---@field toggled? boolean
---@field game_controller_interaction? defines.game_controller_interaction
---@field position? MapPosition
---@field surface_index? uint32
---@field zoom? double
---@field minimap_player_index? uint32
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
---@field drag_target? LuaGuiElement
---@field selected_tab_index? uint32
---@field entity? LuaEntity
---@field anchor? GuiAnchor
---@field tags? Tags
---@field raise_hover_events? boolean
---@field inventory? LuaInventory
---@field slots_per_row? uint8
---@field empty_slot_info? EmptySlotInfo
---@field handle_cursor_transfer? boolean
---@field handle_cursor_split? boolean
---@field handle_open_item? boolean
---@field handle_open_mod_item? boolean
---@field handle_send_stack_to_trash? boolean
---@field handle_send_stacks_to_trash? boolean
---@field switch_state? SwitchState
---@field allow_none_state? boolean
---@field left_label_caption? LocalisedString
---@field left_label_tooltip? LocalisedString
---@field right_label_caption? LocalisedString
---@field right_label_tooltip? LocalisedString

---@class StyleMods
---@field substyle? table<string, StyleMods>
---@field minimal_width? int32
---@field maximal_width? int32
---@field minimal_height? int32
---@field maximal_height? int32
---@field natural_width? int32
---@field natural_height? int32
---@field top_padding? int16
---@field right_padding? int16
---@field bottom_padding? int16
---@field left_padding? int16
---@field top_margin? int16
---@field right_margin? int16
---@field bottom_margin? int16
---@field left_margin? int16
---@field horizontal_align? "left"|"center"|"right"?
---@field vertical_align? "top"|"center"|"bottom"?
---@field font_color? Color
---@field font? string
---@field top_cell_padding? int16
---@field right_cell_padding? int16
---@field bottom_cell_padding? int16
---@field left_cell_padding? int16
---@field horizontally_stretchable? boolean
---@field vertically_stretchable? boolean
---@field horizontally_squashable? boolean
---@field vertically_squashable? boolean
---@field rich_text_setting? defines.rich_text_setting
---@field hovered_font_color? Color
---@field clicked_font_color? Color
---@field disabled_font_color? Color
---@field pie_progress_color? Color
---@field clicked_vertical_offset? uint32
---@field selected_font_color? Color
---@field selected_hovered_font_color? Color
---@field selected_clicked_font_color? Color
---@field strikethrough_color? Color
---@field draw_grayscale_picture? boolean
---@field horizontal_spacing? int32
---@field vertical_spacing? int32
---@field use_header_filler? boolean
---@field bar_width? uint32
---@field color? Color
---@field single_line? boolean
---@field extra_top_padding_when_activated? int32
---@field extra_bottom_padding_when_activated? int32
---@field extra_left_padding_when_activated? int32
---@field extra_right_padding_when_activated? int32
---@field extra_top_margin_when_activated? int32
---@field extra_bottom_margin_when_activated? int32
---@field extra_left_margin_when_activated? int32
---@field extra_right_margin_when_activated? int32
---@field extra_padding_when_activated? int32|int32[]
---@field extra_margin_when_activated? int32|int32[]
---@field stretch_image_to_widget_size? boolean
---@field badge_font? string
---@field badge_horizontal_spacing? int32
---@field default_badge_font_color? Color
---@field selected_badge_font_color? Color
---@field disabled_badge_font_color? Color
---@field width? int32
---@field height? int32
---@field size? int32|int32[]
---@field padding? int16|int16[]
---@field margin? int16|int16[]
---@field cell_padding? int16