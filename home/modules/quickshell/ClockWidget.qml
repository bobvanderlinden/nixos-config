import Quickshell
import QtQuick
import QtQuick.Controls

// Clock - format: "Mon, 22. Feb  14:35"
// Uses SystemClock for reactive minute-aligned updates.
// Click to open/close the CalendarPopup.
BarPill {
    id: root

    // Pass the bar PanelWindow so CalendarPopup can anchor to it
    property var barWindow

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    CalendarPopup {
        id: cal
        anchorWindow: root.barWindow
        anchorItem: root
        visible: false
    }

    Text {
        id: label
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
