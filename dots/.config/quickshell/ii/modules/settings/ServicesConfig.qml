import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page;
    readonly property int index: 5
    property bool register: parent.register ?? false
    forceWidth: true

    ContentSection {
        icon: "neurology"
        title: Translation.tr("AI")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("System prompt")
            text: Config.options.ai.systemPrompt
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Qt.callLater(() => {
                    Config.options.ai.systemPrompt = text;
                });
            }
        }
    }

    ContentSection {
        icon: "album"
        title: Translation.tr("Media")

        ContentSubsection {
            title: Translation.tr("Prioritized player")
            tooltip: Translation.tr("Automatically sets the active player to a newly detected player if its identifier matches the value specified in the priority player property so you dont have to manually set the active player")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Desktop entry name (e.g. spotify, google-chrome)")
                text: Config.options.media.priorityPlayer
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.media.priorityPlayer = text;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "filter_list"
            text: Translation.tr("Filter duplicate players")
            checked: Config.options.media.filterDuplicatePlayers
            onCheckedChanged: {
                Config.options.media.filterDuplicatePlayers = checked;
            }
            StyledToolTip {
                text: Translation.tr("Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)")
            }
        }

    }

    ContentSection {
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        ConfigSpinBox {
            icon: "timer_off"
            text: Translation.tr("Total duration timeout (s)")
            value: Config.options.musicRecognition.timeout
            from: 10
            to: 100
            stepSize: 2
            onValueChanged: {
                Config.options.musicRecognition.timeout = value;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (s)")
            value: Config.options.musicRecognition.interval
            from: 2
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.musicRecognition.interval = value;
            }
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("User agent (for services that require it)")
            text: Config.options.networking.userAgent
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.networking.userAgent = text;
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
        
    }


    ContentSection {
        icon: "lyrics"
        title: Translation.tr("Lyrics")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable lyrics service")
            checked: Config.options.lyricsService.enable
            onCheckedChanged: {
                Config.options.lyricsService.enable = checked;
            }
            StyledToolTip {
                text: Translation.tr("Disabling this will prevent the API from being called, but already cached lyrics will still be available.")
            }
        }


        ConfigRow {
            uniform: true

            ConfigSwitch {
                enabled: Config.options.lyricsService.enable
                buttonIcon: "mood"
                text: Translation.tr("Enable genius lyrics service")
                checked: Config.options.lyricsService.enableGenius
                onCheckedChanged: {
                    Config.options.lyricsService.enableGenius = checked;
                }
            }
            ConfigSwitch {
                enabled: Config.options.lyricsService.enable
                buttonIcon: "library_books"
                text: Translation.tr("Enable lrclib lyrics service")
                checked: Config.options.lyricsService.enableLrclib
                onCheckedChanged: {
                    Config.options.lyricsService.enableLrclib = checked;
                }
            }
        }
    }

    ContentSection {
        icon: "file_open"
        title: Translation.tr("Save paths")
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Video Recording Path")
            text: Config.options.screenRecord.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenRecord.savePath = text;
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Screenshot Path (leave empty to just copy)")
            text: Config.options.screenSnip.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenSnip.savePath = text;
            }
        }
    }

    ContentSection {
        icon: "devices"
        title: Translation.tr("LocalSend")
        tooltip: Translation.tr("You must have the localsend-cli installed\nCheck repo wiki for more information")

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("Auto-start server")
            checked: Config.options.localsend.autoStart
            enabled: LocalSend.available
            onCheckedChanged: {
                Config.options.localsend.autoStart = checked;
            }
            StyledToolTip {
                text: Translation.tr("Automatically start LocalSend server when shell starts")
            }
        }

        ConfigSwitch {
            buttonIcon: "notifications"
            text: Translation.tr("Show notifications")
            checked: Config.options.localsend.showNotifications
            enabled: LocalSend.available
            onCheckedChanged: {
                Config.options.localsend.showNotifications = checked;
            }
            StyledToolTip {
                text: Translation.tr("Show notifications for incoming transfers and completed downloads")
            }
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Download path")
            text: Config.options.localsend.downloadPath
            wrapMode: TextEdit.Wrap
            enabled: LocalSend.available
            onTextChanged: {
                Config.options.localsend.downloadPath = text;
            }
        }
    }

    ContentSection {
        icon: "search"
        title: Translation.tr("Search")

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Math")
                    text: Config.options.search.prefix.math
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.math = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Shell command")
                    text: Config.options.search.prefix.shellCommand
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.shellCommand = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Web search")
                    text: Config.options.search.prefix.webSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.webSearch = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("File search")
                    text: Config.options.search.prefix.fileSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.fileSearch = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Base URL")
                text: Config.options.search.engineBaseUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.engineBaseUrl = text;
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("File search")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Search directory")
                text: Config.options.search.fileSearchDirectory
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.fileSearchDirectory = text;
                }
            }

            ConfigSwitch {
                buttonIcon: "hide_image"
                text: Translation.tr("Blur file search result previews")
                checked: Config.options.search.blurFileSearchResultPreviews
                onCheckedChanged: {
                    Config.options.search.blurFileSearchResultPreviews = checked;
                }
            }

        }
    }

    ContentSection {
        icon: "file_open"
        title: Translation.tr("Wallpaper Browser")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Download path")
            text: Config.options.wallpapers.paths.download
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.wallpapers.paths.download = text;
            }
        }
    }

    // There's no update indicator in ii for now so we shouldn't show this yet
    // ContentSection {
    //     icon: "deployed_code_update"
    //     title: Translation.tr("System updates (Arch only)")

    //     ConfigSwitch {
    //         text: Translation.tr("Enable update checks")
    //         checked: Config.options.updates.enableCheck
    //         onCheckedChanged: {
    //             Config.options.updates.enableCheck = checked;
    //         }
    //     }

    //     ConfigSpinBox {
    //         icon: "av_timer"
    //         text: Translation.tr("Check interval (mins)")
    //         value: Config.options.updates.checkInterval
    //         from: 60
    //         to: 1440
    //         stepSize: 60
    //         onValueChanged: {
    //             Config.options.updates.checkInterval = value;
    //         }
    //     }
    // }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Weather")

        ContentSubsection {
            title: Translation.tr("Provider")
            tooltip: Translation.tr("wttr.in is the default; switch to Open-Meteo if weather data looks wrong for your country.")

            ConfigSelectionArray {
                currentValue: Config.options.bar.weather.provider
                onSelected: newValue => {
                    Config.options.bar.weather.provider = newValue;
                }
                options: [
                    {
                        displayName: "wttr.in",
                        icon: "cloud",
                        value: "wttr"
                    },
                    {
                        displayName: "Open-Meteo",
                        icon: "public",
                        value: "open-meteo"
                    }
                ]
            }
        }

        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }
    }

    ContentSection {
        icon: "translate"
        title: Translation.tr("Screen Translator")

        ContentSubsection {
            title: Translation.tr("Translate to")
            tooltip: Translation.tr("Defaults to UI language when empty")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Language code (e.g. ru, en, ja) or empty for auto")
                text: Config.options.screenTranslator.targetLanguage
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.screenTranslator.targetLanguage = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Provider")

            ConfigSelectionArray {
                currentValue: Config.options.screenTranslator.provider
                onSelected: newValue => {
                    Config.options.screenTranslator.provider = newValue;
                }
                options: [
                    { displayName: "Google", icon: "public", value: "google" },
                    { displayName: "Local (offline)", icon: "wifi_off", value: "local" }
                ]
            }
        }

        // Local-only options
        Loader {
            Layout.fillWidth: true
            active: Config.options.screenTranslator.provider === "local"
            sourceComponent: ColumnLayout {
                spacing: 8

                ContentSubsection {
                    title: Translation.tr("Tesseract model")
                    tooltip: Translation.tr("Fast is smaller and faster; Best is more accurate")

                    ConfigSelectionArray {
                        currentValue: Config.options.screenTranslator.local.tesseractModel
                        onSelected: newValue => {
                            Config.options.screenTranslator.local.tesseractModel = newValue;
                        }
                        options: [
                            { displayName: "Fast", icon: "bolt", value: "fast" },
                            { displayName: "Best", icon: "diamond", value: "best" }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Language packs")

                    MaterialTextArea {
                        id: langSearch
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Search…")
                        wrapMode: TextEdit.NoWrap
                    }

                    Repeater {
                        model: LocalTranslator.languageRegistry.filter(entry => {
                            const q = langSearch.text.toLowerCase();
                            if (!q) return true;
                            return entry.name.toLowerCase().includes(q)
                                || entry.tess.includes(q)
                                || entry.argos.includes(q);
                        })

                        delegate: RowLayout {
                            id: row
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8

                            readonly property string rowState: LocalTranslator.rowState(modelData.tess)

                            StyledText {
                                text: modelData.name
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                id: chip
                                implicitWidth: chipLabel.implicitWidth + 16
                                implicitHeight: chipLabel.implicitHeight + 8
                                radius: 6
                                color: {
                                    switch (row.rowState) {
                                    case "system":      return Appearance.colors.colSecondaryContainer;
                                    case "installed":   return Appearance.colors.colSecondaryContainer;
                                    case "partial":     return Appearance.colors.colTertiaryContainer;
                                    case "installing":  return Appearance.colors.colSecondaryContainer;
                                    case "uninstalling":return Appearance.colors.colSecondaryContainer;
                                    case "error":       return Appearance.colors.colError;
                                    case "missing":     return Appearance.colors.colSurfaceContainer;
                                    default:            return Appearance.colors.colSurfaceContainer;
                                    }
                                }
                                StyledText {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: {
                                        switch (row.rowState) {
                                        case "system":      return Translation.tr("System");
                                        case "installed":   return Translation.tr("Installed");
                                        case "partial":     return Translation.tr("Partial");
                                        case "installing":  return Translation.tr("Installing…");
                                        case "uninstalling":return Translation.tr("Removing…");
                                        case "error":       return Translation.tr("Error");
                                        case "missing":     return Translation.tr("Not installed");
                                        default:            return "";
                                        }
                                    }
                                    color: row.rowState === "error" ? Appearance.colors.colOnError : Appearance.m3colors.m3onSurface
                                }
                            }

                            DialogButton {
                                visible: row.rowState === "missing"
                                    || row.rowState === "partial"
                                    || row.rowState === "error"
                                enabled: row.rowState !== "installing" && row.rowState !== "uninstalling"
                                buttonText: row.rowState === "error" ? Translation.tr("Retry") : Translation.tr("Install")
                                onClicked: LocalTranslator.installLanguage(row.modelData.tess)
                            }
                            DialogButton {
                                visible: row.rowState === "installed"
                                enabled: true
                                buttonText: Translation.tr("Uninstall")
                                onClicked: LocalTranslator.uninstallLanguage(row.modelData.tess)
                            }
                        }
                    }
                }
            }
        }

        // Google-only hint
        Loader {
            Layout.fillWidth: true
            active: Config.options.screenTranslator.provider === "google"
            sourceComponent: StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: Translation.tr("Configure your Google Cloud service account key inside the Screen Translator panel (SUPER+SHIFT+T → key icon).")
            }
        }
    }
}
