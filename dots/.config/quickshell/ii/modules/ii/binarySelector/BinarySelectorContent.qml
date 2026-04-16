import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

MouseArea {
    id: rootArea
    property int columns: 5
    property real cellAspectRatio: 1.0
    property string filterText: ""

    focus: true
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.BackButton | Qt.ForwardButton

    onPressed: event => {
        if (event.button === Qt.BackButton) folderModel.navigateBack();
        else if (event.button === Qt.ForwardButton) folderModel.navigateForward();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            GlobalStates.binarySelectorOpen = false;
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Up) {
            folderModel.navigateUp();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Left) {
            folderModel.navigateBack();
            event.accepted = true;
        } else if (event.modifiers & Qt.AltModifier && event.key === Qt.Key_Right) {
            folderModel.navigateForward();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            if (rootArea.filterText.length > 0) {
                rootArea.filterText = rootArea.filterText.substring(0, rootArea.filterText.length - 1);
            }
            event.accepted = true;
        } else if (event.text.length > 0 && !(event.modifiers & Qt.ControlModifier)) {
            rootArea.filterText += event.text;
            event.accepted = true;
        }
    }

    FolderListModelWithHistory {
        id: folderModel
        folder: Qt.resolvedUrl(Directories.home)
        caseSensitive: false
        nameFilters: rootArea.filterText.length > 0
            ? rootArea.filterText.split(" ").filter(s => s.length > 0).map(s => `*${s}*`)
            : ["*"]
        showDirs: true
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        sortReversed: false
    }

    function selectFile(filePath, isDir) {
        if (isDir) {
            folderModel.folder = Qt.resolvedUrl(filePath);
            return;
        }
        CustomApps.addApp(filePath);
        rootArea.filterText = "";
        GlobalStates.binarySelectorOpen = false;
    }

    StyledRectangularShadow { target: background }

    Rectangle {
        id: background
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        focus: true
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

        RowLayout {
            anchors.fill: parent
            spacing: -4

            // Sidebar: quick directories
            Rectangle {
                Layout.fillHeight: true
                Layout.margins: 4
                implicitWidth: sideColumn.implicitWidth
                color: Appearance.colors.colLayer1
                radius: background.radius - Layout.margins

                ColumnLayout {
                    id: sideColumn
                    anchors.fill: parent
                    spacing: 0

                    StyledText {
                        Layout.margins: 12
                        font {
                            pixelSize: Appearance.font.pixelSize.normal
                            weight: Font.Medium
                        }
                        text: Translation.tr("Pick a binary")
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        implicitWidth: 170

                        Flickable {
                            id: sideFlick
                            anchors.fill: parent
                            contentHeight: sideRail.implicitHeight
                            clip: true
                            interactive: contentHeight > height
                            ScrollBar.vertical: StyledScrollBar {
                                visible: sideFlick.interactive
                            }

                            NavigationRailTabArray {
                                id: sideRail
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                expanded: true
                                currentIndex: {
                                    const model = sideRepeater.model;
                                    const current = FileUtils.trimFileProtocol(folderModel.folder.toString());
                                    for (let i = 0; i < model.length; i++) {
                                        const item = model[i];
                                        if (!item.path || item.path === "INVALID") continue;
                                        const resolved = FileUtils.trimFileProtocol(Qt.resolvedUrl(item.path).toString());
                                        if (resolved === current) return i;
                                    }
                                    return -1;
                                }

                                Repeater {
                                    id: sideRepeater
                                    model: [
                                        { icon: "home", name: Translation.tr("Home"), path: Directories.home },
                                        { icon: "download", name: Translation.tr("Downloads"), path: Directories.downloads },
                                        { icon: "desktop_windows", name: Translation.tr("Desktop"), path: `${Directories.home}/Desktop` },
                                        { icon: "folder", name: "Applications", path: `${Directories.home}/Applications` },
                                        { icon: "", name: "---", path: "INVALID" },
                                        { icon: "deployed_code", name: "/usr/bin", path: "file:///usr/bin" },
                                        { icon: "deployed_code", name: "/usr/local/bin", path: "file:///usr/local/bin" },
                                        { icon: "deployed_code", name: "/opt", path: "file:///opt" },
                                    ]
                                    delegate: NavigationRailButton {
                                        required property var modelData
                                        required property int index
                                        baseSize: 40
                                        baseHighlightHeight: 32
                                        iconSize: 18
                                        buttonIcon: modelData.icon
                                        buttonText: modelData.name
                                        expanded: true
                                        toggled: sideRail.currentIndex === index
                                        showToggledHighlight: false
                                        enabled: modelData.icon.length > 0
                                        onClicked: {
                                            folderModel.folder = Qt.resolvedUrl(modelData.path);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Main: address bar + grid
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                AddressBar {
                    id: addressBar
                    Layout.margins: 4
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    directory: FileUtils.trimFileProtocol(folderModel.folder.toString())
                    radius: background.radius - Layout.margins
                    onNavigateToDirectory: path => {
                        folderModel.folder = Qt.resolvedUrl(path.length === 0 ? "/" : path);
                    }
                }

                Item {
                    id: gridRegion
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledText {
                        visible: grid.count === 0
                        anchors.centerIn: parent
                        text: rootArea.filterText.length > 0
                            ? Translation.tr("No matches for \"%1\"").arg(rootArea.filterText)
                            : Translation.tr("Empty folder")
                        font.family: Appearance.font.family.reading
                    }

                    GridView {
                        id: grid
                        anchors.fill: parent
                        cellWidth: width / rootArea.columns
                        cellHeight: cellWidth / rootArea.cellAspectRatio
                        interactive: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        bottomMargin: filterBar.visible ? filterBar.implicitHeight + 16 : 0
                        ScrollBar.vertical: StyledScrollBar {}
                        model: folderModel

                        delegate: BinaryFileItem {
                            required property var modelData
                            required property int index
                            fileModelData: modelData
                            width: grid.cellWidth
                            height: grid.cellHeight
                            onActivated: rootArea.selectFile(modelData.filePath, modelData.fileIsDir)
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: gridRegion.width
                                height: gridRegion.height
                                radius: background.radius
                            }
                        }
                    }

                    Rectangle {
                        id: filterBar
                        visible: rootArea.filterText.length > 0
                        anchors {
                            bottom: parent.bottom
                            horizontalCenter: parent.horizontalCenter
                            bottomMargin: 8
                        }
                        implicitWidth: Math.min(parent.width - 40, filterText.implicitWidth + 40)
                        implicitHeight: 36
                        color: Appearance.m3colors.m3surfaceContainerLow
                        radius: Appearance.rounding.full
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 8

                            MaterialSymbol {
                                text: "filter_alt"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                id: filterText
                                text: rootArea.filterText
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates
        function onBinarySelectorOpenChanged() {
            if (GlobalStates.binarySelectorOpen) {
                rootArea.filterText = "";
                rootArea.forceActiveFocus();
            }
        }
    }
}
