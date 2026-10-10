pragma Singleton

import QtQml
import Quickshell

// Central motion tokens inspired by Ryoku's Motion service. Keeping the
// timings here makes every shared popup feel like part of the same shell and
// gives us a safe reduced-motion/speed override without changing each view.
QtObject {
    readonly property bool reduceMotion:
        Quickshell.env("TARTARUS_REDUCE_MOTION") === "1"

    readonly property real speed: {
        const requested = Number(Quickshell.env("TARTARUS_MOTION_SPEED"))
        if (!Number.isFinite(requested) || requested <= 0)
            return 1.0
        return Math.min(2.0, Math.max(0.25, requested))
    }

    function dur(milliseconds) {
        return reduceMotion ? 0 : Math.round(milliseconds * speed)
    }

    readonly property int fast: dur(80)
    readonly property int normal: dur(120)
    readonly property int popupOpen: dur(190)
    readonly property int popupClose: dur(135)
    readonly property int popupResize: dur(160)
    readonly property int panel: dur(210)
    readonly property int morph: dur(240)

    // Cubic curves are shared as arrays because QML's BezierSpline expects
    // the four control points plus the final endpoint.
    readonly property var popupOpenCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
    readonly property var popupCloseCurve: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1.0, 1.0, 1.0]
    readonly property var effectCurve: [0.34, 0.8, 0.34, 1.0, 1.0, 1.0]
}
