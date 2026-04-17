import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    Loader {
        id: binarySelectorLoader
        active: GlobalStates.binarySelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:binarySelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors.top: true
            margins {
                top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: 620
            implicitWidth: 1000

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(panelWindow);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.binarySelectorOpen = false;
                }
            }

            BinarySelectorContent {
                id: content
                anchors.fill: parent
            }
        }
    }

    function toggleBinarySelector() {
        GlobalStates.binarySelectorOpen = !GlobalStates.binarySelectorOpen
    }

    IpcHandler {
        target: "binarySelector"

        function toggle(): void {
            root.toggleBinarySelector();
        }
        function open(): void {
            GlobalStates.binarySelectorOpen = true;
        }
        function close(): void {
            GlobalStates.binarySelectorOpen = false;
        }
    }
}
