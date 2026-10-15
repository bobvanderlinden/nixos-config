pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    property list<NotificationWrapper> notifications: []

    NotificationServer {
        id: server

        // Reload intentionally expires old notifications. Quickshell does not
        // preserve their remaining timeout when re-emitting them on reload.
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
            root.notifications = [...root.notifications, wrapper];
        }
    }

    component NotificationWrapper: QtObject {
        id: wrapper

        required property Notification notification
        property bool closed: false
        property int viewCount: 0
        property double deadline: 0
        readonly property int timeout: expireTimeout < 0 ? 5000 : expireTimeout

        readonly property string summary: notification?.summary ?? ""
        readonly property string body: notification?.body ?? ""
        readonly property string appName: notification?.appName ?? ""
        readonly property string appIcon: notification?.appIcon ?? ""
        readonly property int urgency: notification?.urgency ?? 1
        readonly property int expireTimeout: notification?.expireTimeout ?? 0
        // Do not expose NotificationAction objects to delegates. Replacement
        // can delete them, and invocation can synchronously close their owner.
        readonly property var actions: notification?.actions.map(action => ({
            identifier: action.identifier, text: action.text
        })) ?? []
        readonly property string windowAddress: {
            const address = notification?.hints?.["x-hyprland-window-address"] ?? "";
            return address.toString().replace(/^0x/, "");
        }

        // Retain notification data until all delegates finish their exit
        // animations. A JS reference alone does not retain a C++ Notification.
        property RetainableLock lifetimeLock: RetainableLock {
            object: wrapper.notification
            locked: true
            onDropped: wrapper.retire()
            onAboutToDestroy: wrapper.retire()
        }

        property Connections notificationConnections: Connections {
            target: wrapper.notification
            function onClosed() { wrapper.retire(); }
            // Quickshell updates replacements in place without re-emitting
            // NotificationServer.notification. Restart on property changes.
            // An identical replacement has no observable signal in 0.3.1.
            function onExpireTimeoutChanged() { wrapper.restartExpiry(); }
            function onSummaryChanged() { wrapper.restartExpiry(); }
            function onBodyChanged() { wrapper.restartExpiry(); }
            function onAppNameChanged() { wrapper.restartExpiry(); }
            function onAppIconChanged() { wrapper.restartExpiry(); }
            function onUrgencyChanged() { wrapper.restartExpiry(); }
            function onActionsChanged() { wrapper.restartExpiry(); }
            function onHasActionIconsChanged() { wrapper.restartExpiry(); }
            function onHasInlineReplyChanged() { wrapper.restartExpiry(); }
            function onInlineReplyPlaceholderChanged() { wrapper.restartExpiry(); }
            function onHintsChanged() { wrapper.restartExpiry(); }
            function onResidentChanged() { wrapper.restartExpiry(); }
            function onTransientChanged() { wrapper.restartExpiry(); }
            function onDesktopEntryChanged() { wrapper.restartExpiry(); }
            function onImageChanged() { wrapper.restartExpiry(); }
        }

        property Timer expiryTimer: Timer {
            interval: Math.max(1, wrapper.timeout)
            onTriggered: wrapper.expire()
        }

        Component.onCompleted: restartExpiry()

        function restartExpiry(): void {
            if (closed) return;
            deadline = timeout === 0 ? 0 : Date.now() + timeout;
            expiryTimer.stop();
            if (timeout !== 0) expiryTimer.start();
        }

        function retainView(): void {
            viewCount++;
        }

        function releaseView(): void {
            viewCount--;
            collect();
        }

        function collect(): void {
            // Defer past model removal and signal delivery. Delegates keep the
            // wrapper and its data alive until Component.onDestruction.
            Qt.callLater(collectIfUnused);
        }

        function collectIfUnused(): void {
            if (closed && viewCount === 0) destroy();
        }

        function retire(): void {
            if (closed) return;
            closed = true;
            expiryTimer.stop();
            root.notifications = root.notifications.filter(candidate => candidate !== wrapper);
            collect();
        }

        function dismiss(): void {
            if (closed || !notification || lifetimeLock.retained) return;
            retire();
            notification.dismiss();
        }

        function expire(): void {
            if (closed || !notification || lifetimeLock.retained) return;
            retire();
            notification.expire();
        }

        function invokeAction(identifier: string): void {
            if (closed || !notification || lifetimeLock.retained) return;
            const action = notification.actions.find(candidate => candidate.identifier === identifier);
            if (!action) return;
            // Non-resident actions close themselves. Resident actions remain
            // usable until explicitly dismissed or expired.
            action.invoke();
        }

        function activate(): void {
            if (closed) return;
            if (actions.some(action => action.identifier === "default")) invokeAction("default");
            else dismiss();
        }
    }

    Component {
        id: wrapperComponent
        NotificationWrapper {}
    }
}
