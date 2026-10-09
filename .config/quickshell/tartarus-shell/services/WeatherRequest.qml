import QtQuick

QtObject {
    id: root
    property var request: null
    property var callback: null
    readonly property bool running: root.callback !== null
    function cancel() {
        const old = root.request
        root.callback = null
        root.request = null
        deadline.stop()
        if (old) old.abort()
    }
    function finish(data) {
        const done = root.callback
        root.callback = null
        root.request = null
        deadline.stop()
        if (done) done(data)
    }
    function start(url, done) {
        root.cancel()
        const xhr = new XMLHttpRequest()
        root.request = xhr
        root.callback = done
        xhr.onreadystatechange = () => {
            if (root.request !== xhr || xhr.readyState !== XMLHttpRequest.DONE) return
            let data = null
            if (xhr.status === 200) {
                try { data = JSON.parse(xhr.responseText) } catch (error) { }
            }
            root.finish(data)
        }
        xhr.open("GET", url)
        deadline.restart()
        xhr.send()
    }
    property Timer timeoutTimer: Timer {
        id: deadline
        interval: 12000
        onTriggered: {
            const old = root.request
            root.request = null
            if (old) old.abort()
            root.finish(null)
        }
    }
    Component.onDestruction: root.cancel()
}
