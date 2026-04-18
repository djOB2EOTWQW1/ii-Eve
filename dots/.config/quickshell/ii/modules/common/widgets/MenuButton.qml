import qs.modules.common
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    property string symbolName: ""

    buttonRadius: 0
    implicitHeight: 36
    implicitWidth: rowContent.implicitWidth + 14 * 2

    contentItem: RowLayout {
        id: rowContent
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 8

        MaterialSymbol {
            visible: root.symbolName.length > 0
            text: root.symbolName
            iconSize: Appearance.font.pixelSize.normal
            color: root.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        StyledText {
            id: buttonTextWidget
            Layout.fillWidth: true
            text: root.buttonText
            horizontalAlignment: Text.AlignLeft
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

}
