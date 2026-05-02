import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.appLauncher.vimium
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ContentPage {
    id: page
    readonly property int index: 1
    property bool register: false
    forceWidth: true
    interactive: false

    property bool vimiumActive: false
    property string vimiumTyped: ""
    property var vimiumHints: []

    readonly property var lp: Persistent.states.appLauncher?.launchParams ?? null

    // Default Launch Parameters
    ContentSection {
        icon: "tune"
        title: Translation.tr("Default Launch Parameters")
        Layout.fillWidth: true

        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "speed"
            text: "MANGOHUD=1"
            checked: page.lp?.defaultsMangohud ?? false
            onCheckedChanged: {
                if (page.lp && page.lp.defaultsMangohud !== checked) {
                    page.lp.defaultsMangohud = checked
                }
            }
        }

        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "sports_esports"
            text: "gamemoderun"
            checked: page.lp?.defaultsGamemoderun ?? false
            onCheckedChanged: {
                if (page.lp && page.lp.defaultsGamemoderun !== checked) {
                    page.lp.defaultsGamemoderun = checked
                }
            }
        }

        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "videocam"
            text: "OBS_VKCAPTURE=1"
            checked: page.lp?.defaultsObsVkCapture ?? false
            onCheckedChanged: {
                if (page.lp && page.lp.defaultsObsVkCapture !== checked) {
                    page.lp.defaultsObsVkCapture = checked
                }
            }
        }

        ContentSubsectionLabel {
            Layout.fillWidth: true
            text: Translation.tr("Extra")
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: extraInput.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            StyledTextInput {
                id: extraInput
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                text: page.lp?.defaultsExtra ?? ""
                onEditingFinished: {
                    if (page.lp && page.lp.defaultsExtra !== text) {
                        page.lp.defaultsExtra = text
                    }
                }
                // Placeholder via a sibling Text (StyledTextInput is a TextInput, no native placeholder).
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 8 + (extraInput.padding ?? 0)
                anchors.verticalCenter: parent.verticalCenter
                visible: extraInput.text.length === 0 && !extraInput.activeFocus
                text: "WINEDEBUG=-all RADV_PERFTEST=video_decode"
                color: Appearance.colors.colSubtext
                opacity: 0.7
                font.pixelSize: extraInput.font.pixelSize
            }
        }
    }

    // Per-app Parameters
    ContentSection {
        id: perAppSection
        icon: "terminal"
        title: Translation.tr("Per-app Parameters")
        Layout.fillWidth: true

        property string selectedPath: ""

        readonly property var nativeApps: {
            const out = []
            const list = CustomApps.entries || []
            for (let i = 0; i < list.length; i++) {
                const e = list[i]
                if (!e || !e.path) continue
                if (String(e.path).toLowerCase().endsWith('.exe')) continue
                out.push(e)
            }
            return out
        }

        readonly property var selectedEntry: {
            const map = page.lp?.perApp || {}
            return map[perAppSection.selectedPath] || null
        }

        function _writePerApp(path, params, useDefaults) {
            if (!page.lp || !path) return
            const trimmed = String(params || "").trim()
            const next = Object.assign({}, page.lp.perApp || {})
            if (trimmed.length === 0 && !useDefaults) {
                delete next[path]
            } else {
                next[path] = { params: trimmed, useDefaults: !!useDefaults }
            }
            page.lp.perApp = next
        }

        component BinaryPicker: Item {
            id: picker
            Layout.fillWidth: true
            implicitHeight: anchorRow.implicitHeight + 12

            Rectangle {
                id: anchorRow
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: anchorMouse.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 10

                    MaterialSymbol {
                        text: "apps"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (perAppSection.selectedPath.length === 0)
                                    return Translation.tr("Select a binary")
                                const list = CustomApps.entries || []
                                for (let i = 0; i < list.length; i++) {
                                    if (list[i].path === perAppSection.selectedPath)
                                        return list[i].name || list[i].path
                                }
                                return perAppSection.selectedPath
                            }
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: perAppSection.selectedPath.length > 0
                            text: perAppSection.selectedPath
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            elide: Text.ElideMiddle
                        }
                    }

                    MaterialSymbol {
                        text: popup.opened ? "expand_less" : "expand_more"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                }

                MouseArea {
                    id: anchorMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: popup.opened ? popup.close() : popup.open()
                }
            }

            Popup {
                id: popup
                y: anchorRow.height + 4
                width: anchorRow.width
                padding: 4
                background: Rectangle {
                    color: Appearance.colors.colLayer1
                    radius: Appearance.rounding.normal
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.85)
                }

                ListView {
                    id: listView
                    width: popup.width - 8
                    // 6 rows, ~44px each
                    implicitHeight: Math.min(perAppSection.nativeApps.length, 6) * 44
                    clip: true
                    model: perAppSection.nativeApps
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        height: 40
                        radius: Appearance.rounding.small
                        color: rowMouse.containsMouse ? Appearance.colors.colLayer1Hover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                source: {
                                    const icon = modelData.icon || ""
                                    if (icon.startsWith("/")) return "file://" + icon
                                    return Quickshell.iconPath(icon || "application-x-executable", "application-x-executable")
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name || modelData.path
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.path
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideMiddle
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                perAppSection.selectedPath = modelData.path
                                popup.close()
                            }
                        }
                    }
                }
            }
        }

        BinaryPicker {
            id: binaryPicker
        }
    }
}
