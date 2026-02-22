import Quickshell
import QtQuick

// Clock - format: "Mon, 22. Feb  14:35"
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22

    property string timeText: formatDate(new Date())

    function formatDate(d) {
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        const day = days[d.getDay()];
        const date = String(d.getDate()).padStart(2, "0");
        const month = months[d.getMonth()];
        const hours = String(d.getHours()).padStart(2, "0");
        const mins = String(d.getMinutes()).padStart(2, "0");
        return day + ", " + date + ". " + month + "  " + hours + ":" + mins;
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.timeText = root.formatDate(new Date())
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.timeText
        color: "#f8f8f2"
        font.pixelSize: 12
    }
}
