import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Privacy indicator — shows icons when microphone, camera, or screen sharing is active.
// Hidden entirely when nothing is active.
// Hover to see a tooltip listing which apps are using each resource.
BarPill {
    id: root

    required property var barWindow

    readonly property bool micActive: SharedPrivacyProvider.micActive
    readonly property bool scrActive: SharedPrivacyProvider.scrActive
    readonly property bool camActive: SharedPrivacyProvider.camActive
    readonly property var micApps: SharedPrivacyProvider.micApps
    readonly property var scrApps: SharedPrivacyProvider.scrApps
    readonly property var camApps: SharedPrivacyProvider.camApps

    // ── Visibility ────────────────────────────────────────────────────────────

    visible: micActive || camActive || scrActive || SharedPrivacyProvider.cameraStatus !== "ready" || SharedPrivacyProvider.cameraLimited || SharedPrivacyProvider.pipewireUnavailable

    // ── Bar pill content ──────────────────────────────────────────────────────

    RowLayout {
        spacing: 4

        Text {
            visible: SharedPrivacyProvider.cameraStatus !== "ready" || SharedPrivacyProvider.cameraLimited || SharedPrivacyProvider.pipewireUnavailable
            text: "⚠"
            color: "#ffb86c"
            font.pixelSize: 13
        }

        Text {
            visible: root.micActive
            text: "󰍬"
            color: "#ff5555"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }

        Text {
            visible: root.camActive
            text: "󰄀"
            color: "#ff5555"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }

        Text {
            visible: root.scrActive
            text: "󱍊"
            color: "#ff5555"
            font.pixelSize: 13
            font.family: "SauceCodePro Nerd Font"
        }
    }

    // ── Tooltip ───────────────────────────────────────────────────────────────

    BarTooltip {
        id: tooltip
        barWindow: root.barWindow
        widget: root
        shown: hoverHandler.hovered
        text: {
            var parts = [SharedPrivacyProvider.cameraMessage];
            if (SharedPrivacyProvider.pipewireUnavailable) parts.push("Microphone and screen capture status unavailable: PipeWire is not ready.");
            if (root.micActive)
                parts.push("Mic" + (SharedPrivacyProvider.pipewireUnavailable ? " (last known)" : "") + ": " + (root.micApps.length > 0 ? root.micApps.join(", ") : "active"));
            if (root.camActive)
                parts.push("Camera open" + (SharedPrivacyProvider.cameraStatus === "stale" ? " (last known)" : " (may not be streaming)") + ": " + root.camApps.join(", "));
            if (root.scrActive)
                parts.push("Screen share" + (SharedPrivacyProvider.pipewireUnavailable ? " (last known)" : "") + ": " + (root.scrApps.length > 0 ? root.scrApps.join(", ") : "active"));
            return parts.join("\n");
        }
    }

    HoverHandler {
        id: hoverHandler
    }
}
