import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme"

ColumnLayout {
    id: root

    required property var service
    property color backgroundColor: "#171925"
    property color surfaceColor: "#20243a"
    property color surfaceHighColor: "#282e48"
    property color surfaceHoverColor: "#303957"
    property color accentColor: "#83aef7"
    property color textColor: "#d9e1ff"
    property color mutedColor: "#9ba7ca"

    Layout.fillWidth: true
    spacing: Style.spacingMedium

    readonly property var selected: root.service.selectedMonitor()

    function modeOptions(monitor) {
        if (!monitor)
            return []
        const values = []
        for (const raw of (monitor.availableModes || [])) {
            const value = String(raw).replace(/Hz$/, "")
            if (values.indexOf(value) === -1)
                values.push(value)
        }
        if (values.indexOf(monitor.mode) === -1 && monitor.mode)
            values.unshift(monitor.mode)
        return values
    }

    function layoutMinX() {
        const values = root.service.draftMonitors || []
        return values.length ? Math.min(...values.map(monitor => Number(monitor.x || 0))) : 0
    }

    function layoutMinY() {
        const values = root.service.draftMonitors || []
        return values.length ? Math.min(...values.map(monitor => Number(monitor.y || 0))) : 0
    }

    function layoutWidth() {
        const values = root.service.draftMonitors || []
        if (!values.length)
            return 1
        return Math.max(...values.map(monitor => Number(monitor.x || 0) + Math.max(1, Number(monitor.width || 1) / Number(monitor.scale || 1)))) - root.layoutMinX()
    }

    function layoutHeight() {
        const values = root.service.draftMonitors || []
        if (!values.length)
            return 1
        return Math.max(...values.map(monitor => Number(monitor.y || 0) + Math.max(1, Number(monitor.height || 1) / Number(monitor.scale || 1)))) - root.layoutMinY()
    }

    function canvasScale() {
        return Math.min(
            0.24,
            Math.max(0.08, (monitorCanvas.width - 28) / Math.max(1, root.layoutWidth())),
            Math.max(0.08, (monitorCanvas.height - 28) / Math.max(1, root.layoutHeight()))
        )
    }

    function mapX(monitor) {
        return 14 + (Number(monitor.x || 0) - root.layoutMinX()) * root.canvasScale()
    }

    function mapY(monitor) {
        return 14 + (Number(monitor.y || 0) - root.layoutMinY()) * root.canvasScale()
    }

    function mapWidth(monitor) {
        return Math.max(72, Number(monitor.width || 1) / Number(monitor.scale || 1) * root.canvasScale())
    }

    function mapHeight(monitor) {
        return Math.max(58, Number(monitor.height || 1) / Number(monitor.scale || 1) * root.canvasScale())
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 76
        radius: Style.cardRadius
        color: root.surfaceColor
        border.width: 1
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.12)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingMedium
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: Style.radiusMedium
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                MaterialIcon { anchors.centerIn: parent; text: "monitor"; iconSize: Style.materialIconLarge; iconColor: root.accentColor }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { text: root.service.monitors.length + " pantalla" + (root.service.monitors.length === 1 ? "" : "s") + " conectada" + (root.service.monitors.length === 1 ? "" : "s"); color: root.textColor; font.pixelSize: Style.fontNormal; font.bold: true }
                Text { text: root.service.loading ? "Leyendo el estado de Hyprland…" : root.service.previewActive ? "Previsualización activa · " + root.service.previewSeconds + " s para confirmar" : "Organiza la disposición y ajusta cada salida"; color: root.mutedColor; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; elide: Text.ElideRight }
            }
            Text { visible: root.service.managerConflict; text: "hyprmoncfg activo"; color: "#f5b86b"; font.pixelSize: 12; font.bold: true }
            RowLayout {
                visible: root.service.previewActive
                Layout.alignment: Qt.AlignVCenter
                spacing: Style.spacingXs
                MonitorButton { text: "Revertir"; buttonIcon: "undo"; danger: true; onClicked: root.service.revertChanges() }
                MonitorButton { text: "Mantener"; buttonIcon: "check"; primary: true; onClicked: root.service.keepChanges() }
            }
        }
    }

    GridLayout {
        id: editorGrid
        Layout.fillWidth: true
        columns: width >= 760 ? 2 : 1
        columnSpacing: Style.spacingMedium
        rowSpacing: Style.spacingMedium
        Layout.preferredHeight: columns === 2 ? 360 : 680

        Rectangle {
            id: monitorCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 360
            Layout.minimumHeight: 300
            radius: Style.cardRadius
            color: root.backgroundColor
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.22)
            clip: true

            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Style.paddingMedium
                text: "Mapa del escritorio"
                color: root.textColor
                font.pixelSize: Style.fontSmall
                font.bold: true
                z: 2
            }

            Repeater {
                model: root.service.draftMonitors
                delegate: Rectangle {
                    id: monitorTile
                    required property var modelData
                    readonly property var monitor: modelData
                    readonly property bool selectedMonitor: root.service.selectedName === monitor.name
                    x: root.mapX(monitor)
                    y: root.mapY(monitor) + 28
                    width: root.mapWidth(monitor)
                    height: root.mapHeight(monitor)
                    radius: Style.radiusMedium
                    color: selectedMonitor ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.32) : root.surfaceHighColor
                    border.width: selectedMonitor ? 2 : 1
                    border.color: selectedMonitor ? root.accentColor : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.24)
                    opacity: monitor.disabled ? 0.45 : 1
                    property real dragStartX: 0
                    property real dragStartY: 0
                    Behavior on color { ColorAnimation { duration: Style.motionFast } }
                    Behavior on border.color { ColorAnimation { duration: Style.motionFast } }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 3
                        Text { width: parent.width; text: monitor.name; color: root.textColor; font.pixelSize: 12; font.bold: true; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                        Text { width: parent.width; text: monitor.disabled ? "Desactivado" : monitor.width + "×" + monitor.height; color: root.mutedColor; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                        Text { visible: parent.parent.width > 105; width: parent.width; text: monitor.focused ? "Enfocado" : Math.round(monitor.refreshRate) + " Hz"; color: root.accentColor; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                    }
                    TapHandler { onTapped: root.service.select(monitor.name) }
                    DragHandler {
                        enabled: !root.service.previewActive && !monitor.disabled
                        onActiveChanged: {
                            if (active) {
                                root.service.select(monitor.name)
                                monitorTile.dragStartX = Number(monitor.x || 0)
                                monitorTile.dragStartY = Number(monitor.y || 0)
                            }
                        }
                        onTranslationChanged: {
                            if (active)
                                root.service.moveDraft(monitor.name, monitorTile.dragStartX + translation.x / root.canvasScale(), monitorTile.dragStartY + translation.y / root.canvasScale())
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.service.draftMonitors.length === 0 && !root.service.loading
                text: root.service.errorMessage || "No hay monitores disponibles"
                color: root.mutedColor
                font.pixelSize: Style.fontSmall
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 360
            Layout.minimumHeight: 360
            radius: Style.cardRadius
            color: root.surfaceColor
            border.width: 1
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)

            ColumnLayout {
                id: monitorInspector
                anchors.fill: parent
                anchors.margins: Style.paddingMedium
                spacing: Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: root.selected ? root.selected.name : "Selecciona una pantalla"; color: root.textColor; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { visible: root.selected !== null && root.selected.focused === true; text: "Enfocado"; color: root.accentColor; font.pixelSize: 12; font.bold: true }
                }
                Text { visible: root.selected !== null; text: root.selected ? (root.selected.description || "Salida de Hyprland") : ""; color: root.mutedColor; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Activa"; color: root.textColor; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }
                    Switch {
                        id: enabledSwitch
                        enabled: root.selected !== null && !root.service.previewActive
                        checked: root.selected ? !root.selected.disabled : false
                        onToggled: if (root.selected) root.service.setDraftField(root.selected.name, "disabled", !checked)
                        indicator: Rectangle {
                            x: enabledSwitch.leftPadding
                            y: enabledSwitch.topPadding + (enabledSwitch.availableHeight - height) / 2
                            implicitWidth: 44
                            implicitHeight: 24
                            radius: height / 2
                            color: enabledSwitch.checked ? root.accentColor : root.surfaceHighColor
                            border.width: 1
                            border.color: enabledSwitch.checked ? root.accentColor : root.mutedColor
                            Rectangle { width: 18; height: 18; y: 2; x: enabledSwitch.checked ? parent.width - width - 3 : 3; radius: Style.radiusFull; color: enabledSwitch.checked ? root.backgroundColor : root.mutedColor }
                        }
                    }
                }

                Text { text: "Resolución y frecuencia"; color: root.mutedColor; font.pixelSize: 12; Layout.topMargin: 4 }
                ComboBox {
                    id: modeBox
                    Layout.fillWidth: true
                    enabled: root.selected !== null && !root.service.previewActive
                    model: root.modeOptions(root.selected)
                    currentIndex: Math.max(0, model.indexOf(root.selected ? root.selected.mode : ""))
                    onActivated: if (root.selected && currentIndex >= 0) root.service.setDraftField(root.selected.name, "mode", model[currentIndex])
                    contentItem: Text { leftPadding: 12; rightPadding: 34; text: modeBox.displayText || "Sin modos disponibles"; color: root.textColor; font.pixelSize: Style.fontSmall; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    background: Rectangle { radius: Style.controlRadius; color: root.surfaceHighColor; border.width: modeBox.activeFocus ? 1 : 0; border.color: root.accentColor }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Escala"; color: root.mutedColor; font.pixelSize: 12 }
                    Text { text: root.selected ? Number(root.selected.scale).toFixed(2) + "×" : "—"; color: root.textColor; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight }
                }
                Slider {
                    id: scaleSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    enabled: root.selected !== null && !root.service.previewActive
                    from: 0.75
                    to: 2.5
                    stepSize: 0.05
                    value: root.selected ? root.selected.scale : 1
                    onMoved: if (root.selected) root.service.setDraftField(root.selected.name, "scale", Math.round(value * 20) / 20)
                    background: Rectangle {
                        x: scaleSlider.leftPadding
                        y: scaleSlider.topPadding + (scaleSlider.availableHeight - height) / 2
                        width: scaleSlider.availableWidth
                        height: 7
                        radius: height / 2
                        color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                        Rectangle {
                            width: scaleSlider.visualPosition * parent.width
                            height: parent.height
                            radius: height / 2
                            color: root.accentColor
                        }
                    }
                    handle: Rectangle {
                        x: scaleSlider.leftPadding + scaleSlider.visualPosition * (scaleSlider.availableWidth - width)
                        y: scaleSlider.topPadding + (scaleSlider.availableHeight - height) / 2
                        width: scaleSlider.pressed ? 22 : 18
                        height: width
                        radius: width / 2
                        color: scaleSlider.enabled ? root.accentColor : root.mutedColor
                        border.width: 3
                        border.color: root.surfaceColor
                        scale: scaleSlider.pressed ? 1.06 : 1
                        Behavior on width { NumberAnimation { duration: Style.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: Style.motionFast; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: Style.motionFast; easing.type: Easing.OutCubic } }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Orientación"; color: root.mutedColor; font.pixelSize: 12 }
                    ComboBox {
                        id: transformBox
                        Layout.fillWidth: true
                        enabled: root.selected !== null && !root.service.previewActive
                        model: ["Normal", "90°", "180°", "270°"]
                        currentIndex: root.selected ? Math.min(3, Number(root.selected.transform || 0) % 4) : 0
                        onActivated: if (root.selected) root.service.setDraftField(root.selected.name, "transform", currentIndex)
                        contentItem: Text { leftPadding: 12; rightPadding: 30; text: transformBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: Style.controlRadius; color: root.surfaceHighColor }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Modo"; color: root.mutedColor; font.pixelSize: 12 }
                    ComboBox {
                        id: mirrorBox
                        Layout.fillWidth: true
                        enabled: root.selected !== null && !root.service.previewActive
                        model: ["Extendido"].concat((root.service.draftMonitors || []).filter(monitor => monitor.name !== (root.selected ? root.selected.name : "")).map(monitor => "Duplicar: " + monitor.name))
                        currentIndex: root.selected && root.selected.mirrorOf !== "none" ? Math.max(1, model.findIndex(value => value.endsWith(root.selected.mirrorOf))) : 0
                        onActivated: {
                            if (!root.selected)
                                return
                            root.service.setDraftField(root.selected.name, "mirrorOf", currentIndex === 0 ? "none" : String(model[currentIndex]).replace("Duplicar: ", ""))
                        }
                        contentItem: Text { leftPadding: 12; rightPadding: 30; text: mirrorBox.displayText; color: root.textColor; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                        background: Rectangle { radius: Style.controlRadius; color: root.surfaceHighColor }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    MonitorButton { text: "Enfocar"; buttonIcon: "center_focus_strong"; enabled: root.selected !== null; onClicked: root.service.focusMonitor(root.selected.name) }
                    Item { Layout.fillWidth: true }
                }
            }
        }
    }

    Rectangle {
        id: actionsCard
        Layout.fillWidth: true
        implicitHeight: actionsContent.implicitHeight + Style.paddingMedium * 2
        radius: Style.cardRadius
        color: root.service.errorMessage !== "" ? Qt.rgba(0.95, 0.42, 0.45, 0.12) : root.surfaceColor
        border.width: 1
        border.color: root.service.errorMessage !== "" ? Qt.rgba(0.95, 0.42, 0.45, 0.35) : Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.10)
        ColumnLayout {
            id: actionsContent
            x: Style.paddingMedium
            y: Style.paddingMedium
            width: actionsCard.width - Style.paddingMedium * 2
            spacing: Style.spacingMedium
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.service.errorMessage || (root.service.managerConflict ? "hyprmoncfg está activo; no se guardarán cambios desde Tartarus" : root.service.previewActive ? "Comprueba la nueva disposición antes de mantenerla" : "Los cambios se prueban antes de guardarse")
                    color: root.service.errorMessage !== "" ? "#ffb4ab" : root.mutedColor
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !root.service.previewActive
                MonitorButton { text: "Descartar cambios"; buttonIcon: "undo"; enabled: root.service.hasDraftChanges(); onClicked: root.service.resetDraft() }
                Item { Layout.fillWidth: true }
                MonitorButton { text: "Aplicar"; buttonIcon: "check"; primary: true; enabled: root.service.hasDraftChanges() && !root.service.managerConflict && !root.service.loading; onClicked: root.service.applyPreview() }
            }
        }
    }

    component MonitorButton: Button {
        id: button
        property string buttonIcon: ""
        property bool primary: false
        property bool danger: false
        implicitHeight: 34
        implicitWidth: Math.max(104, contentItem.implicitWidth + 24)
        contentItem: RowLayout {
            spacing: 6
            MaterialIcon { visible: button.buttonIcon !== ""; text: button.buttonIcon; iconSize: 15; iconColor: button.enabled ? (button.primary ? root.backgroundColor : root.textColor) : root.mutedColor }
            Text { text: button.text; color: button.enabled ? (button.primary ? root.backgroundColor : root.textColor) : root.mutedColor; font.pixelSize: 12; font.bold: button.primary; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; Layout.fillWidth: true }
        }
        background: Rectangle {
            radius: Style.radiusFull
            color: !button.enabled ? root.surfaceHighColor : button.down ? (button.primary ? Qt.lighter(root.accentColor, 115) : root.surfaceHoverColor) : button.primary ? root.accentColor : button.hovered ? root.surfaceHoverColor : root.surfaceHighColor
            border.width: button.primary || button.danger ? 1 : 0
            border.color: button.danger ? Qt.rgba(1, 0.48, 0.48, 0.55) : button.primary ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.9) : "transparent"
            opacity: button.enabled ? 1 : 0.5
            Behavior on color { ColorAnimation { duration: Style.motionFast } }
        }
    }
}
