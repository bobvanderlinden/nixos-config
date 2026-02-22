import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Shell root - manages the bar and notification daemon.
// Binary paths are substituted by Nix via sed on @placeholder@ tokens.
ShellRoot {
    // ── Notification daemon (replaces swaync) ─────────────────────────────────
    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    // ── Notification popups (stacked bottom-right, newest on top) ─────────────
    Variants {
        model: notifServer.trackedNotifications

        delegate: NotificationPopup {
            required property var modelData
            required property int index
            notification: modelData
            popupIndex: index
        }
    }

    // ── Status bar (one instance per screen) ──────────────────────────────────
    Variants {
        model: Quickshell.screens.values

        delegate: StatusBar {
            required property var modelData
            screen: modelData
        }
    }

    // ── Volume OSD (one instance per screen) ──────────────────────────────────
    Variants {
        model: Quickshell.screens.values

        delegate: VolumeOsd {
            required property var modelData
            screen: modelData
        }
    }
}
