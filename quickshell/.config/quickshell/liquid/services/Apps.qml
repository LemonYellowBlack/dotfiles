pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

// What the launcher searches: installed apps (desktop entries) and shell actions, plus three
// prefix modes, = for a calculator, : for cliphist and vpn for Tailscale exit nodes.
Singleton {
    id: root

    property string query: ""
    readonly property string mode: query.startsWith("=") ? "calc" : (query.startsWith(":") ? "clip"
        : (Host.exitNode && query.toLowerCase().startsWith("vpn") ? "vpn" : "apps"))
    readonly property string body: mode === "apps" ? query.trim() : (mode === "vpn" ? query.slice(3).trim() : query.slice(1).trim())
    readonly property var items: build(query, clips, Net.countries).slice(0, 8)

    // A safe arithmetic parser: + - * / % ^ and parentheses. No eval.
    function calc(src) {
        const s = src.replace(/\s+/g, "").replace(/,/g, "");
        let i = 0;
        function pk() { return s[i]; }
        function num() { const m = /^\d*\.?\d+/.exec(s.slice(i)); if (!m) throw 0; i += m[0].length; return parseFloat(m[0]); }
        function atom() { if (pk() === "(") { i++; const v = expr(); if (pk() !== ")") throw 0; i++; return v; } if (pk() === "-") { i++; return -atom(); } return num(); }
        function pow() { const b = atom(); if (pk() === "^") { i++; return Math.pow(b, pow()); } return b; }
        function term() { let v = pow(); while ("*/%".includes(pk() || "#")) { const o = s[i++], r = pow(); v = o === "*" ? v * r : (o === "/" ? v / r : v % r); } return v; }
        function expr() { let v = term(); while (pk() === "+" || pk() === "-") { const o = s[i++], r = term(); v = o === "+" ? v + r : v - r; } return v; }
        const v = expr();
        if (i !== s.length || !isFinite(v)) throw 0;
        return Number(v.toPrecision(10));
    }

    // Subsequence match that favours word starts and runs; returns matched positions for highlighting.
    function fuzzy(q, text) {
        const t = text.toLowerCase(), pos = [];
        let score = 0, j = 0;
        for (let k = 0; k < q.length; k++) {
            const at = t.indexOf(q[k], j);
            if (at < 0) return null;
            score += (at === j && k > 0 ? 6 : 0) + (at === 0 || " -_.".includes(t[at - 1]) ? 4 : 0) - Math.min(at - j, 5);
            pos.push(at);
            j = at + 1;
        }
        return { score: score - pos[0] * 0.1, pos: pos };
    }

    function setQuery(v) { query = v; if (mode === "clip") loadClips(); if (mode === "vpn") Net.loadCountries(); }
    function done(text) { Shell.close(); query = ""; if (text) Shell.msg(Icons.check, text, Theme.success); }
    function sh(cmd) { Quickshell.execDetached(["sh", "-c", cmd]); }

    readonly property var actions: [
        { name: "Lock screen", desc: "loginctl lock-session · hyprlock", hint: "SUPER L", icon: Icons.lock, run: () => { done(); sh("loginctl lock-session"); } },
        { name: "Caffeine", desc: "keep the machine awake · caff", hint: "SUPER ⇧ F12", icon: Icons.coffee, run: () => { done(); Toggles.toggle("caff"); } },
        { name: "Auto-lock", desc: "idle and lid locking · lock-toggle", hint: "SUPER ⇧ F9", icon: Icons.unlock, run: () => { done(); Toggles.toggle("autolock"); } },
        { name: "Touchpad", desc: "touchpad-toggle", hint: "SUPER ⇧ F10", icon: Icons.pad, host: Host.touchpad, run: () => { done(); Toggles.toggle("touch"); } },
        { name: "dGPU", desc: Host.gpuName + " · gpu-toggle", hint: "SUPER ⇧ F11", icon: Icons.gpu, host: Host.gpu === "prime", run: () => { done(); Toggles.toggle("gpu"); } },
        { name: "Sunshine", desc: "let Moonlight stream this desktop", hint: "", icon: Icons.stream, host: Host.sunshine, run: () => { done(); Toggles.toggle("sunshine"); } },
        { name: "Night light", desc: "pause or resume gammastep", hint: "", icon: Icons.moon, run: () => { done(); Toggles.toggle("night"); } },
        { name: "Do not disturb", desc: "hold notification popups", hint: "", icon: Icons.bellOff, run: () => { done(); Toggles.toggle("dnd"); } },
        { name: "Screenshot region", desc: "hyprshot -m region", hint: "SUPER Print", icon: Icons.crop, run: () => { done(); sh("sleep 0.3; hyprshot -m region -o ~/Pictures/Screenshots"); } },
        { name: "Clipboard history", desc: "cliphist", hint: ":", icon: Icons.clip, run: () => setQuery(":") },
        { name: "Calculator", desc: "type an expression", hint: "=", icon: Icons.hash, run: () => setQuery("=") },
        { name: "Exit node…", desc: "Mullvad through Tailscale", hint: "vpn", icon: Icons.shield, host: Host.exitNode, run: () => setQuery("vpn ") },
        { name: "Workspace overview", desc: "every workspace, live", hint: "SUPER Tab", icon: Icons.grid, run: () => Shell.toggle("overview") },
        { name: "Keybinds", desc: "the cheat sheet", hint: "SUPER /", icon: Icons.keyboard, run: () => Shell.toggle("keys") },
        { name: "Power menu", desc: "suspend, log out, reboot, shut down", hint: "SUPER Esc", icon: Icons.power, run: () => Shell.toggle("power") },
        { name: "Reload the shell", desc: "qs -c liquid, from ~/.config/quickshell/liquid", hint: "", icon: Icons.reload, run: () => { done(); Quickshell.reload(true); } }
    ].filter(a => a.host !== false)

    property var clips: []
    Process {
        id: cliphist
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.clips = text.split("\n").filter(l => l).slice(0, 60) }
    }
    function loadClips() { if (!cliphist.running) cliphist.running = true; }

    function filter(list, q) {
        if (!q) return list;
        const lq = q.toLowerCase();
        return list.map(it => ({ it: it, m: fuzzy(lq, it.name) })).filter(x => x.m).sort((a, b) => b.m.score - a.m.score)
            .map(x => Object.assign({}, x.it, { pos: x.m.pos }));
    }

    function build(q, clipList, countries) {
        if (mode === "calc") {
            let r = null;
            try { r = body ? calc(body) : null; } catch (e) { r = null; }
            if (!body) return [{ name: "= 63.84 / 85.09", desc: "type an expression", hint: "", icon: Icons.hash, run: () => setQuery("= 63.84 / 85.09") }];
            return [{ name: r === null ? body : "= " + r, desc: r === null ? "not an expression yet" : body + " · ↵ copies the result", hint: r === null ? "" : "wl-copy", icon: Icons.hash,
                      run: () => { if (r !== null) { Quickshell.execDetached(["wl-copy", String(r)]); done("copied " + r); } } }];
        }
        if (mode === "clip") {
            return filter(clipList.map(l => {
                const tab = l.indexOf("\t"), text = tab >= 0 ? l.slice(tab + 1) : l;
                return { name: text.slice(0, 120), desc: "cliphist", hint: "", icon: text.startsWith("[[") ? Icons.image : Icons.clip,
                         run: () => { Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", l]); done("copied to the clipboard"); } };
            }), body);
        }
        if (mode === "vpn") {
            const nodes = [{ name: "Chicago", desc: "nearest · best server in the city", hint: "", icon: Icons.shield, run: () => { Net.useExit("chicago"); done("exit node → Chicago"); } }]
                .concat(countries.map(c => ({ name: c.name, desc: c.cities + " cities · " + c.servers + " servers · best by priority, then ping", hint: "", icon: Icons.globe,
                                             run: () => { Net.useExit(c.name + " any"); done("exit node → " + c.name); } })));
            return filter(nodes, body).concat([{ name: "Turn the exit node off", desc: "tailscale set --exit-node=", hint: Net.exitNode ? "now " + Net.exitNode : "",
                                                 icon: Icons.power, run: () => { Net.useExit("off"); done("exit node off"); } }]);
        }
        const apps = DesktopEntries.applications.values.filter(e => !e.noDisplay).map(e => ({
            name: e.name, desc: e.genericName || e.comment || "", hint: "", iconName: e.icon, run: () => { e.execute(); done(); } }));
        if (!body) return actions.slice(0, 4).concat(apps.slice().sort((a, b) => a.name.localeCompare(b.name)));
        return filter(apps.concat(actions), body);
    }
}
