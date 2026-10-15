import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../theme" as Theme
import "../components"

Item {
    id: root

    required property var controller
    required property bool active
    visible: root.active

    property string expression: ""
    property string result: ""
    property string latex: ""
    property string errorText: ""

    function append(value) {
        root.expression += value
        expressionInput.forceActiveFocus()
        root.scheduleEvaluation()
    }

    function backspace() {
        root.expression = root.expression.slice(0, -1)
        root.scheduleEvaluation()
    }

    function scheduleEvaluation() {
        evaluationDelay.restart()
    }

    function evaluate() {
        const value = root.expression.trim()
        if (value === "") {
            root.result = ""
            root.latex = ""
            root.errorText = ""
            return
        }

        root.errorText = ""
        numericProcess.command = ["sh", "-c", "qalc -t \"$1\"", "qalc", value]
        latexProcess.command = ["sh", "-c", "qalc -t \"$1 to latex\"", "qalc", value]
        numericProcess.running = true
        latexProcess.running = true
    }

    onActiveChanged: {
        if (root.active) {
            root.expression = root.controller.calculatorQuery
            Qt.callLater(() => expressionInput.forceActiveFocus())
            root.scheduleEvaluation()
        }
    }

    Timer {
        id: evaluationDelay
        interval: 160
        repeat: false
        onTriggered: root.evaluate()
    }

    Process {
        id: numericProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const output = String(text).trim()
                root.result = output
                if (output === "" || output.toLowerCase().includes("error"))
                    root.errorText = output || "No se pudo calcular"
            }
        }
    }

    Process {
        id: latexProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.latex = String(text).trim()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.Style.paddingLarge
        spacing: Theme.Style.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.spacingMedium

            Theme.MaterialIcon {
                text: "calculate"
                iconSize: Theme.Style.materialIconMedium
                iconColor: Theme.Color.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.Style.spacingXs

                Text {
                    text: "Calculadora científica"
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontNormal
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Qalculate · funciones, unidades y LaTeX"
                    color: Theme.Color.foregroundMuted
                    font.pixelSize: Theme.Style.fontSmall
                }
            }

            Theme.MaterialIcon {
                text: "backspace"
                iconSize: Theme.Style.materialIconSmall
                iconColor: Theme.Color.foregroundMuted
                TapHandler { onTapped: root.backspace() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Theme.Style.radiusMedium
            color: Theme.Color.surfaceContainerHigh
            border.width: Theme.Style.panelBorderWidth
            border.color: Theme.Color.outlineVariant

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.Style.paddingSmall
                spacing: Theme.Style.spacingXs

                TextInput {
                    id: expressionInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: root.expression
                    color: Theme.Color.foreground
                    font.pixelSize: Theme.Style.fontNormal
                    selectByMouse: true
                    onTextChanged: {
                        if (root.expression !== text)
                            root.expression = text
                        root.scheduleEvaluation()
                    }
                    Keys.onReturnPressed: root.evaluate()
                }

                Text {
                    Layout.fillWidth: true
                    text: root.latex !== "" ? root.latex : "Escribe una expresión…"
                    color: root.latex !== "" ? Theme.Color.primary : Theme.Color.foregroundMuted
                    font.family: Theme.Style.materialIconFont
                    font.pixelSize: Theme.Style.fontSmall
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.Style.spacingSmall

            Text {
                Layout.fillWidth: true
                text: root.errorText !== "" ? root.errorText : root.result
                color: root.errorText !== "" ? Theme.Color.error : Theme.Color.foreground
                font.pixelSize: Theme.Style.fontLarge
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                text: "qalc"
                color: Theme.Color.foregroundMuted
                font.pixelSize: Theme.Style.fontSmall
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 5
            rowSpacing: Theme.Style.spacingXs
            columnSpacing: Theme.Style.spacingXs

            Repeater {
                model: ["7", "8", "9", "÷", "sin(",
                        "4", "5", "6", "×", "cos(",
                        "1", "2", "3", "−", "tan(",
                        "0", ".", "(", ")", "sqrt(",
                        "π", "e", "^", "=" , "⌫",
                        "asin(", "acos(", "atan(", "ln(", "log(",
                        "cbrt(", "exp(", "abs(", "floor(", "ceil(",
                        "!", "%", "deg", "rad", "to"]

                delegate: Rectangle {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.Style.radiusMedium
                    color: modelData === "=" ? Theme.Color.primaryContainer : Theme.Color.surfaceContainerHigh
                    border.width: Theme.Style.panelBorderWidth
                    border.color: Theme.Color.outlineVariant

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: modelData === "=" ? Theme.Color.onPrimaryContainer : Theme.Color.foreground
                        font.pixelSize: Theme.Style.fontSmall
                    }

                    TapHandler {
                        onTapped: {
                            if (modelData === "=")
                                root.evaluate()
                            else if (modelData === "⌫")
                                root.backspace()
                            else
                                root.append(modelData
                                    .replace("÷", "/")
                                    .replace("×", "*")
                                    .replace("−", "-")
                                    .replace("deg", " deg ")
                                    .replace("rad", " rad ")
                                    .replace("to", " to "))
                        }
                    }
                }
            }
        }
    }
}
