import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.appLauncher.vimium
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Android 16 style expanded folder: dimmed backdrop + centered app grid panel.
Item {
    id: root
    property var folder: null
    property int iconSize: 64
    property bool vimiumActive: false
    property string vimiumTyped: ""
    property var vimiumHints: []
    signal closed()
    signal renameAppRequested(int appIndex, string currentName)

    property bool selectionModeActive: false
    property var selectedAppIndices: []

    function toggleAppSelection(originalIndex) {
        const arr = selectedAppIndices.slice();
        const pos = arr.indexOf(originalIndex);
        if (pos >= 0) arr.splice(pos, 1);
        else arr.push(originalIndex);
        selectedAppIndices = arr;
        if (arr.length === 0) selectionModeActive = false;
    }

    function deleteSelectedApps() {
        for (let i = 0; i < selectedAppIndices.length; i++)
            CustomApps.removeAppFromFolder(root.folder.id, selectedAppIndices[i]);
        selectedAppIndices = [];
        selectionModeActive = false;
    }

    function exitSelectionMode() {
        selectedAppIndices = [];
        selectionModeActive = false;
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
        radius: Appearance.rounding.normal

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
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
            from: 0; to: 1
            duration: 160
            easing.type: Easing.OutCubic
            running: true
        }
        NumberAnimation {
            target: openScale; property: "xScale"
            from: 0.92; to: 1
            duration: 200
            easing.type: Easing.OutBack; easing.overshoot: 0.8
            running: true
        }
        NumberAnimation {
            target: openScale; property: "yScale"
            from: 0.92; to: 1
            duration: 200
            easing.type: Easing.OutBack; easing.overshoot: 0.8
            running: true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: width * 0.28
                    color: Appearance.m3colors.m3primaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "folder_open"
                        iconSize: 22
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -1

                    StyledText {
                        Layout.fillWidth: true
                        text: root.folder?.name ?? ""
                        color: Appearance.colors.colOnLayer1
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.larger
                            variableAxes: Appearance.font.variableAxes.title
                        }
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.selectionModeActive
                            ? (root.selectedAppIndices.length > 0
                                ? Translation.tr("%1 selected · Esc to cancel").arg(root.selectedAppIndices.length)
                                : Translation.tr("Tap to select · Esc to cancel"))
                            : (folderAppsGrid.count === 0
                                ? Translation.tr("Empty")
                                : folderAppsGrid.count === 1
                                    ? Translation.tr("1 app")
                                    : Translation.tr("%1 apps").arg(folderAppsGrid.count))
                        color: root.selectionModeActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }
                    }
                }

                RippleButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !root.selectionModeActive
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: {
                        GlobalStates.binarySelectorTargetFolderId = root.folder?.id ?? ""
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
                        hintText: root.vimiumHints[0] ?? ""
                        typedText: root.vimiumTyped
                        vimiumActive: root.vimiumActive
                    }
                }

                RippleButton {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.selectionModeActive
                    enabled: root.selectedAppIndices.length > 0
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
                }

                RippleButton {
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: root.closed()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
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
            }

            GridView {
                id: folderAppsGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property int columns: Math.max(1, Math.floor(width / (root.iconSize + 40)))
                cellWidth: width / columns
                cellHeight: root.iconSize + 50
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}

                model: {
                    const _e = CustomApps.entries
                    const _f = CustomApps.folders
                    return root.folder ? CustomApps.appsInFolder(root.folder.id) : []
                }

                delegate: Item {
                    id: folderAppDelegate
                    required property var modelData
                    required property int index
                    width: folderAppsGrid.cellWidth
                    height: folderAppsGrid.cellHeight

                    readonly property bool isSelected: root.selectedAppIndices.indexOf(folderAppDelegate.modelData._originalIndex) >= 0

                    Timer {
                        id: folderLongPressTimer
                        interval: 500
                        repeat: false
                        onTriggered: {
                            root.selectionModeActive = true;
                            root.toggleAppSelection(folderAppDelegate.modelData._originalIndex);
                            folderAppArea.longPressActivated = true;
                        }
                    }

                    VimiumHintLabel {
                        x: 4
                        y: 4
                        hintText: root.vimiumHints[folderAppDelegate.index + 2] ?? ""
                        typedText: root.vimiumTyped
                        vimiumActive: root.vimiumActive
                    }

                    MouseArea {
                        id: folderAppArea
                        property bool longPressActivated: false
                        anchors.fill: parent
                        anchors.margins: 4
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onPressed: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                longPressActivated = false;
                                if (!root.selectionModeActive)
                                    folderLongPressTimer.start();
                            }
                        }
                        onPositionChanged: {
                            if (folderLongPressTimer.running)
                                folderLongPressTimer.stop();
                        }
                        onReleased: folderLongPressTimer.stop()
                        onCanceled: folderLongPressTimer.stop()

                        onClicked: (mouse) => {
                            if (longPressActivated) {
                                longPressActivated = false;
                                return;
                            }
                            if (mouse.button === Qt.RightButton) {
                                const pos = folderAppArea.mapToItem(folderPanel, mouse.x, mouse.y)
                                folderItemMenu.targetAppIndex = folderAppDelegate.modelData._originalIndex
                                folderItemMenu.targetAppName = folderAppDelegate.modelData.name
                                folderItemMenu.openAt(pos.x, pos.y)
                                return;
                            }
                            if (root.selectionModeActive) {
                                root.toggleAppSelection(folderAppDelegate.modelData._originalIndex);
                                return;
                            }
                            CustomApps.launch(folderAppDelegate.modelData)
                            GlobalStates.appLauncherOpen = false
                            root.closed()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: folderAppArea.pressed
                                ? Appearance.colors.colLayer2Active
                                : folderAppArea.containsMouse
                                    ? Appearance.colors.colLayer2Hover
                                    : "transparent"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: folderAppDelegate.isSelected
                                color: Appearance.colors.colPrimary
                                opacity: 0.15
                                z: 1
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                visible: folderAppDelegate.isSelected
                                color: "transparent"
                                border.width: 2
                                border.color: Appearance.colors.colPrimary
                                z: 2
                            }

                            Rectangle {
                                visible: folderAppDelegate.isSelected
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 4
                                anchors.rightMargin: 4
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
                                anchors.margins: 8
                                spacing: 4

                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.iconSize
                                    Layout.preferredHeight: root.iconSize
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
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

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.bottomMargin: 12
                visible: folderAppsGrid.count === 0
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "drag_pan"
                    iconSize: 36
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Drag apps here to add them")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 8
            visible: folderItemMenu.visible
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: event => {
                const inMenu = (event.x >= folderItemMenu.x && event.x <= folderItemMenu.x + folderItemMenu.width
                    && event.y >= folderItemMenu.y && event.y <= folderItemMenu.y + folderItemMenu.height)
                const subAbsX = folderItemMenu.x + folderItemSubmenu.x
                const subAbsY = folderItemMenu.y + folderItemSubmenu.y
                const inSub = folderItemSubmenu.visible
                    && event.x >= subAbsX && event.x <= subAbsX + folderItemSubmenu.width
                    && event.y >= subAbsY && event.y <= subAbsY + folderItemSubmenu.height
                if (!inMenu && !inSub) {
                    folderItemMenu.hide()
                    event.accepted = true
                } else {
                    event.accepted = false
                }
            }
        }

        Rectangle {
            id: folderItemMenu
            z: 9
            visible: false
            implicitWidth: 200
            implicitHeight: folderItemMenuColumn.implicitHeight + 12
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            property int targetAppIndex: -1
            property string targetAppName: ""

            readonly property string currentGpu: {
                const e = CustomApps.entries[targetAppIndex]
                return e?.gpu ?? ""
            }

            function openAt(cx, cy) {
                const maxX = folderPanel.width - folderItemMenu.width - 4
                const maxY = folderPanel.height - folderItemMenu.height - 4
                folderItemMenu.x = Math.max(4, Math.min(cx - folderItemMenu.width / 2, maxX))
                folderItemMenu.y = Math.max(4, Math.min(cy, maxY))
                folderItemMenu.visible = true
            }

            function hide() {
                folderItemOpenSubmenuTimer.stop()
                folderItemCloseSubmenuTimer.stop()
                folderItemSubmenu.visible = false
                folderItemMenu.visible = false
            }

            function _toggleSubmenu() {
                folderItemOpenSubmenuTimer.stop()
                folderItemCloseSubmenuTimer.stop()
                folderItemSubmenu.visible = !folderItemSubmenu.visible
            }

            function _launchWithGpu(gpu) {
                const idx = folderItemMenu.targetAppIndex
                if (idx < 0) return
                CustomApps.setEntryGpu(idx, gpu)
                folderItemMenu.hide()
                CustomApps.launch(CustomApps.entries[idx])
                GlobalStates.appLauncherOpen = false
                root.closed()
            }

            function _setDefaultGpu(gpu) {
                const idx = folderItemMenu.targetAppIndex
                if (idx < 0) return
                CustomApps.setEntryGpu(idx, gpu)
                folderItemMenu.hide()
            }

            Timer {
                id: folderItemOpenSubmenuTimer
                interval: 100
                repeat: false
                onTriggered: folderItemSubmenu.visible = true
            }

            Timer {
                id: folderItemCloseSubmenuTimer
                interval: 200
                repeat: false
                onTriggered: folderItemSubmenu.visible = false
            }

            StyledRectangularShadow {
                target: folderItemMenu
                visible: folderItemMenu.visible
            }

            ColumnLayout {
                id: folderItemMenuColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 0

                MenuButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Rename")
                    onClicked: {
                        const idx = folderItemMenu.targetAppIndex
                        const name = folderItemMenu.targetAppName
                        folderItemMenu.hide()
                        root.renameAppRequested(idx, name)
                    }
                }

                MenuButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Remove from folder")
                    onClicked: {
                        const idx = folderItemMenu.targetAppIndex
                        folderItemMenu.hide()
                        CustomApps.removeAppFromFolder(root.folder.id, idx)
                    }
                }

                MenuButton {
                    id: folderItemMoreButton
                    Layout.fillWidth: true
                    visible: GpuInfo.hybrid
                    symbolName: "chevron_right"
                    buttonText: Translation.tr("More")
                    onClicked: folderItemMenu._toggleSubmenu()

                    HoverHandler {
                        id: folderItemMoreHover
                        onHoveredChanged: {
                            if (folderItemMoreHover.hovered) {
                                folderItemCloseSubmenuTimer.stop()
                                if (!folderItemSubmenu.visible) folderItemOpenSubmenuTimer.start()
                            } else {
                                folderItemOpenSubmenuTimer.stop()
                                if (!folderItemSubmenuHover.hovered) folderItemCloseSubmenuTimer.start()
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: folderItemSubmenu
                z: 11
                visible: false

                width: 200
                height: folderItemSubmenuColumn.implicitHeight + 12

                // Default: right of main menu, aligned to moreButton.
                // Flip horizontally if it would overflow folderPanel; clamp vertically.
                x: {
                    const defaultX = folderItemMenu.width - 2
                    const absoluteRight = folderItemMenu.x + defaultX + folderItemSubmenu.width
                    const panelWidth = folderPanel.width
                    if (absoluteRight > panelWidth - 8) {
                        return -folderItemSubmenu.width + 2
                    }
                    return defaultX
                }

                y: {
                    const desired = folderItemMoreButton.y
                    const maxY = folderPanel.height - folderItemMenu.y - folderItemSubmenu.height - 8
                    return Math.max(0, Math.min(desired, maxY))
                }

                color: Appearance.m3colors.m3surfaceContainer
                radius: Appearance.rounding.normal
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                StyledRectangularShadow {
                    target: folderItemSubmenu
                    visible: folderItemSubmenu.visible
                }

                HoverHandler {
                    id: folderItemSubmenuHover
                    onHoveredChanged: {
                        if (folderItemSubmenuHover.hovered) {
                            folderItemCloseSubmenuTimer.stop()
                        } else if (!folderItemMoreHover.hovered) {
                            folderItemCloseSubmenuTimer.start()
                        }
                    }
                }

                ColumnLayout {
                    id: folderItemSubmenuColumn
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 0

                    MenuButton {
                        Layout.fillWidth: true
                        visible: folderItemMenu.currentGpu !== "dGPU"
                        symbolName: "developer_board"
                        buttonText: Translation.tr("Launch with dGPU")
                        onClicked: folderItemMenu._launchWithGpu("dGPU")
                    }

                    MenuButton {
                        Layout.fillWidth: true
                        visible: folderItemMenu.currentGpu === "dGPU"
                        symbolName: "memory"
                        buttonText: Translation.tr("Launch with iGPU")
                        onClicked: folderItemMenu._launchWithGpu("iGPU")
                    }

                    MenuButton {
                        Layout.fillWidth: true
                        visible: folderItemMenu.currentGpu !== "dGPU"
                        symbolName: "bookmark_add"
                        buttonText: Translation.tr("Set default to dGPU")
                        onClicked: folderItemMenu._setDefaultGpu("dGPU")
                    }

                    MenuButton {
                        Layout.fillWidth: true
                        visible: folderItemMenu.currentGpu === "dGPU"
                        symbolName: "bookmark_add"
                        buttonText: Translation.tr("Set default to iGPU")
                        onClicked: folderItemMenu._setDefaultGpu("iGPU")
                    }
                }
            }
        }
    }
}
