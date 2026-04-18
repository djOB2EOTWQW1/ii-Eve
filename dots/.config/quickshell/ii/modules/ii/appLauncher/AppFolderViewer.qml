import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

// Android 16 style expanded folder: dimmed backdrop + centered app grid panel.
Item {
    id: root
    property var folder: null
    property int iconSize: 64
    signal closed()

    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
        radius: Appearance.rounding.normal

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Rectangle {
        id: folderPanel
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 560)
        height: Math.min(parent.height - 40, 520)
        color: Appearance.m3colors.m3surfaceContainer
        radius: Appearance.rounding.large
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => mouse.accepted = true
        }

        transform: Scale {
            id: openScale
            origin.x: folderPanel.width / 2
            origin.y: folderPanel.height / 2
            xScale: 0.92
            yScale: 0.92
        }
        opacity: 0

        NumberAnimation on opacity {
            from: 0; to: 1
            duration: 160
            easing.type: Easing.OutCubic
            running: true
        }
        NumberAnimation {
            target: openScale; property: "xScale"
            from: 0.92; to: 1
            duration: 200
            easing.type: Easing.OutBack; easing.overshoot: 0.8
            running: true
        }
        NumberAnimation {
            target: openScale; property: "yScale"
            from: 0.92; to: 1
            duration: 200
            easing.type: Easing.OutBack; easing.overshoot: 0.8
            running: true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: width * 0.28
                    color: Appearance.m3colors.m3primaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "folder_open"
                        iconSize: 22
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: -1

                    StyledText {
                        Layout.fillWidth: true
                        text: root.folder?.name ?? ""
                        color: Appearance.colors.colOnLayer1
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.larger
                            variableAxes: Appearance.font.variableAxes.title
                        }
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: folderAppsGrid.count === 0
                            ? Translation.tr("Empty")
                            : folderAppsGrid.count === 1
                                ? Translation.tr("1 app")
                                : Translation.tr("%1 apps").arg(folderAppsGrid.count)
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                RippleButton {
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: {
                        GlobalStates.binarySelectorTargetFolderId = root.folder?.id ?? ""
                        GlobalStates.binarySelectorOpen = true
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "add"
                        iconSize: 20
                    }
                }

                RippleButton {
                    Layout.alignment: Qt.AlignVCenter
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 36
                    implicitHeight: 36
                    onClicked: root.closed()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
            }

            GridView {
                id: folderAppsGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: root.iconSize + 40
                cellHeight: root.iconSize + 50
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}

                model: root.folder ? CustomApps.appsInFolder(root.folder.id) : []

                delegate: Item {
                    id: folderAppDelegate
                    required property var modelData
                    required property int index
                    width: folderAppsGrid.cellWidth
                    height: folderAppsGrid.cellHeight

                    MouseArea {
                        id: folderAppArea
                        anchors.fill: parent
                        anchors.margins: 4
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                CustomApps.removeAppFromFolder(root.folder.id, folderAppDelegate.modelData._originalIndex)
                                return
                            }
                            CustomApps.launch(folderAppDelegate.modelData)
                            root.closed()
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: folderAppArea.pressed
                                ? Appearance.colors.colLayer2Active
                                : folderAppArea.containsMouse
                                    ? Appearance.colors.colLayer2Hover
                                    : "transparent"

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                Image {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: root.iconSize
                                    Layout.preferredHeight: root.iconSize
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    source: {
                                        const icon = folderAppDelegate.modelData.icon || ""
                                        if (icon.startsWith("/")) return "file://" + icon
                                        return Quickshell.iconPath(icon, "application-x-executable")
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    text: folderAppDelegate.modelData.name
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.bottomMargin: 12
                visible: folderAppsGrid.count === 0
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "drag_pan"
                    iconSize: 36
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Drag apps here to add them")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
