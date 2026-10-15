import Quickshell
import QtQuick

// Standalone, windowless smoke test. Run with QT_QPA_PLATFORM=offscreen.
ShellRoot {
    property var firstConsumer: BrightnessProvider
    property var secondConsumer: BrightnessProvider
    property int changeCount: 0

    Connections {
        target: BrightnessProvider
        function onBrightnessChange() { changeCount += 1; }
    }

    Timer {
        interval: 1600
        running: true
        onTriggered: {
            if (firstConsumer !== secondConsumer)
                throw new Error("Brightness provider is not shared");
            if (changeCount !== 0)
                throw new Error("Startup or unchanged polling emitted a change");
            console.log("Brightness smoke test passed:", BrightnessProvider.device,
                        BrightnessProvider.available, BrightnessProvider.brightness);
            Qt.quit();
        }
    }
}
