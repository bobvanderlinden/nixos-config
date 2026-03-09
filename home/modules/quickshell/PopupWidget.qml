import Quickshell
import QtQuick
import QtQuick.Layouts

// Base component for bar widgets that have a hover-activated popup.
//
// Contains an inline pill (same styling as BarPill) and a PopupWindow.
// Manages all popup machinery:
//   - Hover open/close with 200ms grace timer so mouse can travel pill→popup
//   - Immediate close when another widget opens (via BarState singleton)
//   - Consistent popup chrome: #1e1e2e bg, radius 8, #44475a border, 12px padding
//
// Usage:
//   PopupWidget {
//       barWindow: bar          // required — set by StatusBar
//       popupWidth: 320         // optional
//
//       pillContent: Component {
//           Text { text: "hello" }
//       }
//
//       popupContent: Component {
//           ColumnLayout { ... }
//       }
//   }
//
// NOTE: subclasses must NOT redeclare `barWindow` — that shadows this property
// and leaves it null. Just assign it: `barWindow: bar`.
Rectangle {
    id: root

    // The enclosing PanelWindow. Must be set by the parent (StatusBar).
    // Do NOT redeclare in subclasses — assign it directly.
    required property var barWindow

    // Width of the popup. Override per widget.
    property real popupWidth: 320

    // True while the popup is visible.
    readonly property bool popupOpen: popup.visible

    // Content components — set these in subclasses.
    property Component pillContent: null
    property Component popupContent: null

    // Pill appearance — mirrors BarPill.
    color: "#313244"
    radius: 4
    implicitHeight: 22
    implicitWidth: pillLoader.implicitWidth + 12

    // ── Pill content ──────────────────────────────────────────────────────────

    Loader {
        id: pillLoader
        anchors.centerIn: parent
        sourceComponent: root.pillContent
    }

    // ── Hover detection ───────────────────────────────────────────────────────

    HoverHandler {
        id: barHover
        onHoveredChanged: {
            if (barHover.hovered) {
                hideTimer.stop();
                popup.visible = true;
                BarState.activePopupWidget = root;
            } else if (!popupHover.hovered) {
                hideTimer.restart();
            }
        }
    }

    // ── Hide timer — 200ms grace so mouse can travel pill→popup ───────────────

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: {
            popup.visible = false;
            if (BarState.activePopupWidget === root)
                BarState.activePopupWidget = null;
        }
    }

    // ── React to another widget opening its popup ─────────────────────────────

    Connections {
        target: BarState
        function onActivePopupWidgetChanged() {
            if (BarState.activePopupWidget !== root) {
                hideTimer.stop();
                popup.visible = false;
            }
        }
    }

    // ── Popup ─────────────────────────────────────────────────────────────────

    PopupWindow {
        id: popup
        visible: false

        anchor.window: root.barWindow
        anchor.rect: {
            const mapped = root.mapToItem(root.barWindow.contentItem, 0, 0);
            return Qt.rect(mapped.x, -popup.implicitHeight - 4, 1, 1);
        }

        implicitWidth: root.popupWidth
        implicitHeight: chrome.implicitHeight
        color: "transparent"

        HoverHandler {
            id: popupHover
            onHoveredChanged: {
                if (popupHover.hovered) {
                    hideTimer.stop();
                } else if (!barHover.hovered) {
                    hideTimer.restart();
                }
            }
        }

        Rectangle {
            id: chrome
            anchors.fill: parent
            color: "#1e1e2e"
            radius: 8
            border.color: "#44475a"
            border.width: 1
            implicitHeight: contentLoader.implicitHeight + 24

            Loader {
                id: contentLoader
                anchors {
                    fill: parent
                    margins: 12
                }
                sourceComponent: root.popupContent
            }
        }
    }
}
