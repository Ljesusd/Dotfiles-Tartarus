import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../theme"
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
        anchors.margins: Style.paddingLarge
        spacing: Style.spacingSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacingMedium

            MaterialIcon {
                text: "calculate"
                iconSize: Style.materialIconMedium
                iconColor: Color.primary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Style.spacingXs

                Text {
                    text: "Calculadora científica"
                    color: Color.foreground
                    font.pixelSize: Style.fontNormal
                    font.weight: Font.DemiBold
                }

                Text {
                    text: "Qalculate · funciones, unidades y LaTeX"
                    color: Color.foregroundMuted
                    font.pixelSize: Style.fontSmall
                }
            }

            MaterialIcon {
                text: "backspace"
                iconSize: Style.materialIconSmall
                iconColor: Color.foregroundMuted
                TapHandler { onTapped: root.backspace() }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: Style.radiusMedium
            color: Color.surfaceContainerHigh
            border.width: Style.panelBorderWidth
            border.color: Color.outlineVariant

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Style.paddingSmall
                spacing: Style.spacingXs

                TextInput {
                    id: expressionInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: root.expression
                    color: Color.foreground
                    font.pixelSize: Style.fontNormal
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
                    color: root.latex !== "" ? Color.primary : Color.foregroundMuted
                    font.family: Style.materialIconFont
                    font.pixelSize: Style.fontSmall
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacingSmall

            Text {
                Layout.fillWidth: true
                text: root.errorText !== "" ? root.errorText : root.result
                color: root.errorText !== "" ? Color.error : Color.foreground
                font.pixelSize: Style.fontLarge
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                text: "qalc"
                color: Color.foregroundMuted
                font.pixelSize: Style.fontSmall
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 5
            rowSpacing: Style.spacingXs
            columnSpacing: Style.spacingXs

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
                    radius: Style.radiusMedium
                    color: modelData === "=" ? Color.primaryContainer : Color.surfaceContainerHigh
                    border.width: Style.panelBorderWidth
                    border.color: Color.outlineVariant

                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: modelData === "=" ? Color.onPrimaryContainer : Color.foreground
                        font.pixelSize: Style.fontSmall
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
