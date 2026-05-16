import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property var device
    property bool expanded: false
    readonly property bool connected: root.device?.connected ?? false
    readonly property bool paired: root.device?.paired ?? false
    readonly property bool hasBattery: root.device?.batteryAvailable ?? false
    readonly property real batteryLevel: root.device?.battery ?? 0
    pointingHandCursor: !expanded

    onClicked: expanded = !expanded
    altAction: () => expanded = !expanded

    component ActionButton: DialogButton {
        colBackground: Appearance.colors.colPrimary
        colBackgroundHover: Appearance.colors.colPrimaryHover
        colRipple: Appearance.colors.colPrimaryActive
        colText: Appearance.colors.colOnPrimary
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
                iconSize: 18
                padding: 7
                shape: MaterialShape.Shape.Cookie7Sided
                color: root.connected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest
                colSymbol: root.connected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                    text: root.device?.name || Translation.tr("Unknown device")
                    textFormat: Text.PlainText
                }
                StyledText {
                    visible: root.connected || root.paired
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.connected ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: root.connected ? Translation.tr("Connected") : Translation.tr("Paired")
                }
            }

            // Battery chip
            Rectangle {
                visible: root.hasBattery && (root.connected || root.paired)
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 22
                implicitWidth: batteryRow.implicitWidth + 12
                radius: Appearance.rounding.full
                color: Appearance.colors.colSecondaryContainer

                RowLayout {
                    id: batteryRow
                    anchors.centerIn: parent
                    spacing: 3

                    MaterialSymbol {
                        iconSize: 14
                        color: Appearance.colors.colOnSecondaryContainer
                        text: {
                            const p = root.batteryLevel;
                            if (p > 0.85) return "battery_full";
                            if (p > 0.65) return "battery_5_bar";
                            if (p > 0.45) return "battery_4_bar";
                            if (p > 0.25) return "battery_2_bar";
                            if (p > 0.10) return "battery_1_bar";
                            return "battery_alert";
                        }
                    }
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.variableAxes: ({ "wght": 600 })
                        color: Appearance.colors.colOnSecondaryContainer
                        text: Math.round(root.batteryLevel * 100) + "%"
                    }
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer3
                rotation: root.expanded ? 180 : 0
                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        RowLayout {
            visible: root.expanded
            Layout.topMargin: 10
            Layout.fillWidth: true
            spacing: 4

            Item {
                Layout.fillWidth: true
            }

            ActionButton {
                visible: root.paired
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive
                colText: Appearance.colors.colOnErrorContainer

                buttonText: Translation.tr("Forget")
                onClicked: root.device?.forget()
            }
            ActionButton {
                buttonText: root.connected
                    ? Translation.tr("Disconnect")
                    : (root.paired ? Translation.tr("Connect") : Translation.tr("Pair & connect"))
                onClicked: {
                    if (root.connected) {
                        root.device.disconnect();
                    } else {
                        root.device.connect();
                    }
                }
            }
        }
    }
}
