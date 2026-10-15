import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

import "../../services" as Services
import "../../theme" as Theme
import "."

FloatingWindow {
    id: root

    required property var shellState

    readonly property var targetContext: {
        if (!root.shellState)
            return null

        const name = Services.ImageViewerService.targetScreenName
        const contexts = root.shellState.monitorContexts || []
        return contexts.find(
            context => context.name === name
        ) || null
    }
    readonly property string viewerPath:
        root.targetContext?.imageViewerPath ?? ""

    title: Services.ImageViewerService.fileNameFor(
        root.viewerPath
    )
        + " - Tartarus Image Viewer"

    readonly property var targetScreen:
        resolveScreen(Services.ImageViewerService.targetScreenName)

    screen: root.targetScreen
    visible:
        root.targetContext?.imageViewerOpen === true
        && root.targetScreen !== null
    color: Theme.Color.background
    minimumSize: Qt.size(560, 315)

    // Keep the viewer compact on the target monitor. FloatingWindow lets
    // the compositor place this normal toplevel, while the viewport keeps
    // the image fitted without changing its aspect ratio.
    implicitWidth: root.targetScreen
        ? Math.max(
            root.minimumSize.width,
            Math.round(root.targetScreen.width * 0.50)
        )
        : 960
    implicitHeight: root.targetScreen
        ? Math.max(
            root.minimumSize.height,
            Math.round(root.targetScreen.height * 0.56)
        )
        : 640

    function resolveScreen(screenName) {
        if (screenName && screenName.length > 0) {
            for (let i = 0; i < Quickshell.screens.length; ++i) {
                const screen = Quickshell.screens[i]

                if (screen && screen.name === screenName)
                    return screen
            }
        }

        return null
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut

        onActivated: {
            Services.ImageViewerService.close()
        }
    }

    Shortcut {
        sequence: "F"
        context: Qt.WindowShortcut

        onActivated: {
            root.fullscreen = !root.fullscreen
        }
    }

    Shortcut {
        sequence: "0"
        context: Qt.WindowShortcut

        onActivated: {
            viewport.resetView()
        }
    }

    Shortcut {
        sequences: ["Ctrl++", "Ctrl+="]
        context: Qt.WindowShortcut

        onActivated: {
            viewport.zoomIn()
        }
    }

    Shortcut {
        sequence: "Ctrl+-"
        context: Qt.WindowShortcut

        onActivated: {
            viewport.zoomOut()
        }
    }

    onClosed: {
        Services.ImageViewerService.close()
    }

    ImageViewport {
        id: viewport
        anchors.fill: parent
        imagePath: root.viewerPath
    }

    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 44
        color: Theme.Color.surfaceContainer
        z: 4

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 8
            spacing: Theme.Style.spacingXs

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: viewport.drawing ? "edit_off" : "edit"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }
                ToolTip.text: viewport.drawing ? "Desactivar dibujo" : "Dibujar"
                ToolTip.visible: hovered
                onClicked: viewport.drawing = !viewport.drawing
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: "delete_sweep"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }
                ToolTip.text: "Borrar dibujo"
                ToolTip.visible: hovered
                onClicked: viewport.clearDrawing()
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: "remove"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }
                background: Rectangle {
                    radius: Theme.Style.radiusSmall
                    color: parent.pressed ? Theme.Color.selection
                        : parent.hovered ? Theme.Color.surfaceHover : "transparent"
                }
                onClicked: viewport.zoomOut()
            }

            Label {
                text: Math.round(viewport.userScale * 100) + "%"
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.Color.foreground
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: "add"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }
                background: Rectangle {
                    radius: Theme.Style.radiusSmall
                    color: parent.pressed ? Theme.Color.selection
                        : parent.hovered ? Theme.Color.surfaceHover : "transparent"
                }
                onClicked: viewport.zoomIn()
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: "restart_alt"
                    color: Theme.Color.foreground
                    font.pixelSize: 18
                }
                background: Rectangle {
                    radius: Theme.Style.radiusSmall
                    color: parent.pressed ? Theme.Color.selection
                        : parent.hovered ? Theme.Color.surfaceHover : "transparent"
                }
                onClicked: viewport.resetView()
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: root.fullscreen ? "fullscreen_exit" : "fullscreen"
                    color: Theme.Color.foreground
                    font.pixelSize: 18
                }
                background: Rectangle {
                    radius: Theme.Style.radiusSmall
                    color: parent.pressed ? Theme.Color.selection
                        : parent.hovered ? Theme.Color.surfaceHover : "transparent"
                }
                onClicked: root.fullscreen = !root.fullscreen
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: "save_as"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }
                ToolTip.text: "Guardar como…"
                ToolTip.visible: hovered
                background: Rectangle {
                    radius: Theme.Style.radiusSmall
                    color: parent.pressed ? Theme.Color.selection
                        : parent.hovered ? Theme.Color.surfaceHover : "transparent"
                }
                onClicked: saveDialog.open()
            }

            ToolButton {
                display: AbstractButton.IconOnly
                contentItem: Theme.MaterialIcon {
                    text: "close"
                    color: parent.parent.hovered ? Theme.Color.error : Theme.Color.foreground
                    font.pixelSize: Theme.Style.materialIconMedium
                }
                ToolTip.text: "Cerrar"
                ToolTip.visible: hovered
                background: Rectangle {
                    radius: Theme.Style.radiusSmall
                    color: parent.pressed ? Theme.Color.error
                        : parent.hovered ? Theme.Color.surfaceHover : "transparent"
                }
                onClicked: Services.ImageViewerService.close()
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: "Guardar imagen como…"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PNG (*.png)", "JPEG (*.jpg *.jpeg)", "Todos los archivos (*)"]

        onAccepted: {
            const destination = selectedFile.toString().replace("file://", "")
            viewport.grabToImage(function(result) {
                result.saveToFile(destination)
            })
        }
    }
}
