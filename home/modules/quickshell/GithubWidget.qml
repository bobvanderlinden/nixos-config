import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Pull request inbox modelled after github.com/pulls.
PopupWidget {
    id: root

    popupWidth: 520

    required property var githubProvider

    readonly property int pullRequestCount: githubProvider.reviewRequests.length
        + githubProvider.teamReviewRequests.length
        + githubProvider.drafts.length
        + githubProvider.waitingForReview.length
        + githubProvider.needsAction.length
        + githubProvider.readyToMerge.length

    Process {
        id: openProcess
        property string url: ""
        command: ["xdg-open", url]
        running: false
    }

    pillContent: Component {
        RowLayout {
            spacing: 4

            Text {
                text: "󰊤"
                color: "#f8f8f2"
                font.family: "SauceCodePro Nerd Font"
                font.pixelSize: 12
            }

            Text {
                text: root.pullRequestCount.toString()
                color: "#f8f8f2"
                font.family: "SauceCodePro Nerd Font"
                font.pixelSize: 11
            }
        }
    }

    popupContent: Component {
        ColumnLayout {
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4

                Text {
                    text: "Pull request inbox"
                    color: "#f8f8f2"
                    font.family: "SauceCodePro Nerd Font"
                    font.pixelSize: 14
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "↻"
                    color: "#8be9fd"
                    font.family: "SauceCodePro Nerd Font"
                    font.pixelSize: 16

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.githubProvider.refresh()
                    }
                }
            }

            InboxGroup {
                title: "Needs your review"
                pullRequests: root.githubProvider.reviewRequests
                accentColor: "#ffb86c"
            }

            InboxGroup {
                title: "Needs your teams' review"
                pullRequests: root.githubProvider.teamReviewRequests
                accentColor: "#bd93f9"
            }

            InboxGroup {
                title: "Your drafts"
                pullRequests: root.githubProvider.drafts
                accentColor: "#6272a4"
            }

            InboxGroup {
                title: "Waiting for review or checks"
                pullRequests: root.githubProvider.waitingForReview
                accentColor: "#8be9fd"
            }

            InboxGroup {
                title: "Needs action"
                pullRequests: root.githubProvider.needsAction
                accentColor: "#ff5555"
            }

            InboxGroup {
                title: "Ready to merge"
                pullRequests: root.githubProvider.readyToMerge
                accentColor: "#50fa7b"
            }
        }
    }

    component InboxGroup: ColumnLayout {
        id: group

        required property string title
        required property var pullRequests
        required property color accentColor
        property bool expanded: false

        Layout.fillWidth: true
        spacing: 2

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 4
            color: groupHeaderHover.hovered ? "#313244" : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8

                Text {
                    text: group.expanded ? "⌄" : "›"
                    color: "#6272a4"
                    font.family: "SauceCodePro Nerd Font"
                    font.pixelSize: 18
                }

                Text {
                    text: group.title
                    color: "#f8f8f2"
                    font.family: "SauceCodePro Nerd Font"
                    font.pixelSize: 12
                    font.bold: true
                }

                Rectangle {
                    implicitWidth: countLabel.implicitWidth + 10
                    implicitHeight: 18
                    radius: 9
                    color: "#44475a"

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: group.pullRequests.length.toString()
                        color: group.accentColor
                        font.family: "SauceCodePro Nerd Font"
                        font.pixelSize: 10
                    }
                }

                Item { Layout.fillWidth: true }
            }

            HoverHandler { id: groupHeaderHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: group.expanded = !group.expanded
            }
        }

        Repeater {
            model: group.expanded ? group.pullRequests : []

            Rectangle {
                required property var modelData
                property var pullRequest: modelData

                Layout.fillWidth: true
                implicitHeight: 38
                radius: 4
                color: pullRequestHover.hovered ? "#313244" : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    Text {
                        text: "󰊤"
                        color: group.accentColor
                        font.family: "SauceCodePro Nerd Font"
                        font.pixelSize: 12
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: "#" + pullRequest.number + " " + pullRequest.title
                            color: "#f8f8f2"
                            font.family: "SauceCodePro Nerd Font"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: pullRequest.repository
                            color: "#6272a4"
                            font.family: "SauceCodePro Nerd Font"
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                }

                HoverHandler { id: pullRequestHover }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        openProcess.url = pullRequest.url;
                        openProcess.running = true;
                        BarState.activePopupWidget = null;
                    }
                }
            }
        }
    }
}
