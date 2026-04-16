import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    required property string icon
    required property string label
    property string value: ""
    property list<real> graphValues: []
    property color graphColor: Appearance.colors.colPrimary
    spacing: 4

    MaterialSymbol {
        text: root.icon
        color: Appearance.colors.colOnSurfaceVariant
        iconSize: Appearance.font.pixelSize.large
    }
    StyledText {
        text: root.label
        color: Appearance.colors.colOnSurfaceVariant
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: root.graphValues.length >= 2 ? 28 : valueText.implicitHeight

        StyledText {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.graphValues.length < 2
            color: Appearance.colors.colOnSurfaceVariant
            text: root.value
        }

        Rectangle {
            visible: root.graphValues.length >= 2
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.colors.colSecondaryContainer

            Graph {
                anchors.fill: parent
                values: {
                    if (root.graphValues.length < 2) return []
                    const maxV = root.graphValues.reduce((a, b) => Math.max(a, b), 1)
                    return root.graphValues.map(v => v / maxV)
                }
                alignment: Graph.Alignment.Right
                color: root.graphColor
                fillOpacity: 0.3
            }
        }
    }
}
