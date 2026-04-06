import qs.modules.common
import qs.modules.common.widgets
import "./cards"
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    property string formattedDate: Qt.locale().toString(DateTime.clock.date, "MMMM dd, dddd")
    property string formattedTime: DateTime.time
    property string formattedUptime: DateTime.uptime
    property string todosSection: getUpcomingTodos(Todo.list)
    property bool todosEmpty: todosSection === ""

    function getUpcomingTodos(todos) {
        const unfinishedTodos = todos.filter(function (item) {
            return !item.done;
        });
        if (unfinishedTodos.length === 0) {
            return "";
        }

        // Limit to first 3 todos
        const limitedTodos = unfinishedTodos.slice(0, 3);
        let todoText = limitedTodos.map(function (item, index) {
            return `  • ${item.content}`;
        }).join('\n');

        if (unfinishedTodos.length > 3) {
            todoText += `\n  ${Translation.tr("... and %1 more").arg(unfinishedTodos.length - 3)}`;
        }

        return todoText;
    }

    function formatTimerDisplay(seconds) {
        let m = Math.floor(seconds / 60);
        let s = seconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    ColumnLayout {
        id: columnLayout
        anchors.centerIn: parent
        spacing: 12

        // Hero date time card
        HeroCard {
            id: clockHero

            shapeContent: MaterialSymbol {
                anchors.centerIn: parent
                text: "schedule"
                iconSize: 48
                color: Appearance.colors.colOnPrimaryContainer
            }

            StyledText {
                text: root.formattedTime
                font.pixelSize: Appearance.font.pixelSize.hugeass * 2.5
                font.family: Appearance.font.family.title
                font.weight: Font.Black
                color: clockHero.textColor
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }

            StyledText {
                text: root.formattedDate
                font.pixelSize: Appearance.font.pixelSize.normal
                font.family: Appearance.font.family.main
                font.weight: Font.DemiBold
                color: clockHero.textColor
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignRight
            }
        }

        // 2 middle shapes
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12

            // Uptime pill
            InfoPill {
                text: root.formattedUptime

                CustomIcon {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: SystemInfo.distroIcon
                    colorize: true
                    color: Appearance.colors.colOnSecondary
                }
            }

            // Timer Pill
            InfoPill {
                text: TimerService.pomodoroRunning ? root.formatTimerDisplay(TimerService.pomodoroSecondsLeft) : (TimerService.stopwatchRunning ? root.formatTimerDisplay(TimerService.stopwatchTime) : Translation.tr("Timer Off"))
                containerColor: TimerService.pomodoroBreak ? Appearance.colors.colTertiaryContainer : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer)
                color: containerColor
                shapeColor: TimerService.pomodoroBreak ? Appearance.colors.colTertiary : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colPrimary : Appearance.colors.colSecondary)
                textColor: TimerService.pomodoroBreak ? Appearance.colors.colOnTertiaryContainer : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer)

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: TimerService.pomodoroBreak ? "coffee" : "timer"
                    iconSize: Appearance.font.pixelSize.large
                    color: TimerService.pomodoroBreak ? Appearance.colors.colOnTertiary : (TimerService.pomodoroRunning || TimerService.stopwatchRunning ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondary)
                }
            }
        }

        // To-dos List Card
        SectionCard {
            title: Translation.tr("To-Do Tasks")

            shapeContent: MaterialSymbol {
                anchors.centerIn: parent
                text: "checklist"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnTertiaryContainer
            }

            StyledText {
                visible: !root.todosEmpty
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignLeft
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurfaceVariant
                text: root.todosSection
                lineHeight: 1.4
            }

            // using loading indicator on empty state for now
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                visible: root.todosEmpty
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialLoadingIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        loading: true
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No pending tasks")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }
}
