import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool detach: false

    function toggleDetach() {
        root.detach = !root.detach;
    }

    onDetachChanged: {
        if (root.detach) {
            GlobalFocusGrab.removeDismissable(launcherLoader.item);
            launcherLoader.active = false;
            detachedLoader.active = true;
        } else {
            detachedLoader.active = false;
            launcherLoader.active = true;
        }
    }

    component LauncherContent: MouseArea {
        id: contentRoot
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: event => {
            if (settingsOverlay.shown) {
                event.accepted = false;
                return;
            }
            if (event.button === Qt.RightButton) {
                contextMenu.selectedAppIndex = -1;
                contextMenu.selectedFolderId = "";
                contextMenu.openFolderId = folderViewer.active ? (folderViewer.folder?.id ?? "") : "";
                contextMenu.x = event.x - contextMenu.width / 2;
                contextMenu.y = event.y;
                contextMenu.openAt();
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }

        readonly property int iconSize: Persistent.states.appLauncher?.iconSize ?? 64

        // Tracks which folder tile the current drag is hovering over.
        // Cleared on drop/release. Uses folder id to survive model updates.
        property string hoverFolderId: ""
        property int draggedEntryIndex: -1
        // True while an external file-manager drag (source === null) hovers over the launcher.
        property bool externalDragHover: false

        readonly property var gridModel: {
            const folders = (CustomApps.folders || []).map(f => ({
                _isFolder: true,
                id: f.id,
                name: f.name,
                icon: f.icon,
                appIndices: f.appIndices
            }))
            const roots = CustomApps.rootEntries || []
            return folders.concat(roots)
        }

        property bool vimiumActive: false
        property string vimiumTyped: ""
        property bool settingsVimiumActive: false
        property string settingsVimiumTyped: ""
        property bool folderVimiumActive: false
        property string folderVimiumTyped: ""

        readonly property bool inSettings: settingsOverlay.shown
        readonly property bool isFolderOpen: folderViewer.active
        readonly property bool canActivateVimium: !contextMenu.visible && !renameDialog.visible

        readonly property var vimiumHints: {
            const count = 1 + gridModel.length
            return _generateHints(count)
        }

        readonly property var settingsVimiumHints: {
            const foldersLen = CustomApps.folders ? CustomApps.folders.length : 0
            return _generateHints(5 + foldersLen)
        }

        readonly property var folderVimiumHints: {
            const _e = CustomApps.entries
            const _f = CustomApps.folders
            if (!folderViewer.active || !folderViewer.folder) return _generateHints(2)
            const apps = CustomApps.appsInFolder(folderViewer.folder.id)
            return _generateHints(2 + (apps ? apps.length : 0))
        }

        function _generateHints(count) {
            const chars = "ASDFGHJKLQWERTYUIOP"
            const n = chars.length
            const hints = []
            if (count <= n) {
                for (let i = 0; i < count; i++)
                    hints.push(chars[i])
            } else if (count <= n * n) {
                for (let i = 0; i < count; i++)
                    hints.push(chars[Math.floor(i / n)] + chars[i % n])
            } else {
                for (let i = 0; i < count; i++) {
                    hints.push(chars[Math.floor(i / (n * n))] + chars[Math.floor(i / n) % n] + chars[i % n])
                }
            }
            return hints
        }

        onVimiumTypedChanged: {
            if (!vimiumActive || vimiumTyped.length === 0) return
            const hints = vimiumHints
            const typed = vimiumTyped
            let exactIndex = -1
            let hasLongerPrefix = false
            for (let i = 0; i < hints.length; i++) {
                if (hints[i] === typed) exactIndex = i
                else if (hints[i].startsWith(typed)) hasLongerPrefix = true
            }
            if (exactIndex < 0 && !hasLongerPrefix) {
                vimiumTyped = ""
                return
            }
            if (exactIndex >= 0 && !hasLongerPrefix) {
                vimiumActive = false
                vimiumTyped = ""
                if (exactIndex === 0) {
                    settingsOverlay.shown = true
                } else {
                    const gm = gridModel[exactIndex - 1]
                    if (gm && gm._isFolder) folderViewer.open(gm)
                    else if (gm) CustomApps.launch(gm)
                }
            }
        }

        onSettingsVimiumActiveChanged: {
            if (settingsOverlay.item) settingsOverlay.item.vimiumActive = settingsVimiumActive
        }

        onSettingsVimiumTypedChanged: {
            if (settingsOverlay.item) settingsOverlay.item.vimiumTyped = settingsVimiumTyped
            if (!settingsVimiumActive || settingsVimiumTyped.length === 0) return
            const hints = settingsVimiumHints
            const typed = settingsVimiumTyped
            let exactIndex = -1
            let hasLongerPrefix = false
            for (let i = 0; i < hints.length; i++) {
                if (hints[i] === typed) exactIndex = i
                else if (hints[i].startsWith(typed)) hasLongerPrefix = true
            }
            if (exactIndex < 0 && !hasLongerPrefix) {
                settingsVimiumTyped = ""
                return
            }
            if (exactIndex >= 0 && !hasLongerPrefix) {
                settingsVimiumActive = false
                settingsVimiumTyped = ""
                if (exactIndex === 0) {
                    settingsOverlay.shown = false
                } else if (exactIndex === 1) {
                    if (settingsOverlay.item && settingsOverlay.item.settingsRef)
                        settingsOverlay.item.settingsRef.toggleNavExpand()
                } else if (exactIndex === 2) {
                    if (settingsOverlay.item && settingsOverlay.item.settingsRef)
                        settingsOverlay.item.settingsRef.currentPage = 0
                } else if (exactIndex === 3) {
                    if (Persistent.states.appLauncher)
                        Persistent.states.appLauncher.windowSize = "current"
                } else if (exactIndex === 4) {
                    if (Persistent.states.appLauncher)
                        Persistent.states.appLauncher.windowSize = "settings"
                } else {
                    CustomApps.removeFolderAt(exactIndex - 5)
                }
            }
        }

        onFolderVimiumTypedChanged: {
            if (!folderVimiumActive || folderVimiumTyped.length === 0) return
            const hints = folderVimiumHints
            const typed = folderVimiumTyped
            let exactIndex = -1
            let hasLongerPrefix = false
            for (let i = 0; i < hints.length; i++) {
                if (hints[i] === typed) exactIndex = i
                else if (hints[i].startsWith(typed)) hasLongerPrefix = true
            }
            if (exactIndex < 0 && !hasLongerPrefix) {
                folderVimiumTyped = ""
                return
            }
            if (exactIndex >= 0 && !hasLongerPrefix) {
                folderVimiumActive = false
                folderVimiumTyped = ""
                if (exactIndex === 0) {
                    GlobalStates.binarySelectorTargetFolderId = folderViewer.folder?.id ?? ""
                    GlobalStates.binarySelectorOpen = true
                } else if (exactIndex === 1) {
                    folderViewer.close()
                } else {
                    const apps = CustomApps.appsInFolder(folderViewer.folder?.id ?? "")
                    const appIndex = exactIndex - 2
                    if (apps && appIndex < apps.length) {
                        CustomApps.launch(apps[appIndex])
                        folderViewer.close()
                    }
                }
            }
        }

        Rectangle {
            id: innerLayer
            anchors.fill: parent
            anchors.margins: 10
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            Item {
                id: headerBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: 58

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: settingsButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 20
                    anchors.topMargin: 10
                    anchors.bottomMargin: 6
                    spacing: 0

                    StyledText {
                        text: Translation.tr("Apps")
                        color: Appearance.colors.colOnLayer1
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.larger
                            variableAxes: Appearance.font.variableAxes.title
                        }
                    }

                    StyledText {
                        topPadding: -1
                        text: appGrid.count === 0
                            ? Translation.tr("Right-click to add an application")
                            : Translation.tr("%1 items · drag onto a folder to group").arg(appGrid.count)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                RippleButton {
                    id: settingsButton
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    visible: !settingsOverlay.shown
                    onClicked: settingsOverlay.shown = true
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "settings"
                        iconSize: 20
                    }

                    VimiumHintLabel {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -5
                        anchors.topMargin: -5
                        hintText: contentRoot.vimiumHints[0] ?? ""
                        typedText: contentRoot.vimiumTyped
                        vimiumActive: contentRoot.vimiumActive
                    }
                }
            }

            PagePlaceholder {
                visible: appGrid.count === 0 && !contentRoot.externalDragHover
                icon: "apps"
                title: Translation.tr("No applications yet")
                description: Translation.tr("Right-click anywhere to add one")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            GridView {
                id: appGrid
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: headerBar.height + 4
                visible: count > 0
                cellWidth: contentRoot.iconSize + 76
                cellHeight: contentRoot.iconSize + 76
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}

                model: contentRoot.gridModel

                delegate: Item {
                    id: delegateRoot
                    required property var modelData
                    required property int index
                    width: appGrid.cellWidth
                    height: appGrid.cellHeight

                    readonly property bool isFolder: !!delegateRoot.modelData?._isFolder
                    readonly property int entryIndex: delegateRoot.modelData?._originalIndex ?? -1
                    readonly property string folderId: delegateRoot.modelData?.id ?? ""

                    VimiumHintLabel {
                        x: 12
                        y: 12
                        hintText: contentRoot.vimiumHints[delegateRoot.index + 1] ?? ""
                        typedText: contentRoot.vimiumTyped
                        vimiumActive: contentRoot.vimiumActive
                    }

                    // Android 16 style folder tile: rounded-square preview
                    // container with up to 4 mini app icons in a 2x2 grid.
                    Rectangle {
                        id: folderTileItem
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: delegateRoot.isFolder
                        radius: Appearance.rounding.normal
                        color: folderHoverArea.pressed
                            ? Appearance.colors.colLayer3Active
                            : folderHoverArea.containsMouse
                                ? Appearance.colors.colLayer3
                                : "transparent"

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 6

                            Rectangle {
                                id: folderSquircle
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: contentRoot.iconSize
                                Layout.preferredHeight: contentRoot.iconSize
                                radius: contentRoot.iconSize * 0.28
                                color: contentRoot.hoverFolderId === delegateRoot.folderId && contentRoot.draggedEntryIndex >= 0
                                    ? Appearance.colors.colPrimaryContainer
                                    : Appearance.m3colors.m3surfaceContainerHigh
                                border.width: contentRoot.hoverFolderId === delegateRoot.folderId && contentRoot.draggedEntryIndex >= 0 ? 2 : 0
                                border.color: Appearance.colors.colPrimary

                                Behavior on color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }
                                Behavior on border.color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }

                                FolderPreviewGrid {
                                    anchors.centerIn: parent
                                    width: parent.width * 0.72
                                    height: parent.height * 0.72
                                    icons: delegateRoot.isFolder ? CustomApps.folderPreviewIcons(delegateRoot.modelData, 4) : []
                                }

                                MaterialSymbol {
                                    visible: (delegateRoot.modelData?.appIndices?.length ?? 0) === 0
                                    anchors.centerIn: parent
                                    text: "folder"
                                    iconSize: Math.round(contentRoot.iconSize * 0.5)
                                    color: Appearance.colors.colOnLayer1
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: delegateRoot.modelData?.name ?? ""
                            }
                        }

                        // Drop target covers the whole tile (icon + label) so it's
                        // reachable even at the smallest icon sizes.
                        DropArea {
                            id: folderDropArea
                            anchors.fill: parent
                            onEntered: (drag) => {
                                if (contentRoot.draggedEntryIndex < 0) return
                                contentRoot.hoverFolderId = delegateRoot.folderId
                                drag.accept(Qt.MoveAction)
                            }
                            onExited: {
                                if (contentRoot.hoverFolderId === delegateRoot.folderId) {
                                    contentRoot.hoverFolderId = ""
                                }
                            }
                        }

                        MouseArea {
                            id: folderHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    const pos = folderHoverArea.mapToItem(contentRoot, mouse.x, mouse.y);
                                    contextMenu.selectedFolderId = delegateRoot.folderId;
                                    contextMenu.selectedAppIndex = -1;
                                    contextMenu.x = pos.x - contextMenu.width / 2;
                                    contextMenu.y = pos.y;
                                    contextMenu.openAt();
                                    return
                                }
                                folderViewer.open(delegateRoot.modelData)
                            }
                        }
                    }

                    Rectangle {
                        id: appTile
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: !delegateRoot.isFolder
                        radius: Appearance.rounding.normal
                        color: itemArea.pressed
                            ? Appearance.colors.colLayer3Active
                            : itemArea.containsMouse
                                ? Appearance.colors.colLayer3
                                : "transparent"

                        Drag.active: itemArea.drag.active
                        Drag.source: itemArea
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.supportedActions: Qt.MoveAction

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        states: State {
                            name: "dragging"
                            when: appTile.Drag.active
                            PropertyChanges {
                                target: appTile
                                anchors.fill: undefined
                                anchors.margins: 0
                                opacity: 0.88
                                scale: 1.04
                                z: 50
                            }
                            ParentChange {
                                target: appTile
                                parent: innerLayer
                            }
                        }

                        Behavior on scale {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: contentRoot.iconSize
                                Layout.preferredHeight: contentRoot.iconSize
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                source: {
                                    const icon = delegateRoot.modelData?.icon || ""
                                    if (icon.startsWith("/")) return "file://" + icon
                                    return Quickshell.iconPath(icon, "application-x-executable")
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: delegateRoot.modelData?.name ?? ""
                            }
                        }

                        MouseArea {
                            id: itemArea
                            // Exposed so DropArea sees it via drag.source during drag.
                            property int entryIndex: delegateRoot.entryIndex
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: appTile
                            drag.threshold: 8
                            preventStealing: true

                            onPressed: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    contentRoot.draggedEntryIndex = delegateRoot.entryIndex
                                }
                            }
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    const pos = itemArea.mapToItem(contentRoot, mouse.x, mouse.y);
                                    contextMenu.selectedAppIndex = delegateRoot.entryIndex;
                                    contextMenu.selectedFolderId = "";
                                    contextMenu.x = pos.x - contextMenu.width / 2;
                                    contextMenu.y = pos.y;
                                    contextMenu.openAt();
                                    return
                                }
                                if (!appTile.Drag.active) {
                                    CustomApps.launch(delegateRoot.modelData);
                                }
                            }
                            onReleased: {
                                const targetFolder = contentRoot.hoverFolderId
                                const idx = delegateRoot.entryIndex
                                contentRoot.hoverFolderId = ""
                                contentRoot.draggedEntryIndex = -1
                                if (targetFolder.length > 0 && idx >= 0) {
                                    CustomApps.addAppToFolder(targetFolder, idx)
                                }
                            }
                            onCanceled: {
                                contentRoot.hoverFolderId = ""
                                contentRoot.draggedEntryIndex = -1
                            }
                        }
                    }
                }
            }

            FadeLoader {
                id: settingsOverlay
                anchors.fill: parent
                z: 15
                shown: false
                sourceComponent: Rectangle {
                    id: settingsRect
                    color: Appearance.m3colors.m3surfaceContainerLow
                    radius: Appearance.rounding.normal

                    property var settingsRef: null
                    property bool vimiumActive: contentRoot.settingsVimiumActive
                    property string vimiumTyped: contentRoot.settingsVimiumTyped

                    Component.onCompleted: settingsRect.settingsRef = launcherSettings

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                    }

                    AppLauncherSettings {
                        id: launcherSettings
                        anchors.fill: parent
                        vimiumActive: settingsRect.vimiumActive
                        vimiumTyped: settingsRect.vimiumTyped
                        vimiumHints: contentRoot.settingsVimiumHints
                        onClosed: settingsOverlay.shown = false
                    }
                }
            }

            // Overlay shown while an external binary is dragged over the launcher (detach mode).
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: parent.radius
                visible: contentRoot.externalDragHover
                z: 25
                color: "transparent"
                border.width: 2
                border.color: Appearance.colors.colPrimary

                Behavior on border.color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Appearance.colors.colPrimaryContainer
                    opacity: 0.12
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "add_circle"
                        iconSize: 48
                        color: Appearance.colors.colPrimary
                        opacity: 0.9
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Drop to add application")
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.normal
                    }
                }
            }

            // Android 16 style expanded folder: dimmed backdrop + centered panel.
            Loader {
                id: folderViewer
                anchors.fill: parent
                z: 20
                active: false
                property var folder: null

                function open(f) {
                    folderViewer.folder = f
                    folderViewer.active = true
                }

                function close() {
                    folderViewer.active = false
                    folderViewer.folder = null
                }

                onActiveChanged: {
                    if (!active) {
                        contentRoot.folderVimiumActive = false
                        contentRoot.folderVimiumTyped = ""
                    }
                }

                sourceComponent: AppFolderViewer {
                    folder: folderViewer.folder
                    iconSize: contentRoot.iconSize
                    vimiumActive: contentRoot.folderVimiumActive
                    vimiumTyped: contentRoot.folderVimiumTyped
                    vimiumHints: contentRoot.folderVimiumHints
                    onClosed: folderViewer.close()
                    onRenameAppRequested: (appIndex, currentName) => renameDialog.openForApp(appIndex, currentName)
                }
            }
        }

        AppContextMenu {
            id: contextMenu
            onFolderOpenRequested: (folder) => folderViewer.open(folder)
            onRenameAppRequested: (appIndex, currentName) => renameDialog.openForApp(appIndex, currentName)
            onRenameFolderRequested: (folderId, currentName) => renameDialog.openForFolder(folderId, currentName)
        }

        RenameDialog {
            id: renameDialog
            anchors.fill: parent
        }

        MouseArea {
            anchors.fill: parent
            visible: contextMenu.visible
            z: 9
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: event => {
                const localX = event.x;
                const localY = event.y;
                if (localX < contextMenu.x || localX > contextMenu.x + contextMenu.width
                    || localY < contextMenu.y || localY > contextMenu.y + contextMenu.height) {
                    contextMenu.hide();
                    event.accepted = true;
                } else {
                    event.accepted = false;
                }
            }
        }

        // Receives file drops from external apps (file managers) in detach mode.
        // Ignores internal QML drags (drag.source !== null) so folder drop targets remain functional.
        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]

            onEntered: (drag) => {
                if (drag.source !== null) return
                if (settingsOverlay.shown) return
                contentRoot.externalDragHover = true
                drag.accept(Qt.CopyAction)
            }
            onExited: {
                contentRoot.externalDragHover = false
            }
            onDropped: (drop) => {
                contentRoot.externalDragHover = false
                if (settingsOverlay.shown) return
                const raw = drop.getDataAsString("text/uri-list")
                if (!raw) return
                const urls = raw.split(/\r?\n/).filter(u => u.trim().length > 0)
                const targetFolderId = folderViewer.active ? (folderViewer.folder?.id ?? "") : ""
                for (let i = 0; i < urls.length; i++) {
                    const filePath = urls[i].trim()
                    CustomApps.addApp(filePath)
                    if (targetFolderId.length > 0) {
                        const idx = CustomApps.indexOfPath(filePath)
                        if (idx >= 0) CustomApps.addAppToFolder(targetFolderId, idx)
                    }
                }
                drop.accept(Qt.CopyAction)
            }
        }
    }

    Loader {
        id: launcherLoader
        active: true

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: GlobalStates.appLauncherOpen

            function hide() {
                GlobalStates.appLauncherOpen = false;
            }

            exclusionMode: ExclusionMode.Normal
            WlrLayershell.namespace: "quickshell:appLauncher"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            mask: Region {
                item: launcherBackground
            }

            onVisibleChanged: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                } else {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    panelWindow.hide();
                }
            }

            StyledRectangularShadow {
                target: launcherBackground
                radius: launcherBackground.radius
            }

            Rectangle {
                id: launcherBackground
                focus: true
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                readonly property bool fixedSize: (Persistent.states.appLauncher?.windowSize ?? "settings") === "settings"
                anchors.centerIn: parent
                width: fixedSize ? 900 : (parent.width - 2 * Appearance.sizes.hyprlandGapsOut)
                height: fixedSize ? 750 : (parent.height - 2 * Appearance.sizes.hyprlandGapsOut)

                Behavior on width {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on height {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                LauncherContent {
                    id: launcherContent
                }

                Keys.onPressed: (event) => {
                    const inSettings = launcherContent.inSettings;

                    if (event.key === Qt.Key_Escape) {
                        if (launcherContent.isFolderOpen && launcherContent.folderVimiumActive) {
                            launcherContent.folderVimiumActive = false;
                            launcherContent.folderVimiumTyped = "";
                            event.accepted = true;
                            return;
                        }
                        if (!inSettings && launcherContent.vimiumActive) {
                            launcherContent.vimiumActive = false;
                            launcherContent.vimiumTyped = "";
                            event.accepted = true;
                            return;
                        }
                        if (inSettings && launcherContent.settingsVimiumActive) {
                            launcherContent.settingsVimiumActive = false;
                            launcherContent.settingsVimiumTyped = "";
                            event.accepted = true;
                            return;
                        }
                        if (!inSettings) {
                            panelWindow.hide();
                            return;
                        }
                        return;
                    }

                    if (event.key === Qt.Key_F && !event.modifiers) {
                        if (!launcherContent.canActivateVimium) return;

                        if (inSettings) {
                            if (!launcherContent.settingsVimiumActive) {
                                launcherContent.settingsVimiumActive = true;
                                launcherContent.settingsVimiumTyped = "";
                                event.accepted = true;
                                return;
                            }
                        } else if (launcherContent.isFolderOpen) {
                            if (!launcherContent.folderVimiumActive) {
                                launcherContent.folderVimiumActive = true;
                                launcherContent.folderVimiumTyped = "";
                                event.accepted = true;
                                return;
                            }
                        } else {
                            if (!launcherContent.vimiumActive) {
                                launcherContent.vimiumActive = true;
                                launcherContent.vimiumTyped = "";
                                event.accepted = true;
                                return;
                            }
                        }
                    }

                    if (launcherContent.isFolderOpen && launcherContent.folderVimiumActive) {
                        if (event.key === Qt.Key_Backspace && launcherContent.folderVimiumTyped.length > 0) {
                            launcherContent.folderVimiumTyped = launcherContent.folderVimiumTyped.slice(0, -1);
                            event.accepted = true;
                            return;
                        }
                        const ch = event.text.toUpperCase();
                        if (event.text.length > 0 && ch >= 'A' && ch <= 'Z') {
                            launcherContent.folderVimiumTyped += ch;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (!inSettings && launcherContent.vimiumActive) {
                        if (event.key === Qt.Key_Backspace && launcherContent.vimiumTyped.length > 0) {
                            launcherContent.vimiumTyped = launcherContent.vimiumTyped.slice(0, -1);
                            event.accepted = true;
                            return;
                        }
                        const ch = event.text.toUpperCase();
                        if (event.text.length > 0 && ch >= 'A' && ch <= 'Z') {
                            launcherContent.vimiumTyped += ch;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (inSettings && launcherContent.settingsVimiumActive) {
                        if (event.key === Qt.Key_Backspace && launcherContent.settingsVimiumTyped.length > 0) {
                            launcherContent.settingsVimiumTyped = launcherContent.settingsVimiumTyped.slice(0, -1);
                            event.accepted = true;
                            return;
                        }
                        const ch = event.text.toUpperCase();
                        if (event.text.length > 0 && ch >= 'A' && ch <= 'Z') {
                            launcherContent.settingsVimiumTyped += ch;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    Loader {
        id: detachedLoader
        active: false

        sourceComponent: FloatingWindow {
            id: detachedRoot
            color: "transparent"
            visible: GlobalStates.appLauncherOpen

            readonly property bool fixedSize: (Persistent.states.appLauncher?.windowSize ?? "settings") === "settings"
            width: fixedSize ? 900 : implicitWidth
            height: fixedSize ? 750 : implicitHeight

            StyledRectangularShadow {
                target: detachedBackground
                radius: detachedBackground.radius
            }

            Rectangle {
                id: detachedBackground
                focus: true
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                LauncherContent {
                    id: launcherContent
                }

                Keys.onPressed: (event) => {
                    const inSettings = launcherContent.inSettings;

                    if (event.key === Qt.Key_Escape) {
                        if (launcherContent.isFolderOpen && launcherContent.folderVimiumActive) {
                            launcherContent.folderVimiumActive = false;
                            launcherContent.folderVimiumTyped = "";
                            event.accepted = true;
                            return;
                        }
                        if (!inSettings && launcherContent.vimiumActive) {
                            launcherContent.vimiumActive = false;
                            launcherContent.vimiumTyped = "";
                            event.accepted = true;
                            return;
                        }
                        if (inSettings && launcherContent.settingsVimiumActive) {
                            launcherContent.settingsVimiumActive = false;
                            launcherContent.settingsVimiumTyped = "";
                            event.accepted = true;
                            return;
                        }
                        return;
                    }

                    if (event.key === Qt.Key_F && !event.modifiers) {
                        if (!launcherContent.canActivateVimium) return;

                        if (inSettings) {
                            if (!launcherContent.settingsVimiumActive) {
                                launcherContent.settingsVimiumActive = true;
                                launcherContent.settingsVimiumTyped = "";
                                event.accepted = true;
                                return;
                            }
                        } else if (launcherContent.isFolderOpen) {
                            if (!launcherContent.folderVimiumActive) {
                                launcherContent.folderVimiumActive = true;
                                launcherContent.folderVimiumTyped = "";
                                event.accepted = true;
                                return;
                            }
                        } else {
                            if (!launcherContent.vimiumActive) {
                                launcherContent.vimiumActive = true;
                                launcherContent.vimiumTyped = "";
                                event.accepted = true;
                                return;
                            }
                        }
                    }

                    if (launcherContent.isFolderOpen && launcherContent.folderVimiumActive) {
                        if (event.key === Qt.Key_Backspace && launcherContent.folderVimiumTyped.length > 0) {
                            launcherContent.folderVimiumTyped = launcherContent.folderVimiumTyped.slice(0, -1);
                            event.accepted = true;
                            return;
                        }
                        const ch = event.text.toUpperCase();
                        if (event.text.length > 0 && ch >= 'A' && ch <= 'Z') {
                            launcherContent.folderVimiumTyped += ch;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (!inSettings && launcherContent.vimiumActive) {
                        if (event.key === Qt.Key_Backspace && launcherContent.vimiumTyped.length > 0) {
                            launcherContent.vimiumTyped = launcherContent.vimiumTyped.slice(0, -1);
                            event.accepted = true;
                            return;
                        }
                        const ch = event.text.toUpperCase();
                        if (event.text.length > 0 && ch >= 'A' && ch <= 'Z') {
                            launcherContent.vimiumTyped += ch;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (inSettings && launcherContent.settingsVimiumActive) {
                        if (event.key === Qt.Key_Backspace && launcherContent.settingsVimiumTyped.length > 0) {
                            launcherContent.settingsVimiumTyped = launcherContent.settingsVimiumTyped.slice(0, -1);
                            event.accepted = true;
                            return;
                        }
                        const ch = event.text.toUpperCase();
                        if (event.text.length > 0 && ch >= 'A' && ch <= 'Z') {
                            launcherContent.settingsVimiumTyped += ch;
                            event.accepted = true;
                        }
                        return;
                    }

                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen;
        }

        function close(): void {
            GlobalStates.appLauncherOpen = false;
        }

        function open(): void {
            GlobalStates.appLauncherOpen = true;
        }
    }

    GlobalShortcut {
        name: "appLauncherToggle"
        description: "Toggles app launcher on press"

        onPressed: {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen;
        }
    }

    GlobalShortcut {
        name: "appLauncherToggleDetach"
        description: "Detach app launcher into a window / attach it back"

        onPressed: {
            root.toggleDetach();
        }
    }
}
