import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Pull request inbox modelled after github.com/pulls.
PopupWidget {
    id: root

    popupWidth: 520

    property var reviewRequests: []
    property var teamReviewRequests: []
    property var drafts: []
    property var waitingForReview: []
    property var needsAction: []
    property var readyToMerge: []

    readonly property int pullRequestCount: reviewRequests.length
        + teamReviewRequests.length
        + drafts.length
        + waitingForReview.length
        + needsAction.length
        + readyToMerge.length

    function parsePullRequests(output, destination) {
        try {
            const data = JSON.parse(output);
            root[destination] = data.map(pullRequest => ({
                number: pullRequest.number,
                title: pullRequest.title,
                repository: pullRequest.repository.name,
                url: pullRequest.url
            }));
        } catch (error) {
            console.warn("GithubWidget: failed to parse pull request search:", error);
        }
    }

    function parseReviewRequests(output) {
        try {
            const result = JSON.parse(output).data;
            const userReviewRequests = [];
            const teamRequests = [];

            for (const pullRequest of result.search.nodes) {
                const reviewers = pullRequest.reviewRequests.nodes.map(request => request.requestedReviewer);
                const request = {
                    number: pullRequest.number,
                    title: pullRequest.title,
                    repository: pullRequest.repository.name,
                    url: pullRequest.url
                };

                if (reviewers.some(reviewer => reviewer.__typename === "User" && reviewer.login === result.viewer.login))
                    userReviewRequests.push(request);
                if (reviewers.some(reviewer => reviewer.__typename === "Team"))
                    teamRequests.push(request);
            }

            root.reviewRequests = userReviewRequests;
            root.teamReviewRequests = teamRequests;
        } catch (error) {
            console.warn("GithubWidget: failed to parse review requests:", error);
        }
    }

    function refresh() {
        reviewRequestsProcess.running = true;
        draftsProcess.running = true;
        waitingForReviewProcess.running = true;
        needsActionProcess.running = true;
        readyToMergeProcess.running = true;
    }

    Process {
        id: reviewRequestsProcess
        command: [
            "gh", "api", "graphql",
            "-f", "query=query { viewer { login } search(query: \"is:open is:pr review-requested:@me\", type: ISSUE, first: 100) { nodes { ... on PullRequest { number title url repository { name } reviewRequests(first: 100) { nodes { requestedReviewer { __typename ... on User { login } ... on Team { slug } } } } } } } }"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseReviewRequests(this.text)
        }
    }

    Process {
        id: draftsProcess
        command: ["gh", "search", "prs", "--author=@me", "--draft", "--state=open", "--json", "number,title,repository,url", "--limit", "50"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "drafts")
        }
    }

    Process {
        id: waitingForReviewProcess
        command: ["gh", "search", "prs", "--author=@me", "--review=required", "--state=open", "--json", "number,title,repository,url", "--limit", "50", "--", "draft:false"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "waitingForReview")
        }
    }

    Process {
        id: needsActionProcess
        command: ["gh", "search", "prs", "--author=@me", "--review=changes_requested", "--state=open", "--json", "number,title,repository,url", "--limit", "50", "--", "draft:false"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "needsAction")
        }
    }

    Process {
        id: readyToMergeProcess
        command: ["gh", "search", "prs", "--author=@me", "--review=approved", "--state=open", "--json", "number,title,repository,url", "--limit", "50", "--", "draft:false"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "readyToMerge")
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

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
                        onClicked: root.refresh()
                    }
                }
            }

            InboxGroup {
                title: "Needs your review"
                pullRequests: root.reviewRequests
                accentColor: "#ffb86c"
            }

            InboxGroup {
                title: "Needs your teams' review"
                pullRequests: root.teamReviewRequests
                accentColor: "#bd93f9"
            }

            InboxGroup {
                title: "Your drafts"
                pullRequests: root.drafts
                accentColor: "#6272a4"
            }

            InboxGroup {
                title: "Waiting for review or checks"
                pullRequests: root.waitingForReview
                accentColor: "#8be9fd"
            }

            InboxGroup {
                title: "Needs action"
                pullRequests: root.needsAction
                accentColor: "#ff5555"
            }

            InboxGroup {
                title: "Ready to merge"
                pullRequests: root.readyToMerge
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
