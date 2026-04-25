import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    anchors.fill: parent

    signal closed()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    component KeyChip: Rectangle {
        id: keyChip
        property string label: ""
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2
        implicitWidth: chipText.implicitWidth + 16
        implicitHeight: chipText.implicitHeight + 8

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: keyChip.label
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }
    }

    component HelpRow: RowLayout {
        id: helpRow
        property string keyLabel: ""
        property string descText: ""
        Layout.fillWidth: true
        spacing: 12

        KeyChip {
            label: helpRow.keyLabel
        }

        StyledText {
            Layout.fillWidth: true
            text: helpRow.descText
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.normal
            wrapMode: Text.Wrap
        }
    }

    component HelpSection: ColumnLayout {
        id: helpSection
        property string title: ""
        default property alias rows: rowContainer.data
        Layout.fillWidth: true
        spacing: 8

        StyledText {
            text: helpSection.title
            color: Appearance.colors.colOnLayer1
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.large
                variableAxes: Appearance.font.variableAxes.title
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
            implicitHeight: rowContainer.implicitHeight + 24

            ColumnLayout {
                id: rowContainer
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 8
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.m3colors.m3surfaceContainerLow
        radius: Appearance.rounding.normal

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: 8

                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: root.closed()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "arrow_back"
                        iconSize: 20
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    text: Translation.tr("Help")
                    color: Appearance.colors.colOnLayer0
                    font {
                        family: Appearance.font.family.title
                        pixelSize: Appearance.font.pixelSize.large
                        variableAxes: Appearance.font.variableAxes.title
                    }
                }
            }

            ScrollView {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: scroll.availableWidth
                    spacing: 16

                    HelpSection {
                        title: Translation.tr("Keyboard")

                        HelpRow {
                            keyLabel: "Esc"
                            descText: Translation.tr("Close / cancel current mode")
                        }
                        HelpRow {
                            keyLabel: "Ctrl + D"
                            descText: Translation.tr("Detach window")
                        }
                        HelpRow {
                            keyLabel: "Ctrl + ?"
                            descText: Translation.tr("Show this help")
                        }
                    }

                    HelpSection {
                        title: Translation.tr("Mouse & Drag")

                        HelpRow {
                            keyLabel: Translation.tr("Right-click")
                            descText: Translation.tr("Context menu / add app")
                        }
                        HelpRow {
                            keyLabel: Translation.tr("Drag app onto folder")
                            descText: Translation.tr("Group apps")
                        }
                        HelpRow {
                            keyLabel: Translation.tr("Drop file from file manager")
                            descText: Translation.tr("Add to launcher")
                        }
                    }

                    HelpSection {
                        title: Translation.tr("Vimium hints")

                        HelpRow {
                            keyLabel: "F"
                            descText: Translation.tr("Activate hints in current view")
                        }
                        HelpRow {
                            keyLabel: Translation.tr("Type letters")
                            descText: Translation.tr("Trigger highlighted action")
                        }
                        HelpRow {
                            keyLabel: Translation.tr("Backspace")
                            descText: Translation.tr("Erase one character")
                        }
                        HelpRow {
                            keyLabel: "Esc"
                            descText: Translation.tr("Cancel")
                        }
                    }
                }
            }
        }
    }
}
