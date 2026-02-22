import Quickshell
import QtQuick

// Tooltip that appears above the bar, centered over a given anchor item.
//
// Usage:
//   BarTooltip {
//       id: tip
//       barWindow: bar
//       text: "Hello"
//   }
//   HoverHandler {
//       onHoveredChanged: tip.visible = hovered
//   }
Item {
    id: root

    // The enclosing PanelWindow — required for PopupWindow anchoring.
    required property var barWindow

    // The widget to center the tooltip above. Defaults to the parent item.
    property Item widget: parent

    property string text: ""
    property bool shown: false

    PopupWindow {
        id: popup
        visible: root.shown && root.text !== ""

        anchor.window: root.barWindow
        anchor.rect: {
            if (!root.widget || !root.barWindow) return Qt.rect(0, 0, 0, 0);
            const mapped = root.widget.mapToItem(root.barWindow.contentItem, 0, 0);
            return Qt.rect(
                mapped.x + root.widget.width / 2 - implicitWidth / 2,
                -implicitHeight - 4,
                implicitWidth,
                1
            );
        }

        implicitWidth: tipText.implicitWidth + 16
        implicitHeight: tipText.implicitHeight + 10
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 4
            border.width: 1
            border.color: "#45475a"

            Text {
                id: tipText
                anchors.centerIn: parent
                text: root.text
                font.pixelSize: 11
                font.family: "SauceCodePro Nerd Font"
                color: "#f8f8f2"
            }
        }
    }
}
