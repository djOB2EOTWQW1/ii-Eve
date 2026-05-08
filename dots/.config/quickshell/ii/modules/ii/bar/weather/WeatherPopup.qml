import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "../cards"

import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar

StyledPopup {
    id: root
    popupRadius: Appearance.rounding.large

    property bool compactMode: Config.options.bar.tooltips.compactPopups
    property int cardMargins: 14

    // Forecast data model — bound to the Weather service (single source of truth)
    readonly property var forecastData: Weather.forecastDaily
    readonly property var hourlyData: Weather.forecastHourly
    readonly property bool forecastLoading: Weather.forecastLoading
    property int maxHourlyBars: 5

    property var filteredHourlyData: {
        if (hourlyData.length === 0) return [];

        // Detect the source's time step from the first two entries — wttr.in
        // returns 3-hour slots, open-meteo returns 1-hour slots. Falling back
        // to 3 keeps behavior unchanged for single-entry payloads.
        let stepHours = 3;
        if (hourlyData.length >= 2) {
            const h0 = Math.floor(parseInt(hourlyData[0].time) / 100);
            const h1 = Math.floor(parseInt(hourlyData[1].time) / 100);
            const diff = (h1 - h0 + 24) % 24;
            if (diff > 0) stepHours = diff;
        }

        const currentHr = new Date().getHours();
        const currentSlot = Math.floor(currentHr / stepHours) * stepHours;
        let futureHours = [];
        let passedMidnight = false;

        for (let i = 0; i < hourlyData.length; i++) {
            const item = hourlyData[i];
            const itemHour = Math.floor(parseInt(item.time) / 100);

            if (i > 0 && itemHour < Math.floor(parseInt(hourlyData[i - 1].time) / 100)) {
                passedMidnight = true;
            }

            if (passedMidnight || itemHour >= currentSlot) {
                futureHours.push(item);
            }
        }
        return futureHours.slice(0, maxHourlyBars);
    }

    function getDayName(dateStr, index) {
        if (index === 0)
            return Translation.tr("Today");
        if (index === 1)
            return Translation.tr("Tomorrow");
        const date = new Date(dateStr);
        const days = [Translation.tr("Sun"), Translation.tr("Mon"), Translation.tr("Tue"), Translation.tr("Wed"), Translation.tr("Thu"), Translation.tr("Fri"), Translation.tr("Sat")];
        return days[date.getDay()];
    }

    function formatHour(timeStr) {
        const hour = Math.floor(parseInt(timeStr) / 100);
        return hour.toString().padStart(2, '0') + ":00";
    }

    function getHourlyTempRange() {
        const data = filteredHourlyData.length > 0 ? filteredHourlyData : hourlyData;
        if (data.length === 0)
            return {
                min: 0,
                max: 100
            };
        const temps = data.map(h => Weather.useUSCS ? parseInt(h.tempF) : parseInt(h.tempC));
        const min = Math.min(...temps);
        const max = Math.max(...temps);
        // 20% padding (minimum 2°) — chosen so that a near-flat day (e.g.
        // 22→23°C) still produces a visually meaningful bar height delta
        // without exaggerating already-large swings.
        const padding = Math.max(2, (max - min) * 0.2);
        return {
            min: min - padding,
            max: max + padding
        };
    }

    contentItem: ColumnLayout {
        id: contentLayout
        anchors.centerIn: parent
        spacing: 12

        HeroCard {
            id: weatherHero
            Layout.minimumWidth: 320
            margins: 20
            iconSize: 100
            icon: Icons.getWeatherIcon(Weather.data.wCode) || "cloud_off"
            pillText: Weather.data.city || "--"
            pillIcon: (Weather.data.city || "").length > 0 ? "location_on" : ""
            title: Weather.data.temp
            subtitle: Weather.data.wDesc
        }
        
        HourlyForecast {
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: 6
            shapeString: "Clover4Leaf"
            shapeColor: Appearance.colors.colSecondaryContainer
            symbolColor: Appearance.colors.colOnSecondaryContainer
            showDivider: false
            title: Translation.tr("Hourly")
            icon: "schedule"
            headerExtraText: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh || "--")
        }

        MetricsGrid {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            uniformCellWidths: true
        }

        InDayForecast {
            Layout.minimumWidth: 360
            margins: root.cardMargins
            spacing: 8
            shapeString: "Cookie6Sided"
            shapeColor: Appearance.colors.colSecondaryContainer
            symbolColor: Appearance.colors.colOnSecondaryContainer
            showDivider: false
            title: Translation.tr("Forecast")
            icon: "calendar_month"
        }
    }
}
