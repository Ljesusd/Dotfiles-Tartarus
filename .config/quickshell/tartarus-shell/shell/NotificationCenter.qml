import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../theme" as Theme
import "../launcher/components" as LauncherComponents

Scope {
    id: root

    required property ShellScreen monitorScreen
    required property var monitorContext
    required property Item anchorItem
    required property Item anchorSurface

    readonly property var groups: Services.NotificationService.groupedHistory
    readonly property real panelWidth: Math.min(
        440,
        Math.max(300, (root.monitorScreen?.width ?? 1280) - Theme.Style.spacingLarge * 2)
    )
    readonly property real panelHeight: Math.min(
        720,
        Math.max(
            420,
            (root.monitorScreen?.height ?? 800)
                - Theme.Style.barHeight
                - Theme.Style.paddingLarge * 2
        )
    )

    PopupWindow {
        anchor.item: root.anchorItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: Math.min(
            root.panelWidth + notificationSurface.horizontalInset * 2,
            Math.max(1, root.monitorScreen?.width ?? 1280)
        )
        implicitHeight: root.panelHeight
            + Theme.Style.barPopupGap * 2
            + notificationSurface.shadowPadding
        color: "transparent"
        visible: Services.NotificationService.centerOpen
            || notificationSurface.reveal > 0
        mask: Region { item: notificationSurface.maskItem }

        LauncherComponents.LauncherSurface {
            id: notificationSurface
            anchors.fill: parent
            opened: Services.NotificationService.centerOpen
            contentWidth: root.panelWidth
            contentHeight: root.panelHeight

            Item {
                id: drawer
                parent: notificationSurface.contentItem
                anchors.fill: parent
                clip: true

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.Style.paddingLarge
                    anchors.bottomMargin: Theme.Style.paddingLarge + Theme.Style.barPopupGap * 2
                    spacing: Theme.Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Notificaciones"
                            color: Theme.Color.foreground
                            font.pixelSize: Theme.Style.fontNormal
                            font.bold: true
                        }
                        Text {
                            text: `${historyList.count} aplicaciones · ${Services.NotificationService.history.count} avisos`
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                        }
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: Services.NotificationService.dnd
                            ? "Desactivar no molestar"
                            : "Activar no molestar"
                        contentItem: Theme.MaterialIcon {
                            text: Services.NotificationService.dnd
                                ? "notifications_off"
                                : "notifications"
                            color: Services.NotificationService.dnd
                                ? Theme.Color.tertiaryContainer
                                : Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconMedium
                        }
                        onClicked: Services.NotificationService.toggleDnd(
                            root.monitorScreen.name
                        )
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Limpiar historial"
                        contentItem: Theme.MaterialIcon {
                            text: "delete_sweep"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconMedium
                        }
                        onClicked: Services.NotificationService.clearHistory()
                    }

                    ToolButton {
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Cerrar"
                        contentItem: Theme.MaterialIcon {
                            text: "close"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconMedium
                        }
                        onClicked: {
                            root.monitorContext.closeNotificationCenter()
                            Services.NotificationService.closeCenter()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.Color.surfaceHover
                }

                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.Style.spacingSmall
                    model: root.groups
                    verticalLayoutDirection: ListView.TopToBottom

                    Connections {
                        target: Services.NotificationService
                        function onCenterOpenChanged() {
                            if (Services.NotificationService.centerOpen)
                                Qt.callLater(historyList.positionViewAtBeginning)
                        }
                    }

                    delegate: Item {
                        id: groupItem
                        required property string appName
                        required property int count
                        required property string itemsJson
                        required property string latestAppName
                        required property string latestSummary
                        required property string latestBody
                        required property string latestImage
                        required property double latestTimestamp
                        required property int latestHistoryIndex
                        property bool expanded: false

                        function olderItems() {
                            try {
                                return JSON.parse(itemsJson || "[]")
                            } catch (error) {
                                return []
                            }
                        }

                        width: historyList.width
                        implicitHeight: groupContent.implicitHeight

                        Column {
                            id: groupContent
                            width: parent.width
                            spacing: Theme.Style.spacingSmall

                            NotificationCard {
                                width: parent.width
                                appName: groupItem.latestAppName || groupItem.appName
                                summary: groupItem.latestSummary
                                body: groupItem.latestBody
                                image: groupItem.latestImage
                                timestampLabel: root.relativeTime(groupItem.latestTimestamp)
                                groupCount: groupItem.count
                                showActions: false
                                showRemove: true
                                historyIndex: groupItem.latestHistoryIndex
                                screenName: root.monitorScreen.name
                                onRemoveRequested: index =>
                                    Services.NotificationService.removeHistory(index)
                            }

                            ToolButton {
                                visible: groupItem.count > 1
                                width: parent.width
                                height: 32
                                text: groupItem.expanded
                                    ? "Ocultar avisos anteriores"
                                    : `Ver ${groupItem.count - 1} avisos anteriores`
                                onClicked: groupItem.expanded = !groupItem.expanded

                                background: Rectangle {
                                    radius: Theme.Style.controlRadius
                                    color: parent.hovered
                                        ? Theme.Color.surfaceHover
                                        : Theme.Color.surfaceElevated
                                    border.width: 1
                                    border.color: Theme.Color.outlineVariant
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: Theme.Color.foregroundMuted
                                    font.pixelSize: Theme.Style.fontSmall
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.Style.spacingSmall
                                visible: groupItem.expanded

                                Repeater {
                                    model: groupItem.olderItems()
                                    delegate: NotificationCard {
                                        width: groupContent.width
                                        appName: modelData.appName
                                        summary: modelData.summary
                                        body: modelData.body
                                        image: modelData.image
                                        timestampLabel: root.relativeTime(
                                            modelData.timestamp
                                        )
                                        showActions: false
                                        showRemove: true
                                        historyIndex: modelData.historyIndex
                                        screenName: root.monitorScreen.name
                                        onRemoveRequested: index =>
                                            Services.NotificationService.removeHistory(index)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No hay notificaciones"
                        color: Theme.Color.foregroundMuted
                        font.pixelSize: Theme.Style.fontSmall
                        visible: historyList.count === 0
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.Color.surfaceHover
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Layout.leftMargin: Theme.Style.paddingSmall
                    Layout.rightMargin: Theme.Style.paddingSmall
                    radius: Theme.Style.controlRadius
                    color: Theme.Color.surfaceElevated
                    border.width: 1
                    border.color: Theme.Color.outlineVariant

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.Style.paddingSmall
                        anchors.rightMargin: Theme.Style.paddingSmall
                        spacing: Theme.Style.spacingSmall

                        Theme.MaterialIcon {
                            text: Services.NotificationService.dnd
                                ? "notifications_off"
                                : "notifications"
                            color: Services.NotificationService.dnd
                                ? Theme.Color.tertiaryContainer
                                : Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconSmall
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Services.NotificationService.dnd
                                ? "No molestar activo"
                                : "Notificaciones activas"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                            elide: Text.ElideRight
                        }
                    }
                }
                }
            }
        }
    }

    function relativeTime(timestamp) {
        const seconds = Math.max(0, Math.floor((Date.now() - timestamp) / 1000))
        if (seconds < 60) return "ahora"
        const minutes = Math.floor(seconds / 60)
        if (minutes < 60) return `${minutes} min`
        const hours = Math.floor(minutes / 60)
        if (hours < 24) return `${hours} h`
        return `${Math.floor(hours / 24)} d`
    }
}
