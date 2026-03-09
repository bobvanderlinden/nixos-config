import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// The status bar panel — anchored to the bottom of the given screen.
PanelWindow {
    id: bar

    // Set by parent (shell.qml Variants loop).
    // Use a distinct name to avoid shadowing PanelWindow's built-in 'screen' property.
    required property var targetScreen

    screen: bar.targetScreen
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
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 6

        // ── Left: Workspaces ─────────────────────────────────────────────────
        WorkspacesWidget { }

        // ── Center: stretch ───────────────────────────────────────────────────
        Item { Layout.fillWidth: true }

        // ── Right: status modules ─────────────────────────────────────────────

        SystemdFailedUnits { }

        PrivacyWidget {
            barWindow: bar
        }

        GithubWidget {
            barWindow: bar
        }

        DockerWidget {
            barWindow: bar
        }

        AgentsWidget {
            barWindow: bar
        }

        SessionTimeWidget { }

        VolumeWidget {
            barWindow: bar
        }

        NetworkWidget {
            barWindow: bar
        }

        BatteryWidget {
            barWindow: bar
        }

        ClockWidget {
            barWindow: bar
        }

        TrayWidget {
            parentWindow: bar
        }
    }
}
