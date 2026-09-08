import Quickshell
import Quickshell.Io
import QtQml

QtObject {
    id: root

    property string completionQuery: ""
    property var completions: []

    signal completionSelected(string value)

    function requestCompletions(query) {
        if (query === completionQuery)
            return;
        completionQuery = query;
        completionTimer.restart();
    }

    function replacementPrefix(query) {
        const lastWhitespace = query.search(/\s[^\s]*$/);
        return lastWhitespace === -1 ? "" : query.slice(0, lastWhitespace + 1);
    }

    function startCompletion() {
        completionProcess.query = completionQuery;
        completionProcess.running = true;
    }

    function items(query) {
        if (query.trim().length === 0)
            return [];

        requestCompletions(query);
        const prefix = replacementPrefix(query);
        const completionItems = completions.map(completion => ({
            label: prefix + completion.value,
            detail: completion.description || "Fish completion",
            icon: "",
            glyph: "⇥",
            keywords: [completion.value],
            keepOpen: true,
            activate: () => root.completionSelected(completion.value),
        }));

        return [...completionItems, {
            label: `Run command: ${query}`,
            detail: "Run with sh -lc",
            icon: "",
            glyph: ">_",
            keywords: [],
            activate: () => Quickshell.execDetached(["sh", "-lc", query]),
        }];
    }

    property var completionTimer: Timer {
        interval: 75
        onTriggered: {
            if (!completionProcess.running)
                root.startCompletion();
        }
    }

    property var completionProcess: Process {

        property string query: ""
        command: ["fish", "-c", "complete -C \"$argv[1]\"", "--", query]
        onExited: {
            if (query !== root.completionQuery)
                root.startCompletion();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (completionProcess.query !== root.completionQuery)
                    return;

                const seen = new Set();
                root.completions = text.trim().split("\n")
                    .filter(line => line.length > 0)
                    .map(line => {
                        const fields = line.split("\t");
                        return { value: fields[0], description: fields.slice(1).join(" ") };
                    })
                    .filter(completion => {
                        if (seen.has(completion.value))
                            return false;
                        seen.add(completion.value);
                        return true;
                    });
            }
        }
    }
}
