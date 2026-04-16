"""
agents-idle — exits 0 when no opencode agents are actively running.

Connects to the statebus subscribe socket, receives the current session state
replay, then monitors live updates. Exits 0 once no session is in an active
state or no sessions exist.
"""

import json
import os
import select
import socket
import sys

SOCKET_PATH = f"/run/user/{os.getuid()}/statebus-sub.sock"

# Seconds without a new message before the initial replay is considered done.
REPLAY_SETTLE_TIMEOUT = 0.1


def any_active(sessions: dict[str, str]) -> bool:
    return any(state in {"busy", "retry"} for state in sessions.values())


def main() -> None:
    sessions: dict[str, str] = {}

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        try:
            sock.connect(SOCKET_PATH)
        except FileNotFoundError:
            print(f"agents-idle: socket not found: {SOCKET_PATH}", file=sys.stderr)
            sys.exit(1)

        buffer = b""
        replay_done = False

        while True:
            timeout = REPLAY_SETTLE_TIMEOUT if not replay_done else None
            readable, _, _ = select.select([sock], [], [], timeout)

            if not readable:
                # Timeout elapsed with no new data — replay is complete.
                replay_done = True
                if not any_active(sessions):
                    sys.exit(0)
                continue

            data = sock.recv(4096)
            if not data:
                # Server closed the connection.
                if not any_active(sessions):
                    sys.exit(0)
                sys.exit(1)

            buffer += data
            lines = buffer.split(b"\n")
            buffer = lines[-1]  # keep any incomplete trailing line

            for raw_line in lines[:-1]:
                line = raw_line.strip()
                if not line:
                    continue

                try:
                    message = json.loads(line)
                except json.JSONDecodeError:
                    continue

                message_type = message.get("type")
                key = message.get("key")

                if message_type == "update" and key:
                    sessions[key] = message.get("state", "idle")
                elif message_type == "remove" and key:
                    sessions.pop(key, None)

                if replay_done and not any_active(sessions):
                    sys.exit(0)


if __name__ == "__main__":
    main()
