local styles = data.raw["gui-styles"].default
local button = styles.button

local lib = {}

--- Takes a button style name and creates a
---@param name string
function lib.selected(name)
    local new_name = name.."_selected"
    if styles[new_name] then return end
    styles[new_name] = {
        type = "button_style",
        parent = name,
        default_font_color    = button.selected_font_color,
        default_graphical_set = button.selected_graphical_set,
        hovered_font_color    = button.selected_hovered_font_color,
        hovered_graphical_set = button.selected_hovered_graphical_set,
        clicked_font_color    = button.selected_clicked_font_color,
        clicked_graphical_set = button.selected_clicked_graphical_set,
    }
end

return lib