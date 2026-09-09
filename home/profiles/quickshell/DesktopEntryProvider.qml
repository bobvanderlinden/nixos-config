import Quickshell
import QtQml

// Launcher-provider contract: items(query) returns objects with label, detail,
// icon, keywords, and activate() fields. The launcher owns matching and ordering.
QtObject {
    function items(query) {
        return DesktopEntries.applications.values.map(entry => {
            const icon = Quickshell.iconPath(entry.icon, true);
            return {
                label: entry.name,
                detail: entry.genericName,
                icon,
                glyph: icon === "" ? "▦" : "",
                keywords: entry.keywords,
                activate: () => entry.execute(),
            };
        });
    }
}
