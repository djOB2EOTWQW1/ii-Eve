import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: Network.wifiEnabled
                ? (Network.wifiStatus === "connected" ? "wifi" : "wifi_find")
                : "wifi_off"
            iconSize: 18
            padding: 7
            shape: MaterialShape.Shape.Cookie7Sided
            color: Network.wifiEnabled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest
            colSymbol: Network.wifiEnabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Wi-Fi")
                color: Appearance.colors.colOnSurface
                elide: Text.ElideRight
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.title
                    variableAxes: Appearance.font.variableAxes.title
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (!Network.wifiEnabled) return Translation.tr("Off");
                    if (Network.wifiStatus === "connecting") return Translation.tr("Connecting…");
                    if (Network.wifiStatus === "connected" && Network.active?.ssid)
                        return Translation.tr("Connected") + " • " + Network.active.ssid;
                    if (Network.wifiScanning) return Translation.tr("Scanning…");
                    return Translation.tr("Not connected");
                }
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
                animateChange: true
            }
        }

        StyledSwitch {
            Layout.alignment: Qt.AlignVCenter
            checked: Network.wifiEnabled
            onToggled: Network.toggleWifi()
        }
    }

    WindowDialogSeparator {
        visible: !Network.wifiScanning
    }
    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        ListView {
            id: networksList
            anchors.fill: parent
            clip: true
            spacing: 0
            visible: Network.wifiEnabled && Network.friendlyWifiNetworks.length > 0

            model: ScriptModel {
                values: Network.friendlyWifiNetworks
            }
            delegate: WifiNetworkItem {
                required property WifiAccessPoint modelData
                wifiNetwork: modelData
                width: ListView.view.width
            }
        }

        PagePlaceholder {
            icon: "wifi_off"
            title: Translation.tr("Wi-Fi is off")
            description: Translation.tr("Turn on Wi-Fi to see nearby networks")
            descriptionHorizontalAlignment: Text.AlignHCenter
            shape: MaterialShape.Shape.Cookie7Sided
            shown: !Network.wifiEnabled
        }

        PagePlaceholder {
            icon: "wifi_find"
            title: Translation.tr("No networks found")
            description: Translation.tr("Try rescanning or move closer to a router")
            descriptionHorizontalAlignment: Text.AlignHCenter
            shape: MaterialShape.Shape.Cookie7Sided
            shown: Network.wifiEnabled && Network.friendlyWifiNetworks.length === 0 && !Network.wifiScanning
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Rescan")
            enabled: Network.wifiEnabled && !Network.wifiScanning
            onClicked: Network.rescanWifi()
        }

        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
