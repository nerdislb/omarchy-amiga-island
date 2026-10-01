import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "views"
import "IslandModel.js" as Model
import "bridge" as Bridge

// Notifications in the bar: one column right under the island, rolling out
// of the bar's lower edge. The open card on top; the next ones wait as title
// rows under it and move up like a paternoster; a critical one (a requester)
// slides in on top and pauses the open card. Coming and going is mechanical:
// the head slides out of the edge, then the body unrolls; back the same way.
// Reduced motion: the same moments, faded instead of moved.
//
// Only the cards take input; the strip never takes keyboard focus.
Item {
  id: column

  property var island: null
  property var service: null

  readonly property bool serving: !!island && island.columnNotes
  readonly property bool bubble: !!island && String(island.setting("noteStyle", "workbench")) === "bubble"
  readonly property bool topaz: !!island && island.setting("noteTopaz", true) !== false
  readonly property real cardW: island ? island.s(480) : 480
  readonly property bool reduced: Style.reduceMotion

  // What belongs on screen, top to bottom: the open card, two waiting rows,
  // "+N" for the rest.
  readonly property var wanted: {
    if (!serving || !service || !service.current) return []
    var out = [{ key: service.current.key, kind: "note" }]
    var w = service.waiting
    for (var i = 0; i < w.length && i < Model.maxWaitingRows; i++) out.push({ key: w[i].key, kind: "note" })
    if (w.length > Model.maxWaitingRows) out.push({ key: -1, kind: "more" })
    return out
  }
  readonly property int hiddenCount: service ? Math.max(0, service.waiting.length - Model.maxWaitingRows) : 0

  // Entries by key, kept while their row is still rolling away.
  property var cache: ({})
  function entryOf(key) {
    if (service) {
      var b = service.banners
      for (var i = 0; i < b.length; i++) if (b[i].key === key) return b[i]
    }
    return cache[key] || null
  }

  ListModel { id: rows }   // { key, kind, leaving }

  onWantedChanged: Qt.callLater(sync)

  function indexOfKey(key) {
    for (var i = 0; i < rows.count; i++) if (rows.get(i).key === key) return i
    return -1
  }
  // Where the n-th wanted row goes: before the n-th row that is not leaving.
  function slotIndex(n) {
    var seen = 0
    for (var i = 0; i < rows.count; i++) {
      if (rows.get(i).leaving) continue
      if (seen === n) return i
      seen++
    }
    return rows.count
  }

  function sync() {
    var want = wanted
    var keys = want.map(function(w) { return w.key })
    var nextCache = {}
    for (var c = 0; c < want.length; c++) {
      var e = entryOf(want[c].key)
      if (e) nextCache[want[c].key] = e
    }
    for (var i = 0; i < rows.count; i++) {
      var r = rows.get(i)
      if (keys.indexOf(r.key) === -1) {
        if (cache[r.key]) nextCache[r.key] = cache[r.key]
        if (!r.leaving) rows.setProperty(i, "leaving", true)
      }
    }
    cache = nextCache
    for (var j = 0; j < want.length; j++) {
      var at = indexOfKey(want[j].key)
      var target = slotIndex(j)
      if (at === -1) {
        rows.insert(Math.min(target, rows.count), { key: want[j].key, kind: want[j].kind, leaving: false })
        continue
      }
      if (rows.get(at).leaving) rows.setProperty(at, "leaving", false)
      if (at !== target && target < rows.count) rows.move(at, target, 1)
    }
    if (rows.count > 0) latchAnchor()
  }

  // A row has rolled away completely.
  function finishLeave(key) {
    var i = indexOfKey(key)
    if (i !== -1 && rows.get(i).leaving) rows.remove(i)
  }

  // ------------------------------------------------------------ placement
  // The column hangs from the island in the bar on the focused monitor.
  readonly property var targetScreen: {
    var screens = Quickshell.screens
    var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    for (var i = 0; i < screens.length; i++) if (screens[i].name === name) return screens[i]
    return island ? island.targetScreen : (screens.length ? screens[0] : null)
  }
  property real anchorX: -1
  property var latchedScreen: null
  // Screen and x are taken together when the first card comes, so the
  // column stays put (on its monitor, under its island) while the queue
  // lasts, even if focus moves or the segment beside the clock grows.
  function latchAnchor() {
    if (anchorX >= 0 && latchedScreen) return
    latchedScreen = targetScreen
    var name = latchedScreen ? latchedScreen.name : ""
    var list = Bridge.IslandBus.list
    var pick = null
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].screenName === name) pick = list[i]
    if (!pick && list.length) pick = list[0]
    anchorX = pick && typeof pick.anchorX === "function" ? pick.anchorX() : (latchedScreen ? latchedScreen.width / 2 : 960)
  }
  Connections {
    target: rows
    function onCountChanged() { if (rows.count === 0) { column.anchorX = -1; column.latchedScreen = null } }
  }

  PanelWindow {
    id: win

    screen: column.latchedScreen || column.targetScreen
    visible: column.serving && rows.count > 0
    anchors { top: true; left: true; right: true }
    // Tall enough for a requester, two rows and "+N"; only the cards take input.
    implicitHeight: island ? island.s(560) : 560
    color: "transparent"

    WlrLayershell.namespace: "amiga-island-notes"
    WlrLayershell.layer: island && island.setting("layer", "top") === "overlay" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Below the bar (its exclusive zone), without reserving space of its own.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0

    mask: Region { item: stack }

    Column {
      id: stack
      readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1
      x: Math.round(Math.max(0, Math.min(win.width - width, column.anchorX - width / 2)) * dpr) / dpr
      y: 0
      width: column.cardW
      spacing: 0

      HoverHandler {
        onHoveredChanged: if (column.service) column.service.columnHovered = hovered
      }

      Repeater {
        model: rows

        delegate: Item {
          id: slot

          required property int index
          required property int key
          required property string kind
          required property bool leaving

          readonly property var entry: kind === "note" ? column.entryOf(key) : null
          readonly property bool open: !leaving && kind === "note" && !!column.service
            && !!column.service.current && column.service.current.key === key
          // presence: 0 = still inside the bar (or under the row above), 1 = out
          property real presence: 0
          property real openness: 0
          // Plain values (set once below): switching the style or reduced
          // motion later must not collapse a card that is already out.
          property real spread: 1
          property real fade: 1
          property bool arrived: false

          width: column.cardW
          height: Math.max(0, note.visibleH - (1 - presence) * note.rowH)
          clip: true

          NoteCard {
            id: note
            y: -(1 - slot.presence) * rowH
            width: parent.width
            island: column.island
            entry: slot.entry
            kind: slot.kind
            moreCount: column.hiddenCount
            bubble: column.bubble
            topaz: column.topaz
            first: slot.index === 0
            active: slot.open
            stateLabel: slot.open ? "now" : (slot.entry && slot.entry.shown ? "paused" : "next")
            openness: slot.openness
            spread: slot.spread
            tone: column.island.noteTone(slot.entry)
            opacity: slot.fade

            onOpened: column.island.notificationOpen(slot.key)
            onDismissed: column.island.notificationDismiss(slot.key)
            onLater: column.service.later(slot.key)
            onAction: function(id) { column.island.notificationAction(slot.key, id) }
            onPromoted: {
              if (slot.kind === "more") {
                var w = column.service.waiting
                if (w.length > Model.maxWaitingRows) column.service.promote(w[Model.maxWaitingRows].key)
              } else column.service.promote(slot.key)
            }
          }

          // Mechanical: constant speed, hard stop (Amiga screens), Omarchy's
          // short durations. Reduced motion: final geometry, faded.
          // The target is set here, not bound: a binding to `open` may not
          // have updated yet when onOpenChanged starts the animation.
          function run(anim) {
            arrive.stop(); unroll.stop(); depart.stop()
            if (anim === unroll) {
              unroll.to = open ? 1 : 0
              unroll.duration = open ? 220 : 180
            }
            anim.start()
          }
          SequentialAnimation {
            id: arrive
            NumberAnimation { target: slot; property: "presence"; to: 1; duration: column.bubble ? 120 : 160; easing.type: Easing.Linear }
            NumberAnimation { target: slot; property: "spread"; to: 1; duration: column.bubble ? 130 : 0; easing.type: Easing.Linear }
            ScriptAction { script: { slot.arrived = true; slot.run(unroll) } }
          }
          NumberAnimation { id: unroll; target: slot; property: "openness"; easing.type: Easing.Linear }
          SequentialAnimation {
            id: depart
            NumberAnimation { target: slot; property: "openness"; to: 0; duration: 180; easing.type: Easing.Linear }
            NumberAnimation { target: slot; property: "presence"; to: 0; duration: 160; easing.type: Easing.Linear }
            ScriptAction { script: column.finishLeave(slot.key) }
          }
          // Reduced motion: fade in or out at the final geometry.
          NumberAnimation { id: fadeIn; target: slot; property: "fade"; to: 1; duration: 150 }
          SequentialAnimation {
            id: fadeOut
            NumberAnimation { target: slot; property: "fade"; to: 0; duration: 150 }
            ScriptAction { script: column.finishLeave(slot.key) }
          }

          Component.onCompleted: {
            if (column.reduced) {
              presence = 1; spread = 1; arrived = true; fade = 0
              openness = open ? 1 : 0
              fadeIn.start()
            } else {
              spread = column.bubble ? 0 : 1
              run(arrive)
            }
          }
          onOpenChanged: {
            if (column.reduced) { openness = open ? 1 : 0; return }
            if (arrived && !leaving) run(unroll)
          }
          onLeavingChanged: {
            if (column.reduced) {
              if (leaving) fadeOut.start()
              else { fadeOut.stop(); fade = 1 }
              return
            }
            if (leaving) run(depart)
            else {
              // Back before it was gone: finish whatever its arrival left.
              presence = 1; spread = 1; arrived = true
              run(unroll)
            }
          }
        }
      }
    }
  }
}
