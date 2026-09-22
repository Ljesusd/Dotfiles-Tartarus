import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as Controls
import "../../services" as Services
import "../../theme"

Item {
    id: root
    required property var controller
    required property string consumerKey
    required property bool active
    property var service: Services.DockerService
    property var pending: null
    property bool viewingLogs: false
    readonly property var items: root.service.filtered(root.controller.dockerQuery)
    readonly property var groups: root.service.grouped(root.controller.dockerQuery)
    visible: active

    function acceptSelection() {
        if (root.pending || root.viewingLogs || root.service.busy) return
        const group = root.groups[root.controller.selectedIndex]
        if (group && group.containers.length) root.showLogs(group.containers[0].id)
    }
    function showLogs(id) {
        if (root.service.busy) return
        root.service.readLogs(id)
        root.viewingLogs = true
    }
    function back() {
        if (root.pending) { root.pending = null; return true }
        if (root.viewingLogs) { root.viewingLogs = false; return true }
        return false
    }
    function requestAction(verb, label, container) {
        root.pending = {verb: verb, label: label, id: container.id, name: container.name}
    }
    onActiveChanged: {
        root.service.setConsumer(root.consumerKey, root.active)
        if (!root.active) { root.pending = null; root.viewingLogs = false }
    }
    Component.onCompleted: root.service.setConsumer(root.consumerKey, root.active)
    Component.onDestruction: root.service.setConsumer(root.consumerKey, false)
    onGroupsChanged: root.controller.select(root.controller.selectedIndex)
    Connections {
        target: root.controller
        function onSelectedIndexChanged() {
            if (root.active && containerList.currentIndex >= 0)
                containerList.positionViewAtIndex(containerList.currentIndex, ListView.Contain)
        }
        function onDockerQueryChanged() { root.pending = null; root.viewingLogs = false }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall
        RowLayout {
            Layout.fillWidth: true
            MaterialIcon { text: "deployed_code"; iconColor: Color.primary; iconSize: 24 }
            Label {
                Layout.fillWidth: true
                text: root.viewingLogs ? "Docker · Logs" : "Docker · Contenedores"
                font.pixelSize: Style.fontNormal
                font.bold: true
            }
            ActionButton {
                text: root.service.busy ? "Consultando…" : "Actualizar"
                enabled: !root.service.busy
                onClicked: root.viewingLogs ? root.service.readLogs(root.service.logId) : root.service.refresh()
            }
        }
        RowLayout {
            visible: !root.viewingLogs
            Layout.fillWidth: true
            Repeater {
                model: [{label: "Todos", query: ""}, {label: "Activos", query: "activos"}, {label: "Detenidos", query: "detenidos"}]
                delegate: ActionButton {
                    required property var modelData
                    text: modelData.label
                    emphasized: root.controller.dockerQuery === modelData.query
                    onClicked: root.controller.launcherState.query = ">docker " + modelData.query
                }
            }
            Label {
                Layout.fillWidth: true
                text: root.items.length + " contenedores"
                color: Color.foregroundMuted
                horizontalAlignment: Text.AlignRight
            }
        }
        Label {
            Layout.fillWidth: true
            visible: !root.viewingLogs && text !== ""
            text: root.service.error || root.service.warning || root.service.actionMessage
            color: root.service.error ? Color.error : Color.foregroundMuted
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: confirmBody.implicitHeight + 20
            visible: root.pending !== null
            radius: Style.radiusSmall
            color: Color.surfaceContainerHigh
            border.color: Color.outline
            ColumnLayout {
                id: confirmBody
                x: 10; y: 10; width: parent.width - 20
                Label {
                    Layout.fillWidth: true
                    text: root.pending ? root.pending.label + " «" + root.pending.name + "»?" : ""
                    wrapMode: Text.Wrap
                    font.bold: true
                }
                RowLayout {
                    ActionButton {
                        text: "Confirmar"
                        emphasized: true
                        enabled: !root.service.busy
                        onClicked: {
                            root.service.execute(root.pending.verb, root.pending.id)
                            root.pending = null
                        }
                    }
                    ActionButton { text: "Cancelar"; onClicked: root.pending = null }
                }
            }
        }
        ListView {
            id: containerList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.viewingLogs
            model: root.groups
            currentIndex: root.controller.selectedIndex
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: ListView.isCurrentItem
                property bool expanded: selected
                width: containerList.width
                implicitHeight: cardBody.implicitHeight + 24
                radius: Style.radiusMedium
                color: card.selected ? Color.primaryContainer : Color.surfaceContainerHigh
                border.width: 1
                border.color: card.selected ? Color.primary : Color.outlineVariant
                ColumnLayout {
                    id: cardBody
                    x: 12; y: 12; width: parent.width - 24
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialIcon {
                            text: card.expanded ? "folder_open" : "folder"
                            iconColor: Color.primary
                            iconSize: 21
                        }
                        Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: card.modelData.project
                            font.bold: true
                            font.pixelSize: Style.fontNormal
                            elide: Text.ElideRight
                        }
                        Label {
                            text: card.modelData.containers.length + " contenedor" + (card.modelData.containers.length === 1 ? "" : "es")
                            color: Color.primary
                            font.bold: true
                        }
                        MaterialIcon {
                            text: card.expanded ? "expand_less" : "expand_more"
                            iconColor: Color.foregroundMuted
                            iconSize: 20
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: card.modelData.containers.filter(c => c.state === "running").length + " activos   ·   " + card.modelData.containers.filter(c => c.state !== "running").length + " detenidos"
                        color: Color.foregroundMuted
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        text: card.expanded ? "Servicios de este proyecto" : "Pulsa para ver los servicios"
                        color: Color.foregroundMuted
                        elide: Text.ElideRight
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: !card.expanded
                        text: card.modelData.containers.map(c => c.name).join(" · ")
                        color: Color.foregroundMuted
                        elide: Text.ElideRight
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        height: 30
                        visible: false
                        spacing: 6
                        ActionButton { text: "Logs"; enabled: !root.service.busy; onClicked: root.showLogs(card.modelData.containers[0].id) }
                        ActionButton { text: "Actualizar"; enabled: !root.service.busy; onClicked: root.service.refresh() }
                    }
                    Repeater {
                        model: card.expanded ? card.modelData.containers : []
                        delegate: Rectangle {
                            required property var modelData
                            width: cardBody.width
                            Layout.fillWidth: true
                            implicitHeight: serviceBody.implicitHeight + 16
                            radius: Style.radiusSmall
                            color: Color.surfaceContainer
                            border.width: 1
                            border.color: Color.outlineVariant
                            ColumnLayout {
                                id: serviceBody
                                x: 10; y: 8; width: parent.width - 20
                                spacing: 5
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label { Layout.fillWidth: true; text: modelData.name; font.bold: true; elide: Text.ElideRight }
                                    Label { text: modelData.state; color: modelData.state === "running" ? Color.primary : Color.foregroundMuted; font.bold: true }
                                }
                                Label { Layout.fillWidth: true; text: "CPU " + modelData.cpu + "  ·  RAM " + modelData.memory; color: Color.foregroundMuted; elide: Text.ElideRight }
                                Flow {
                                    Layout.fillWidth: true; Layout.preferredHeight: 30; spacing: 6
                                    ActionButton { text: "Logs"; onClicked: root.showLogs(modelData.id) }
                                    ActionButton { text: "Iniciar"; visible: ["exited", "created"].includes(modelData.state); onClicked: root.requestAction("start", text, modelData) }
                                    ActionButton { text: "Detener"; visible: modelData.state === "running"; onClicked: root.requestAction("stop", text, modelData) }
                                    ActionButton { text: "Reiniciar"; visible: modelData.state === "running"; onClicked: root.requestAction("restart", text, modelData) }
                                    ActionButton { text: "Reanudar"; visible: modelData.state === "paused"; onClicked: root.requestAction("unpause", text, modelData) }
                                }
                            }
                        }
                    }
                }
                TapHandler { onTapped: { root.controller.select(card.index); card.expanded = !card.expanded } }
            }
            Label {
                anchors.centerIn: parent
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: root.items.length === 0
                text: root.service.busy ? "Consultando Docker…"
                    : root.service.error ? "No se pueden listar los contenedores."
                    : "No hay contenedores que coincidan."
                color: Color.foregroundMuted
            }
        }
        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.viewingLogs
            clip: true
            Controls.TextArea {
                readOnly: true
                selectByMouse: true
                focus: root.viewingLogs
                Keys.onEscapePressed: function(event) {
                    root.back()
                    event.accepted = true
                }
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WrapAnywhere
                text: root.service.logs || "Leyendo logs…"
                color: Color.foreground
                font.family: "monospace"
                font.pixelSize: 12
                background: Rectangle { color: Color.surfaceContainer; radius: 6 }
            }
        }
        Label {
            Layout.fillWidth: true
            text: root.viewingLogs ? "Últimas 100 líneas · Esc para volver"
                : "Busca con >docker nombre · ↑↓ seleccionar · Enter logs · Esc volver"
            color: Color.foregroundMuted
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
    component Label: Text {
        textFormat: Text.PlainText
        font.pixelSize: Style.fontSmall
        color: Color.foreground
    }
    component ActionButton: Controls.Button {
        id: button
        property bool emphasized: false
        implicitWidth: label.implicitWidth + 22
        implicitHeight: 30
        opacity: enabled ? 1 : 0.5
        contentItem: Label {
            id: label
            text: button.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: button.emphasized ? Color.onPrimary : Color.foreground
        }
        background: Rectangle {
            radius: 8
            color: button.emphasized ? Color.primary : button.hovered ? Color.surfaceHover : Color.surfaceContainerHigh
            border.color: button.activeFocus ? Color.primary : Color.outlineVariant
        }
    }
}
