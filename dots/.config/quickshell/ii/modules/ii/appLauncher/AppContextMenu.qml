import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    z: 10
    visible: false
    property int selectedAppIndex: -1
    property string selectedFolderId: ""
    property string openFolderId: ""
    readonly property bool isFolderContext: selectedFolderId.length > 0
    readonly property bool isAppContext: selectedAppIndex >= 0
    readonly property bool isEmptyContext: !isFolderContext && !isAppContext
    readonly property string currentGpu: {
        if (isAppContext) {
            const e = CustomApps.entries[selectedAppIndex]
            return e?.gpu ?? ""
        }
        if (isFolderContext) {
            const f = CustomApps.folderById(selectedFolderId)
            return f?.gpu ?? ""
        }
        return ""
    }
    implicitWidth: 220
    implicitHeight: menuColumn.implicitHeight + 12
    color: Appearance.m3colors.m3surfaceContainer
    radius: Appearance.rounding.normal
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    signal folderOpenRequested(var folder)
    signal renameAppRequested(int appIndex, string currentName)
    signal renameFolderRequested(string folderId, string currentName)

    function openAt() {
        const maxX = parent.width - root.width - 8;
        const maxY = parent.height - root.height - 8;
        root.x = Math.max(8, Math.min(root.x, maxX));
        root.y = Math.max(8, Math.min(root.y, maxY));
        root.visible = true;
    }

    function hide() {
        openSubmenuTimer.stop()
        closeSubmenuTimer.stop()
        submenu.visible = false
        root.visible = false
    }

    function _toggleSubmenu() {
        openSubmenuTimer.stop()
        closeSubmenuTimer.stop()
        submenu.visible = !submenu.visible
    }

    function _applyGpu(gpu) {
        if (root.isAppContext) {
            const idx = root.selectedAppIndex
            CustomApps.setEntryGpu(idx, gpu)
            root.hide()
            CustomApps.launch(CustomApps.entries[idx])
            return
        }
        if (root.isFolderContext) {
            CustomApps.setFolderGpu(root.selectedFolderId, gpu)
            root.hide()
            return
        }
    }

    Timer {
        id: openSubmenuTimer
        interval: 100
        repeat: false
        onTriggered: submenu.visible = true
    }

    Timer {
        id: closeSubmenuTimer
        interval: 200
        repeat: false
        onTriggered: submenu.visible = false
    }

    StyledRectangularShadow {
        target: root
        visible: root.visible
    }

    ColumnLayout {
        id: menuColumn
        anchors.fill: parent
        anchors.margins: 6
        spacing: 0

        MenuButton {
            Layout.fillWidth: true
            visible: root.isAppContext
            symbolName: "drive_file_rename_outline"
            buttonText: Translation.tr("Rename")
            onClicked: {
                const idx = root.selectedAppIndex;
                const name = CustomApps.entries[idx]?.name ?? "";
                root.hide();
                root.renameAppRequested(idx, name);
            }
        }

        MenuButton {
            Layout.fillWidth: true
            visible: root.isAppContext
            symbolName: "delete"
            buttonText: Translation.tr("Remove from launcher")
            onClicked: {
                const idx = root.selectedAppIndex;
                root.hide();
                CustomApps.removeAppAt(idx);
            }
        }

        MenuButton {
            Layout.fillWidth: true
            visible: root.isFolderContext
            symbolName: "folder_open"
            buttonText: Translation.tr("Open folder")
            onClicked: {
                const fid = root.selectedFolderId;
                root.hide();
                const f = CustomApps.folderById(fid);
                if (f) root.folderOpenRequested(f);
            }
        }

        MenuButton {
            Layout.fillWidth: true
            visible: root.isFolderContext
            symbolName: "drive_file_rename_outline"
            buttonText: Translation.tr("Rename")
            onClicked: {
                const fid = root.selectedFolderId;
                const f = CustomApps.folderById(fid);
                root.hide();
                root.renameFolderRequested(fid, f?.name ?? "");
            }
        }

        MenuButton {
            Layout.fillWidth: true
            visible: root.isFolderContext
            symbolName: "folder_delete"
            buttonText: Translation.tr("Delete folder")
            onClicked: {
                const fid = root.selectedFolderId;
                root.hide();
                for (let i = 0; i < CustomApps.folders.length; i++) {
                    if (CustomApps.folders[i].id === fid) {
                        CustomApps.removeFolderAt(i);
                        break;
                    }
                }
            }
        }

        MenuButton {
            Layout.fillWidth: true
            visible: root.isEmptyContext
            symbolName: "add_circle"
            buttonText: Translation.tr("Add application")
            onClicked: {
                root.hide();
                GlobalStates.binarySelectorTargetFolderId = root.openFolderId;
                GlobalStates.binarySelectorOpen = true;
            }
        }

        MenuButton {
            Layout.fillWidth: true
            visible: root.isEmptyContext
            symbolName: "create_new_folder"
            buttonText: Translation.tr("Add folder")
            onClicked: {
                root.hide();
                CustomApps.createDefaultFolder();
            }
        }

        MenuButton {
            id: moreButton
            Layout.fillWidth: true
            visible: GpuInfo.hybrid && (root.isAppContext || root.isFolderContext)
            symbolName: "chevron_right"
            buttonText: Translation.tr("More")
            onClicked: root._toggleSubmenu()

            HoverHandler {
                id: moreHover
                onHoveredChanged: {
                    if (moreHover.hovered) {
                        closeSubmenuTimer.stop()
                        if (!submenu.visible) openSubmenuTimer.start()
                    } else {
                        openSubmenuTimer.stop()
                        if (!submenuHover.hovered) closeSubmenuTimer.start()
                    }
                }
            }
        }
    }

    Rectangle {
        id: submenu
        z: 11
        visible: false

        width: 200
        height: submenuColumn.implicitHeight + 12

        // Default: right of main menu, aligned to moreButton
        x: root.width - 2
        y: moreButton.y

        color: Appearance.m3colors.m3surfaceContainer
        radius: Appearance.rounding.normal
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        StyledRectangularShadow {
            target: submenu
            visible: submenu.visible
        }

        HoverHandler {
            id: submenuHover
            onHoveredChanged: {
                if (submenuHover.hovered) {
                    closeSubmenuTimer.stop()
                } else if (!moreHover.hovered) {
                    closeSubmenuTimer.start()
                }
            }
        }

        ColumnLayout {
            id: submenuColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 0

            MenuButton {
                Layout.fillWidth: true
                visible: root.currentGpu !== "dGPU"
                symbolName: "developer_board"
                buttonText: Translation.tr("Run on dGPU")
                onClicked: root._applyGpu("dGPU")
            }

            MenuButton {
                Layout.fillWidth: true
                visible: root.currentGpu === "dGPU"
                symbolName: "memory"
                buttonText: Translation.tr("Run on iGPU")
                onClicked: root._applyGpu("iGPU")
            }
        }
    }
}
