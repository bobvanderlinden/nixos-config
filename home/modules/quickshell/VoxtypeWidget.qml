import Quickshell.Io
import QtQuick

// Voxtype PTT status. Reads long-running JSON stream from `voxtype status --follow --format json`.
// JSON format: {"text": "...", "tooltip": "...", "class": "..."}
Item {
    id: root
    implicitWidth: label.implicitWidth + 12
    implicitHeight: 22
    visible: voxtypeText !== ""

    property string voxtypeText: ""
    property string voxtypeTooltip: ""
    property string voxtypeClass: ""

    Process {
        id: voxtypeProc
        command: ["voxtype", "status", "--follow", "--format", "json"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "") return;
                try {
                    const obj = JSON.parse(data);
                    root.voxtypeText = obj.text ?? "";
                    root.voxtypeTooltip = obj.tooltip ?? "";
                    root.voxtypeClass = obj["class"] ?? "";
                } catch (e) { }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.voxtypeClass === "active" ? "#cf5700" : "#999999"
        radius: 4

        Text {
            id: label
            anchors.centerIn: parent
            text: root.voxtypeText
            color: "#ffffff"
            font.pixelSize: 11
        }
    }
}
