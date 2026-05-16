import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property WifiAccessPoint wifiNetwork
    readonly property bool isActive: root.wifiNetwork?.active ?? false
    readonly property bool isConnecting: Network.wifiConnectTarget === root.wifiNetwork && !root.isActive
    readonly property bool isSecure: root.wifiNetwork?.isSecure ?? false
    readonly property int strength: root.wifiNetwork?.strength ?? 0
    readonly property string strengthIcon: strength > 80 ? "signal_wifi_4_bar"
        : strength > 60 ? "network_wifi_3_bar"
        : strength > 40 ? "network_wifi_2_bar"
        : strength > 20 ? "network_wifi_1_bar"
        : "signal_wifi_0_bar"

    enabled: !(root.isConnecting)
    active: (wifiNetwork?.askingPassword || root.isActive) ?? false
    onClicked: Network.connectToWifiNetwork(wifiNetwork)

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

            // Signal strength icon — highlighted container only when active
            Item {
                Layout.alignment: Qt.AlignVCenter
                width: 30
                height: 30

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colPrimaryContainer
                    opacity: root.isActive ? 1 : 0
                    Behavior on opacity {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconSize: 20
                    text: root.strengthIcon
                    color: root.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                    textFormat: Text.PlainText
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    text: {
                        if (root.isConnecting) return Translation.tr("Connecting…");
                        if (root.isActive) return Translation.tr("Connected") + " • " + root.strength + "%";
                        const sec = root.isSecure ? Translation.tr("Secured") : Translation.tr("Open");
                        return sec + " • " + root.strength + "%";
                    }
                    animateChange: true
                }
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                visible: root.isActive || root.isConnecting || root.isSecure
                text: root.isActive ? "check_circle" : root.isConnecting ? "more_horiz" : "lock"
                iconSize: Appearance.font.pixelSize.large
                color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
            }
        }

        ColumnLayout { // Password
            id: passwordPrompt
            Layout.topMargin: 10
            visible: root.wifiNetwork?.askingPassword ?? false

            MaterialTextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Password")

                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onAccepted: Network.changePassword(root.wifiNetwork, passwordField.text)
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: root.wifiNetwork.askingPassword = false
                }

                DialogButton {
                    buttonText: Translation.tr("Connect")
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    colText: Appearance.colors.colOnPrimary
                    onClicked: Network.changePassword(root.wifiNetwork, passwordField.text)
                }
            }
        }

        ColumnLayout { // Public wifi login page
            id: publicWifiPortal
            Layout.topMargin: 10
            visible: (root.isActive && (root.wifiNetwork?.security ?? "").trim().length === 0) ?? false

            DialogButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Open network portal")
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                colText: Appearance.colors.colOnSecondaryContainer
                onClicked: {
                    Network.openPublicWifiPortal();
                    GlobalStates.sidebarRightOpen = false;
                }
            }
        }
    }
}
