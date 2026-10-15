import QtQuick

// Session time (HH:MM 🔒), shared across screens.
BarPill {
    id: root
    color: "#1a2e28"

    readonly property string sessionTime: SharedSessionProvider.sessionTime

    Text {
        id: label
        text: "🔓 " + root.sessionTime
        color: "#50fa7b"
        font.pixelSize: 12
    }
}
