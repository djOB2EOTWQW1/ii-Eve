import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.appLauncherOpen

        function hide() {
            GlobalStates.appLauncherOpen = false;
        }

        exclusionMode: ExclusionMode.Normal
        WlrLayershell.namespace: "quickshell:appLauncher"
        WlrLayershell.keyboardFocus: GlobalStates.appLauncherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
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
}
