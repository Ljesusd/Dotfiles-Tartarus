import QtQml

QtObject {
    id: root

    property string query: ""

    signal moveUpRequested()
    signal moveDownRequested()
    signal acceptRequested()
    signal escapeRequested()
    signal focusRequested()

    function focusSearch() {
        root.focusRequested()
    }
}
