import QtQuick
import Quickshell
import Quickshell.Io

// Watches for things that really broke: failed systemd units (user and
// system) and new core dumps. Each new one is announced once as a Guru
// strip; a click on it opens the details in a terminal. Read-only.
Item {
  id: watch

  property var island: null
  readonly property bool enabled_: island ? island.setting("guru", true) !== false : true

  property var initializedScopes: ({})
  property var knownUnits: null      // null until the first scan (no alarms for old failures)
  property double sinceMs: Date.now()
  property var seenDumps: ({})

  function quote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }

  function scanned(scope, text) {
    var units = String(text || "").split("\n").map(function(l) { return l.trim().split(/\s+/)[0] }).filter(function(u) { return u && u.indexOf(".") > 0 })
    var prev = knownUnits || {}
    var next = {}
    for (var k in prev) if (k.indexOf(scope + ":") !== 0) next[k] = true
    for (var i = 0; i < units.length; i++) {
      var key = scope + ":" + units[i]
      next[key] = true
      if (initializedScopes[scope] && !prev[key] && island)
        island.showGuru({ kind: "unit", scope: scope, name: units[i],
                          code: "#8000" + (scope === "user" ? "0004" : "0003") + "." + units[i].replace(/\.service$/, ""),
                          command: scope === "user" ? "journalctl --user -u " + quote(units[i]) + " -n 80 --no-pager; echo; systemctl --user status " + quote(units[i]) + " --no-pager"
                                                    : "journalctl -u " + quote(units[i]) + " -n 80 --no-pager; echo; systemctl status " + quote(units[i]) + " --no-pager" })
    }
    knownUnits = next
    var initialized = Object.assign({}, initializedScopes)
    initialized[scope] = true
    initializedScopes = initialized
  }

  Process {
    id: userUnits
    command: ["systemctl", "--user", "list-units", "--failed", "--plain", "--no-legend"]
    stdout: StdioCollector { onStreamFinished: watch.scanned("user", text) }
  }
  Process {
    id: sysUnits
    command: ["systemctl", "list-units", "--failed", "--plain", "--no-legend"]
    stdout: StdioCollector { onStreamFinished: watch.scanned("system", text) }
  }
  Process {
    id: dumps
    command: ["coredumpctl", "list", "--no-pager", "--json=short", "--since=@" + Math.floor(watch.sinceMs / 1000)]
    stdout: StdioCollector {
      onStreamFinished: {
        var list = []
        try { list = JSON.parse(text || "[]") } catch (e) { return }
        for (var i = 0; i < list.length; i++) {
          var d = list[i], key = String(d.pid) + "@" + String(d.time)
          if (watch.seenDumps[key]) continue
          var s = {}
          for (var k in watch.seenDumps) s[k] = true
          s[key] = true
          watch.seenDumps = s
          var exe = String(d.exe || "").split("/").pop() || "?"
          if (watch.island) watch.island.showGuru({ kind: "crash", name: exe, code: "#0000000" + (d.sig || 11) + "." + exe,
                                                     command: "coredumpctl info " + quote(String(d.pid)) + " --no-pager | head -120" })
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: watch.enabled_
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!userUnits.running) userUnits.running = true
      if (!sysUnits.running) sysUnits.running = true
      if (!dumps.running) dumps.running = true
    }
  }
}
