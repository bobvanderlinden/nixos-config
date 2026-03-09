pragma Singleton
import Quickshell

// Global bar state shared across all bar widgets.
// Used to coordinate which widget's popup is currently open so that
// opening one popup immediately closes all others.
Singleton {
    // The PopupWidget instance that currently has its popup open.
    // A PopupWidget writes this to itself when opening and to null when closing.
    // All other PopupWidgets watch this and close immediately when it changes.
    property var activePopupWidget: null
}
