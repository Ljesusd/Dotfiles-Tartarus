import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../services" as Services
import "../theme"

Item {
    id: root
    required property var monitorScreen
    readonly property string weatherText: Services.WeatherService.current
        ? Services.WeatherService.current.temp + "°C · " + Services.WeatherService.description(Services.WeatherService.current.code)
        : "Clima no disponible"
    readonly property string weatherLocation: Services.WeatherService.location
    readonly property string weatherIcon: Services.WeatherService.current
        ? Services.WeatherService.icon(Services.WeatherService.current.code, Services.WeatherService.current.isDay)
        : "cloud"
    readonly property bool weatherLoading: Services.WeatherService.loading
    readonly property date today: new Date()
    property int shownMonth: today.getMonth()
    property int shownYear: today.getFullYear()

    function monthTitle() {
        return new Date(root.shownYear, root.shownMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
    }
    function calendarCells() {
        const first = new Date(root.shownYear, root.shownMonth, 1)
        const count = new Date(root.shownYear, root.shownMonth + 1, 0).getDate()
        const offset = (first.getDay() + 6) % 7
        const cells = []
        for (let i = 0; i < offset; ++i) cells.push({ day: "", current: false })
        for (let day = 1; day <= count; ++day) {
            const current = day === root.today.getDate()
                && root.shownMonth === root.today.getMonth()
                && root.shownYear === root.today.getFullYear()
            cells.push({ day: String(day), current: current })
        }
        while (cells.length % 7) cells.push({ day: "", current: false })
        return cells
    }
    function moveMonth(delta) {
        const next = new Date(root.shownYear, root.shownMonth + delta, 1)
        root.shownMonth = next.getMonth()
        root.shownYear = next.getFullYear()
    }
    function refreshWeather() { Services.WeatherService.refresh(true) }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ColumnLayout {
            id: content
            width: parent.width
            spacing: Style.spacingMedium
            Text { text: "Dashboard"; color: Color.foreground; font.pixelSize: Style.fontLarge; font.bold: true }
            Text { text: Qt.formatDate(root.today, "dddd, d MMMM"); color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; Layout.fillWidth: true }

            DashboardCard {
                title: "Clima"
                icon: root.weatherIcon
                subtitle: root.weatherLocation || (root.weatherLoading ? "Consultando…" : "Sin ubicación")
                value: root.weatherText
                ActionButton { text: "Actualizar"; enabled: !root.weatherLoading; onClicked: root.refreshWeather() }
            }
            DashboardCard {
                title: "Reproducción"
                icon: "music_note"
                subtitle: Services.MediaService.available ? Services.MediaService.identity : "Sin reproductor activo"
                value: Services.MediaService.available ? Services.MediaService.title + " · " + Services.MediaService.artist : "—"
                ActionButton { text: "‹"; enabled: Services.MediaService.canPrevious; onClicked: Services.MediaService.command("previous") }
                ActionButton { text: Services.MediaService.playing ? "Pausa" : "Reproducir"; enabled: Services.MediaService.canToggle; onClicked: Services.MediaService.command("play-pause") }
                ActionButton { text: "›"; enabled: Services.MediaService.canNext; onClicked: Services.MediaService.command("next") }
            }
            DashboardCard {
                title: root.monthTitle()
                icon: "calendar_month"
                subtitle: "Calendario local"
                RowLayout {
                    Layout.fillWidth: true
                    ActionButton { text: "‹"; onClicked: root.moveMonth(-1) }
                    Item { Layout.fillWidth: true }
                    ActionButton { text: "›"; onClicked: root.moveMonth(1) }
                }
                GridLayout {
                    columns: 7
                    Layout.fillWidth: true
                    Repeater { model: ["L", "M", "X", "J", "V", "S", "D"]; delegate: Text { required property string modelData; text: modelData; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true } }
                    Repeater { model: root.calendarCells(); delegate: Rectangle { id: calendarCell; required property var modelData; implicitWidth: 30; implicitHeight: 28; radius: Style.radiusSmall; color: calendarCell.modelData.current ? Color.primary : "transparent"; Text { anchors.centerIn: parent; text: calendarCell.modelData.day; color: calendarCell.modelData.current ? Color.onPrimary : Color.foreground; font.pixelSize: Style.fontSmall } } }
                }
            }
            DashboardCard {
                title: "Acciones"
                icon: "bolt"
                subtitle: "Controles frecuentes"
                ActionButton { text: "Bloquear"; onClicked: Services.PowerService.lock() }
                ActionButton { text: Services.NotificationService.dnd ? "Activar notificaciones" : "No molestar"; onClicked: Services.NotificationService.toggleDnd() }
            }
        }
    }

    component DashboardCard: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        property string subtitle: ""
        property string value: ""
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + Style.paddingMedium * 2
        radius: Style.cardRadius
        color: Color.surfaceContainer
        border.width: 1
        border.color: Color.outlineVariant
        ColumnLayout {
            id: body
            anchors.fill: parent
            anchors.margins: Style.paddingMedium
            spacing: Style.spacingSmall
            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: card.icon; iconSize: Style.sectionIconSize; iconColor: Color.primary }
                Text { text: card.title; color: Color.foreground; font.pixelSize: Style.fontNormal; font.bold: true; Layout.fillWidth: true }
                Text { text: card.subtitle; color: Color.foregroundMuted; font.pixelSize: Style.fontSmall }
            }
            Text { text: card.value; color: Color.foreground; font.pixelSize: Style.fontNormal; Layout.fillWidth: true; elide: Text.ElideRight }
        }
    }
    component ActionButton: Button {
        id: actionButton
        implicitHeight: 32
        implicitWidth: Math.max(86, contentItem.implicitWidth + 20)
        contentItem: Text { text: actionButton.text; color: actionButton.enabled ? Color.foreground : Color.foregroundMuted; font.pixelSize: Style.fontSmall; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle { radius: Style.radiusFull; color: actionButton.down ? Color.primary : actionButton.hovered ? Color.surfaceHover : Color.surface; border.width: Style.panelBorderWidth; border.color: Color.outlineVariant; opacity: actionButton.enabled ? 1 : 0.55 }
    }
}
