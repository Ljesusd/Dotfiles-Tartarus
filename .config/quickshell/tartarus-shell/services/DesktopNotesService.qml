pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string text: ""
    property bool loaded: false
    readonly property FileView file: FileView {
        path: Quickshell.stateDir + "/desktop-notes.txt"
        blockLoading: true
        printErrors: false
    }
    property Timer writer: Timer {
        interval: 350
        repeat: false
        onTriggered: root.file.setText(root.text)
    }

    function save(value) {
        root.text = String(value || "")
        if (root.loaded)
            root.writer.restart()
    }

    Component.onCompleted: {
        root.text = root.file.text()
        root.loaded = true
    }
}
