import Quickshell
import QtQuick

// Clock — format: "Mon, 22. Feb  14:35"
// Uses SystemClock (Quickshell built-in) for reactive, precision-aligned updates.
// Click to open/close the CalendarPopup. Hover shows full date tooltip.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    required property var barWindow

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    property bool calendarShown: false

    CalendarPopup {
        id: cal
        anchorItem: label
        shown: root.calendarShown
    }

    BarTooltip {
        id: tooltip
        barWindow: root.barWindow
        text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
        shown: hoverHandler.hovered && !root.calendarShown
    }

    Rectangle {
        anchors.fill: parent
        color: "#252535"
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: Qt.formatDateTime(clock.date, "ddd, dd. MMM  hh:mm")
            color: "#f8f8f2"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"
        }

        HoverHandler {
            id: hoverHandler
        }

        TapHandler {
            onTapped: root.calendarShown = !root.calendarShown
        }
    }
}
