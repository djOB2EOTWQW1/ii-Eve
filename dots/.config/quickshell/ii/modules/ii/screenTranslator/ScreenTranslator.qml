pragma ComponentBehavior: Bound
import qs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    function dismiss() {
        GlobalStates.screenTranslatorOpen = false
    }

    readonly property var currentScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

    function screenByName(name) {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    Loader {
        id: translatorLoader
        property var lockedScreen
        property var lockedRegionInfo: null
        active: false
        Connections {
            target: GlobalStates
            function onScreenTranslatorOpenChanged() {
                if (!GlobalStates.screenTranslatorOpen) {
                    translatorLoader.active = false;
                    translatorLoader.lockedRegionInfo = null;
                    GlobalStates.screenTranslatorRegionInfo = null;
                } else {
                    const regionInfo = GlobalStates.screenTranslatorRegionInfo;
                    translatorLoader.lockedRegionInfo = regionInfo;
                    translatorLoader.lockedScreen = regionInfo
                        ? root.screenByName(regionInfo.screenName)
                        : root.currentScreen;
                    translatorLoader.active = true;
                }
            }
        }

        sourceComponent: ScreenTranslatorPanel {
            screen: translatorLoader.lockedScreen
            regionInfo: translatorLoader.lockedRegionInfo
            onDismiss: root.dismiss()
        }
    }

    function translate() {
        GlobalStates.screenTranslatorOpen = true
    }

    IpcHandler {
        target: "screenTranslator"

        function translate() {
            root.translate()
        }
    }

    GlobalShortcut {
        name: "screenTranslate"
        description: "Translates screen content"
        onPressed: root.translate()
    }
}
