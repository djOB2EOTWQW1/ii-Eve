import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Grid delegate for a single tile — either a folder (Android-16 style squircle
// with a 2x2 preview) or an application (launch on click; drag onto a folder;
// long-press to enter selection mode).
Item {
    id: delegateRoot

    required property var modelData
    required property int index

    // LauncherContent reference (hints, selection state, drag state, etc.).
    property var launcher
    // Rectangle the appTile reparents to while dragging so it floats above
    // sibling tiles during the drag gesture.
    property Item innerLayer

    signal openFolderRequested(var folder)
    signal contextMenuForAppRequested(int entryIndex, real launcherX, real launcherY)
    signal contextMenuForFolderRequested(string folderId, real launcherX, real launcherY)

    readonly property bool isFolder: !!delegateRoot.modelData?._isFolder
    readonly property int entryIndex: delegateRoot.modelData?._originalIndex ?? -1
    readonly property string folderId: delegateRoot.modelData?.id ?? ""
    readonly property bool isSelected: !delegateRoot.isFolder
        && (delegateRoot.launcher?.selectedAppIndices?.indexOf(delegateRoot.entryIndex) ?? -1) >= 0

    Timer {
        id: longPressTimer
        interval: 500
        repeat: false
        onTriggered: {
            delegateRoot.launcher.selectionModeActive = true
            delegateRoot.launcher.toggleAppSelection(delegateRoot.entryIndex)
            itemArea.longPressActivated = true
        }
    }

    VimiumHintLabel {
        x: 12
        y: 12
        hintText: delegateRoot.launcher?.vimiumHints[delegateRoot.index + 1] ?? ""
        typedText: delegateRoot.launcher?.vimiumTyped ?? ""
        vimiumActive: delegateRoot.launcher?.vimiumActive ?? false
    }

    // Android 16 style folder tile: rounded-square preview container
    // with up to 4 mini app icons in a 2x2 grid.
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
                Layout.preferredWidth: delegateRoot.launcher?.iconSize ?? 64
                Layout.preferredHeight: delegateRoot.launcher?.iconSize ?? 64
                radius: (delegateRoot.launcher?.iconSize ?? 64) * 0.28
                color: delegateRoot.launcher?.hoverFolderId === delegateRoot.folderId
                        && (delegateRoot.launcher?.draggedEntryIndex ?? -1) >= 0
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.m3colors.m3surfaceContainerHigh
                border.width: delegateRoot.launcher?.hoverFolderId === delegateRoot.folderId
                        && (delegateRoot.launcher?.draggedEntryIndex ?? -1) >= 0 ? 2 : 0
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
                    iconSize: Math.round((delegateRoot.launcher?.iconSize ?? 64) * 0.5)
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
                if ((delegateRoot.launcher?.draggedEntryIndex ?? -1) < 0) return
                delegateRoot.launcher.hoverFolderId = delegateRoot.folderId
                drag.accept(Qt.MoveAction)
            }
            onExited: {
                if (delegateRoot.launcher?.hoverFolderId === delegateRoot.folderId) {
                    delegateRoot.launcher.hoverFolderId = ""
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
                    const pos = folderHoverArea.mapToItem(delegateRoot.launcher, mouse.x, mouse.y)
                    delegateRoot.contextMenuForFolderRequested(delegateRoot.folderId, pos.x, pos.y)
                    return
                }
                delegateRoot.openFolderRequested(delegateRoot.modelData)
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

        Drag.active: itemArea.drag.active && !(delegateRoot.launcher?.selectionModeActive ?? false)
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
                parent: delegateRoot.innerLayer
            }
        }

        Behavior on scale {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: delegateRoot.isSelected
            color: Appearance.colors.colPrimary
            opacity: 0.15
            z: 1
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: delegateRoot.isSelected
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colPrimary
            z: 2
        }

        Rectangle {
            visible: delegateRoot.isSelected
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 6
            anchors.rightMargin: 6
            width: 20
            height: 20
            radius: 10
            color: Appearance.colors.colPrimary
            z: 3

            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: 13
                color: Appearance.colors.colOnPrimary
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: delegateRoot.launcher?.iconSize ?? 64
                Layout.preferredHeight: delegateRoot.launcher?.iconSize ?? 64
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
            property bool longPressActivated: false
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: (delegateRoot.launcher?.selectionModeActive ?? false) ? null : appTile
            drag.threshold: 8
            preventStealing: true

            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    longPressActivated = false
                    delegateRoot.launcher.draggedEntryIndex = delegateRoot.entryIndex
                    if (!delegateRoot.launcher.selectionModeActive) {
                        longPressTimer.start()
                    }
                }
            }
            onPositionChanged: {
                if (drag.active && longPressTimer.running) {
                    longPressTimer.stop()
                }
            }
            onClicked: (mouse) => {
                if (longPressActivated) {
                    longPressActivated = false
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    const pos = itemArea.mapToItem(delegateRoot.launcher, mouse.x, mouse.y)
                    delegateRoot.contextMenuForAppRequested(delegateRoot.entryIndex, pos.x, pos.y)
                    return
                }
                if (delegateRoot.launcher.selectionModeActive) {
                    delegateRoot.launcher.toggleAppSelection(delegateRoot.entryIndex)
                    return
                }
                if (!appTile.Drag.active) {
                    CustomApps.launch(delegateRoot.modelData)
                    GlobalStates.appLauncherOpen = false
                }
            }
            onReleased: {
                longPressTimer.stop()
                const targetFolder = delegateRoot.launcher.hoverFolderId
                const idx = delegateRoot.entryIndex
                delegateRoot.launcher.hoverFolderId = ""
                delegateRoot.launcher.draggedEntryIndex = -1
                if (!delegateRoot.launcher.selectionModeActive && targetFolder.length > 0 && idx >= 0) {
                    CustomApps.addAppToFolder(targetFolder, idx)
                }
            }
            onCanceled: {
                longPressTimer.stop()
                delegateRoot.launcher.hoverFolderId = ""
                delegateRoot.launcher.draggedEntryIndex = -1
            }
        }
    }
}
