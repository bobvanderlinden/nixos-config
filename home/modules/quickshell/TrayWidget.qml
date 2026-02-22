import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import QtQuick.Layouts

// System tray using Quickshell.Services.SystemTray.
// parentWindow must be set to the enclosing PanelWindow for QsMenuAnchor.
RowLayout {
    spacing: 4

    required property var parentWindow

    Repeater {
        model: SystemTray.items

        Item {
            required property var modelData
            property var item: modelData

            implicitWidth: 22
            implicitHeight: 22

            Image {
                anchors.fill: parent
                source: item.icon
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) {
                        item.activate();
                    } else if (mouse.button === Qt.RightButton && item.hasMenu) {
                        menuAnchor.open();
                    }
                }
            }

            QsMenuAnchor {
                id: menuAnchor
                anchor.window: parentWindow
                anchor.rect: Qt.rect(
                    parent.mapToItem(parentWindow.contentItem, 0, 0).x,
                    parent.mapToItem(parentWindow.contentItem, 0, 0).y,
                    parent.width,
                    1
                )
                menu: item.menu
            }
        }
    }
}
