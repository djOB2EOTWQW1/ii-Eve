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
                contextMenu.x = event.x - contextMenu.width / 2;
                contextMenu.y = event.y;
                contextMenu.openAt();
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }

        readonly property int iconSize: Persistent.states.appLauncher?.iconSize ?? 64

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

                    Rectangle {
                        id: folderRect
                        anchors.fill: parent
                        anchors.margins: 6
                        visible: delegateRoot.isFolder
                        radius: Appearance.rounding.normal
                        color: folderDropArea.containsDrag
                            ? Appearance.colors.colPrimaryContainer
                            : (folderHoverArea.containsMouse
                                ? Appearance.colors.colLayer1Hover
                                : "transparent")
                        border.width: (folderHoverArea.containsMouse || folderDropArea.containsDrag) ? 2 : 0
                        border.color: Appearance.colors.colPrimary

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                        Behavior on border.color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: contentRoot.iconSize
                                verticalAlignment: Text.AlignVCenter
                                text: "folder_open"
                                iconSize: contentRoot.iconSize
                                color: Appearance.colors.colOnLayer1
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

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            implicitWidth: Math.max(20, countBadgeText.implicitWidth + 12)
                            implicitHeight: 20
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colPrimary
                            visible: (delegateRoot.modelData?.appIndices?.length ?? 0) > 0

                            StyledText {
                                id: countBadgeText
                                anchors.centerIn: parent
                                text: delegateRoot.modelData?.appIndices?.length ?? 0
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        MouseArea {
                            id: folderHoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            onClicked: folderViewer.open(delegateRoot.modelData)
                        }

                        DropArea {
                            id: folderDropArea
                            anchors.fill: parent
                            onDropped: (drop) => {
                                const data = drop.getDataAsString("text/plain")
                                const idx = parseInt(data)
                                if (!isNaN(idx)) {
                                    CustomApps.addAppToFolder(delegateRoot.modelData.id, idx)
                                    drop.accept(Qt.MoveAction)
                                }
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
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.mimeData: ({ "text/plain": String(delegateRoot.entryIndex) })
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
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            drag.target: appTile
                            drag.threshold: 8
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    const pos = itemArea.mapToItem(contentRoot, mouse.x, mouse.y);
                                    contextMenu.selectedAppIndex = delegateRoot.entryIndex;
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
                                if (appTile.Drag.active) appTile.Drag.drop()
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

                sourceComponent: Rectangle {
                    color: Appearance.m3colors.m3surfaceContainer
                    radius: Appearance.rounding.normal
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

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
                            cellWidth: contentRoot.iconSize + 76
                            cellHeight: contentRoot.iconSize + 76
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
                                    anchors.margins: 6
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            CustomApps.removeAppFromFolder(folderViewer.folder.id, folderAppDelegate.modelData._originalIndex)
                                            return
                                        }
                                        CustomApps.launch(folderAppDelegate.modelData)
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
                    }
                }
            }
        }

        Rectangle {
            id: contextMenu
            z: 10
            visible: false
            property int selectedAppIndex: -1
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
                    visible: contextMenu.selectedAppIndex >= 0
                    buttonText: Translation.tr("Remove from launcher")
                    onClicked: {
                        const idx = contextMenu.selectedAppIndex;
                        contextMenu.hide();
                        CustomApps.removeAppAt(idx);
                    }
                }

                MenuButton {
                    Layout.fillWidth: true
                    visible: contextMenu.selectedAppIndex < 0
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
