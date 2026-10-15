"""Run with: python3 -B home/profiles/quickshell/brightness-monitor-test.py"""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

specification = importlib.util.spec_from_file_location(
    "brightness_monitor", Path(__file__).with_name("brightness-monitor.py")
)
module = importlib.util.module_from_spec(specification)
specification.loader.exec_module(module)


class BrightnessMonitorTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.monitor = module.BrightnessMonitor(self.directory)

    def device(self, name="nvidia_0", current="50", maximum="100"):
        device = self.directory / name
        device.mkdir(exist_ok=True)
        (device / "brightness").write_text(current)
        (device / "max_brightness").write_text(maximum)
        return device

    def test_discovery_initial_unchanged_change_and_zero(self):
        device = self.device()
        self.assertEqual(self.monitor.sample(), {
            "available": True, "device": "nvidia_0", "brightness": 0.5,
            "changed": False,
        })
        self.assertIsNone(self.monitor.sample())
        (device / "brightness").write_text("75")
        sample = self.monitor.sample()
        self.assertEqual(sample["brightness"], 0.75)
        self.assertTrue(sample["changed"])
        self.assertIsNone(self.monitor.sample())
        (device / "brightness").write_text("0")
        sample = self.monitor.sample()
        self.assertTrue(sample["changed"])
        self.assertEqual(sample["brightness"], 0)

    def test_absent_then_added_and_removed(self):
        self.assertFalse(self.monitor.sample()["available"])
        self.assertIsNone(self.monitor.sample())
        device = self.device()
        self.assertFalse(self.monitor.sample()["changed"])
        (device / "brightness").unlink()
        self.assertFalse(self.monitor.sample()["available"])
        (device / "brightness").write_text("80")
        self.assertFalse(self.monitor.sample()["changed"])
        (device / "brightness").write_text("90")
        self.assertTrue(self.monitor.sample()["changed"])

    def test_missing_directory_and_permission_errors(self):
        self.assertFalse(module.BrightnessMonitor(self.directory / "missing")
                         .sample()["available"])
        self.device()
        with patch.object(Path, "read_text", side_effect=PermissionError):
            self.assertFalse(self.monitor.sample()["available"])
        self.assertFalse(self.monitor.sample()["changed"])
        with patch.object(Path, "iterdir", side_effect=PermissionError):
            self.assertFalse(self.monitor.sample()["available"])

    def test_invalid_values_and_fallback_device(self):
        for current, maximum in [("bad", "100"), ("1", "0"),
                                 ("-1", "100"), ("101", "100"),
                                 ("1", "bad")]:
            with self.subTest(current=current, maximum=maximum):
                self.device(current=current, maximum=maximum)
                sample = module.BrightnessMonitor(self.directory).sample()
                self.assertFalse(sample["available"])
        self.device("other_backlight", "20", "40")
        self.assertEqual(self.monitor.sample()["device"], "other_backlight")

    def test_device_change_establishes_new_baseline(self):
        first = self.device("first")
        self.monitor.sample()
        self.device("second", "90")
        self.assertIsNone(self.monitor.sample())
        (first / "brightness").unlink()
        sample = self.monitor.sample()
        self.assertEqual(sample["device"], "second")
        self.assertFalse(sample["changed"])

    def test_maximum_is_reread(self):
        device = self.device()
        self.monitor.sample()
        (device / "max_brightness").write_text("200")
        sample = self.monitor.sample()
        self.assertEqual(sample["brightness"], 0.25)
        self.assertTrue(sample["changed"])


if __name__ == "__main__":
    unittest.main()
