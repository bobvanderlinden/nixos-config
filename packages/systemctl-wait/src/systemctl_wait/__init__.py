import argparse
import asyncio
import sys
from dataclasses import dataclass
from typing import Final

from dbus_fast import BusType, Message, MessageFlag, MessageType
from dbus_fast.aio import MessageBus

LOGIND_DESTINATION: Final = "org.freedesktop.login1"
LOGIND_PATH: Final = "/org/freedesktop/login1"
LOGIND_INTERFACE: Final = "org.freedesktop.login1.Manager"

BLOCKED_BY_INHIBITOR_LOCK: Final = "org.freedesktop.login1.BlockedByInhibitorLock"
UNKNOWN_METHOD: Final = "org.freedesktop.DBus.Error.UnknownMethod"

SD_LOGIND_ROOT_CHECK_INHIBITORS: Final = 1 << 0
SD_LOGIND_REBOOT_VIA_KEXEC: Final = 1 << 1
SD_LOGIND_SOFT_REBOOT: Final = 1 << 2


@dataclass(frozen=True)
class Action:
    method_with_flags: str
    legacy_method: str | None
    flags: int = 0


ACTIONS: Final[dict[str, Action]] = {
    "halt": Action("HaltWithFlags", "Halt"),
    "poweroff": Action("PowerOffWithFlags", "PowerOff"),
    "reboot": Action("RebootWithFlags", "Reboot"),
    "kexec": Action("RebootWithFlags", None, SD_LOGIND_REBOOT_VIA_KEXEC),
    "soft-reboot": Action("RebootWithFlags", None, SD_LOGIND_SOFT_REBOOT),
    "sleep": Action("Sleep", None),
    "suspend": Action("SuspendWithFlags", "Suspend"),
    "hibernate": Action("HibernateWithFlags", "Hibernate"),
    "hybrid-sleep": Action("HybridSleepWithFlags", "HybridSleep"),
    "suspend-then-hibernate": Action(
        "SuspendThenHibernateWithFlags",
        "SuspendThenHibernate",
    ),
}

ALIASES: Final[dict[str, str]] = {
    "shutdown": "poweroff",
}


class LogindCallError(Exception):
    def __init__(self, error_name: str, message: str):
        super().__init__(message)
        self.error_name = error_name
        self.message = message


def normalize_mode(mode: str) -> str:
    normalized = mode.lower()
    return ALIASES.get(normalized, normalized)


async def call_logind(bus: MessageBus, member: str, signature: str, body: list[object]) -> None:
    reply = await bus.call(
        Message(
            destination=LOGIND_DESTINATION,
            path=LOGIND_PATH,
            interface=LOGIND_INTERFACE,
            member=member,
            signature=signature,
            body=body,
            flags=MessageFlag.ALLOW_INTERACTIVE_AUTHORIZATION,
        )
    )

    if reply.message_type == MessageType.ERROR:
        message = reply.body[0] if reply.body else reply.error_name or "Unknown D-Bus error"
        raise LogindCallError(reply.error_name or "org.freedesktop.DBus.Error.Failed", message)


async def invoke_action(bus: MessageBus, action: Action) -> None:
    try:
        await call_logind(
            bus,
            action.method_with_flags,
            "t",
            [action.flags | SD_LOGIND_ROOT_CHECK_INHIBITORS],
        )
    except LogindCallError as error:
        if error.error_name != UNKNOWN_METHOD or action.legacy_method is None:
            raise

        await call_logind(bus, action.legacy_method, "b", [True])


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Wait for logind inhibitors before running a system power action",
    )
    parser.add_argument(
        "mode",
        help=(
            "one of: "
            + ", ".join([*ACTIONS.keys(), *ALIASES.keys()])
        ),
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=1.0,
        help="seconds to wait before retrying after an inhibitor block (default: 1.0)",
    )
    return parser


async def run(mode: str, interval: float) -> int:
    normalized_mode = normalize_mode(mode)
    action = ACTIONS.get(normalized_mode)
    if action is None:
        raise SystemExit(f"Unknown mode: {mode}")

    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()
    try:
        announced_wait = False

        while True:
            try:
                await invoke_action(bus, action)
                return 0
            except LogindCallError as error:
                if error.error_name != BLOCKED_BY_INHIBITOR_LOCK:
                    raise

                if not announced_wait:
                    print(
                        f"Waiting for inhibitors to clear before {normalized_mode}...",
                        file=sys.stderr,
                    )
                    announced_wait = True

                await asyncio.sleep(interval)
    finally:
        bus.disconnect()


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()

    if args.interval <= 0:
        raise SystemExit("--interval must be greater than 0")

    try:
        raise SystemExit(asyncio.run(run(args.mode, args.interval)))
    except LogindCallError as error:
        raise SystemExit(f"{error.error_name}: {error.message}") from error
