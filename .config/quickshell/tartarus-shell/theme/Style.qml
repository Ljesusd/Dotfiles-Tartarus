pragma Singleton

import QtQml

QtObject {
    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 10
    readonly property int radiusLarge: 16

    readonly property int spacingSmall: 6
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16

    readonly property int paddingSmall: 8
    readonly property int paddingMedium: 12
    readonly property int paddingLarge: 16
    readonly property int paddingXLarge: 30

    readonly property int fontSmall: 13
    readonly property int fontNormal: 18
    readonly property int fontLarge: 24

    readonly property string iconFont: "JetBrainsMono Nerd Font"

    readonly property int iconSmall: 16
    readonly property int iconMedium: 22
    readonly property int iconLarge: 32

    readonly property int controlHeight: 50
    readonly property int itemHeight: 56

    readonly property int barHeight: 56
    readonly property int barControlHeight: 38

    readonly property int barIconSmall: 18
    readonly property int barIconNormal: 20
    readonly property int barIconLarge: 22

    readonly property int barFontSmall: 14
    readonly property int barFontNormal: 16

    readonly property int barPaddingSmall: 8
    readonly property int barPaddingNormal: 12

    readonly property int barSpacingSmall: 6
    readonly property int barSpacingNormal: 10

    readonly property int barWorkspaceSize: 12
    readonly property int barWorkspaceGap: 8

    readonly property int barPopupGap: 6

    readonly property int launcherSearchWidth: 380
    readonly property int launcherSearchHeight: 42
    readonly property int launcherWidth: 600
    readonly property int launcherHeight: 400

    readonly property int animationFast: 100
    readonly property int animationNormal: 180
    readonly property int animationSlow: 300
}
