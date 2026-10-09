pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../services" as Services
import "../../services/WeatherLocation.js" as Places
import "../../theme"

ColumnLayout {
    id: root
    objectName: "weatherLocationPicker"
    property alias text: field.text
    property bool active: true
    property color accentColor: Color.primary
    property color textColor: Color.foreground
    property color mutedColor: Color.foregroundMuted
    property color surfaceColor: Color.surfaceContainerHigh
    property bool busy: false
    property bool suggestionsOpen: false
    property var results: []
    property string message: ""
    property int generation: 0
    signal locationSelected(var place)
    signal escapePressed()
    spacing: 6

    function begin(value) {
        field.text = value || ""
        root.search()
        Qt.callLater(() => { if (root.active) field.forceActiveFocus() })
    }
    function cancel() {
        ++root.generation
        debounce.stop()
        request.cancel()
        root.busy = false
        root.results = []
        root.message = ""
        root.suggestionsOpen = false
    }
    function search() {
        root.cancel()
        if (!root.active) return
        root.suggestionsOpen = true
        if (field.text.trim().length < 2) {
            root.message = field.text.trim() ? "Escribe al menos 2 letras" : "Busca una ciudad y elige su país"
            return
        }
        root.busy = true
        debounce.restart()
    }
    function choose(index) {
        const place = root.results[index]
        if (!place || root.busy) return
        field.text = place.label
        root.cancel()
        root.locationSelected(place)
    }
    function move(direction) {
        if (!root.results.length) return
        suggestions.currentIndex = (suggestions.currentIndex + direction + root.results.length) % root.results.length
        suggestions.positionViewAtIndex(suggestions.currentIndex, ListView.Contain)
    }
    onActiveChanged: { if (!active) root.cancel() }

    Controls.TextField {
        id: field
        Layout.fillWidth: true
        implicitHeight: 38
        placeholderText: "Ciudad o ciudad, país…"
        selectByMouse: true
        color: root.textColor
        placeholderTextColor: root.mutedColor
        font.pixelSize: Style.fontSmall
        leftPadding: 12
        rightPadding: 12
        background: Rectangle {
            color: root.surfaceColor
            radius: Style.controlRadius
            border.width: field.activeFocus ? 1 : 0
            border.color: root.accentColor
        }
        onTextEdited: root.search()
        onAccepted: root.choose(suggestions.currentIndex)
        Keys.onDownPressed: event => { root.move(1); event.accepted = true }
        Keys.onUpPressed: event => { root.move(-1); event.accepted = true }
        Keys.onEscapePressed: event => { root.cancel(); root.escapePressed(); event.accepted = true }
    }
    Text {
        visible: root.active && root.suggestionsOpen && (root.busy || root.message !== "")
        text: root.busy ? "Buscando ciudades…" : root.message
        color: root.mutedColor
        textFormat: Text.PlainText
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
    Rectangle {
        visible: root.active && root.suggestionsOpen && root.results.length > 0
        Layout.fillWidth: true
        implicitHeight: Math.min(root.results.length, 4) * 56 + 8
        color: root.surfaceColor
        radius: Style.controlRadius
        ListView {
            id: suggestions
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }
            delegate: Rectangle {
                id: suggestion
                required property var modelData
                required property int index
                width: suggestions.width
                height: 56
                radius: Style.controlRadius - 2
                color: suggestions.currentIndex === index ? Qt.alpha(root.accentColor, 0.16) : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10
                    MaterialIcon { text: "location_on"; iconSize: 18; iconColor: root.accentColor }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        Text {
                            text: suggestion.modelData.label
                            textFormat: Text.PlainText
                            font.pixelSize: Style.fontSmall
                            font.bold: true
                            color: root.textColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: suggestion.modelData.detail || "Ciudad · " + suggestion.modelData.countryCode
                            textFormat: Text.PlainText
                            font.pixelSize: 11
                            color: root.mutedColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    MaterialIcon { text: "chevron_right"; iconSize: 16; iconColor: root.mutedColor }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: suggestions.currentIndex = suggestion.index
                    onClicked: root.choose(suggestion.index)
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
    Timer {
        id: debounce
        interval: 300
        onTriggered: {
            const id = root.generation
            const query = field.text.trim()
            request.start(Places.searchUrl(query, 8), data => {
                if (!root.active || id !== root.generation || field.text.trim() !== query) return
                root.busy = false
                root.results = Places.results(data)
                suggestions.currentIndex = root.results.length ? 0 : -1
                root.message = !data || data.error ? "No se pudo buscar. Revisa la conexión o vuelve a escribir."
                    : root.results.length ? "" : "No se encontraron ciudades. Prueba otro nombre o añade el país."
            })
        }
    }
    Services.WeatherRequest { id: request }
}
