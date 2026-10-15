import Quickshell.Hyprland
import QtQuick

import "../../theme" as Theme

Text {
    id: root

    text: Hyprland.activeToplevel
        ? Hyprland.activeToplevel.title
        : ""

    color: Theme.Color.foreground

    elide: Text.ElideRight
}
