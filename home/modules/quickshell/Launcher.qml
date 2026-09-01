import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A desktop-entry launcher with a shell-command fallback.
//
// Providers return objects with label, detail, icon, keywords, and activate() fields.
// Their results share the same filtering, ordering, keyboard navigation, and
// result panel.
PanelWindow {
    id: root

    visible: false
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusiveZone: 0

    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""
    property int currentIndex: 0
    property var items: []
    required property var githubProvider
    property var providers: [workspaceProvider, desktopEntryProvider, shellCommandProvider]

    WorkspaceProvider {
        id: workspaceProvider
    }

    DesktopEntryProvider {
        id: desktopEntryProvider
    }

    ShellCommandProvider {
        id: shellCommandProvider
    }

    function normalize(value) {
        return value.toLocaleLowerCase().trim();
    }

    function score(item, normalizedQuery) {
        const haystack = [item.label, item.detail, ...(item.keywords || [])]
            .join(" ")
            .toLocaleLowerCase();
        if (normalizedQuery.length === 0)
            return 0;
        if (item.label.toLocaleLowerCase().startsWith(normalizedQuery))
            return 100;
        if (haystack.includes(normalizedQuery))
            return 10;
        return -1;
    }

    // Add providers here. Each can supply a separate item source without
    // changing matching, navigation, or the result panel.
    onQueryChanged: updateItems()

    function updateItems() {
        const normalizedQuery = normalize(query);
        const isGithubSearch = normalizedQuery === "gh" || normalizedQuery.startsWith("gh ");
        const searchQuery = isGithubSearch ? normalizedQuery.slice(2).trim() : normalizedQuery;
        const activeProviders = isGithubSearch ? [githubProvider] : providers;
        const providerItems = [];
        for (const provider of activeProviders)
            providerItems.push(...provider.items(searchQuery));

        items = providerItems
            .map((item, index) => ({ item, index, score: score(item, searchQuery) }))
            .filter(result => result.score >= 0)
            .sort((first, second) => second.score - first.score
                || (isGithubSearch ? first.index - second.index : first.item.label.localeCompare(second.item.label)))
            .map(result => result.item);
        currentIndex = 0;
    }

    function open() {
        visible = true;
    }

    function close() {
        visible = false;
    }

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    function moveSelection(offset) {
        if (items.length === 0)
            return;
        currentIndex = (currentIndex + offset + items.length) % items.length;
        results.positionViewAtIndex(currentIndex, ListView.Contain);
    }

    function activateCurrent() {
        if (currentIndex < 0 || currentIndex >= items.length)
            return;
        const item = items[currentIndex];
        close();
        item.activate();
    }

    onVisibleChanged: {
        if (!visible)
            return;
        searchInput.text = "";
        updateItems();
        searchInput.forceActiveFocus();
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.updateItems();
        }
    }

    Connections {
        target: githubProvider
        function onReviewRequestsChanged() { root.updateItems(); }
        function onTeamReviewRequestsChanged() { root.updateItems(); }
        function onDraftsChanged() { root.updateItems(); }
        function onWaitingForReviewChanged() { root.updateItems(); }
        function onNeedsActionChanged() { root.updateItems(); }
        function onReadyToMergeChanged() { root.updateItems(); }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        id: panel
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 120
        }
        width: 680
        height: 560
        color: "#1e1e2e"
        radius: 10
        border.color: "#44475a"
        border.width: 1

        ColumnLayout {
            id: content
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 10

            TextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "Search applications, GitHub with gh, or run a command"
                placeholderTextColor: "#bac2de"
                color: "#f8f8f2"
                font.pixelSize: 18
                selectByMouse: true

                background: Rectangle {
                    color: "#313244"
                    radius: 6
                    border.color: searchInput.activeFocus ? "#89b4fa" : "#44475a"
                    border.width: 1
                }

                onTextChanged: root.query = text
                onAccepted: root.activateCurrent()

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down) {
                        root.moveSelection(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-1);
                        event.accepted = true;
                    }
                }
            }

            ListView {
                id: results
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.items
                spacing: 2

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: results.width
                    height: 54
                    radius: 6
                    color: index === root.currentIndex ? "#45475a" : "transparent"

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 10

                        Item {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            IconImage {
                                anchors.fill: parent
                                visible: (modelData.glyph || "").length === 0
                                source: modelData.icon || ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: (modelData.glyph || "").length > 0
                                text: modelData.glyph || ""
                                color: "#89b4fa"
                                font.bold: true
                                font.pixelSize: 16
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: "#f8f8f2"
                                elide: Text.ElideRight
                                font.pixelSize: 15
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.detail
                                visible: text.length > 0
                                color: "#a6adc8"
                                elide: Text.ElideRight
                                font.pixelSize: 12
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.currentIndex = index
                        onClicked: {
                            root.currentIndex = index;
                            root.activateCurrent();
                        }
                    }
                }
            }
        }
    }
}
