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
            if (event.button === Qt.RightButton) {
                contextMenu.selectedAppIndex = -1;
                contextMenu.selectedFolderId = "";
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

        Rectangle {
            id: innerLayer
            anchors.fill: parent
            anchors.margins: 10
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            PagePlaceholder {
                visible: appGrid.count === 0
                icon: "apps"
                title: "AppLauncher"
            }

            GridView {
                id: appGrid
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 54
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

                    // Android 16 style folder tile: rounded-square preview
                    // container with up to 4 mini app icons in a 2x2 grid.
                    Item {
                        id: folderTileItem
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: delegateRoot.isFolder

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
                                    : folderHoverArea.containsMouse
                                        ? Appearance.colors.colLayer1Hover
                                        : Appearance.m3colors.m3surfaceContainerHigh
                                border.width: contentRoot.hoverFolderId === delegateRoot.folderId && contentRoot.draggedEntryIndex >= 0 ? 2 : 0
                                border.color: Appearance.colors.colPrimary

                                Behavior on color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }
                                Behavior on border.color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }

                                GridLayout {
                                    id: previewGrid
                                    anchors.centerIn: parent
                                    width: parent.width * 0.72
                                    height: parent.height * 0.72
                                    columns: 2
                                    rowSpacing: Math.max(2, parent.width * 0.04)
                                    columnSpacing: Math.max(2, parent.width * 0.04)

                                    readonly property var icons: delegateRoot.isFolder
                                        ? CustomApps.folderPreviewIcons(delegateRoot.modelData, 4)
                                        : []

                                    Repeater {
                                        model: previewGrid.icons

                                        delegate: Item {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                cache: false
                                                source: {
                                                    const icon = parent.modelData || ""
                                                    if (icon.startsWith("/")) return "file://" + icon
                                                    return Quickshell.iconPath(icon, "application-x-executable")
                                                }
                                            }
                                        }
                                    }
                                }

                                MaterialSymbol {
                                    visible: (delegateRoot.modelData?.appIndices?.length ?? 0) === 0
                                    anchors.centerIn: parent
                                    text: "folder"
                                    iconSize: Math.round(contentRoot.iconSize * 0.5)
                                    color: Appearance.colors.colOnLayer1
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
                    }

                    Rectangle {
                        id: appTile
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: !delegateRoot.isFolder
                        radius: Appearance.rounding.normal
                        color: itemArea.containsMouse
                            ? Appearance.colors.colLayer1Hover
                            : "transparent"
                        border.width: itemArea.containsMouse ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        Drag.active: itemArea.drag.active
                        Drag.source: itemArea
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.supportedActions: Qt.MoveAction

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                        Behavior on border.color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        states: State {
                            name: "dragging"
                            when: appTile.Drag.active
                            PropertyChanges {
                                target: appTile
                                anchors.fill: undefined
                                anchors.margins: 0
                                opacity: 0.85
                                z: 50
                            }
                            ParentChange {
                                target: appTile
                                parent: innerLayer
                            }
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

            RippleButton {
                id: settingsButton
                z: 5
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 12
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
            }

            FadeLoader {
                id: settingsOverlay
                anchors.fill: parent
                z: 15
                shown: false
                sourceComponent: Rectangle {
                    color: Appearance.m3colors.m3surfaceContainerLow
                    radius: Appearance.rounding.normal

                    AppLauncherSettings {
                        anchors.fill: parent
                        onClosed: settingsOverlay.shown = false
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

                sourceComponent: Item {
                    anchors.fill: parent

                    Rectangle {
                        id: backdrop
                        anchors.fill: parent
                        color: "#000000"
                        opacity: 0.45
                        radius: Appearance.rounding.normal

                        MouseArea {
                            anchors.fill: parent
                            onClicked: folderViewer.close()
                        }
                    }

                    Rectangle {
                        id: folderPanel
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, 560)
                        height: Math.min(parent.height - 40, 520)
                        color: Appearance.m3colors.m3surfaceContainer
                        radius: Appearance.rounding.large
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border

                        // Prevent backdrop click from closing when clicking inside.
                        MouseArea {
                            anchors.fill: parent
                            onPressed: (mouse) => mouse.accepted = true
                        }

                        transform: Scale {
                            id: openScale
                            origin.x: folderPanel.width / 2
                            origin.y: folderPanel.height / 2
                            xScale: 0.92
                            yScale: 0.92
                        }
                        opacity: 0

                        NumberAnimation on opacity {
                            from: 0
                            to: 1
                            duration: 160
                            easing.type: Easing.OutCubic
                            running: true
                        }
                        NumberAnimation {
                            target: openScale
                            property: "xScale"
                            from: 0.92
                            to: 1
                            duration: 200
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.8
                            running: true
                        }
                        NumberAnimation {
                            target: openScale
                            property: "yScale"
                            from: 0.92
                            to: 1
                            duration: 200
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.8
                            running: true
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                MaterialSymbol {
                                    text: "folder_open"
                                    iconSize: 28
                                    color: Appearance.colors.colOnLayer1
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: folderViewer.folder?.name ?? ""
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    elide: Text.ElideRight
                                }

                                RippleButton {
                                    buttonRadius: Appearance.rounding.full
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    onClicked: folderViewer.close()
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "close"
                                        iconSize: 20
                                    }
                                }
                            }

                            GridView {
                                id: folderAppsGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                cellWidth: contentRoot.iconSize + 40
                                cellHeight: contentRoot.iconSize + 50
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: StyledScrollBar {}

                                model: folderViewer.folder ? CustomApps.appsInFolder(folderViewer.folder.id) : []

                                delegate: Item {
                                    id: folderAppDelegate
                                    required property var modelData
                                    required property int index
                                    width: folderAppsGrid.cellWidth
                                    height: folderAppsGrid.cellHeight

                                    MouseArea {
                                        id: folderAppArea
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                CustomApps.removeAppFromFolder(folderViewer.folder.id, folderAppDelegate.modelData._originalIndex)
                                                return
                                            }
                                            CustomApps.launch(folderAppDelegate.modelData)
                                            folderViewer.close()
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Appearance.rounding.normal
                                            color: folderAppArea.containsMouse
                                                ? Appearance.colors.colLayer1Hover
                                                : "transparent"
                                            border.width: folderAppArea.containsMouse ? 2 : 0
                                            border.color: Appearance.colors.colPrimary

                                            Behavior on color {
                                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                            }
                                            Behavior on border.color {
                                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                            }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 4

                                                Image {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: contentRoot.iconSize
                                                    Layout.preferredHeight: contentRoot.iconSize
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    cache: false
                                                    source: {
                                                        const icon = folderAppDelegate.modelData.icon || ""
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
                                                    text: folderAppDelegate.modelData.name
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                visible: folderAppsGrid.count === 0
                                text: Translation.tr("Drag apps onto this folder to add them.")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: contextMenu
            z: 10
            visible: false
            property int selectedAppIndex: -1
            property string selectedFolderId: ""
            readonly property bool isFolderContext: selectedFolderId.length > 0
            readonly property bool isAppContext: selectedAppIndex >= 0
            readonly property bool isEmptyContext: !isFolderContext && !isAppContext
            implicitWidth: 220
            implicitHeight: menuColumn.implicitHeight + 12
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            function openAt() {
                const maxX = contentRoot.width - contextMenu.width - 8;
                const maxY = contentRoot.height - contextMenu.height - 8;
                contextMenu.x = Math.max(8, Math.min(contextMenu.x, maxX));
                contextMenu.y = Math.max(8, Math.min(contextMenu.y, maxY));
                contextMenu.visible = true;
            }

            function hide() { contextMenu.visible = false; }

            StyledRectangularShadow {
                target: contextMenu
                visible: contextMenu.visible
            }

            ColumnLayout {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 0

                MenuButton {
                    Layout.fillWidth: true
                    visible: contextMenu.isAppContext
                    buttonText: Translation.tr("Remove from launcher")
                    onClicked: {
                        const idx = contextMenu.selectedAppIndex;
                        contextMenu.hide();
                        CustomApps.removeAppAt(idx);
                    }
                }

                MenuButton {
                    Layout.fillWidth: true
                    visible: contextMenu.isFolderContext
                    buttonText: Translation.tr("Open folder")
                    onClicked: {
                        const fid = contextMenu.selectedFolderId;
                        contextMenu.hide();
                        const f = CustomApps.folderById(fid);
                        if (f) folderViewer.open(f);
                    }
                }

                MenuButton {
                    Layout.fillWidth: true
                    visible: contextMenu.isFolderContext
                    buttonText: Translation.tr("Delete folder")
                    onClicked: {
                        const fid = contextMenu.selectedFolderId;
                        contextMenu.hide();
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
                    visible: contextMenu.isEmptyContext
                    buttonText: Translation.tr("Add application")
                    onClicked: {
                        contextMenu.hide();
                        GlobalStates.binarySelectorOpen = true;
                    }
                }
            }
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

                anchors {
                    fill: parent
                    topMargin: Appearance.sizes.hyprlandGapsOut
                    bottomMargin: Appearance.sizes.hyprlandGapsOut
                    leftMargin: Appearance.sizes.hyprlandGapsOut
                    rightMargin: Appearance.sizes.hyprlandGapsOut
                }

                LauncherContent {}

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        panelWindow.hide();
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

                LauncherContent {}

                Keys.onPressed: (event) => {
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
