import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Flow {
    id: root
    Layout.fillWidth: true

    property color colBackground: Appearance.colors.colSecondaryContainer
    property color colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    property color colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    spacing: 2
    property var vimiumHints: []
    property string vimiumTyped: ""
    property bool vimiumActive: false
    property list<var> options: [
        {
            "displayName": "Option 1",
            "icon": "check",
            "shape": "Arch", // Optional (for material shape)
            "symbol": "google-gemini-symbolic", // Optional (for custom icons)
            "color": "red", // Optional (for custom shape color)
            "value": 1
        },
        {
            "displayName": "Option 2",
            "icon": "close",
            "shape": "Circle", // Optional (for material shape)
            "symbol": "mistral-symbolic", // Optional (for custom icons)
            "color": "blue", // Optional (for custom shape color)
            "value": 2
        },
    ]
    property var currentValue: null

    signal selected(var newValue)

    Repeater {
        model: root.options
        delegate: SelectionGroupButton {
            id: paletteButton
            required property var modelData
            required property int index
            onYChanged: {
                if (index === 0) {
                    paletteButton.leftmost = true
                } else {
                    var prev = root.children[index - 1]
                    var thisIsOnNewLine = prev && prev.y !== paletteButton.y
                    paletteButton.leftmost = thisIsOnNewLine
                    prev.rightmost = thisIsOnNewLine
                }
            }
            leftmost: index === 0
            rightmost: index === root.options.length - 1
            buttonIcon: modelData.icon || ""
            buttonShape: modelData.shape || ""
            buttonSymbol: modelData.symbol || ""
            buttonColor: modelData.color || ""
            buttonText: modelData.displayName
            toggled: root.currentValue == modelData.value
            releaseAction: modelData.releaseAction || ""

            colBackground: root.colBackground
            colBackgroundHover: root.colBackgroundHover
            colBackgroundActive: root.colBackgroundActive

            onClicked: {
                root.selected(modelData.value);
            }

            Rectangle {
                property string hintText: root.vimiumHints[index] ?? ""
                visible: root.vimiumActive && hintText.length > 0 && hintText.startsWith(root.vimiumTyped)
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -5
                anchors.topMargin: -5
                width: hintLabel.implicitWidth + 10
                height: hintLabel.implicitHeight + 6
                color: "#f5e100"
                border.color: "#a89800"
                border.width: 1
                radius: 3
                z: 300

                Text {
                    id: hintLabel
                    anchors.centerIn: parent
                    text: parent.hintText
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "monospace"
                    color: "#1a1200"
                }
            }
        }
    }
}
