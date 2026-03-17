import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// Todo widget — shows open Vikunja tasks.
//
// Pill: checkmark icon + count of open tasks
// Popup (click to open):
//   - Text input at top for adding new tasks
//   - List of open tasks with checkboxes to mark done
// Enter: add task and close
// Esc: close popup
Rectangle {
    id: root

    required property var barWindow

    property var tasks: []
    property real popupWidth: 360
    property bool popupVisible: false

    // Pill appearance
    color: "#313244"
    radius: 4
    implicitHeight: 22
    implicitWidth: pillRow.implicitWidth + 12

    // ── Fetch tasks ───────────────────────────────────────────────────────────

    Process {
        id: fetchProc
        command: ["vja", "ls", "--jsonvja"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    root.tasks = parsed.filter(t => !t.done);
                } catch (e) {
                    console.warn("TodoWidget: failed to parse vja output:", e);
                }
            }
        }
    }

    Timer {
        interval: 60 * 1000
        running: true
        repeat: true
        onTriggered: fetchProc.running = true
    }

    // ── Add task process ──────────────────────────────────────────────────────

    Process {
        id: addProc
        property string taskTitle: ""
        command: ["vja", "add", "--quiet", taskTitle]
        running: false
        onRunningChanged: {
            if (!running && taskTitle !== "") {
                taskTitle = "";
                fetchProc.running = true;
            }
        }
    }

    // ── Toggle task process ───────────────────────────────────────────────────

    Process {
        id: toggleProc
        property int taskId: 0
        command: ["vja", "toggle", "--quiet", taskId.toString()]
        running: false
        onRunningChanged: {
            if (!running && taskId !== 0) {
                taskId = 0;
                fetchProc.running = true;
            }
        }
    }

    // ── Pill content ──────────────────────────────────────────────────────────

    RowLayout {
        id: pillRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "󰄬"
            color: "#50fa7b"
            font.pixelSize: 12
            font.family: "SauceCodePro Nerd Font"
        }

        Text {
            text: root.tasks.length.toString()
            color: "#50fa7b"
            font.pixelSize: 11
            font.family: "SauceCodePro Nerd Font"
        }
    }

    // ── Click to open popup ───────────────────────────────────────────────────

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.popupVisible) {
                root.popupVisible = false;
                BarState.activePopupWidget = null;
            } else {
                root.popupVisible = true;
                BarState.activePopupWidget = root;
                taskInput.forceActiveFocus();
            }
        }
    }

    // ── React to another widget opening its popup ─────────────────────────────

    Connections {
        target: BarState
        function onActivePopupWidgetChanged() {
            if (BarState.activePopupWidget !== root) {
                root.popupVisible = false;
            }
        }
    }

    // ── Popup Window ──────────────────────────────────────────────────────────

    PopupWindow {
        id: popup
        visible: root.popupVisible

        anchor.window: root.barWindow
        anchor.rect: {
            // Reference root.x to ensure binding re-evaluates when widget position changes
            void(root.x);
            const mapped = root.mapToItem(root.barWindow.contentItem, 0, 0);
            return Qt.rect(mapped.x, -popup.implicitHeight - 4, 1, 1);
        }

        implicitWidth: root.popupWidth
        implicitHeight: chrome.implicitHeight

        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                taskInput.forceActiveFocus();
            }
        }

        HyprlandFocusGrab {
            active: root.popupVisible
            windows: [popup]
            onCleared: {
                root.popupVisible = false;
                BarState.activePopupWidget = null;
            }
        }

        Rectangle {
            id: chrome
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 8
            border.color: "#44475a"
            border.width: 1
            implicitHeight: contentColumn.implicitHeight + 24

            ColumnLayout {
                id: contentColumn
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                // ── Input for new task ────────────────────────────────────────

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 6
                    color: "#313244"
                    border.color: taskInput.activeFocus ? "#bd93f9" : "#44475a"
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    TextInput {
                        id: taskInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#f8f8f2"
                        font.pixelSize: 12
                        font.family: "SauceCodePro Nerd Font"
                        selectionColor: "#44475a"

                        Keys.onReturnPressed: addTask()
                        Keys.onEnterPressed: addTask()
                        Keys.onEscapePressed: closePopup()

                        function addTask() {
                            if (taskInput.text.trim() !== "") {
                                addProc.taskTitle = taskInput.text.trim();
                                addProc.running = true;
                                taskInput.text = "";
                            }
                            closePopup();
                        }

                        function closePopup() {
                            root.popupVisible = false;
                            BarState.activePopupWidget = null;
                        }
                    }

                    // Placeholder text
                    Text {
                        anchors { fill: parent; leftMargin: 10 }
                        verticalAlignment: Text.AlignVCenter
                        text: "Add new task..."
                        color: "#6272a4"
                        font.pixelSize: 12
                        font.family: "SauceCodePro Nerd Font"
                        visible: taskInput.text === "" && !taskInput.activeFocus
                    }
                }

                // ── Task list ─────────────────────────────────────────────────

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    visible: root.tasks.length > 0

                    Repeater {
                        model: root.tasks

                        Rectangle {
                            required property var modelData
                            property var task: modelData

                            Layout.fillWidth: true
                            implicitHeight: taskRow.implicitHeight + 8
                            radius: 4
                            color: taskHover.hovered ? "#313244" : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            HoverHandler { id: taskHover }

                            RowLayout {
                                id: taskRow
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 6
                                    rightMargin: 6
                                }
                                spacing: 8

                                // Checkbox
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 3
                                    color: checkHover.hovered ? "#44475a" : "#313244"
                                    border.color: "#6272a4"
                                    border.width: 1

                                    HoverHandler { id: checkHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            toggleProc.taskId = task.id;
                                            toggleProc.running = true;
                                        }
                                    }
                                }

                                // Task title
                                Text {
                                    Layout.fillWidth: true
                                    text: task.title
                                    color: "#f8f8f2"
                                    font.pixelSize: 12
                                    font.family: "SauceCodePro Nerd Font"
                                    elide: Text.ElideRight
                                }

                                // Priority indicator
                                Text {
                                    visible: task.priority > 0
                                    text: "!" + task.priority
                                    color: task.priority >= 3 ? "#ff5555" : (task.priority >= 2 ? "#ffb86c" : "#f1fa8c")
                                    font.pixelSize: 10
                                    font.family: "SauceCodePro Nerd Font"
                                }
                            }
                        }
                    }
                }

                // ── Empty state ───────────────────────────────────────────────

                Text {
                    Layout.fillWidth: true
                    visible: root.tasks.length === 0
                    text: "No open tasks"
                    color: "#6272a4"
                    font.pixelSize: 12
                    font.family: "SauceCodePro Nerd Font"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
