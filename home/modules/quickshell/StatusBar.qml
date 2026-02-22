import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The status bar panel — anchored to the bottom of the given screen.
PanelWindow {
    id: bar

    // Set by parent (shell.qml Variants loop)
    required property var screen

    screen: bar.screen
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 28
    color: "#1e1e2e"

    // Use Top layer so the bar sits above normal windows (Bottom puts it behind them)
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    exclusiveZone: implicitHeight

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 0

        // ── Left: Workspaces + Agents ────────────────────────────────────────
        WorkspacesWidget { }

        AgentsWidget {
            barWindow: bar
        }

        // ── Center: stretch ───────────────────────────────────────────────────
        Item { Layout.fillWidth: true }

        // ── Right: status modules ─────────────────────────────────────────────

        SystemdFailedUnits { }

        DockerWidget { }

        SessionTimeWidget { }

        VoxtypeWidget { }

        NetworkWidget { }

        BatteryWidget { }

        VolumeWidget { }

        ClockWidget { }

        TrayWidget {
            parentWindow: bar
        }
    }
}
