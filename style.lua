local styles = data.raw["gui-style"].default
local button = styles.button

local lib = {}

--- Creates a selected variant of a button style.
--- @param name string The parent style to copy for the new style.
function lib.generate_selected(name)
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