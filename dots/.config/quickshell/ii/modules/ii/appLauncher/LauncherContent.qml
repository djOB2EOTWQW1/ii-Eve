import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.appLauncher.settings
import qs.modules.ii.appLauncher.vimium
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "vimium/LauncherVimium.js" as LV

// Main launcher surface: header bar, app/folder grid, settings overlay,
// folder viewer, context menu, rename dialog, external-drop receiver.
// Instantiated both inside the attached PanelWindow and the detached
// FloatingWindow so the behaviour is identical in either mode.
MouseArea {
    id: root

    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    propagateComposedEvents: true

    readonly property int iconSize: Persistent.states.appLauncher?.iconSize ?? 64

    // Tracks which folder tile the current drag is hovering over.
    // Cleared on drop/release. Uses folder id to survive model updates.
    property string hoverFolderId: ""
    property int draggedEntryIndex: -1
    // True while an external file-manager drag (source === null) hovers over the launcher.
    property bool externalDragHover: false

    // Folder objects pass through unwrapped — the delegate identifies them by
    // the presence of `appIndices` (folders have it, root entries don't).
    readonly property var gridModel: (CustomApps.folders || []).concat(CustomApps.rootEntries || [])

    property bool vimiumActive: false
    property string vimiumTyped: ""
    property bool settingsVimiumActive: false
    property string settingsVimiumTyped: ""
    property bool folderVimiumActive: false
    property string folderVimiumTyped: ""

    property bool selectionModeActive: false
    property var selectedAppIndices: []

    readonly property bool inSettings: settingsOverlay.shown
    readonly property bool isFolderOpen: folderViewer.active
    readonly property bool isFolderSelectionModeActive: folderViewer.item?.selectionModeActive ?? false
    readonly property bool helpOverlayShown: helpOverlay.shown
    readonly property bool canActivateVimium: !contextMenu.visible && !renameDialog.visible && !helpOverlay.shown

    function toggleHelp() {
        const opening = !helpOverlay.shown
        if (opening) {
            vimiumActive = false; vimiumTyped = ""
            folderVimiumActive = false; folderVimiumTyped = ""
            settingsVimiumActive = false; settingsVimiumTyped = ""
        }
        helpOverlay.shown = opening
    }

    readonly property var vimiumHints: LV.generateHints(2 + gridModel.length)

    readonly property var settingsVimiumHints: {
        const foldersLen = CustomApps.folders ? CustomApps.folders.length : 0
        return LV.generateHints(5 + foldersLen)
    }

    readonly property var folderVimiumHints: {
        // Touch CustomApps.entries/folders so the binding re-evaluates when the
        // model changes even though we don't otherwise use those values here.
        const _e = CustomApps.entries
        const _f = CustomApps.folders
        if (!folderViewer.active || !folderViewer.folder) return LV.generateHints(2)
        const apps = CustomApps.appsInFolder(folderViewer.folder.id)
        return LV.generateHints(2 + (apps ? apps.length : 0))
    }

    function toggleAppSelection(entryIndex) {
        const arr = selectedAppIndices.slice()
        const pos = arr.indexOf(entryIndex)
        if (pos >= 0) arr.splice(pos, 1)
        else arr.push(entryIndex)
        selectedAppIndices = arr
        if (arr.length === 0) selectionModeActive = false
    }

    function deleteSelectedApps() {
        const sorted = selectedAppIndices.slice().sort((a, b) => b - a)
        for (let i = 0; i < sorted.length; i++) CustomApps.removeAppAt(sorted[i])
        selectedAppIndices = []
        selectionModeActive = false
    }

    function exitSelectionMode() {
        selectedAppIndices = []
        selectionModeActive = false
    }

    function exitFolderSelectionMode() {
        folderViewer.item?.exitSelectionMode()
    }

    function closeFolder() {
        folderViewer.close()
    }

    onInSettingsChanged: if (inSettings) exitSelectionMode()

    Connections {
        target: GlobalStates
        function onAppLauncherOpenChanged() {
            if (!GlobalStates.appLauncherOpen) root.exitSelectionMode()
        }
    }

    onPressed: event => {
        if (settingsOverlay.shown) {
            event.accepted = false
            return
        }
        if (event.button === Qt.RightButton) {
            contextMenu.selectedAppIndex = -1
            contextMenu.selectedFolderId = ""
            contextMenu.openFolderId = folderViewer.active ? (folderViewer.folder?.id ?? "") : ""
            contextMenu.x = event.x - contextMenu.width / 2
            contextMenu.y = event.y
            contextMenu.openAt()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    onVimiumTypedChanged: {
        if (!vimiumActive) return
        const r = LV.matchTyped(vimiumHints, vimiumTyped)
        if (r.action === "reset") { vimiumTyped = ""; return }
        if (r.action !== "commit") return
        vimiumActive = false
        vimiumTyped = ""
        _dispatchMainVimium(r.index)
    }

    function _dispatchMainVimium(idx) {
        if (idx === 0) {
            if (selectionModeActive) deleteSelectedApps()
            else settingsOverlay.shown = true
            return
        }
        if (idx === 1) {
            GlobalStates.binarySelectorTargetFolderId = ""
            GlobalStates.binarySelectorOpen = true
            return
        }
        const gm = gridModel[idx - 2]
        if (!gm) return
        if (gm.appIndices) { folderViewer.open(gm); return }
        if (selectionModeActive) {
            const eIdx = gm._originalIndex ?? -1
            if (eIdx >= 0) toggleAppSelection(eIdx)
        } else {
            CustomApps.launch(gm)
            GlobalStates.appLauncherOpen = false
        }
    }

    onSettingsVimiumActiveChanged: {
        if (settingsOverlay.item) settingsOverlay.item.vimiumActive = settingsVimiumActive
    }

    onSettingsVimiumTypedChanged: {
        if (settingsOverlay.item) settingsOverlay.item.vimiumTyped = settingsVimiumTyped
        if (!settingsVimiumActive) return
        const r = LV.matchTyped(settingsVimiumHints, settingsVimiumTyped)
        if (r.action === "reset") { settingsVimiumTyped = ""; return }
        if (r.action !== "commit") return
        settingsVimiumActive = false
        settingsVimiumTyped = ""
        _dispatchSettingsVimium(r.index)
    }

    function _dispatchSettingsVimium(idx) {
        if (idx === 0) {
            settingsOverlay.shown = false
            return
        }
        if (idx === 1) {
            if (settingsOverlay.item && settingsOverlay.item.settingsRef)
                settingsOverlay.item.settingsRef.toggleNavExpand()
            return
        }
        if (idx === 2) {
            if (settingsOverlay.item && settingsOverlay.item.settingsRef)
                settingsOverlay.item.settingsRef.currentPage = 0
            return
        }
        if (idx === 3) {
            if (Persistent.states.appLauncher)
                Persistent.states.appLauncher.windowSize = "current"
            return
        }
        if (idx === 4) {
            if (Persistent.states.appLauncher)
                Persistent.states.appLauncher.windowSize = "settings"
            return
        }
        CustomApps.removeFolderAt(idx - 5)
    }

    onFolderVimiumTypedChanged: {
        if (!folderVimiumActive) return
        const r = LV.matchTyped(folderVimiumHints, folderVimiumTyped)
        if (r.action === "reset") { folderVimiumTyped = ""; return }
        if (r.action !== "commit") return
        folderVimiumActive = false
        folderVimiumTyped = ""
        _dispatchFolderVimium(r.index)
    }

    function _dispatchFolderVimium(idx) {
        if (idx === 0) {
            GlobalStates.binarySelectorTargetFolderId = folderViewer.folder?.id ?? ""
            GlobalStates.binarySelectorOpen = true
            return
        }
        if (idx === 1) {
            folderViewer.close()
            return
        }
        const apps = CustomApps.appsInFolder(folderViewer.folder?.id ?? "")
        const appIndex = idx - 2
        if (!apps || appIndex >= apps.length) return
        if (root.isFolderSelectionModeActive) {
            const origIdx = apps[appIndex]._originalIndex ?? -1
            if (origIdx >= 0) folderViewer.item?.toggleAppSelection(origIdx)
        } else {
            CustomApps.launch(apps[appIndex])
            GlobalStates.appLauncherOpen = false
            folderViewer.close()
        }
    }

    Rectangle {
        id: innerLayerRect
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
                anchors.right: headerRightButtons.left
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
                    text: root.selectionModeActive
                        ? (root.selectedAppIndices.length > 0
                            ? Translation.tr("%1 selected · Esc to cancel").arg(root.selectedAppIndices.length)
                            : Translation.tr("Tap to select · Esc to cancel"))
                        : (appGrid.count === 0
                            ? Translation.tr("Right-click to add an application")
                            : Translation.tr("%1 items · drag onto a folder to group").arg(appGrid.count))
                    color: root.selectionModeActive
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }

            Row {
                id: headerRightButtons
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 12
                anchors.topMargin: 10
                spacing: 4

                RippleButton {
                    id: deleteSelectionButton
                    visible: root.selectionModeActive
                    enabled: root.selectedAppIndices.length > 0
                    focusPolicy: Qt.NoFocus
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: root.deleteSelectedApps()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "delete_sweep"
                        iconSize: 20
                    }

                    VimiumHintLabel {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -5
                        anchors.topMargin: -5
                        hintText: root.vimiumHints[0] ?? ""
                        typedText: root.vimiumTyped
                        vimiumActive: root.vimiumActive
                    }
                }

                RippleButton {
                    id: addAppButton
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    visible: !settingsOverlay.shown && !root.selectionModeActive
                    onClicked: {
                        GlobalStates.binarySelectorTargetFolderId = ""
                        GlobalStates.binarySelectorOpen = true
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "add"
                        iconSize: 20
                    }

                    VimiumHintLabel {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -5
                        anchors.topMargin: -5
                        hintText: root.vimiumHints[1] ?? ""
                        typedText: root.vimiumTyped
                        vimiumActive: root.vimiumActive
                    }
                }

                RippleButton {
                    id: settingsButton
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    visible: !settingsOverlay.shown && !root.selectionModeActive
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
                        hintText: root.vimiumHints[0] ?? ""
                        typedText: root.vimiumTyped
                        vimiumActive: root.vimiumActive
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: appGrid.count === 0 && !root.externalDragHover

            PagePlaceholder {
                icon: "apps"
                title: Translation.tr("No applications yet")
                description: Translation.tr("Right-click anywhere to add one")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 24
                anchors.horizontalCenter: parent.horizontalCenter
                text: Translation.tr("Show help: Ctrl + /")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                opacity: 0.7
            }
        }

        GridView {
            id: appGrid
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: headerBar.height + 4
            visible: count > 0
            readonly property int columns: Math.max(1, Math.floor(width / (root.iconSize + 76)))
            cellWidth: width / columns
            cellHeight: root.iconSize + 76
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}

            model: root.gridModel

            delegate: AppGridDelegate {
                width: appGrid.cellWidth
                height: appGrid.cellHeight
                launcher: root
                innerLayer: innerLayerRect
                onOpenFolderRequested: (folder) => folderViewer.open(folder)
                onContextMenuForAppRequested: (entryIndex, launcherX, launcherY) => {
                    contextMenu.selectedAppIndex = entryIndex
                    contextMenu.selectedFolderId = ""
                    contextMenu.x = launcherX - contextMenu.width / 2
                    contextMenu.y = launcherY
                    contextMenu.openAt()
                }
                onContextMenuForFolderRequested: (folderId, launcherX, launcherY) => {
                    contextMenu.selectedFolderId = folderId
                    contextMenu.selectedAppIndex = -1
                    contextMenu.x = launcherX - contextMenu.width / 2
                    contextMenu.y = launcherY
                    contextMenu.openAt()
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
                property bool vimiumActive: root.settingsVimiumActive
                property string vimiumTyped: root.settingsVimiumTyped

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
                    vimiumHints: root.settingsVimiumHints
                    onClosed: settingsOverlay.shown = false
                }
            }
        }

        // Overlay shown while an external binary is dragged over the launcher (detach mode).
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: parent.radius
            visible: root.externalDragHover
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
            // Track folder by id so `folder` re-resolves against the current
            // CustomApps.folders snapshot — the cached object goes stale after
            // rename / reorder when the model rebuilds entries.
            property string folderId: ""
            readonly property var folder: {
                if (!folderId) return null
                const folders = CustomApps.folders || []
                for (let i = 0; i < folders.length; i++) {
                    if (folders[i].id === folderId) return folders[i]
                }
                return null
            }

            function open(f) {
                folderViewer.folderId = f?.id ?? ""
                folderViewer.active = true
            }

            function close() {
                folderViewer.active = false
                folderViewer.folderId = ""
            }

            onActiveChanged: {
                if (!active) {
                    root.folderVimiumActive = false
                    root.folderVimiumTyped = ""
                }
            }

            sourceComponent: AppFolderViewer {
                folder: folderViewer.folder
                iconSize: root.iconSize
                vimiumActive: root.folderVimiumActive
                vimiumTyped: root.folderVimiumTyped
                vimiumHints: root.folderVimiumHints
                onClosed: folderViewer.close()
                onRenameAppRequested: (appIndex, currentName) => renameDialog.openForApp(appIndex, currentName)
            }
        }

        FadeLoader {
            id: helpOverlay
            anchors.fill: parent
            z: 21
            shown: false
            sourceComponent: HelpOverlay {
                onClosed: helpOverlay.shown = false
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

    // Dismisses the context menu when the user clicks outside its bounds.
    MouseArea {
        anchors.fill: parent
        visible: contextMenu.visible
        z: 9
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: event => {
            const localX = event.x
            const localY = event.y
            if (localX < contextMenu.x || localX > contextMenu.x + contextMenu.width
                || localY < contextMenu.y || localY > contextMenu.y + contextMenu.height) {
                contextMenu.hide()
                event.accepted = true
            } else {
                event.accepted = false
            }
        }
    }

    // Receives file drops from external apps (file managers) in detach mode.
    // Ignores internal QML drags (drag.source !== null) so folder drop targets
    // remain functional.
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]

        onEntered: (drag) => {
            if (drag.source !== null) return
            if (settingsOverlay.shown) return
            root.externalDragHover = true
            drag.accept(Qt.CopyAction)
        }
        onExited: {
            root.externalDragHover = false
        }
        onDropped: (drop) => {
            root.externalDragHover = false
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
