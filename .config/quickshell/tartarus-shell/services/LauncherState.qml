import QtQml

QtObject {
    id: root

    property bool opened: false
    property string query: ""
    property var anchorItem: null
    property var barWindow: null

    signal moveUpRequested()
    signal moveDownRequested()
    signal acceptRequested()
    signal escapeRequested()
    signal focusRequested()

    function open() {
        root.opened = true

        Qt.callLater(() => {
            root.focusRequested()
        })
    }

    function close() {
        root.opened = false
        root.query = ""
    }

    function toggle() {
        if (root.opened)
            root.close()
        else
            root.open()
    }

    function focusSearch() {
        root.focusRequested()
    }
}
