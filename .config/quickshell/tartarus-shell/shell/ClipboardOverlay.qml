import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "../theme" as Theme

Scope {
    id: root

    required property ShellScreen monitorScreen
    required property var monitorContext

    readonly property bool isFocused:
        Hyprland.focusedMonitor
        && root.monitorScreen
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

            width: Math.min(
                760,
                Math.max(320, (root.monitorScreen?.width ?? 1280) - Theme.Style.spacingLarge * 2)
            )
            height: Math.min(
                620,
                Math.max(420, (root.monitorScreen?.height ?? 800) - Theme.Style.barHeight - Theme.Style.spacingLarge * 2)
            )
            anchors.centerIn: parent
            radius: Theme.Style.radiusLarge
            color: Theme.Color.surfaceContainer
            border.width: 1
            border.color: Theme.Color.outline

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingLarge
                spacing: Theme.Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true

                    Theme.MaterialIcon {
                        text: "content_paste"
                        color: Theme.Color.accent
                        font.pixelSize: Theme.Style.materialIconMedium
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Clipboard"
                        color: Theme.Color.foreground
                        font.pixelSize: Theme.Style.fontNormal
                        font.bold: true
                    }

                    Text {
                        text: `${root.visibleEntries.length} items`
                        color: Theme.Color.foregroundSubtle
                        font.pixelSize: Theme.Style.fontSmall
                    }

                    ToolButton {
                        id: clearButton
                        implicitWidth: Theme.Style.controlHeight
                        implicitHeight: Theme.Style.controlHeight
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Clear recent entries"
                        background: Rectangle {
                            radius: Theme.Style.radiusSmall
                            color: clearButton.hovered
                                ? Theme.Color.surfaceHover
                                : "transparent"
                        }
                        contentItem: Theme.MaterialIcon {
                            text: "delete_sweep"
                            color: clearButton.hovered
                                ? Theme.Color.foreground
                                : Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconMedium
                        }
                        onClicked: Services.ClipboardService.clear()
                    }

                    ToolButton {
                        id: closeButton
                        implicitWidth: Theme.Style.controlHeight
                        implicitHeight: Theme.Style.controlHeight
                        display: AbstractButton.IconOnly
                        ToolTip.visible: hovered
                        ToolTip.text: "Close"
                        background: Rectangle {
                            radius: Theme.Style.radiusSmall
                            color: closeButton.hovered
                                ? Theme.Color.surfaceHover
                                : "transparent"
                        }
                        contentItem: Theme.MaterialIcon {
                            text: "close"
                            color: closeButton.hovered
                                ? Theme.Color.foreground
                                : Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconMedium
                        }
                        onClicked: Services.ClipboardService.close()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.Style.spacingSmall

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
                            padding: Theme.Style.paddingSmall
                            highlighted:
                                Services.ClipboardService.viewMode
                                === modelData.mode

                            background: Rectangle {
                                radius: Theme.Style.radiusSmall
                                color: modeButton.highlighted
                                    ? Theme.Color.selection
                                    : modeButton.hovered
                                        ? Theme.Color.surfaceHover
                                        : "transparent"
                            }

                                contentItem: Text {
                                    text: modeButton.text
                                    color: modeButton.highlighted
                                        ? Theme.Color.foreground
                                        : Theme.Color.foregroundMuted
                                    font.bold: modeButton.highlighted
                                    font.pixelSize: Theme.Style.fontSmall
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
                    Layout.preferredHeight: Theme.Style.controlHeight
                    radius: Theme.Style.radiusMedium
                    color: Theme.Color.surface
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Theme.Color.accent

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.Style.paddingMedium
                        anchors.rightMargin: Theme.Style.paddingMedium

                        Theme.MaterialIcon {
                            text: "search"
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.materialIconMedium
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            focus: true
                            color: Theme.Color.foreground
                            font.pixelSize: Theme.Style.fontSmall
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
                            color: Theme.Color.foregroundMuted
                            font.pixelSize: Theme.Style.fontSmall
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
                        spacing: Theme.Style.spacingSmall

                        Repeater {
                            model: 3

                            delegate: Column {
                                required property int index

                                width: (
                                    columnsRow.width
                                    - Theme.Style.spacingSmall * 2
                                ) / 3
                                spacing: Theme.Style.spacingSmall

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
                                        radius: Theme.Style.radiusMedium
                                        border.width: modelData.filteredIndex
                                            === Services.ClipboardService.selectedIndex
                                            ? 1
                                            : 0
                                        border.color: Theme.Color.accent
                                        color: modelData.filteredIndex
                                            === Services.ClipboardService.selectedIndex
                                            ? Theme.Color.selection
                                            : cardHover.hovered
                                                ? Theme.Color.surfaceHover
                                                : Theme.Color.surface
                                        clip: true

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: Theme.Style.paddingSmall
                                            spacing: Theme.Style.spacingXs

                                            RowLayout {
                                                width: parent.width
                                                height: Theme.Style.barIconSmall
                                                spacing: Theme.Style.spacingXs

                                                Theme.MaterialIcon {
                                                    text: modelData.icon
                                                    color: Theme.Color.accent
                                                    font.pixelSize: Theme.Style.materialIconSmall
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.label
                                                    color: Theme.Color.foregroundMuted
                                                    font.pixelSize: Theme.Style.fontSmall
                                                    elide: Text.ElideRight
                                                }

                                                ToolButton {
                                                    id: copyButton
                                                    Layout.preferredWidth: Theme.Style.barIconSmall
                                                    Layout.preferredHeight: Theme.Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: "Copy"
                                                    background: Rectangle {
                                                        radius: Theme.Style.radiusSmall
                                                        color: copyButton.hovered
                                                            ? Theme.Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: Theme.MaterialIcon {
                                                        text: "content_copy"
                                                        color: copyButton.hovered
                                                            ? Theme.Color.foreground
                                                            : Theme.Color.foregroundMuted
                                                        font.pixelSize: Theme.Style.materialIconSmall
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
                                                        ? Theme.Style.barIconSmall
                                                        : 0
                                                    Layout.preferredHeight: Theme.Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: modelData.type === "image"
                                                        ? "Open in viewer"
                                                        : "Open"
                                                    background: Rectangle {
                                                        radius: Theme.Style.radiusSmall
                                                        color: openButton.hovered
                                                            ? Theme.Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: Theme.MaterialIcon {
                                                        text: modelData.type === "image"
                                                            ? "visibility"
                                                            : modelData.type === "path"
                                                                ? "folder_open"
                                                                : "open_in_new"
                                                        color: openButton.hovered
                                                            ? Theme.Color.foreground
                                                            : Theme.Color.foregroundMuted
                                                        font.pixelSize: Theme.Style.materialIconSmall
                                                    }
                                                    onClicked:
                                                        Services.ClipboardService.openEntry(
                                                            modelData,
                                                            root.monitorScreen?.name ?? ""
                                                        )
                                                }

                                                ToolButton {
                                                    id: pinButton
                                                    Layout.preferredWidth: Theme.Style.barIconSmall
                                                    Layout.preferredHeight: Theme.Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: modelData.pinned
                                                        ? "Unpin"
                                                        : "Pin"
                                                    background: Rectangle {
                                                        radius: Theme.Style.radiusSmall
                                                        color: pinButton.hovered
                                                            ? Theme.Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: Theme.MaterialIcon {
                                                        text: modelData.pinned
                                                            ? "push_pin"
                                                            : "push_pin"
                                                        color: modelData.pinned
                                                            ? Theme.Color.accent
                                                                : pinButton.hovered
                                                                ? Theme.Color.foreground
                                                                : Theme.Color.foregroundMuted
                                                        font.pixelSize: Theme.Style.materialIconSmall
                                                    }
                                                    onClicked:
                                                        Services.ClipboardService.togglePin(
                                                            modelData.sourceIndex
                                                        )
                                                }

                                                ToolButton {
                                                    id: removeButton
                                                    Layout.preferredWidth: Theme.Style.barIconSmall
                                                    Layout.preferredHeight: Theme.Style.barIconSmall
                                                    padding: 0
                                                    display: AbstractButton.IconOnly
                                                    ToolTip.visible: hovered
                                                    ToolTip.text: "Remove"
                                                    background: Rectangle {
                                                        radius: Theme.Style.radiusSmall
                                                        color: removeButton.hovered
                                                            ? Theme.Color.surfaceHover
                                                            : "transparent"
                                                    }
                                                    contentItem: Theme.MaterialIcon {
                                                        text: "close"
                                                        color: removeButton.hovered
                                                            ? Theme.Color.foreground
                                                            : Theme.Color.foregroundMuted
                                                        font.pixelSize: Theme.Style.materialIconSmall
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
                                                color: Theme.Color.foreground
                                                font.pixelSize: Theme.Style.fontSmall
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
                        color: Theme.Color.foregroundMuted
                        font.pixelSize: Theme.Style.fontSmall
                        visible: root.visibleEntries.length === 0
                    }
                }
            }
        }
    }
}
