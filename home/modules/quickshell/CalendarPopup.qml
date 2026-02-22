import Quickshell
import QtQuick
import QtQuick.Layouts

// A minimal calendar popup anchored above the clock widget.
// Shows the current month with day-of-week headers and today highlighted.
//
// Usage: set anchorWindow (the bar PanelWindow) and anchorItem (the clock Item).
// PopupWindow.anchor is a grouped property — not an instantiable child type.
PopupWindow {
    id: root

    // The bar PanelWindow this popup belongs to
    property var anchorWindow
    // The Item in the bar to position above (the clock widget)
    property Item anchorItem

    anchor.window: root.anchorWindow
    anchor.rect: {
        if (!root.anchorItem || !root.anchorWindow) return Qt.rect(0, 0, 0, 0);
        const mapped = root.anchorItem.mapToItem(null, 0, 0);
        return Qt.rect(mapped.x, 0, root.anchorItem.width, 0);
    }
    anchor.adjustment: PopupAdjustment.Flip
    anchor.edges: Edges.Top

    color: "transparent"
    implicitWidth: calBox.implicitWidth + 24
    implicitHeight: calBox.implicitHeight + 24

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        id: calBox
        anchors.centerIn: parent
        implicitWidth: grid.implicitWidth + 24
        implicitHeight: monthRow.implicitHeight + header.implicitHeight + grid.implicitHeight + 28
        color: "#2a2b3d"
        radius: 10
        border.color: "#44475a"
        border.width: 1

        ColumnLayout {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            // Month + year heading with prev/next buttons
            RowLayout {
                id: monthRow
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "‹"
                    color: "#6272a4"
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.shiftMonth(-1)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                    color: "#f8f8f2"
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    text: "›"
                    color: "#6272a4"
                    font.pixelSize: 16
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.shiftMonth(1)
                    }
                }
            }

            // Day-of-week header: Mon–Sun
            RowLayout {
                id: header
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: "#6272a4"
                        font.pixelSize: 11
                    }
                }
            }

            // Day grid — 6 rows × 7 cols
            Grid {
                id: grid
                columns: 7
                spacing: 2

                Repeater {
                    model: root.calendarCells

                    Rectangle {
                        required property var modelData
                        implicitWidth: 28
                        implicitHeight: 24
                        radius: 4
                        color: modelData.isToday ? "#bd93f9" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.isToday ? "#1e1e2e"
                                 : modelData.inMonth  ? "#f8f8f2"
                                                      : "#44475a"
                            font.pixelSize: 12
                            font.bold: modelData.isToday
                        }
                    }
                }
            }
        }
    }

    // ── Calendar logic ────────────────────────────────────────────────────────

    property var viewDate: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)

    function shiftMonth(delta) {
        const d = root.viewDate;
        root.viewDate = new Date(d.getFullYear(), d.getMonth() + delta, 1);
    }

    onVisibleChanged: {
        if (visible)
            root.viewDate = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
    }

    // Produces 42 cell objects (6 weeks × 7 days), ISO week order (Mon first)
    property var calendarCells: {
        const today = clock.date;
        const year = root.viewDate.getFullYear();
        const month = root.viewDate.getMonth();
        const firstDow = (new Date(year, month, 1).getDay() + 6) % 7;
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const daysInPrev = new Date(year, month, 0).getDate();
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const offset = i - firstDow;
            let day, inMonth;
            if (offset < 0) {
                day = daysInPrev + offset + 1;
                inMonth = false;
            } else if (offset < daysInMonth) {
                day = offset + 1;
                inMonth = true;
            } else {
                day = offset - daysInMonth + 1;
                inMonth = false;
            }
            const isToday = inMonth
                && day === today.getDate()
                && month === today.getMonth()
                && year === today.getFullYear();
            cells.push({ day, inMonth, isToday });
        }
        return cells;
    }
}
