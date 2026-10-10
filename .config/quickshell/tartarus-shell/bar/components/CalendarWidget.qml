import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import "../../theme"
import "../../services" as Services
import "../../launcher/components" as LauncherComponents

Item {
    id: root
    required property Item anchorSurface
    required property var shellState
    signal closeLauncherRequested()
    property bool popupOpen: false
    property bool newTaskOpen: false
    property string taskText: ""
    property string taskTime: ""
    property string taskFeedback: ""
    property bool taskFeedbackSuccess: false
    property string viewMode: "month"
    property string viewedDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
    property string viewedMonth: Qt.formatDate(new Date(new Date().getFullYear(), new Date().getMonth(), 1, 12), "yyyy-MM-dd")

    readonly property var monthNames: ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    readonly property var weekdayNames: ["L", "M", "X", "J", "V", "S", "D"]

    function dateKey(date) {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    function monthCells() {
        const first = new Date(root.viewedMonth + "T12:00:00")
        const year = first.getFullYear()
        const month = first.getMonth()
        const firstWeekday = (first.getDay() + 6) % 7
        const cells = []
        for (let index = 0; index < 42; index++) {
            const day = new Date(year, month, index - firstWeekday + 1, 12)
            cells.push({
                date: root.dateKey(day),
                day: day.getDate(),
                inMonth: day.getMonth() === month,
                today: root.dateKey(day) === root.dateKey(new Date())
            })
        }
        return cells
    }

    function monthLabel() {
        const date = new Date(root.viewedMonth + "T12:00:00")
        return root.monthNames[date.getMonth()] + " " + date.getFullYear()
    }

    function selectedDateLabel() {
        const date = new Date(root.viewedDate + "T12:00:00")
        const weekdays = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
        return weekdays[date.getDay()] + " " + date.getDate() + " de " + root.monthNames[date.getMonth()].toLowerCase()
    }

    function weekStart(date) {
        const value = new Date(date + "T12:00:00")
        value.setDate(value.getDate() - ((value.getDay() + 6) % 7))
        return value
    }

    function weekDays() {
        const start = root.weekStart(root.viewedDate)
        const days = []
        for (let index = 0; index < 7; index++) {
            const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + index, 12)
            days.push({
                date: root.dateKey(date),
                day: date.getDate(),
                label: root.weekdayNames[index]
            })
        }
        return days
    }

    function agendaDays() {
        return root.weekDays().filter(day => Services.CalendarService.eventsForDate(day.date).length > 0)
    }

    function weekLabel() {
        const days = root.weekDays()
        const first = new Date(days[0].date + "T12:00:00")
        const last = new Date(days[6].date + "T12:00:00")
        if (first.getMonth() === last.getMonth())
            return first.getDate() + "–" + last.getDate() + " de " + root.monthNames[first.getMonth()]
        return first.getDate() + " de " + root.monthNames[first.getMonth()] + " – " + last.getDate() + " de " + root.monthNames[last.getMonth()]
    }

    function selectDate(date) {
        root.viewedDate = date
        const selected = new Date(date + "T12:00:00")
        root.viewedMonth = root.dateKey(new Date(selected.getFullYear(), selected.getMonth(), 1, 12))
    }

    function changeMonth(amount) {
        const current = new Date(root.viewedMonth + "T12:00:00")
        const next = new Date(current.getFullYear(), current.getMonth() + amount, 1, 12)
        root.viewedMonth = root.dateKey(next)
        root.viewedDate = root.dateKey(next)
    }

    function changeRange(amount) {
        if (root.viewMode === "agenda") {
            const current = new Date(root.viewedDate + "T12:00:00")
            current.setDate(current.getDate() + amount * 7)
            root.selectDate(root.dateKey(current))
            return
        }
        root.changeMonth(amount)
    }

    function submitTask() {
        const value = root.taskText.trim()
        if (value === "") {
            root.taskFeedback = "Escribe una tarea antes de añadirla"
            root.taskFeedbackSuccess = false
            return
        }
        if (root.taskTime !== "" && !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(root.taskTime)) {
            root.taskFeedback = "La hora debe tener el formato HH:MM"
            root.taskFeedbackSuccess = false
            return
        }
        if (Services.CalendarService.addTimedTask(value, root.viewedDate, root.taskTime)) {
            root.taskText = ""
            root.taskTime = ""
            root.newTaskOpen = false
            root.taskFeedback = "Tarea añadida"
            root.taskFeedbackSuccess = true
            taskFeedbackTimer.restart()
        } else {
            root.taskFeedback = "No se pudo guardar la tarea"
            root.taskFeedbackSuccess = false
        }
    }

    implicitWidth: Style.barControlHeight
    implicitHeight: Style.barControlHeight

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusFull
        color: root.popupOpen ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.18) : "transparent"
        Behavior on color { ColorAnimation { duration: Style.motionFast } }
        MaterialIcon { anchors.centerIn: parent; text: "calendar_month"; iconSize: Style.barIconNormal; iconColor: Color.foreground }
        Rectangle {
            visible: Services.CalendarService.todayEvents.length > 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            width: 7; height: 7; radius: width / 2
            color: Color.primary
            border.width: 1; border.color: Color.surfaceContainer
        }
        TapHandler {
            onTapped: {
                root.closeLauncherRequested()
                root.viewedDate = Qt.formatDate(new Date(), "yyyy-MM-dd")
                root.viewedMonth = Qt.formatDate(new Date(new Date().getFullYear(), new Date().getMonth(), 1, 12), "yyyy-MM-dd")
                root.popupOpen = !root.popupOpen
            }
        }
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.adjustment: PopupAdjustment.Slide
        implicitWidth: Math.min(680, Math.max(360, (root.anchorSurface?.width || 1280) - 32))
        implicitHeight: 610
        color: "transparent"
        visible: root.popupOpen || surface.reveal > 0
        mask: Region { item: surface.maskItem }

        LauncherComponents.LauncherSurface {
            id: surface
            anchors.fill: parent
            opened: root.popupOpen
            contentWidth: popup.width - horizontalInset * 2
            contentHeight: popup.height - shadowPadding

            ColumnLayout {
                parent: surface.contentItem
                anchors.fill: parent
                anchors.leftMargin: Style.paddingLarge
                anchors.rightMargin: Style.paddingLarge
                anchors.topMargin: Style.paddingLarge
                anchors.bottomMargin: Style.paddingLarge
                spacing: Style.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    MaterialIcon { text: "event"; iconSize: Style.materialIconMedium; iconColor: Color.primary }
                    ColumnLayout { Layout.fillWidth: true; Text { text: "Calendario"; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true } Text { text: Services.CalendarService.loading ? "Actualizando…" : Services.CalendarService.configured ? "Agenda sincronizada" : Services.CalendarService.localTasks.length > 0 ? "Tareas locales" : "Añade un feed iCalendar"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall } }
                    MaterialIcon { text: "refresh"; iconSize: Style.materialIconSmall; iconColor: Color.foregroundMuted; TapHandler { onTapped: Services.CalendarService.refresh() } }
                    MaterialIcon { text: "close"; iconSize: Style.materialIconSmall; iconColor: Color.foregroundMuted; TapHandler { onTapped: root.popupOpen = false } }
                }

                RowLayout {
                    Layout.fillWidth: true
                    ActionButton { text: "‹"; onClicked: root.changeRange(-1) }
                    Text { Layout.fillWidth: true; text: root.viewMode === "agenda" ? root.weekLabel() : root.monthLabel(); color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; horizontalAlignment: Text.AlignHCenter }
                    ActionButton { text: "Hoy"; implicitWidth: 52; onClicked: root.selectDate(Qt.formatDate(new Date(), "yyyy-MM-dd")) }
                    ActionButton { text: root.viewMode === "agenda" ? "Mes" : "Agenda"; implicitWidth: 70; accented: root.viewMode === "agenda"; onClicked: root.viewMode = root.viewMode === "agenda" ? "month" : "agenda" }
                    ActionButton { text: "›"; onClicked: root.changeRange(1) }
                }

                RowLayout {
                    visible: root.viewMode === "month"
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.weekdayNames
                        delegate: Text {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            color: Color.foregroundMuted
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                GridLayout {
                    id: monthGrid
                    visible: root.viewMode === "month"
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 6
                    rowSpacing: 6
                    Repeater {
                        model: root.monthCells()
                        delegate: Rectangle {
                            id: dayCell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 43
                            radius: Style.controlRadius
                            color: root.viewedDate === dayCell.modelData.date
                                ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.30)
                                : dayCell.modelData.today
                                    ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.12)
                                    : "transparent"
                            border.width: root.viewedDate === dayCell.modelData.date || dayCell.modelData.today ? 1 : 0
                            border.color: Color.primary
                            opacity: dayCell.modelData.inMonth ? 1 : 0.38
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    text: dayCell.modelData.day
                                    color: root.viewedDate === dayCell.modelData.date ? Color.foreground : Color.foregroundMuted
                                    font.pixelSize: Style.fontSmall
                                    font.bold: root.viewedDate === dayCell.modelData.date || dayCell.modelData.today
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Rectangle {
                                    visible: Services.CalendarService.eventsForDate(dayCell.modelData.date).length > 0
                                    Layout.preferredWidth: 6
                                    Layout.preferredHeight: 6
                                    radius: 3
                                    color: Color.primary
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                            TapHandler { onTapped: root.selectDate(dayCell.modelData.date) }
                        }
                    }
                }

                Rectangle {
                    visible: root.viewMode === "month"
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Color.outlineVariant
                    opacity: 0.6
                }

                RowLayout {
                    visible: root.viewMode === "month"
                    Layout.fillWidth: true
                    Text { text: root.selectedDateLabel(); color: Color.foreground; font.pixelSize: Style.fontSmall; font.bold: true; Layout.fillWidth: true }
                    Text { text: Services.CalendarService.eventsForDate(root.viewedDate).length + " elementos"; color: Color.foregroundMuted; font.pixelSize: 12 }
                    ActionButton { text: "+ Tarea"; implicitWidth: 76; accented: true; onClicked: { root.newTaskOpen = !root.newTaskOpen; root.taskFeedback = ""; if (!root.newTaskOpen) { root.taskText = ""; root.taskTime = "" } } }
                }

                RowLayout {
                    visible: root.viewMode === "month" && root.newTaskOpen
                    Layout.fillWidth: true
                    spacing: Style.spacingSmall
                    TextField {
                        id: taskField
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        placeholderText: "Tarea para " + root.selectedDateLabel()
                        text: root.taskText
                        onTextEdited: root.taskText = text
                        onAccepted: root.submitTask()
                        color: Color.foreground
                        placeholderTextColor: Color.foregroundMuted
                        background: Rectangle { radius: Style.controlRadius; color: Color.surfaceContainerHigh; border.width: 1; border.color: Color.outlineVariant }
                    }
                    TextField {
                        id: taskTimeField
                        Layout.preferredWidth: 66
                        Layout.minimumWidth: 66
                        placeholderText: "HH:MM"
                        maximumLength: 5
                        text: root.taskTime
                        onTextEdited: root.taskTime = text
                        onAccepted: root.submitTask()
                        color: Color.foreground
                        placeholderTextColor: Color.foregroundMuted
                        horizontalAlignment: Text.AlignHCenter
                        background: Rectangle { radius: Style.controlRadius; color: Color.surfaceContainerHigh; border.width: 1; border.color: Color.outlineVariant }
                    }
                    ActionButton {
                        text: "Añadir"
                        implicitWidth: 76
                        accented: true
                        onClicked: root.submitTask()
                    }
                }

                Text {
                    visible: root.viewMode === "month" && (root.taskFeedback !== "" || Services.CalendarService.taskSaveError !== "")
                    text: Services.CalendarService.taskSaveError !== "" ? "No se pudo guardar: " + Services.CalendarService.taskSaveError : root.taskFeedback
                    color: Services.CalendarService.taskSaveError !== "" ? Color.error : root.taskFeedbackSuccess ? Color.success : Color.warning
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Flickable {
                    visible: root.viewMode === "month"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: eventsColumn.implicitHeight
                    clip: true
                    ColumnLayout {
                        id: eventsColumn
                        width: parent.width
                        spacing: Style.spacingSmall
                        Repeater {
                            model: Services.CalendarService.eventsForDate(root.viewedDate)
                            delegate: Rectangle {
                                id: eventCard
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: 64
                                radius: Style.controlRadius
                                color: eventCard.modelData.task ? Color.secondaryContainer : Color.surfaceContainerHigh
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Style.paddingSmall
                                    spacing: Style.spacingSmall
                                    Rectangle { Layout.preferredWidth: 4; Layout.fillHeight: true; radius: 2; color: eventCard.modelData.task ? Color.secondary : Color.primary }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: eventCard.modelData.task ? "Tarea · " + eventCard.modelData.title : eventCard.modelData.title; color: eventCard.modelData.completed ? Color.foregroundMuted : Color.foreground; font.pixelSize: Style.fontSmall; font.bold: true; font.strikeout: Boolean(eventCard.modelData.completed); Layout.fillWidth: true; elide: Text.ElideRight }
                                        Text { text: eventCard.modelData.task ? (eventCard.modelData.completed ? "Completada" : (eventCard.modelData.time ? "Alarma a las " + eventCard.modelData.time : "Tarea local")) : Services.CalendarService.formatEventTime(eventCard.modelData) + (eventCard.modelData.location ? " · " + eventCard.modelData.location : ""); color: Color.foregroundMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                    ActionButton { visible: Boolean(eventCard.modelData.task); text: eventCard.modelData.completed ? "✓" : "○"; implicitWidth: 32; onClicked: Services.CalendarService.toggleTask(eventCard.modelData.id) }
                                    ActionButton { visible: Boolean(eventCard.modelData.task); text: "×"; implicitWidth: 32; onClicked: Services.CalendarService.removeTask(eventCard.modelData.id) }
                                }
                            }
                        }
                        ColumnLayout {
                            visible: Services.CalendarService.eventsForDate(root.viewedDate).length === 0
                            Layout.fillWidth: true
                            spacing: Style.spacingSmall
                            Text { text: Services.CalendarService.configured ? "No hay eventos este día" : "Configura una URL iCalendar para mostrar tu agenda"; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                            ActionButton {
                                visible: !Services.CalendarService.configured
                                Layout.alignment: Qt.AlignHCenter
                                text: "Configurar calendario"
                                onClicked: {
                                    root.popupOpen = false
                                    root.shellState.openControlCenterPage(10)
                                }
                            }
                        }
                    }
                }

                Flickable {
                    id: agendaFlickable
                    visible: root.viewMode === "agenda"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: agendaColumn.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: agendaColumn
                        width: parent.width
                        spacing: Style.spacingSmall

                        Repeater {
                            model: root.agendaDays()
                            delegate: ColumnLayout {
                                id: weekDaySection
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 4

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: Style.controlRadius
                                    color: weekDaySection.modelData.date === root.viewedDate ? Qt.rgba(Color.primary.r, Color.primary.g, Color.primary.b, 0.22) : Color.surfaceContainerHigh
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Style.paddingSmall
                                        anchors.rightMargin: Style.paddingSmall
                                        Text {
                                            text: weekDaySection.modelData.label + "  " + weekDaySection.modelData.day
                                            color: Color.foreground
                                            font.pixelSize: Style.fontSmall
                                            font.bold: true
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            text: Services.CalendarService.eventsForDate(weekDaySection.modelData.date).length + " elementos"
                                            color: Color.foregroundMuted
                                            font.pixelSize: 12
                                        }
                                    }
                                    TapHandler { onTapped: root.selectDate(weekDaySection.modelData.date) }
                                }

                                Repeater {
                                    model: Services.CalendarService.eventsForDate(weekDaySection.modelData.date)
                                    delegate: Rectangle {
                                        id: agendaEventCard
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 56
                                        radius: Style.controlRadius
                                        color: agendaEventCard.modelData.task ? Color.secondaryContainer : Color.surfaceContainerHigh
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Style.paddingSmall
                                            spacing: Style.spacingSmall
                                            Rectangle { Layout.preferredWidth: 4; Layout.fillHeight: true; radius: 2; color: agendaEventCard.modelData.task ? Color.secondary : Color.primary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Text { text: agendaEventCard.modelData.task ? agendaEventCard.modelData.title : agendaEventCard.modelData.title; color: agendaEventCard.modelData.completed ? Color.foregroundMuted : Color.foreground; font.pixelSize: Style.fontSmall; font.bold: true; font.strikeout: Boolean(agendaEventCard.modelData.completed); Layout.fillWidth: true; elide: Text.ElideRight }
                                                Text { text: agendaEventCard.modelData.task ? (agendaEventCard.modelData.completed ? "Completada" : (agendaEventCard.modelData.time ? "Tarea · " + agendaEventCard.modelData.time : "Tarea local")) : Services.CalendarService.formatEventTime(agendaEventCard.modelData) + (agendaEventCard.modelData.location ? " · " + agendaEventCard.modelData.location : ""); color: Color.foregroundMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                                            }
                                            ActionButton { visible: Boolean(agendaEventCard.modelData.task); text: agendaEventCard.modelData.completed ? "✓" : "○"; implicitWidth: 32; onClicked: Services.CalendarService.toggleTask(agendaEventCard.modelData.id) }
                                            ActionButton { visible: Boolean(agendaEventCard.modelData.task); text: "×"; implicitWidth: 32; onClicked: Services.CalendarService.removeTask(agendaEventCard.modelData.id) }
                                        }
                                    }
                                }

                            }
                        }

                        Text {
                            visible: root.agendaDays().length === 0
                            text: "No hay eventos esta semana"
                            color: Color.foregroundMuted
                            font.pixelSize: Style.fontSmall
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: Style.paddingLarge
                        }
                    }
                }

                Text { visible: Services.CalendarService.errorMessage !== ""; text: Services.CalendarService.errorMessage; color: Color.error; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            }
        }
    }

    component ActionButton: Button {
        id: actionButton
        property bool accented: false
        implicitWidth: Math.max(34, contentItem.implicitWidth + 22)
        implicitHeight: 34
        padding: 0
        contentItem: Text { text: actionButton.text; color: actionButton.accented ? Color.onPrimary : Color.foreground; font.pixelSize: Style.fontSmall; font.bold: actionButton.accented; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle {
            radius: Style.radiusFull
            color: actionButton.down ? Color.primary : actionButton.accented ? Color.primaryContainer : actionButton.hovered ? Color.surfaceHover : Color.surfaceContainerHigh
            border.width: actionButton.accented || actionButton.hovered ? 1 : 0
            border.color: actionButton.accented ? Color.primary : Color.outlineVariant
            Behavior on color { ColorAnimation { duration: Style.motionFast } }
        }
    }

    Timer {
        id: taskFeedbackTimer
        interval: 2800
        repeat: false
        onTriggered: root.taskFeedback = ""
    }
}
