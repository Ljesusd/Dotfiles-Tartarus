pragma Singleton
import QtQml
import "."

QtObject {
    id: root
    property bool open: false
    property int revision: 0
    property string pendingPower: ""
    function toggle() { root.open = !root.open; root.revision++ }
    function close() { root.open = false; root.revision++ }
    function requestPower(action) { root.pendingPower = action; root.revision++ }
    function cancelPower() { root.pendingPower = ""; root.revision++ }
    function confirmPower() {
        if (root.pendingPower !== "")
            powerService[root.pendingPower]()
        root.pendingPower = ""
    }
    readonly property var powerService: PowerService
}
