pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Global notification singleton.
// Manages a list of active notification wrappers. Each wrapper holds a
// reference to the underlying Notification object and tracks whether it
// should be shown as a popup. Removal from the list happens when the
// Notification's Retainable object is dropped (i.e. the server releases it).
Singleton {
    id: root

    // The list of currently tracked notifications, as NotificationWrapper objects.
    property list<NotificationWrapper> notifications: []

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: function(notification) {
            notification.tracked = true;
            const wrapper = wrapperComponent.createObject(root, {
                notification: notification
            });
            root.notifications.push(wrapper);
            // When the server drops the notification (timeout or dismiss),
            // remove it from our list and destroy the wrapper.
            notification.Retainable.dropped.connect(function() {
                root.notifications = root.notifications.filter(w => w !== wrapper);
                wrapper.destroy();
            });
        }
    }

    component NotificationWrapper: QtObject {
        id: wrapper

        required property Notification notification

        readonly property string summary: notification?.summary ?? ""
        readonly property string body: notification?.body ?? ""
        readonly property string appName: notification?.appName ?? ""
        readonly property string appIcon: notification?.appIcon ?? ""
        readonly property int urgency: notification?.urgency ?? 1
        readonly property int expireTimeout: notification?.expireTimeout ?? 0
        readonly property var actions: notification?.actions ?? []

        function dismiss(): void {
            if (notification) notification.dismiss();
        }
    }

    Component {
        id: wrapperComponent
        NotificationWrapper {}
    }
}
