import Quickshell
import Quickshell.Io
import QtQuick

// Shared pull request data for the GitHub widget and launcher.
Item {
    id: root

    property var reviewRequests: []
    property var teamReviewRequests: []
    property var drafts: []
    property var waitingForReview: []
    property var needsAction: []
    property var readyToMerge: []

    readonly property var pullRequests: [
        ...reviewRequests,
        ...teamReviewRequests,
        ...drafts,
        ...waitingForReview,
        ...needsAction,
        ...readyToMerge,
    ].sort((first, second) => second.updatedAt.localeCompare(first.updatedAt))

    function parsePullRequests(output, destination) {
        try {
            const data = JSON.parse(output);
            root[destination] = data.map(pullRequest => ({
                number: pullRequest.number,
                title: pullRequest.title,
                repository: pullRequest.repository.name,
                url: pullRequest.url,
                updatedAt: pullRequest.updatedAt,
            }));
        } catch (error) {
            console.warn("GithubProvider: failed to parse pull request search:", error);
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
                    url: pullRequest.url,
                    updatedAt: pullRequest.updatedAt,
                };

                if (reviewers.some(reviewer => reviewer.__typename === "User" && reviewer.login === result.viewer.login))
                    userReviewRequests.push(request);
                if (reviewers.some(reviewer => reviewer.__typename === "Team"))
                    teamRequests.push(request);
            }

            root.reviewRequests = userReviewRequests;
            root.teamReviewRequests = teamRequests;
        } catch (error) {
            console.warn("GithubProvider: failed to parse review requests:", error);
        }
    }

    function refresh() {
        reviewRequestsProcess.running = true;
        draftsProcess.running = true;
        waitingForReviewProcess.running = true;
        needsActionProcess.running = true;
        readyToMergeProcess.running = true;
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
        id: reviewRequestsProcess
        command: [
            "gh", "api", "graphql",
            "-f", "query=query { viewer { login } search(query: \"is:open is:pr review-requested:@me\", type: ISSUE, first: 100) { nodes { ... on PullRequest { number title url updatedAt repository { name } reviewRequests(first: 100) { nodes { requestedReviewer { __typename ... on User { login } ... on Team { slug } } } } } } } }"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseReviewRequests(this.text)
        }
    }

    Process {
        id: draftsProcess
        command: ["gh", "search", "prs", "--author=@me", "--draft", "--state=open", "--json", "number,title,repository,url,updatedAt", "--limit", "50"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "drafts")
        }
    }

    Process {
        id: waitingForReviewProcess
        command: ["gh", "search", "prs", "--author=@me", "--review=required", "--state=open", "--json", "number,title,repository,url,updatedAt", "--limit", "50", "--", "draft:false"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "waitingForReview")
        }
    }

    Process {
        id: needsActionProcess
        command: ["gh", "search", "prs", "--author=@me", "--review=changes_requested", "--state=open", "--json", "number,title,repository,url,updatedAt", "--limit", "50", "--", "draft:false"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parsePullRequests(this.text, "needsAction")
        }
    }

    Process {
        id: readyToMergeProcess
        command: ["gh", "search", "prs", "--author=@me", "--review=approved", "--state=open", "--json", "number,title,repository,url,updatedAt", "--limit", "50", "--", "draft:false"]
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
}
