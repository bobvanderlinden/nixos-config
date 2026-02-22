import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import QtQuick.Layouts

// System tray using Quickshell.Services.SystemTray
RowLayout {
    spacing: 4

    // Must be set by parent to the enclosing PanelWindow for menu anchoring.
    property var parentWindow: null

    Repeater {
        model: SystemTray.items

        Item {
            required property var modelData
            property var item: modelData

            implicitWidth: 20
            implicitHeight: 20

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
                // SystemTrayItem.menu is already a QsMenuHandle
                menu: item.menu
            }
        }
    }
}
