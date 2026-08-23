import Quickshell.Hyprland
import QtQuick

import "../../theme"

Text {
    id: root

    text: Hyprland.activeToplevel
        ? Hyprland.activeToplevel.title
        : ""

    color: Color.foreground

    elide: Text.ElideRight
}
