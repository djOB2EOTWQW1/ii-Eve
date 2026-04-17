import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ContentPage {
    id: page
    readonly property int index: 0
    property bool register: false
    forceWidth: true
    interactive: false

    ContentSection {
        icon: "straighten"
        title: Translation.tr("Appearance")
        Layout.fillWidth: true

        ConfigSlider {
            text: Translation.tr("Icon size")
            buttonIcon: "photo_size_select_large"
            from: 32
            to: 96
            value: Persistent.states.appLauncher?.iconSize ?? 64
            onValueChanged: {
                if (!Persistent.states.appLauncher) return
                const rounded = Math.round(value)
                if (Persistent.states.appLauncher.iconSize !== rounded) {
                    Persistent.states.appLauncher.iconSize = rounded
                }
            }
        }
    }

    ContentSection {
        icon: "folder"
        title: Translation.tr("Folders")
        Layout.fillWidth: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: CustomApps.folders

                delegate: Rectangle {
                    id: folderRow
                    required property int index
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 8
                        spacing: 12

                        MaterialSymbol {
                            text: "folder"
                            iconSize: 24
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: folderRow.modelData.name || ""
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: countText.implicitWidth + 16
                            implicitHeight: 22
                            radius: Appearance.rounding.full
                            color: Appearance.colors.colPrimary

                            StyledText {
                                id: countText
                                anchors.centerIn: parent
                                text: (folderRow.modelData.appIndices || []).length
                                color: Appearance.colors.colOnPrimary
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                        }

                        RippleButton {
                            buttonRadius: Appearance.rounding.full
                            implicitWidth: 36
                            implicitHeight: 36
                            onClicked: CustomApps.removeFolderAt(folderRow.index)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "delete"
                                iconSize: 20
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.topMargin: 4
                visible: CustomApps.folders.length === 0
                text: Translation.tr("No folders yet. Create one below.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 8

                ToolbarTextField {
                    id: nameField
                    Layout.fillWidth: true
                    implicitWidth: 0
                    placeholderText: Translation.tr("New folder name")
                    onAccepted: addFolderButton.clicked()
                }

                RippleButton {
                    id: addFolderButton
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 40
                    implicitHeight: 40
                    enabled: nameField.text.trim().length > 0
                    onClicked: {
                        const id = CustomApps.createFolder(nameField.text)
                        if (id.length > 0) nameField.text = ""
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "add"
                        iconSize: 22
                    }
                }
            }
        }
    }
}
