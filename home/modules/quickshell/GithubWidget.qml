import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// GitHub widget — two pills in a row:
//   Review pill : PRs where you are the requested reviewer  (icon , green)
//   Approved pill: PRs you authored that are approved / ready to merge (icon 󰄬, purple)
// Each pill is hidden when its list is empty.
// A single 5-minute timer polls both queries.
RowLayout {
    id: root

    required property var barWindow

    spacing: 4

    property var reviewPrs: []
    property var approvedPrs: []

    // ── Fetchers ──────────────────────────────────────────────────────────────

    Process {
        id: fetchReviewProc
        command: [
            "gh", "search", "prs",
            "--review-requested=@me",
            "--state=open",
            "--json", "number,title,repository,url",
            "--limit", "50"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.reviewPrs = data.map(pr => ({
                        number: pr.number,
                        title: pr.title,
                        repo: pr.repository.name,
                        url: pr.url
                    }));
                } catch (e) {
                    console.warn("GithubWidget (review): failed to parse gh output:", e);
                }
            }
        }
    }

    Process {
        id: fetchApprovedProc
        command: [
            "gh", "search", "prs",
            "--author=@me",
            "--state=open",
            "--review=approved",
            "--json", "number,title,repository,url",
            "--limit", "50"
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.approvedPrs = data.map(pr => ({
                        number: pr.number,
                        title: pr.title,
                        repo: pr.repository.name,
                        url: pr.url
                    }));
                } catch (e) {
                    console.warn("GithubWidget (approved): failed to parse gh output:", e);
                }
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            fetchReviewProc.running = true;
            fetchApprovedProc.running = true;
        }
    }

    Process {
        id: openProc
        property string url: ""
        command: ["xdg-open", url]
        running: false
    }

    // ── Pills ─────────────────────────────────────────────────────────────────

    GithubPrPill {
        barWindow: root.barWindow
        openProcess: openProc
        pillIcon: ""
        pillColor: "#50fa7b"
        pullRequests: root.reviewPrs
    }

    GithubPrPill {
        barWindow: root.barWindow
        openProcess: openProc
        pillIcon: "󰄬"
        pillColor: "#bd93f9"
        pullRequests: root.approvedPrs
    }
}
