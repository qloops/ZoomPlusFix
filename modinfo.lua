name = "Zoom+ (Fix)"
description = [[Expands the limits for zooming in and out.
Settings are available in the mod menu, with additional options in-game.

Controls:
* Middle Mouse — Quick zoom reset
* Scroll — Zoom in/out
* Ctrl+Z — Configure camera and keys]]
author = "Karasik"
version = "1.8.0.dev"
api_version = 10
forumthread = "" -- only steam

icon_atlas = "modicon.xml"
icon = "modicon.tex"

dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false
hamlet_compatible = false
dst_compatible = true

priority = 0

all_clients_require_mod = false
client_only_mod = true

configuration_options =
{
    {
        name = "clouds_enabled",
        label = "Display Clouds",
        hover = "Display clouds when the camera is zoomed out", 
        options = {
            {description = "Off", data = false},
            {description = "On", data = true},
        },
        default = false,
    },
    {
        name = "zoom_sensitivity",
        label = "Zoom Sensitivity",
        hover = "Adjusts how much the camera moves with each mouse wheel click",
        options = {
            {description = "1", data = 1},
            {description = "2", data = 2},
            {description = "3", data = 3},
            {description = "4 (Recommended)", data = 4},
            {description = "5", data = 5},
            {description = "6", data = 6},
            {description = "7", data = 7},
            {description = "8", data = 8},
            {description = "9", data = 9},
            {description = "10", data = 10},
        },
        default = 4,
    },
}