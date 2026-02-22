import Quickshell
import QtQuick
import QtQuick.Controls

// Clock - format: "Mon, 22. Feb  14:35"
// Uses SystemClock (Quickshell built-in) for reactive, precision-aligned updates.
// Click to open/close the CalendarPopup.
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    CalendarPopup {
        id: cal
        anchor: label
        visible: false
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

            ToolTip.visible: hoverArea.containsMouse && !cal.visible
            ToolTip.text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
            ToolTip.delay: 500

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: cal.visible = !cal.visible
            }
        }
    }
}
