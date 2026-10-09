pragma Singleton

import QtQml

QtObject {
    readonly property int spacingXs: 4
    readonly property int spacingSm: 6
    readonly property int spacingMd: 8
    readonly property int spacingLg: 12

    readonly property int radiusSmall: 6
    readonly property int radiusMedium: 10
    readonly property int radiusLarge: 16
    readonly property int radiusFull: 999

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

    readonly property string materialIconFont:
        "Material Symbols Rounded"

    readonly property int iconSmall: 16
    readonly property int iconMedium: 22
    readonly property int iconLarge: 32

    readonly property int materialIconSmall: 15
    readonly property int materialIconMedium: 18
    readonly property int materialIconLarge: 24
    readonly property int materialIconExtraLarge: 36

    // Shared visual rhythm inspired by the rounded reference shells. Keep
    // these separate from the bar metrics so panels, menus and launcher pages
    // use the same compact language.
    readonly property int panelRadius: 22
    readonly property int cardRadius: 16
    readonly property int cardPadding: 14
    readonly property int controlRadius: 13
    readonly property int iconButtonSize: 36
    readonly property int iconButtonIconSize: 18
    readonly property int sectionIconSize: 18

    readonly property int controlHeight: 48
    readonly property int itemHeight: 54

    readonly property int barHeight: 50
    readonly property int barInnerHeight: 28
    readonly property int barControlHeight: 34
    readonly property int barControlRadius: 17
    readonly property int barSurfaceRadius: 18
    // Debe dejar aire dentro de la barra flotante (44 px útiles).
    readonly property int barSearchHeight: 36
    readonly property int barFloatingMargin: 4
    readonly property int barContentHorizontalPadding: 12
    readonly property int panelBorderWidth: 1

    readonly property int barIconSmall: 18
    readonly property int barIconNormal: 20
    readonly property int barIconLarge: 22

    readonly property int barFontSmall: 14
    readonly property int barFontNormal: 16

    readonly property int barPaddingSmall: 8
    readonly property int barPaddingNormal: 12

    readonly property int barSpacingSmall: 6
    readonly property int barSpacingNormal: 10
    readonly property int barHoverBorderWidth: 1

    readonly property int barWorkspaceIconSize: 16
    readonly property int barWorkspaceBaseSize:
        barInnerHeight - spacingMd
    readonly property int barWorkspaceActiveHeight:
        barInnerHeight - spacingMd
    readonly property int barWorkspaceRailPaddingHorizontal: 7
    readonly property int barWorkspaceSpacing: spacingXs
    readonly property int barWorkspaceContentSpacing: 3
    readonly property int barWorkspaceActivePaddingHorizontal: 5

    readonly property int barWorkspaceTrailBaseDuration: 100
    readonly property int barWorkspaceTrailMaxDuration: 180
    readonly property real barWorkspaceTrailDistanceFactor: 0.30
    readonly property int barWorkspaceTrailLag: 130

    readonly property real barWorkspaceBackgroundScale: 0.88
    readonly property real barWorkspaceBackgroundOpacity: 0.35
    readonly property real barWorkspaceSpecialDimOpacity: 0.28
    readonly property real barWorkspaceSpecialEnterScale: 0.78
    readonly property real barWorkspaceSpecialBlur: 0.55
    readonly property int barWorkspaceSpecialBlurMax: 8

    readonly property int barPopupGap: 6

    readonly property int launcherSearchWidth: 380
    readonly property int launcherSearchHeight: barSearchHeight
    readonly property int launcherWidth: 600
    readonly property int launcherHeight: 400
    readonly property int launcherWallpaperHeight: 330
    readonly property int launcherSchemeItemHeight:
        itemHeight + paddingLarge
    readonly property int launcherSchemeBadgeHeight: 22
    readonly property int launcherSchemePreviewWidth: 20
    readonly property int launcherSchemePreviewHeight: 8
    readonly property int launcherSchemePreviewRadius: 4

    // Interaction timings; telemetry smoothing and timers stay independent.
    readonly property int animationFast: motionFast
    readonly property int animationNormal: motionNormal
    readonly property int animationSlow: motionSlow

    readonly property int motionFast: 80
    readonly property int motionNormal: 100
    readonly property int motionSlow: 140
    readonly property int motionPopup: 100
    readonly property int motionPanel: 140
    readonly property int trayHoverDelay: 140
    readonly property int launcherMotionFast: 60
    readonly property int launcherMotionPanel: 80
    readonly property real hoverOpacity: 0.08
    readonly property real selectedOpacity: 0.16
}
