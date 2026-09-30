import Quickshell
import Quickshell.Io
import QtQuick

// Shared pull request data for the GitHub widget and launcher.
Item {
    id: root

    property var reviewRequests: []
    property var teamReviewRequests: []
    property var drafts: []
    property var needsReviewers: []
    property var waitingForReview: []
    property var needsAction: []
    property var approvedNeedsAction: []
    property var readyToMerge: []
    property bool failed: false
    readonly property bool loading: inboxProcess.running

    readonly property var pullRequests: [
        ...reviewRequests,
        ...teamReviewRequests,
        ...drafts,
        ...needsReviewers,
        ...waitingForReview,
        ...needsAction,
        ...approvedNeedsAction,
        ...readyToMerge,
    ].sort((first, second) => second.updatedAt.localeCompare(first.updatedAt))

    function parseInbox(output) {
        try {
            const inbox = JSON.parse(output);
            root.reviewRequests = inbox.reviewRequests;
            root.teamReviewRequests = inbox.teamReviewRequests;
            root.drafts = inbox.drafts;
            root.needsReviewers = inbox.needsReviewers || [];
            root.waitingForReview = inbox.waitingForReview;
            root.needsAction = inbox.needsAction;
            root.approvedNeedsAction = inbox.approvedNeedsAction || [];
            root.readyToMerge = inbox.readyToMerge;
            root.failed = false;
        } catch (error) {
            root.failed = true;
            console.warn("GithubProvider: failed to parse inbox:", error);
        }
    }

    function refresh() {
        if (!inboxProcess.running)
            inboxProcess.running = true;
    }

    function items(query) {
        const seenUrls = new Set();
        return pullRequests
            .filter(pullRequest => {
                if (seenUrls.has(pullRequest.url))
                    return false;
                seenUrls.add(pullRequest.url);
                return true;
            })
            .map(pullRequest => ({
                label: "#" + pullRequest.number + " " + pullRequest.title,
                detail: pullRequest.repository,
                icon: "",
                glyph: "󰊤",
                keywords: [pullRequest.number.toString(), pullRequest.title, pullRequest.repository],
                activate: () => Quickshell.execDetached(["xdg-open", pullRequest.url]),
            }));
    }

    Process {
        id: inboxProcess
        command: ["gh-inbox"]
        running: true
        stdout: StdioCollector {
            id: inboxOutput
        }
        onExited: (exitCode) => {
            if (exitCode === 0)
                root.parseInbox(inboxOutput.text);
            else {
                root.failed = true;
                retryTimer.restart();
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 30 * 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
