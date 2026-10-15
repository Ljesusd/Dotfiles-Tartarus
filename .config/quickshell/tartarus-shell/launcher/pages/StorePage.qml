import QtQuick
import QtQuick.Layouts

import "../../services" as Services
import "../../theme" as Theme
import "../components"

Item {
    id: root

    required property var controller
    required property bool active
    readonly property var store: Services.FlatpakStoreService

    visible: root.active

    function runSearch() {
        if (root.active)
            root.store.search(root.controller.storeQuery)
    }

    onActiveChanged: {
        if (root.active)
            root.runSearch()
    }

    Connections {
        target: root.controller

        function onStoreQueryChanged() {
            if (!storeInput.activeFocus
                    && storeInput.text !== root.controller.storeQuery)
                storeInput.text = root.controller.storeQuery
            root.runSearch()
        }

        function onSelectedIndexChanged() {
            if (root.active && storeList.currentIndex >= 0)
                storeList.positionViewAtIndex(storeList.currentIndex, ListView.Contain)
        }
    }

    Connections {
        target: root.store

        function onResultsChanged() {
            if (root.active)
                root.controller.resetSelection()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.Style.paddingXLarge
        anchors.rightMargin: Theme.Style.paddingXLarge
        anchors.topMargin: Theme.Style.paddingLarge
        anchors.bottomMargin: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingMedium

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.spacingLarge

            Theme.MaterialIcon {
                text: "storefront"
                iconSize: Theme.Style.materialIconMedium
                iconColor: Theme.Color.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.Style.spacingXs

                Text {
                    text: "Flathub Store"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontNormal
                    font.weight: Font.DemiBold
                }

                Text {
                    text: ">store · busca e instala aplicaciones para tu usuario"
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.spacingSmall

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 42
                radius: Theme.Style.controlRadius
                color: Theme.Color.surfaceContainerHigh
                border.width: 1
                border.color: Theme.Color.outlineVariant

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.Style.paddingMedium
                    anchors.rightMargin: Theme.Style.paddingMedium
                    spacing: Theme.Style.spacingSmall

                    Theme.MaterialIcon {
                        text: "search"
                        iconSize: Theme.Style.materialIconSmall
                        iconColor: Theme.Color.foregroundMuted
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.fill: parent
                            visible: storeInput.text === "" && !storeInput.activeFocus
                            text: "Buscar aplicaciones en Flathub…"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        TextInput {
                            id: storeInput
                            anchors.fill: parent
                            text: root.controller.storeQuery
                            color: Theme.Color.foreground
                            font.pixelSize: Theme.Style.fontSmall
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true
                            clip: true

                            onTextEdited: {
                                const value = text.trim()
                                root.controller.launcherState.query =
                                    value === "" ? ">store" : ">store " + value
                            }
                        }
                    }
                }
            }

            StoreButton {
                icon: "system_update_alt"
                label: root.store.updatingFlatpaks ? "Actualizando…" : "Actualizar Flatpaks"
                enabled: !root.store.busy
                onClicked: root.store.updateFlatpaks()
            }

            StoreButton {
                icon: "upgrade"
                label: root.store.updatingSystem ? "Actualizando…" : "Actualizar sistema"
                enabled: !root.store.busy
                onClicked: root.store.updateSystem()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            LauncherListView {
                id: storeList
                anchors.fill: parent
                pageActive: root.active
                model: root.store.results
                currentIndex: root.active ? root.controller.selectedIndex : -1

                onCountChanged: {
                    if (root.active)
                        root.controller.resetSelection()
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: storeList.width
                    height: 76

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.Style.cardRadius
                        color: ListView.isCurrentItem
                            ? Theme.Color.primaryContainer
                            : Theme.Color.surfaceContainerHigh
                        border.width: ListView.isCurrentItem ? 1 : 0
                        border.color: Theme.Color.primary
                        opacity: modelData.installed ? 0.82 : 1

                        Behavior on color { ColorAnimation { duration: Theme.Style.launcherMotionFast } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.Style.paddingMedium
                        anchors.rightMargin: Theme.Style.paddingMedium
                        spacing: Theme.Style.spacingMedium

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 38
                            implicitHeight: 38
                            radius: Theme.Style.radiusMedium
                            color: modelData.installed
                                ? Qt.alpha(Theme.Color.success, 0.18)
                                : Qt.alpha(Theme.Color.primary, 0.16)

                            Theme.MaterialIcon {
                                anchors.centerIn: parent
                                text: modelData.installed ? "check_circle" : "apps"
                                iconSize: Theme.Style.materialIconMedium
                                iconColor: modelData.installed ? Theme.Color.success : Theme.Color.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.Color.foreground
                                font.pixelSize: Theme.Style.fontNormal
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.description
                                color: Theme.Color.foregroundMuted
                                font.pixelSize: Theme.Style.fontSmall
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.applicationId
                                    + (modelData.version !== "" ? " · " + modelData.version : "")
                                color: Theme.Color.foregroundSubtle
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.installed ? "Instalada" : "Instalar"
                            color: modelData.installed ? Theme.Color.success : Theme.Color.primary
                            font.pixelSize: Theme.Style.fontSmall
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.controller.select(index)
                        onClicked: {
                            root.controller.select(index)
                            if (!modelData.installed)
                                root.store.install(modelData)
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(parent.width - Theme.Style.paddingLarge * 2, 520)
                spacing: Theme.Style.spacingSmall
                visible: root.active && storeList.count === 0

                Theme.MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.store.error !== "" ? "error_outline" : "storefront"
                    iconSize: Theme.Style.materialIconExtraLarge
                    iconColor: root.store.error !== "" ? Theme.Color.error : Theme.Color.foregroundSubtle
                }

                Text {
                    width: parent.width
                    text: root.store.error !== "" ? root.store.error : root.store.status
                    color: root.store.error !== "" ? Theme.Color.error : Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Theme.Style.controlRadius
            color: Theme.Color.surfaceContainerHigh
            border.width: 1
            border.color: root.store.error !== "" ? Theme.Color.error : Theme.Color.outlineVariant

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.Style.paddingMedium
                anchors.rightMargin: Theme.Style.paddingMedium
                spacing: Theme.Style.spacingSmall

                Theme.MaterialIcon {
                    text: root.store.busy ? "progress_activity" : "info"
                    iconSize: Theme.Style.materialIconSmall
                    iconColor: root.store.error !== "" ? Theme.Color.error : Theme.Color.foregroundMuted
                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: root.store.busy
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.store.error !== "" ? root.store.error : root.store.status
                    color: root.store.error !== "" ? Theme.Color.error : Theme.Color.foregroundMuted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }

    component StoreButton: Rectangle {
        property string icon: "refresh"
        property string label: ""
        signal clicked()

        implicitWidth: buttonLabel.implicitWidth + 48
        implicitHeight: 42
        radius: Theme.Style.controlRadius
        color: enabled ? Theme.Color.surfaceContainerHigh : Qt.alpha(Theme.Color.surfaceContainerHigh, 0.45)
        border.width: 1
        border.color: enabled ? Theme.Color.outlineVariant : Qt.alpha(Theme.Color.outlineVariant, 0.45)
        opacity: enabled ? 1 : 0.65

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.Style.paddingSmall
            anchors.rightMargin: Theme.Style.paddingSmall
            spacing: Theme.Style.spacingXs

            Theme.MaterialIcon {
                text: parent.parent.icon
                iconSize: Theme.Style.materialIconSmall
                iconColor: Theme.Color.primary
            }

            Text {
                id: buttonLabel
                text: parent.parent.label
                color: Theme.Color.foreground
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        TapHandler {
            enabled: parent.enabled
            onTapped: parent.clicked()
        }
    }
}
