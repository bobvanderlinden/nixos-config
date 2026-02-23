//@ pragma UseQApplication
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Shell root - manages the bar, notification daemon, and OSD overlays.
// Binary paths are substituted by Nix via sed on @placeholder@ tokens.
ShellRoot {
    id: shellRoot

    // ── Notification daemon ───────────────────────────────────────────────────
    NotificationServer {
        id: notifServer
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(n) {
            n.tracked = true;
            // Spread into ScriptModel so ListView picks up the change reactively.
            notifModel.values = [...notifServer.trackedNotifications.values];
        }
    }

    // ScriptModel wrapper — avoids the "Non list data QVariant(QObject*) assigned
    // to Variants.model" silent-fail when passing ObjectModel directly.
    ScriptModel {
        id: notifModel
        values: [...notifServer.trackedNotifications.values]
    }

    // ── Notification toast stack (one per screen, top-right) ─────────────────
    Variants {
        model: Quickshell.screens

        delegate: NotificationPopup {
            required property var modelData
            screen: modelData
            // notifModel is accessible by id from anywhere in the same ShellRoot
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
