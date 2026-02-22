import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Docker widget.
//
// Collapsed (bar): container count badge.
// Expanded (hover): popup listing container name + image + status,
//   with an X button to kill each container.
//   Hidden entirely when no containers are running.
RowLayout {
    id: root

    spacing: 0
    visible: containers.length > 0

    // Must be set by StatusBar to the enclosing PanelWindow.
    required property var barWindow

    property var containers: []  // [{ id, name, image, status }, ...]

    // ── Container list poller ─────────────────────────────────────────────────

    Process {
        id: listProc
        command: ["docker", "ps",
            "--format", '{"id":"{{.ID}}","name":"{{.Names}}","image":"{{.Image}}","status":"{{.Status}}"}']
        running: true

        property string buf: ""

        stdout: SplitParser {
            onRead: data => listProc.buf += data + "\n"
        }

        onExited: {
            const lines = listProc.buf.trim().split("\n").filter(l => l !== "");
            listProc.buf = "";
            const parsed = [];
            for (const line of lines) {
                try { parsed.push(JSON.parse(line)); } catch (e) { }
            }
            root.containers = parsed;
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: listProc.running = true
    }

    // ── Collapsed: count badge ────────────────────────────────────────────────

    BarPill {
        color: "#1e2a40"

        Text {
            id: badgeLabel
            text: "🐳 " + root.containers.length
            color: "#89b4fa"
            font.pixelSize: 11
        }
    }

    // ── Hover detection ───────────────────────────────────────────────────────

    HoverHandler { id: barHover }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: popup.visible = false
    }

    // ── Expanded: popup ───────────────────────────────────────────────────────

    PopupWindow {
        id: popup
        visible: false

        anchor.window: root.barWindow
        anchor.rect.x: root.x
        anchor.rect.y: -popup.implicitHeight
        anchor.rect.width: 1
        anchor.rect.height: 1

        implicitWidth: 360
        implicitHeight: popupCol.implicitHeight + 12
        color: "#2a2b3d"

        HoverHandler {
            id: popupHover
            onHoveredChanged: {
                if (popupHover.hovered) hideTimer.stop();
                else if (!barHover.hovered) hideTimer.restart();
            }
        }

        Connections {
            target: barHover
            function onHoveredChanged() {
                if (barHover.hovered) { hideTimer.stop(); popup.visible = true; }
                else if (!popupHover.hovered) hideTimer.restart();
            }
        }

        ColumnLayout {
            id: popupCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 6
            }
            spacing: 2

            Repeater {
                model: root.containers

                Rectangle {
                    required property var modelData
                    property var container: modelData

                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 4
                    color: rowHover.hovered ? "#383a59" : "transparent"

                    HoverHandler { id: rowHover }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 6
                        }
                        spacing: 8

                        // Container name
                        Text {
                            Layout.fillWidth: true
                            text: container.name
                            color: "#f8f8f2"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        // Image (dimmed)
                        Text {
                            text: container.image
                            color: "#6272a4"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.maximumWidth: 120
                        }

                        // Kill button
                        Rectangle {
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: 3
                            color: killHover.hovered ? "#ff5555" : "#44475a"

                            HoverHandler { id: killHover }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: "#f8f8f2"
            font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    killProc.containerId = container.id;
                                    killProc.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Kill process ──────────────────────────────────────────────────────────

    Process {
        id: killProc
        property string containerId: ""
        command: ["docker", "stop", containerId]
        running: false
        onExited: listProc.running = true  // refresh list after kill
    }
}
