import Quickshell
import Quickshell.Hyprland
import QtQuick

// Clock - format: "Mon, 22. Feb  14:35"
// Uses SystemClock for reactive minute-aligned updates.
// Click to open/close the CalendarPopup.
BarPill {
    id: root

    required property var barWindow

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

    HyprlandFocusGrab {
        active: cal.visible
        windows: [root.barWindow, cal]
        onCleared: cal.visible = false
    }

    BarTooltip {
        barWindow: root.barWindow
        widget: root
        text: Qt.formatDateTime(clock.date, "dddd, dd MMMM yyyy")
        shown: hoverHandler.hovered && !cal.visible
    }

    Text {
        id: label
        text: Qt.formatDateTime(clock.date, "ddd, dd. MMM  hh:mm")
        color: "#f8f8f2"
        font.pixelSize: 12
        font.family: "SauceCodePro Nerd Font"
    }

    HoverHandler {
        id: hoverHandler
    }

    TapHandler {
        onTapped: cal.visible = !cal.visible
    }
}
