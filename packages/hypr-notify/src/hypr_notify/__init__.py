"""
Sends a persistent desktop notification with an action to focus the originating
Hyprland window. Automatically dismisses the notification when the window is
focused.

Usage: hypr-notify [--app-name NAME] [--bell] [--replace-id ID] SUMMARY [BODY]
"""

import argparse
import asyncio
import enum
import os
import subprocess
import sys

from dbus_fast.aio import MessageBus
from dbus_fast import BusType, Message, MessageType


class WindowEvent(enum.Enum):
    FOCUSED = "focused"
    CLOSED = "closed"


NOTIFICATIONS_BUS = "org.freedesktop.Notifications"
NOTIFICATIONS_PATH = "/org/freedesktop/Notifications"
NOTIFICATIONS_IFACE = "org.freedesktop.Notifications"


async def send_notification(
    bus: MessageBus,
    *,
    app_name: str,
    replaces_id: int,
    summary: str,
    body: str,
) -> int:
    """Send a notification and return its ID."""
    reply = await bus.call(
        Message(
            destination=NOTIFICATIONS_BUS,
            path=NOTIFICATIONS_PATH,
            interface=NOTIFICATIONS_IFACE,
            member="Notify",
            signature="susssasa{sv}i",
            body=[
                app_name,
                replaces_id,
                "",  # app_icon
                summary,
                body,
                ["default", "Open"],  # actions: [key, label, ...]
                {},  # hints
                0,  # expire_timeout: 0 = never expire
            ],
        )
    )
    notification_id = reply.body[0]
    return notification_id


async def close_notification(bus: MessageBus, notification_id: int) -> None:
    """Close a notification by ID."""
    await bus.call(
        Message(
            destination=NOTIFICATIONS_BUS,
            path=NOTIFICATIONS_PATH,
            interface=NOTIFICATIONS_IFACE,
            member="CloseNotification",
            signature="u",
            body=[notification_id],
        )
    )


async def watch_hyprland_focus(
    window_address: str, *, verbose: bool = False
) -> WindowEvent:
    """Watch until the given window is focused or closed. Returns which happened."""
    instance_signature = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    runtime_dir = os.environ["XDG_RUNTIME_DIR"]
    socket_path = f"{runtime_dir}/hypr/{instance_signature}/.socket2.sock"

    if verbose:
        print(
            f"Watching socket {socket_path} for window {window_address}",
            file=sys.stderr,
        )

    reader, writer = await asyncio.open_unix_connection(socket_path)
    try:
        while True:
            line = await reader.readline()
            if not line:
                if verbose:
                    print("End of event stream", file=sys.stderr)
                break
            decoded = line.decode(errors="replace").strip()
            event, _, data = decoded.partition(">>")
            if verbose:
                print(f"Event: {event} data: {data}", file=sys.stderr)
            if event == "activewindowv2" and f"0x{data}" == window_address:
                return WindowEvent.FOCUSED
            if event == "closewindow" and f"0x{data}" == window_address:
                return WindowEvent.CLOSED
    finally:
        writer.close()

    return WindowEvent.CLOSED


async def _main() -> None:
    parser = argparse.ArgumentParser(description="Send a Hyprland-aware notification")
    parser.add_argument("--app-name", default="hypr-notify")
    parser.add_argument("--bell", action="store_true")
    parser.add_argument("--replace-id", type=int, default=0)
    parser.add_argument(
        "--window-address",
        default=os.environ.get("HYPR_WINDOW_ADDRESS", ""),
        help="Hyprland window address to track (default: $HYPR_WINDOW_ADDRESS)",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="Print diagnostic output to stderr"
    )
    parser.add_argument("summary")
    parser.add_argument("body", nargs="?", default="")
    args = parser.parse_args()

    window_address = args.window_address

    if args.bell:
        sys.stderr.write("\a")
        sys.stderr.flush()

    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    # Subscribe to ActionInvoked and NotificationClosed signals before sending.
    action_event: asyncio.Event = asyncio.Event()
    close_event: asyncio.Event = asyncio.Event()
    invoked_action: list[str] = []

    def on_action_invoked(message_notification_id: int, action_key: str) -> None:
        if message_notification_id == notification_id:
            if args.verbose:
                print(f"Action invoked: {action_key}", file=sys.stderr)
            invoked_action.append(action_key)
            action_event.set()

    def on_notification_closed(message_notification_id: int, reason: int) -> None:
        if message_notification_id == notification_id:
            if args.verbose:
                print(f"Notification closed, reason: {reason}", file=sys.stderr)
            close_event.set()
            action_event.set()  # unblock waiter if closed without action

    # We need notification_id before we can filter signals, but signals may arrive
    # before we set it. Use a placeholder and filter in the handlers.
    notification_id: int = 0

    bus.add_message_handler(
        lambda msg: (
            on_action_invoked(*msg.body)
            if (
                msg.message_type == MessageType.SIGNAL
                and msg.member == "ActionInvoked"
                and msg.interface == NOTIFICATIONS_IFACE
            )
            else None
        )
    )
    bus.add_message_handler(
        lambda msg: (
            on_notification_closed(*msg.body)
            if (
                msg.message_type == MessageType.SIGNAL
                and msg.member == "NotificationClosed"
                and msg.interface == NOTIFICATIONS_IFACE
            )
            else None
        )
    )

    # Subscribe to signals from the notifications service.
    await bus.call(
        Message(
            destination="org.freedesktop.DBus",
            path="/org/freedesktop/DBus",
            interface="org.freedesktop.DBus",
            member="AddMatch",
            signature="s",
            body=[
                f"type='signal',"
                f"sender='{NOTIFICATIONS_BUS}',"
                f"interface='{NOTIFICATIONS_IFACE}'"
            ],
        )
    )

    notification_id = await send_notification(
        bus,
        app_name=args.app_name,
        replaces_id=args.replace_id,
        summary=args.summary,
        body=args.body,
    )

    if args.verbose:
        print(f"Sent notification with id {notification_id}", file=sys.stderr)

    # Run the window-focus watcher and the action waiter concurrently.
    # Either can cause the notification to close; when one finishes, cancel the other.
    async def focus_watcher() -> None:
        if not window_address:
            return
        window_event = await watch_hyprland_focus(window_address, verbose=args.verbose)
        if args.verbose:
            print(
                f"Window event: {window_event.value}, closing notification",
                file=sys.stderr,
            )
        await close_notification(bus, notification_id)

    focus_task = asyncio.create_task(focus_watcher())
    action_task = asyncio.create_task(action_event.wait())

    done, pending = await asyncio.wait(
        [focus_task, action_task],
        return_when=asyncio.FIRST_COMPLETED,
    )

    for task in pending:
        task.cancel()
    await asyncio.gather(*pending, return_exceptions=True)

    # If an action was invoked, close the notification explicitly.
    # Some notification servers do not auto-close on action invocation.
    if invoked_action and not close_event.is_set():
        if args.verbose:
            print("Action invoked, closing notification", file=sys.stderr)
        await close_notification(bus, notification_id)

    # If the user clicked the action, focus the window.
    if invoked_action and invoked_action[0] == "default" and window_address:
        if args.verbose:
            print(f"Focusing window {window_address}", file=sys.stderr)
        subprocess.run(  # noqa: S603
            ["hyprctl", "dispatch", "focuswindow", f"address:{window_address}"],
            check=False,
        )

    bus.disconnect()


def main() -> None:
    asyncio.run(_main())
