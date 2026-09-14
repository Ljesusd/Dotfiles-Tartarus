import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../theme"

Scope {
    id: root

    required property ShellScreen monitorScreen
    required property var monitorContext

    readonly property bool isFocused:
        Hyprland.focusedMonitor
        && Hyprland.focusedMonitor.name === root.monitorScreen.name
    readonly property var visibleEntries:
        Services.ClipboardService.filteredValues()

    PanelWindow {
        screen: root.monitorScreen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        visible: root.monitorContext.clipboardOpen
            && root.isFocused

        Rectangle {
            id: panel

            width: 720
            height: 560
            anchors.centerIn: parent
            radius: Style.radiusLarge
            color: Color.background
            border.width: 1
            border.color: Color.outline

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.paddingLarge
                spacing: Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true

                    MaterialIcon {
                        text: "content_paste"
                        color: Color.accent
                        font.pixelSize: Style.materialIconMedium
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Clipboard"
                        color: Color.foreground
                        font.pixelSize: Style.fontNormal
                        font.bold: true
                    }

                    Text {
                        text: `${root.visibleEntries.length} items`
                        color: Color.foregroundSubtle
                        font.pixelSize: Style.fontSmall
                    }

                    ToolButton {
                        id: clearButton
                        implicitWidth: Style.controlHeight
                        implicitHeight: Style.controlHeight
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Clear recent entries"
                        background: Rectangle {
                            radius: Style.radiusSmall
                            color: clearButton.hovered
                                ? Color.surfaceHover
                                : "transparent"
                        }
                        contentItem: MaterialIcon {
                            text: "delete_sweep"
                            color: clearButton.hovered
                                ? Color.foreground
                                : Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: Services.ClipboardService.clear()
                    }

                    ToolButton {
                        id: closeButton
                        implicitWidth: Style.controlHeight
                        implicitHeight: Style.controlHeight
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Close"
                        background: Rectangle {
                            radius: Style.radiusSmall
                            color: closeButton.hovered
                                ? Color.surfaceHover
                                : "transparent"
                        }
                        contentItem: MaterialIcon {
                            text: "close"
                            color: closeButton.hovered
                                ? Color.foreground
                                : Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }
                        onClicked: Services.ClipboardService.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.spacingSmall

                    Repeater {
                        model: [
                            { mode: "recent", label: "Recent" },
                            { mode: "pinned", label: "Pinned" }
                        ]

                        delegate: ToolButton {
                            id: modeButton
                            required property var modelData

                            text: modelData.label
                            implicitHeight: 32
                            padding: Style.paddingSmall
                            highlighted:
                                Services.ClipboardService.viewMode
                                === modelData.mode

                            background: Rectangle {
                                radius: Style.radiusSmall
                                color: modeButton.highlighted
                                    ? Color.selection
                                    : modeButton.hovered
                                        ? Color.surfaceHover
                                        : "transparent"
                            }

                                contentItem: Text {
                                    text: modeButton.text
                                    color: modeButton.highlighted
                                        ? Color.foreground
                                        : Color.foregroundMuted
                                    font.bold: modeButton.highlighted
                                    font.pixelSize: Style.fontSmall
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                Services.ClipboardService.viewMode =
                                    modelData.mode
                                Services.ClipboardService.selectedIndex = 0
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.controlHeight
                    radius: Style.radiusMedium
                    color: Color.surface
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Color.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.paddingMedium
                        anchors.rightMargin: Style.paddingMedium

                        MaterialIcon {
                            text: "search"
                            color: Color.foregroundMuted
                            font.pixelSize: Style.materialIconMedium
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            focus: true
                            color: Color.foreground
                            font.pixelSize: Style.fontSmall
                            clip: true
                            onTextChanged: {
                                Services.ClipboardService.query = text
                                Services.ClipboardService.selectedIndex = 0
                            }
                            Keys.onEscapePressed: Services.ClipboardService.close()
                            Keys.onSpacePressed: function(event) {
                                if (text.length !== 0)
                                    return

                                const item = root.visibleEntries[
                                    Services.ClipboardService.selectedIndex
                                ]
                                if (!item)
                                    return

                                Services.ClipboardService.copyEntry(item)
                                event.accepted = true
                            }
                            Keys.onDownPressed: {
                                const count = root.visibleEntries.length
                                if (count > 0)
                                    Services.ClipboardService.selectedIndex =
                                        Math.min(
                                            count - 1,
                                            Services.ClipboardService.selectedIndex + 1
                                        )
                            }
                            Keys.onUpPressed: {
                                Services.ClipboardService.selectedIndex =
                                    Math.max(
                                        0,
                                        Services.ClipboardService.selectedIndex - 1
                                    )
                            }
                            Keys.onReturnPressed: {
                                const item = root.visibleEntries[
                                    Services.ClipboardService.selectedIndex
                                ]
                                if (item)
                                    Services.ClipboardService.copyEntry(item)
                            }
                        }

                        Text {
                            visible: searchInput.text.length === 0
                            text: "Search clipboard..."
                            color: Color.foregroundMuted
                            font.pixelSize: Style.fontSmall
                        }
                    }
                }

                Flickable {
                    id: contentFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: columnsRow.implicitHeight

                    Row {
                        id: columnsRow
                        width: parent.width
                        spacing: Style.spacingSmall

                        Repeater {
                            model: 3

                            delegate: Column {
                                required property int index

                                width: (
                                    columnsRow.width
                                    - Style.spacingSmall * 2
                                ) / 3
                                spacing: Style.spacingSmall

                                Repeater {
                                    model: Services.ClipboardService.columnValues(
                                        index,
                                        3
                                    )

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: parent.width
                                        height: modelData.type === "image"
                                            ? 210
                                            : modelData.type === "code"
                                                ? 116
                                                : modelData.type === "multiline"
                                                    ? 94
                                                    : 76
                                        radius: Style.radiusMedium
                                        border.width: modelData.filteredIndex
                                            === Services.ClipboardService.selectedIndex
                                            ? 1
                                            : 0
                                        border.color: Color.accent
                                        color: modelData.filteredIndex
                                            === Services.ClipboardService.selectedIndex
                                            ? Color.selection
                                            : cardHover.hovered
                                                ? Color.surfaceHover
                                                : Color.surface
                                        clip: true

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: Style.paddingSmall
                                            spacing: Style.spacingXs

                                            RowLayout {
                                                width: parent.width
                                                height: Style.barIconSmall
                                                spacing: Style.spacingXs

                                                MaterialIcon {
                                                    text: modelData.icon
                                                    color: Color.accent
                                                    font.pixelSize: Style.materialIconSmall
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.label
                                                    color: Color.foregroundMuted
                                                    font.pixelSize: Style.fontSmall
                                                    elide: Text.ElideRight
                                                }

                                                ToolButton {
                                                    id: copyButton
                                                    Layout.preferredWidth: Style.barIconSmall
                                                    Layout.preferredHeight: Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: "Copy"
                                                    background: Rectangle {
                                                        radius: Style.radiusSmall
                                                        color: copyButton.hovered
                                                            ? Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: MaterialIcon {
                                                        text: "content_copy"
                                                        color: copyButton.hovered
                                                            ? Color.foreground
                                                            : Color.foregroundMuted
                                                        font.pixelSize: Style.materialIconSmall
                                                    }
                                                    onClicked:
                                                        Services.ClipboardService.copyEntry(
                                                            modelData
                                                        )
                                                }

                                                ToolButton {
                                                    id: openButton
                                                    visible:
                                                        Services.ClipboardService.canOpenEntry(
                                                            modelData
                                                        )
                                                    Layout.preferredWidth: visible
                                                        ? Style.barIconSmall
                                                        : 0
                                                    Layout.preferredHeight: Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: modelData.type === "image"
                                                        ? "Open in viewer"
                                                        : "Open"
                                                    background: Rectangle {
                                                        radius: Style.radiusSmall
                                                        color: openButton.hovered
                                                            ? Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: MaterialIcon {
                                                        text: modelData.type === "image"
                                                            ? "visibility"
                                                            : modelData.type === "path"
                                                                ? "folder_open"
                                                                : "open_in_new"
                                                        color: openButton.hovered
                                                            ? Color.foreground
                                                            : Color.foregroundMuted
                                                        font.pixelSize: Style.materialIconSmall
                                                    }
                                                    onClicked:
                                                        Services.ClipboardService.openEntry(
                                                            modelData,
                                                            root.monitorScreen.name
                                                        )
                                                }

                                                ToolButton {
                                                    id: pinButton
                                                    Layout.preferredWidth: Style.barIconSmall
                                                    Layout.preferredHeight: Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: modelData.pinned
                                                        ? "Unpin"
                                                        : "Pin"
                                                    background: Rectangle {
                                                        radius: Style.radiusSmall
                                                        color: pinButton.hovered
                                                            ? Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: MaterialIcon {
                                                        text: modelData.pinned
                                                            ? "push_pin"
                                                            : "push_pin"
                                                        color: modelData.pinned
                                                            ? Color.accent
                                                                : pinButton.hovered
                                                                ? Color.foreground
                                                                : Color.foregroundMuted
                                                        font.pixelSize: Style.materialIconSmall
                                                    }
                                                    onClicked:
                                                        Services.ClipboardService.togglePin(
                                                            modelData.sourceIndex
                                                        )
                                                }

                                                ToolButton {
                                                    id: removeButton
                                                    Layout.preferredWidth: Style.barIconSmall
                                                    Layout.preferredHeight: Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: "Remove"
                                                    background: Rectangle {
                                                        radius: Style.radiusSmall
                                                        color: removeButton.hovered
                                                            ? Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: MaterialIcon {
                                                        text: "close"
                                                        color: removeButton.hovered
                                                            ? Color.foreground
                                                            : Color.foregroundMuted
                                                        font.pixelSize: Style.materialIconSmall
                                                    }
                                                    onClicked:
                                                        Services.ClipboardService.remove(
                                                            modelData.sourceIndex
                                                        )
                                                }
                                            }

                                            Image {
                                                visible: modelData.type === "image"
                                                width: parent.width
                                                height: 164
                                                source: modelData.type === "image"
                                                    ? "file://" + modelData.imagePath
                                                    : ""
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: true
                                            }

                                            Text {
                                                visible: modelData.type !== "image"
                                                width: parent.width
                                                text: modelData.preview
                                                textFormat: Text.PlainText
                                                color: Color.foreground
                                                font.pixelSize: Style.fontSmall
                                                wrapMode: Text.Wrap
                                                maximumLineCount: modelData.type === "code"
                                                    ? 4
                                                    : 2
                                                elide: Text.ElideRight
                                            }
                                        }

                                        HoverHandler {
                                            id: cardHover
                                        }

                                        TapHandler {
                                            onTapped:
                                                Services.ClipboardService.copyEntry(
                                                    modelData
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No clipboard entries"
                        color: Color.foregroundMuted
                        font.pixelSize: Style.fontSmall
                        visible: root.visibleEntries.length === 0
                    }
                }
            }
        }
    }
}
