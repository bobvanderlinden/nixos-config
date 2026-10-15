"""Poll backlight state in one process shared by all BrightnessOsd views.

The kernel backlight ABI reports changes through uevents associated with
actual_brightness, not inotify MODIFY events on brightness. Driver support for
notifications varies, so read the requested brightness every 500 ms instead.
See https://docs.kernel.org/gpu/backlight.html.
"""

import json
from pathlib import Path
import time


class BrightnessMonitor:
    def __init__(self, directory=Path("/sys/class/backlight")):
        self.directory = Path(directory)
        self.previous = None
        self.last_message = None

    def sample(self):
        state = None
        try:
            devices = sorted(self.directory.iterdir())
        except OSError:
            devices = []
        for device in devices:
            try:
                maximum = int((device / "max_brightness").read_text())
                current = int((device / "brightness").read_text())
                if maximum <= 0 or not 0 <= current <= maximum:
                    continue
                state = (device.name, current / maximum)
                break
            except (OSError, ValueError):
                continue

        message = {
            "available": state is not None,
            "device": state[0] if state else "",
            "brightness": state[1] if state else 0,
        }
        changed = (
            state is not None
            and self.previous is not None
            and state[0] == self.previous[0]
            and state[1] != self.previous[1]
        )
        self.previous = state
        if message == self.last_message:
            return None
        self.last_message = message.copy()
        message["changed"] = changed
        return message


def main():
    monitor = BrightnessMonitor()
    while True:
        message = monitor.sample()
        if message is not None:
            print(json.dumps(message), flush=True)
        time.sleep(0.5)


if __name__ == "__main__":
    main()
