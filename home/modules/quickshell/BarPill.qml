import QtQuick

// Pill-shaped container used by bar widgets.
//
// Default height is 22px; horizontal padding of 6px is applied on each side.
// The background color defaults to the standard Dracula surface (#313244) but
// can be overridden for tinted variants (e.g. DockerWidget, SessionTimeWidget).
//
// Usage:
//   BarPill {
//       Text { ... }
//   }
Rectangle {
    id: pill

    default property alias contents: inner.data

    implicitWidth: inner.implicitWidth + 12
    implicitHeight: 22

    color: "#313244"
    radius: 4

    Item {
        id: inner
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
