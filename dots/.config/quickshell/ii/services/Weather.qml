pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root
    // 10 minute
    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    readonly property string provider: Config.options.bar.weather.provider
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onUseUSCSChanged: {
        root.getData();
    }
    onCityChanged: {
        root.getData();
    }
    onProviderChanged: {
        root.getData();
    }

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        wDesc: "",
        city: 0,
        wind: 0,
        precip: 0,
        visib: 0,
        press: 0,
        temp: 0,
        tempFeelsLike: 0,
        lastRefresh: 0,
    })

    property bool forecastLoading: false
    property var forecastDaily: []      // [{date, maxC, minC, maxF, minF, code}]
    property var forecastHourly: []     // [{time, tempC, tempF, code}]

    function refineData(data) {
        let temp = {};
        temp.uv = data?.current?.uvIndex || 0;
        temp.humidity = (data?.current?.humidity || 0) + "%";
        temp.sunrise = data?.astronomy?.sunrise || "0.0";
        temp.sunset = data?.astronomy?.sunset || "0.0";
        temp.windDir = data?.current?.winddir16Point || "N";
        temp.wCode = data?.current?.weatherCode || "113";
        temp.wDesc = root.getWeatherDescription(temp.wCode);
        temp.city = data?.location?.areaName[0]?.value || "City";
        temp.temp = "";
        temp.tempFeelsLike = "";
        if (root.useUSCS) {
            temp.wind = (data?.current?.windspeedMiles || 0) + " mph";
            temp.precip = (data?.current?.precipInches || 0) + " in";
            temp.visib = (data?.current?.visibilityMiles || 0) + " m";
            temp.press = (data?.current?.pressureInches || 0) + " psi";
            temp.temp += (data?.current?.temp_F || 0);
            temp.tempFeelsLike += (data?.current?.FeelsLikeF || 0);
            temp.temp += "°F";
            temp.tempFeelsLike += "°F";
        } else {
            temp.wind = (data?.current?.windspeedKmph || 0) + " km/h";
            temp.precip = (data?.current?.precipMM || 0) + " mm";
            temp.visib = (data?.current?.visibility || 0) + " km";
            temp.press = (data?.current?.pressure || 0) + " hPa";
            temp.temp += (data?.current?.temp_C || 0);
            temp.tempFeelsLike += (data?.current?.FeelsLikeC || 0);
            temp.temp += "°C";
            temp.tempFeelsLike += "°C";
        }
        temp.lastRefresh = DateTime.time + " • " + DateTime.date;
        root.data = temp;
    }

    function getData() {
        root.forecastLoading = true;
        if (root.provider === "open-meteo") {
            root._fetchOpenMeteo();
        } else {
            root._fetchWttr();
        }
    }

    function _fetchWttr() {
        const ua = (Config.options?.networking?.userAgent || "curl/7.68.0");
        let target;
        if (root.gpsActive && root.location.valid) {
            target = `${root.location.lat},${root.location.long}`;
        } else {
            target = formatCityName(root.city);
        }
        const jq =
            "jq '{" +
            "current: .current_condition[0]," +
            "location: .nearest_area[0]," +
            "astronomy: .weather[0].astronomy[0]," +
            "daily: [.weather[] | {date: .date, maxC: .maxtempC, minC: .mintempC, maxF: .maxtempF, minF: .mintempF, code: .hourly[4].weatherCode}]," +
            "hourly: [.weather[0].hourly[], .weather[1].hourly[] | {time: .time, tempC: .tempC, tempF: .tempF, code: .weatherCode}]" +
            "}'";
        fetcher.command[2] = `curl -s -H 'User-Agent: ${ua}' "wttr.in/${target}?format=j1" | ${jq}`;
        fetcher.running = true;
    }

    function _fetchOpenMeteo() {
        const forecastParams =
            "current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m,uv_index,visibility" +
            "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset" +
            "&hourly=temperature_2m,weather_code" +
            "&timezone=auto" +
            "&forecast_days=3";

        let bash;
        if (root.gpsActive && root.location.valid) {
            const lat = root.location.lat;
            const lon = root.location.long;
            // Synthetic geo block (no name from GPS); city falls back later.
            bash =
                `GEO='{"latitude":${lat},"longitude":${lon},"name":""}'; ` +
                `FC=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&${forecastParams}"); ` +
                `printf '%s' "$FC" | jq --argjson geo "$GEO" '. + {geo: $geo}'`;
        } else {
            const cityParam = formatCityName(root.city);
            bash =
                `GEO_RAW=$(curl -s "https://geocoding-api.open-meteo.com/v1/search?name=${cityParam}&count=1&language=en&format=json"); ` +
                `GEO=$(printf '%s' "$GEO_RAW" | jq -c 'if (.results // [] | length) == 0 then null else {latitude: .results[0].latitude, longitude: .results[0].longitude, name: .results[0].name} end'); ` +
                `if [ "$GEO" = "null" ] || [ -z "$GEO" ]; then exit 0; fi; ` +
                `LAT=$(printf '%s' "$GEO" | jq -r '.latitude'); ` +
                `LON=$(printf '%s' "$GEO" | jq -r '.longitude'); ` +
                `FC=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&${forecastParams}"); ` +
                `printf '%s' "$FC" | jq --argjson geo "$GEO" '. + {geo: $geo}'`;
        }

        openMeteoFetcher.command[2] = bash;
        openMeteoFetcher.running = true;
    }

    function getWeatherDescription(code) {
        const codeInt = parseInt(code);
        const descriptions = {
            "113": Translation.tr("Clear"),
            "116": Translation.tr("Partly Cloudy"),
            "119": Translation.tr("Cloudy"),
            "122": Translation.tr("Overcast"),
            "143": Translation.tr("Mist"),
            "176": Translation.tr("Patchy Rain"),
            "200": Translation.tr("Thundery Outbreaks"),
            "248": Translation.tr("Fog"),
            "266": Translation.tr("Light Drizzle"),
            "296": Translation.tr("Light Rain"),
            "302": Translation.tr("Moderate Rain"),
            "308": Translation.tr("Heavy Rain"),
            "326": Translation.tr("Light Snow"),
            "332": Translation.tr("Moderate Snow"),
            "338": Translation.tr("Heavy Snow"),
            "353": Translation.tr("Light Rain Shower"),
            "389": Translation.tr("Heavy Rain with Thunder")
        };

        if (descriptions[code]) {
            return descriptions[code];
        }

        let keys = Object.keys(descriptions).map(Number).sort((a, b) => a - b);
        let bestMatch = keys[0];

        for (let i = 0; i < keys.length; i++) {
            if (codeInt >= keys[i]) {
                bestMatch = keys[i];
            } else {
                break;
            }
        }

        return descriptions[bestMatch.toString()] || Translation.tr("Unknown");
    }

    function _wmoToWwoCode(wmo) {
        const map = {
            0: "113", 1: "116", 2: "116", 3: "122",
            45: "248", 48: "248",
            51: "266", 53: "266", 55: "266", 56: "266", 57: "266",
            61: "296", 63: "302", 65: "308", 66: "302", 67: "302",
            71: "326", 73: "332", 75: "338", 77: "326",
            80: "353", 81: "302", 82: "308", 85: "326", 86: "338",
            95: "200", 96: "389", 99: "389"
        };
        return map[parseInt(wmo)] || "113";
    }

    function _omWindDir(deg) {
        if (deg === undefined || deg === null) return "N";
        const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
        const idx = Math.round(((deg % 360 + 360) % 360) / 45) % 8;
        return dirs[idx];
    }

    function _refineOpenMeteo(parsed) {
        const cur = parsed.current || {};
        const daily = parsed.daily || {};
        const hourly = parsed.hourly || {};
        const geo = parsed.geo || {};

        const wCode = root._wmoToWwoCode(cur.weather_code);
        const tC = cur.temperature_2m;
        const fC = cur.apparent_temperature;

        const out = {};
        out.uv = cur.uv_index !== undefined ? cur.uv_index : 0;
        out.humidity = (cur.relative_humidity_2m !== undefined ? cur.relative_humidity_2m : 0) + "%";
        out.sunrise = (daily.sunrise && daily.sunrise[0]) ? daily.sunrise[0].slice(11, 16) : "0.0";
        out.sunset = (daily.sunset && daily.sunset[0]) ? daily.sunset[0].slice(11, 16) : "0.0";
        out.windDir = root._omWindDir(cur.wind_direction_10m);
        out.wCode = wCode;
        out.wDesc = root.getWeatherDescription(wCode);
        out.city = geo.name || root.data.city || Translation.tr("Current Location");

        if (root.useUSCS) {
            out.wind = (cur.wind_speed_10m !== undefined ? (cur.wind_speed_10m * 0.621371).toFixed(1) : "0") + " mph";
            out.precip = (cur.precipitation !== undefined ? (cur.precipitation * 0.0393701).toFixed(2) : "0") + " in";
            // UI labels USCS visibility " m" verbatim — preserve.
            out.visib = (cur.visibility !== undefined ? (cur.visibility / 1609).toFixed(1) : "0") + " m";
            out.press = (cur.pressure_msl !== undefined ? (cur.pressure_msl * 0.0145038).toFixed(2) : "0") + " psi";
            out.temp = (tC !== undefined ? Math.round(tC * 9/5 + 32) : 0) + "°F";
            out.tempFeelsLike = (fC !== undefined ? Math.round(fC * 9/5 + 32) : 0) + "°F";
        } else {
            out.wind = (cur.wind_speed_10m !== undefined ? cur.wind_speed_10m : 0) + " km/h";
            out.precip = (cur.precipitation !== undefined ? cur.precipitation : 0) + " mm";
            out.visib = (cur.visibility !== undefined ? (cur.visibility / 1000).toFixed(1) : "0") + " km";
            out.press = (cur.pressure_msl !== undefined ? cur.pressure_msl : 0) + " hPa";
            out.temp = (tC !== undefined ? Math.round(tC) : 0) + "°C";
            out.tempFeelsLike = (fC !== undefined ? Math.round(fC) : 0) + "°C";
        }
        out.lastRefresh = DateTime.time + " • " + DateTime.date;
        root.data = out;

        // Daily forecast: 3 days, °C source, both unit families derived locally.
        const dailyOut = [];
        const times = daily.time || [];
        for (let i = 0; i < times.length; i++) {
            const cMax = daily.temperature_2m_max ? daily.temperature_2m_max[i] : 0;
            const cMin = daily.temperature_2m_min ? daily.temperature_2m_min[i] : 0;
            dailyOut.push({
                date: times[i],
                maxC: Math.round(cMax).toString(),
                minC: Math.round(cMin).toString(),
                maxF: Math.round(cMax * 9/5 + 32).toString(),
                minF: Math.round(cMin * 9/5 + 32).toString(),
                code: root._wmoToWwoCode(daily.weather_code ? daily.weather_code[i] : 0)
            });
        }
        root.forecastDaily = dailyOut;

        // Hourly forecast: starting from current hour, up to 24 entries.
        const hourlyOut = [];
        const hTimes = hourly.time || [];
        const hTemps = hourly.temperature_2m || [];
        const hCodes = hourly.weather_code || [];
        const nowHour = new Date().getHours();
        let startIdx = hTimes.findIndex(iso => parseInt(iso.slice(11, 13)) >= nowHour);
        if (startIdx < 0) startIdx = 0;
        const end = Math.min(startIdx + 24, hTimes.length);
        for (let j = startIdx; j < end; j++) {
            const iso = hTimes[j];
            const c = hTemps[j] !== undefined ? hTemps[j] : 0;
            hourlyOut.push({
                // Match wttr.in's "0"/"300"/"600"/... format for downstream filtering.
                time: (parseInt(iso.slice(11, 13)) * 100).toString(),
                tempC: Math.round(c).toString(),
                tempF: Math.round(c * 9/5 + 32).toString(),
                code: root._wmoToWwoCode(hCodes[j])
            });
        }
        root.forecastHourly = hourlyOut;
    }

    function formatCityName(cityName) {
        return cityName.trim().split(/\s+/).join('+');
    }

    Component.onCompleted: {
        if (!root.gpsActive) return;
        console.info("[WeatherService] Starting the GPS service.");
        positionSource.start();
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    root.forecastLoading = false;
                    return;
                }
                try {
                    const parsedData = JSON.parse(text);
                    root.refineData(parsedData);
                    root.forecastDaily = parsedData.daily || [];
                    root.forecastHourly = parsedData.hourly || [];
                } catch (e) {
                    console.error(`[WeatherService] ${e.message}`);
                }
                root.forecastLoading = false;
            }
        }
    }

    Process {
        id: openMeteoFetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) {
                    root.forecastLoading = false;
                    return;
                }
                try {
                    const parsed = JSON.parse(text);
                    root._refineOpenMeteo(parsed);
                } catch (e) {
                    console.error(`[WeatherService] Open-Meteo parse error: ${e.message}`);
                }
                root.forecastLoading = false;
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            // update the location if the given location is valid
            // if it fails getting the location, use the last valid location
            if (position.latitudeValid && position.longitudeValid) {
                root.location.lat = position.coordinate.latitude;
                root.location.long = position.coordinate.longitude;
                root.location.valid = true;
                // console.info(`📍 Location: ${position.coordinate.latitude}, ${position.coordinate.longitude}`);
                root.getData();
                // if can't get initialized with valid location deactivate the GPS
            } else {
                root.gpsActive = root.location.valid ? true : false;
                console.error("[WeatherService] Failed to get the GPS location.");
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop();
                root.location.valid = false;
                root.gpsActive = false;
                Quickshell.execDetached(["notify-send", Translation.tr("Weather Service"), Translation.tr("Cannot find a GPS service. Using the fallback method instead."), "-a", "Shell"]);
                console.error("[WeatherService] Could not aquire a valid backend plugin.");
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}
