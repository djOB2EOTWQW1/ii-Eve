import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    // Helper function to format KB to GB
    function formatGB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 12

        HeroCard {
            id: resourcesHero
            Layout.fillWidth: true
            icon: "developer_board"
            title: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            subtitle: ResourceUsage.cpuModel
            subtitleSize: Appearance.font.pixelSize.larger
            pillText: ResourceUsage.cpuTemp
            pillIcon: "device_thermostat"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: Appearance.colors.colSurfaceContainerHighest
            radius: 1
        }

        HeroCard {
            Layout.fillWidth: true
            icon: "display_settings"
            title: `${Math.round(ResourceUsage.gpuUsage * 100)}%`
            subtitle: ResourceUsage.gpuModel
            subtitleSize: Appearance.font.pixelSize.normal
            pillText: ResourceUsage.gpuTemp
            pillIcon: "device_thermostat"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: Appearance.colors.colSurfaceContainerHighest
            radius: 1
        }

        RowLayout {
            Layout.fillWidth: true

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12
                ResourceCard {
                    title: Translation.tr("RAM")
                    icon: "memory"
                    shapeString: "Clover4Leaf"
                    shapeColor: Appearance.colors.colSecondaryContainer
                    symbolColor: Appearance.colors.colOnSecondaryContainer

                    resourceName: Translation.tr("Used")
                    resourceValueText: root.formatGB(ResourceUsage.memoryUsed)
                    resourcePercentage: ResourceUsage.memoryUsedPercentage
                    highlightColor: Appearance.colors.colSecondary

                    StyledPopupValueRow {
                        icon: "check_circle"
                        label: Translation.tr("Available")
                        value: root.formatGB(ResourceUsage.memoryFree)
                    }
                }

                ResourceCard {
                    title: Translation.tr("Swap")
                    icon: "swap_horiz"
                    shapeString: "Clover8Leaf"
                    shapeColor: Appearance.colors.colPrimaryContainer
                    symbolColor: Appearance.colors.colOnPrimaryContainer

                    resourceName: Translation.tr("Used")
                    resourceValueText: root.formatGB(ResourceUsage.swapUsed)
                    resourcePercentage: ResourceUsage.swapUsedPercentage
                    highlightColor: Appearance.colors.colPrimary

                    StyledPopupValueRow {
                        icon: "check_circle"
                        label: Translation.tr("Available")
                        value: root.formatGB(ResourceUsage.swapFree)
                    }
                }

                ResourceCard {
                    title: Translation.tr("Storage")
                    icon: "hard_drive"
                    shapeString: "Cookie9Sided"
                    shapeColor: Appearance.colors.colTertiaryContainer
                    symbolColor: Appearance.colors.colOnTertiaryContainer

                    resourceName: Translation.tr("Disk")
                    resourceValueText: `${root.formatGB(ResourceUsage.diskUsed).split(" ")[0]} / ${root.formatGB(ResourceUsage.diskTotal)}`
                    resourcePercentage: ResourceUsage.diskUsedPercentage
                    highlightColor: Appearance.colors.colTertiary

                    StyledPopupValueRow {
                        icon: "memory"
                        label: "Free"
                        value: root.formatGB(ResourceUsage.diskTotal - ResourceUsage.diskUsed)
                    }
                }

                ResourceCard {
                    title: Translation.tr("Network")
                    icon: "network_check"
                    shapeString: "Clover4Leaf"
                    shapeColor: Appearance.colors.colPrimaryContainer
                    symbolColor: Appearance.colors.colOnPrimaryContainer

                    resourceName: Translation.tr("↓ / ↑")
                    resourceValueText: `${ResourceUsage.formatNetSpeed(ResourceUsage.netRxBytesPerSec)} / ${ResourceUsage.formatNetSpeed(ResourceUsage.netTxBytesPerSec)}`
                    resourcePercentage: -1
                    highlightColor: Appearance.colors.colPrimary

                    StyledPopupValueRow {
                        icon: "arrow_downward"
                        label: Translation.tr("Download")
                        graphValues: ResourceUsage.netRxHistory
                        graphColor: Appearance.colors.colPrimary
                    }

                    StyledPopupValueRow {
                        icon: "arrow_upward"
                        label: Translation.tr("Upload")
                        graphValues: ResourceUsage.netTxHistory
                        graphColor: Appearance.colors.colTertiary
                    }
                }
            }
        }
    }
}
