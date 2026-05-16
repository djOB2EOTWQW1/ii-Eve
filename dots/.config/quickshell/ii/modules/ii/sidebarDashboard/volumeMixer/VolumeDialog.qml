pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

WindowDialog {
    id: root
    property bool isSink: true
    readonly property PwNode activeNode: root.isSink ? Audio.sink : Audio.source
    readonly property bool muted: root.activeNode?.audio?.muted ?? false
    readonly property real currentVolume: root.activeNode?.audio?.volume ?? 0
    backgroundHeight: 600

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialShapeWrappedMaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.isSink
                ? (root.muted ? "volume_off"
                    : root.currentVolume > 0.66 ? "volume_up"
                    : root.currentVolume > 0.33 ? "volume_down"
                    : root.currentVolume > 0.01 ? "volume_mute"
                    : "volume_off")
                : (root.muted ? "mic_off" : "mic")
            iconSize: 18
            padding: 7
            shape: MaterialShape.Shape.Cookie7Sided
            color: root.muted ? Appearance.colors.colSurfaceContainerHighest : Appearance.colors.colPrimaryContainer
            colSymbol: root.muted ? Appearance.colors.colOnSurfaceVariant : Appearance.colors.colOnPrimaryContainer
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.isSink ? Translation.tr("Audio output") : Translation.tr("Audio input")
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
                    const node = root.activeNode;
                    const name = node ? Audio.friendlyDeviceName(node) : Translation.tr("No device");
                    if (root.muted) return Translation.tr("Muted") + " • " + name;
                    return Math.round(root.currentVolume * 100) + "% • " + name;
                }
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
                animateChange: true
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 36
            implicitWidth: 36
            buttonRadius: Appearance.rounding.full
            colBackground: root.muted ? Appearance.colors.colErrorContainer : ColorUtils.transparentize(Appearance.colors.colLayer3, 1)
            colBackgroundHover: root.muted ? Appearance.colors.colErrorContainerHover : Appearance.colors.colLayer3Hover
            colRipple: root.muted ? Appearance.colors.colErrorContainerActive : Appearance.colors.colLayer3Active

            onClicked: {
                if (root.activeNode?.audio) root.activeNode.audio.muted = !root.muted;
            }

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.muted
                    ? (root.isSink ? "volume_off" : "mic_off")
                    : (root.isSink ? "volume_up" : "mic")
                iconSize: Appearance.font.pixelSize.larger
                color: root.muted ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    WindowDialogSeparator {}

    VolumeDialogContent {
        isSink: root.isSink
    }

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.volumeMixer}`]);
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
