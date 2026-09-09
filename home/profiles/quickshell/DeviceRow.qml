import QtQuick

// A clickable device row for the audio popup.
// Shows a check mark when isDefault is true.
Item {
    id: row

    property string deviceName: ""
    property bool isDefault: false

    signal selectDevice

    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        radius: 3
        color: hoverArea.containsMouse ? "#3a3b4d" : "transparent"
    }

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: row.isDefault ? "󰄴" : "○"
        color: row.isDefault ? "#89b4fa" : "#555577"
        font.pixelSize: 11
        font.family: "SauceCodePro Nerd Font"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: row.deviceName
        color: row.isDefault ? "#f8f8f2" : "#cdd6f4"
        font.pixelSize: 11
        font.family: "SauceCodePro Nerd Font"
        elide: Text.ElideLeft
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.selectDevice()
    }
}
