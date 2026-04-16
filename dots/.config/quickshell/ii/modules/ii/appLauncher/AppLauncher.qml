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
                contextMenu.x = event.x - contextMenu.width / 2;
                contextMenu.y = event.y;
                contextMenu.openAt();
                event.accepted = true;
            } else {
                event.accepted = false;
            }
        }

        PagePlaceholder {
            visible: appGrid.count === 0
            icon: "apps"
            title: "AppLauncher"
        }

        GridView {
            id: appGrid
            anchors.fill: parent
            anchors.margins: 24
            visible: count > 0
            cellWidth: 140
            cellHeight: 140
            clip: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: StyledScrollBar {}

            model: CustomApps.entries
            delegate: Item {
                required property var modelData
                required property int index
                width: appGrid.cellWidth
                height: appGrid.cellHeight

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    anchors.margins: 6
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: CustomApps.launch(modelData)

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: itemArea.containsMouse
                            ? Appearance.colors.colLayer1Hover
                            : "transparent"

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            Image {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 64
                                Layout.preferredHeight: 64
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: modelData.name
                            }
                        }
                    }
                }
            }
        }

        // Context menu (right-click in empty area)
        Rectangle {
            id: contextMenu
            z: 10
            visible: false
            implicitWidth: 200
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
                    buttonText: Translation.tr("Add application")
                    onClicked: {
                        contextMenu.hide();
                        GlobalStates.appLauncherOpen = false;
                        GlobalStates.binarySelectorOpen = true;
                    }
                }
            }
        }

        // Dismiss the context menu when clicking elsewhere
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
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.appLauncherOpen = false;
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
