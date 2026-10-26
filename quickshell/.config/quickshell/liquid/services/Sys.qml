pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// CPU load per thread, package temperature, fans, memory and zram from /proc and hwmon; the NVIDIA
// card from nvidia-smi, but only while its module is loaded, so polling never wakes a PRIME GPU.
Singleton {
    id: root

    property real cpu: 0                // 0..1, whole package
    property var threads: []            // 0..1 per logical CPU
    property var loadHist: []           // one minute, 1 s apart
    property real temp: 0               // °C
    property var tempHist: []           // half an hour, 10 s apart
    property var fanRpm: []             // in Host.fans order
    property real memUsed: 0            // GiB
    property real memTotal: 0
    property string zram: ""
    property real uptime: 0             // seconds
    property real load1: 0
    property var hwmon: ({})            // hwmon name -> sysfs dir

    property bool gpuLoaded: Host.gpu === "always"
    property var gpu: null              // { util, memUsed, memTotal, power, limit, temp, clock, pstate }

    function upText() {
        const m = Math.floor(uptime / 60);
        return Math.floor(m / 1440) + "d " + Math.floor((m % 1440) / 60) + "h";
    }

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do printf '%s %s\\n' \"$(cat $d/name)\" \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                for (const l of text.trim().split("\n")) {
                    const i = l.indexOf(" ");
                    if (i > 0 && !m[l.slice(0, i)]) m[l.slice(0, i)] = l.slice(i + 1);
                }
                root.hwmon = m;
            }
        }
    }

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: upFile; path: "/proc/uptime"; blockLoading: true }
    FileView { id: loadavg; path: "/proc/loadavg"; blockLoading: true }
    FileView { id: zramFile; path: "/sys/block/zram0/mm_stat"; blockLoading: true; printErrors: false }
    FileView {
        id: tempFile
        path: root.hwmon[Host.tempSensor] ? root.hwmon[Host.tempSensor] + "/" + Host.tempInput : ""
        blockLoading: true
    }
    Variants {
        id: fanFiles
        model: Host.fans
        FileView {
            required property var modelData
            path: root.hwmon[modelData.sensor] ? root.hwmon[modelData.sensor] + "/" + modelData.input : ""
            blockLoading: true
            printErrors: false
        }
    }
    FileView { id: nvmod; path: "/sys/module/nvidia/initstate"; blockLoading: true; printErrors: false }

    property var prev: []
    property int tick: 0
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sample() }

    function sample() {
        tick++;
        stat.reload();
        const rows = stat.text().split("\n").filter(l => l.startsWith("cpu"));
        const cur = rows.map(l => {
            const f = l.trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + (f[4] || 0);
            return { idle: idle, total: f.reduce((a, b) => a + b, 0) };
        });
        if (prev.length === cur.length) {
            const busy = (i) => { const dt = cur[i].total - prev[i].total; return dt > 0 ? 1 - (cur[i].idle - prev[i].idle) / dt : 0; };
            cpu = busy(0);
            const t = [];
            for (let i = 1; i < cur.length; i++) t.push(busy(i));
            threads = t;
            loadHist = loadHist.concat([cpu * 100]).slice(-60);
        }
        prev = cur;

        if (tempFile.path !== "") {
            tempFile.reload();
            const v = parseInt(tempFile.text()) / 1000;
            if (v > 0) temp = v;
            if (tick % 10 === 1) tempHist = tempHist.concat([temp]).slice(-180);
        }

        if (tick % 2 === 1) {
            meminfo.reload();
            const kv = {};
            for (const l of meminfo.text().split("\n")) { const m = l.match(/^(\w+):\s+(\d+)/); if (m) kv[m[1]] = Number(m[2]); }
            memTotal = (kv.MemTotal || 0) / 1048576;
            memUsed = ((kv.MemTotal || 0) - (kv.MemAvailable || 0)) / 1048576;
            upFile.reload();
            uptime = parseFloat(upFile.text());
            loadavg.reload();
            load1 = parseFloat(loadavg.text());
            const rpm = [];
            for (const f of fanFiles.instances) { f.reload(); rpm.push(parseInt(f.text()) || 0); }
            fanRpm = rpm;
            zramFile.reload();
            const z = zramFile.text().trim().split(/\s+/).map(Number);
            zram = z.length > 2 ? Math.round(z[0] / 1048576) + " MiB in " + Math.round(z[2] / 1048576) + " MiB" : "";
        }

        if (Host.gpu === "prime" && tick % 3 === 1) {
            nvmod.reload();
            gpuLoaded = nvmod.text().trim() === "live";
            if (!gpuLoaded) gpu = null;
        }
        if (gpuLoaded && tick % 2 === 0 && !smi.running) smi.running = true;
    }

    Process {
        id: smi
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,power.draw,power.limit,temperature.gpu,clocks.gr,pstate", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0].split(",").map(x => x.trim());
                if (f.length < 8) return;
                root.gpu = { util: Number(f[0]), memUsed: Number(f[1]) / 1024, memTotal: Number(f[2]) / 1024, power: Number(f[3]),
                             limit: Number(f[4]), temp: Number(f[5]), clock: Number(f[6]), pstate: f[7] };
            }
        }
    }
}
