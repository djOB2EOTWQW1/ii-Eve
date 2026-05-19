import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    readonly property bool btEnabled: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool btDiscovering: Bluetooth.defaultAdapter?.discovering ?? false
    readonly property var connectedOrPaired: [...BluetoothStatus.connectedDevices, ...BluetoothStatus.pairedButNotConnectedDevices]
    readonly property var availableDevices: BluetoothStatus.unpairedDevices

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.btEnabled
                ? (BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth")
                : "bluetooth_disabled"
            iconSize: 18
            padding: 7
            shape: MaterialShape.Shape.Cookie7Sided
            color: root.btEnabled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest
            colSymbol: root.btEnabled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Bluetooth")
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
                    if (!root.btEnabled) return Translation.tr("Off");
                    if (root.btDiscovering) return Translation.tr("Scanning…");
                    if (BluetoothStatus.activeDeviceCount > 0) {
                        const name = BluetoothStatus.firstActiveDevice?.name ?? "";
                        if (BluetoothStatus.activeDeviceCount === 1 && name.length > 0)
                            return Translation.tr("Connected") + " • " + name;
                        return Translation.tr("Connected") + " • " + BluetoothStatus.activeDeviceCount;
                    }
                    return Translation.tr("Not connected");
                }
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
                animateChange: true
            }
        }

        StyledSwitch {
            id: btSwitch
            Layout.alignment: Qt.AlignVCenter
            enabled: BluetoothStatus.available
            checked: root.btEnabled
            onToggled: {
                btSwitch.checked = Qt.binding(() => root.btEnabled);
                if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !root.btEnabled;
            }
        }
    }

    WindowDialogSeparator {
        visible: !root.btDiscovering
    }
    StyledIndeterminateProgressBar {
        visible: root.btDiscovering
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

        StyledFlickable {
            id: bodyFlick
            anchors.fill: parent
            clip: true
            contentHeight: bodyColumn.implicitHeight
            visible: root.btEnabled && (root.connectedOrPaired.length > 0 || root.availableDevices.length > 0)

            ColumnLayout {
                id: bodyColumn
                width: bodyFlick.width
                spacing: 0

                // Connected / paired section
                component SectionHeader: RowLayout {
                    property string label
                    property int count: 0
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    Layout.bottomMargin: 4
                    Layout.leftMargin: Appearance.rounding.large
                    Layout.rightMargin: Appearance.rounding.large
                    spacing: 8

                    StyledText {
                        text: label
                        color: Appearance.colors.colPrimary
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.variableAxes: ({ "wght": 600 })
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        visible: count > 0
                        text: count
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                SectionHeader {
                    label: Translation.tr("My devices")
                    count: root.connectedOrPaired.length
                    visible: root.connectedOrPaired.length > 0
                }

                Repeater {
                    model: ScriptModel {
                        values: root.connectedOrPaired
                    }
                    delegate: BluetoothDeviceItem {
                        required property BluetoothDevice modelData
                        device: modelData
                        Layout.fillWidth: true
                    }
                }

                SectionHeader {
                    label: Translation.tr("Available")
                    count: root.availableDevices.length
                    visible: root.availableDevices.length > 0
                }

                Repeater {
                    model: ScriptModel {
                        values: root.availableDevices
                    }
                    delegate: BluetoothDeviceItem {
                        required property BluetoothDevice modelData
                        device: modelData
                        Layout.fillWidth: true
                    }
                }

                Item { Layout.preferredHeight: 12 }
            }
        }

        PagePlaceholder {
            icon: "bluetooth_disabled"
            title: Translation.tr("Bluetooth is off")
            description: Translation.tr("Turn on Bluetooth to see nearby devices")
            descriptionHorizontalAlignment: Text.AlignHCenter
            shape: MaterialShape.Shape.Cookie7Sided
            shown: !root.btEnabled
        }

        PagePlaceholder {
            icon: "bluetooth_searching"
            title: root.btDiscovering ? Translation.tr("Searching…") : Translation.tr("No devices found")
            description: root.btDiscovering
                ? Translation.tr("Make sure the device is in pairing mode")
                : Translation.tr("Tap Scan to search for nearby devices")
            descriptionHorizontalAlignment: Text.AlignHCenter
            shape: MaterialShape.Shape.Cookie7Sided
            shown: root.btEnabled && root.connectedOrPaired.length === 0 && root.availableDevices.length === 0
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: root.btDiscovering ? Translation.tr("Stop") : Translation.tr("Scan")
            enabled: root.btEnabled
            onClicked: {
                if (!Bluetooth.defaultAdapter) return;
                Bluetooth.defaultAdapter.discovering = !root.btDiscovering;
            }
        }

        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`]);
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
