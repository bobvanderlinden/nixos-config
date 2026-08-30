import Quickshell
import QtQml

QtObject {
    function items(query) {
        if (query.trim().length === 0)
            return [];

        return [{
            label: `Run command: ${query}`,
            detail: "Run with sh -lc",
            icon: "",
            glyph: ">_",
            keywords: [],
            activate: () => Quickshell.execDetached(["sh", "-lc", query]),
        }];
    }
}
