pragma Singleton
import QtQuick
import Quickshell
import qs

// Current conditions and the next hours from open-meteo (no key needed), every half hour.
Singleton {
    id: root

    property var now: null      // { temp, feels, code, wind, dir, hi, lo }
    property var hours: []      // [{ hour, temp }]
    property bool ok: false

    function describe(c) {
        if (c === 0) return "clear";
        if (c <= 2) return "partly cloudy";
        if (c === 3) return "overcast";
        if (c <= 48) return "fog";
        if (c <= 57) return "drizzle";
        if (c <= 67) return "rain";
        if (c <= 77) return "snow";
        if (c <= 82) return "showers";
        if (c <= 86) return "snow showers";
        return "thunderstorm";
    }
    function compass(deg) { return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(deg / 45) % 8]; }

    function fetch() {
        const url = "https://api.open-meteo.com/v1/forecast?latitude=" + Host.lat + "&longitude=" + Host.lon
            + "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m"
            + "&hourly=temperature_2m&daily=temperature_2m_max,temperature_2m_min"
            + "&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&forecast_days=2";
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            if (x.status !== 200) { root.ok = false; return; }
            const d = JSON.parse(x.responseText), c = d.current;
            root.now = { temp: Math.round(c.temperature_2m), feels: Math.round(c.apparent_temperature), code: c.weather_code,
                         wind: Math.round(c.wind_speed_10m), dir: compass(c.wind_direction_10m),
                         hi: Math.round(d.daily.temperature_2m_max[0]), lo: Math.round(d.daily.temperature_2m_min[0]) };
            const start = d.hourly.time.findIndex(t => new Date(t) > new Date(Date.now() - 3600000));
            root.hours = d.hourly.time.slice(start, start + 8).map((t, i) => ({ hour: new Date(t).getHours(), temp: d.hourly.temperature_2m[start + i] }));
            root.ok = true;
        };
        x.open("GET", url);
        x.send();
    }
    Timer { interval: 1800000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.fetch() }
}
