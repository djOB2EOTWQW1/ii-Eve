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
}
