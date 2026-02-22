//@ pragma UseQApplication
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Shell root — manages the bar, OSDs, and notification daemon.
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

    // ── Notification popups (stacked, newest on top) ───────────────────────────
    // trackedNotifications is an ObjectModel — use .values for Variants.
    // Each popup looks up its own stacking index reactively.
    Variants {
        model: notifServer.trackedNotifications.values

        delegate: NotificationPopup {
            required property var modelData
            notification: modelData
            popupIndex: {
                const list = notifServer.trackedNotifications.values;
                for (let i = 0; i < list.length; i++) {
                    if (list[i] === modelData) return i;
                }
                return 0;
            }
        }
    }

    // ── Status bar (one instance per screen) ──────────────────────────────────
    Variants {
        model: Quickshell.screens

        delegate: StatusBar {
            required property var modelData
            screen: modelData
        }
    }

    // ── Volume OSD (one instance per screen) ──────────────────────────────────
    Variants {
        model: Quickshell.screens

        delegate: VolumeOsd {
            required property var modelData
            screen: modelData
        }
    }

    // ── Brightness OSD (one instance per screen) ──────────────────────────────
    Variants {
        model: Quickshell.screens

        delegate: BrightnessOsd {
            required property var modelData
            screen: modelData
        }
    }
}
