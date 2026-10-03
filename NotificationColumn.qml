import QtQuick
import QtQuick.Effects
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
// Fog look (Amiga Bar option `fog`, a test): the cards are blobs of the
// bar's colour in one gooey fog layer. A drop falls out of the bar, grows
// into the card, then the text fades in; going back, the text fades, the
// blob shrinks to a drop and is pulled back into the bar, leaving a faint
// fog for a moment. Waiting rows hang under it as smaller blobs.
//
// Only the cards take input; the strip never takes keyboard focus.
Item {
  id: column

  property var island: null
  property var service: null

  readonly property bool serving: !!island && island.columnNotes
  // the fog look (Amiga Bar option), or a Lavur theme's bloom (material card.bloom):
  // both use the gooey fog layer; the bloom adds scallops and a tide line
  readonly property bool fogOpt: !!island && !!island.amigaOptions && island.amigaOptions.fog === "on"
  // theme material (edge "theme"): replaces workbench/bubble with the theme's card
  readonly property var material: !fogOpt && !!island ? island.material : null
  readonly property bool bloom: !!material && !!material.card && material.card.bloom === true
  readonly property bool fog: fogOpt || bloom
  readonly property var tide: bloom ? material.card.tide || null : null
  readonly property color tideColor: tide ? (function() { var c = Qt.color(tide.color || "#000000"); return Qt.rgba(c.r, c.g, c.b, tide.alpha === undefined ? 0.5 : tide.alpha) })() : "transparent"
  readonly property real tideW: tide ? tide.width || 2 : 0
  // scallops along a blob's sides and foot (w × h), grown with `spread`
  function scallopAt(i, n, w, h, spread) {
    var per = 2 * h + w
    var u = ((i + 0.5 + 0.3 * Math.sin(i * 12.9898)) / n) * per
    var x, y
    if (u < h) { x = 0; y = u }
    else if ((u -= h) < w) { x = u; y = h }
    else { u -= w; x = w; y = Math.max(0, h - u) }
    var k = Math.abs(Math.sin(i * 78.233) * 43758.5453) % 1
    return { x: x, y: y, r: (3 + 8 * k * k) * Math.max(0, Math.min(1, spread)) }
  }
  readonly property bool bubble: !fog && !material && !!island && String(island.setting("noteStyle", "workbench")) === "bubble"
  readonly property bool topaz: !!island && island.setting("noteTopaz", true) !== false
  readonly property real cardW: island ? island.s(480) : 480
  readonly property bool reduced: Style.reduceMotion

  // Fog geometry: the layer reaches `fogMargin` past the cards on every
  // side (and up into the bar), so the blur never runs into its edge.
  readonly property color fogColor: island ? island.fogColor : Color.bar.background
  readonly property real fogMargin: 32
  readonly property real fogGap: island ? island.s(8) : 8
  readonly property real dropW: island ? island.s(52) : 52
  readonly property real dropH: island ? island.s(28) : 28

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

    // Fog look: residual fog (blurred, faint) under the gooey blobs.
    Item {
      id: fogArea
      visible: column.fog
      x: stack.x - column.fogMargin
      y: -column.fogMargin
      width: column.cardW + column.fogMargin * 2
      height: win.height + column.fogMargin

      Item {
        id: ghostLayer
        anchors.fill: parent
        // enabled only while shown: a MultiEffect created hidden never draws
        layer.enabled: ghostLayer.visible
        layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48; autoPaddingEnabled: false }
      }
      // bloom: the tide line – the same shapes a little larger, in the ink, under the fill
      FogLayer {
        visible: column.bloom
        anchors.fill: parent
        color: column.tideColor
        blurMax: 24
        threshold: 0.4
        softness: 0.5
        Item { id: rimShapes; anchors.fill: parent }
      }
      FogLayer {
        anchors.fill: parent
        color: column.fogColor
        blurMax: 24
        threshold: 0.4
        softness: 0.5
        Item { id: fogShapes; anchors.fill: parent }
      }
    }

    Column {
      id: stack
      readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1
      x: Math.round(Math.max(0, Math.min(win.width - width, column.anchorX - width / 2)) * dpr) / dpr
      y: column.fog ? 2 : 0
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
          readonly property bool queued: !!column.service && column.service.banners.some(function(b) { return b.key === slot.key })
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
          // Fog look: the text, faded in once the blob has grown.
          property real ink: 1

          // Fog: a drop (dropW × dropH) grows into the row, then the body.
          readonly property real fogGap: index > 0 ? column.fogGap : 0
          readonly property real blobW: column.dropW + (column.cardW - column.dropW) * spread
          readonly property real blobH: presence * column.dropH * (1 - spread) + note.rowH * spread
            + note.bodyH * Math.max(0, Math.min(1, openness))

          width: column.cardW
          height: column.fog ? fogGap + blobH
            : Math.max(0, note.visibleH - (1 - presence) * note.rowH)
          // The card is clipped by `cardClip` below (it slides out of the bar's
          // edge); the material's shadow and halo sit outside that clip.

          // This row's blob, in the column's fog layer (moved there below);
          // the first one also reaches up into the bar, where the fog layer
          // melts it into the bar's edge. Shapes only change size: the fog
          // layer does not repaint for a shape that is merely shown/hidden.
          Rectangle {
            id: blob
            // reduced motion fades the row: the fog shapes fade with it
            opacity: slot.fade
            x: column.fogMargin + (column.cardW - slot.blobW) / 2
            y: column.fogMargin + stack.y + slot.y + slot.fogGap
            width: slot.blobW
            height: slot.blobH
            radius: column.island.s(10)
            color: "white"
          }
          Rectangle {
            id: neck
            opacity: slot.fade
            x: blob.x - column.island.s(14)
            y: 0
            width: slot.index === 0 && slot.presence > 0 ? slot.blobW + column.island.s(28) : 0
            height: column.fogMargin + stack.y + 1
            color: "white"
          }
          // Bloom (Lavur): scallops on the blob, and blob, neck and scallops a
          // little larger in the tide-line layer (moved into the layers below).
          Item {
            id: scallops
            opacity: slot.fade
            x: blob.x; y: blob.y; width: blob.width; height: blob.height
            Repeater {
              model: column.bloom ? 26 : 0
              Rectangle {
                required property int index
                readonly property var p: column.scallopAt(index, 26, scallops.width, scallops.height, slot.spread)
                x: p.x - p.r; y: p.y - p.r; width: 2 * p.r; height: 2 * p.r; radius: p.r
                color: "white"
              }
            }
          }
          Item {
            id: rimScallops
            opacity: slot.fade
            x: blob.x; y: blob.y; width: blob.width; height: blob.height
            Repeater {
              model: column.bloom ? 26 : 0
              Rectangle {
                required property int index
                readonly property var p: column.scallopAt(index, 26, rimScallops.width, rimScallops.height, slot.spread)
                readonly property real r: p.r > 0 ? p.r + column.tideW : 0
                x: p.x - r; y: p.y - r; width: 2 * r; height: 2 * r; radius: r
                color: "white"
              }
            }
          }
          Rectangle {
            id: rimBlob
            opacity: slot.fade
            x: blob.x - column.tideW; y: blob.y
            width: column.bloom && blob.width > 0 ? blob.width + 2 * column.tideW : 0
            height: blob.height + column.tideW
            radius: blob.radius + column.tideW
            color: "white"
          }
          Rectangle {
            id: rimNeck
            opacity: slot.fade
            x: neck.x - column.tideW; y: neck.y
            width: column.bloom && neck.width > 0 ? neck.width + 2 * column.tideW : 0
            height: neck.height
            color: "white"
          }
          // Residual fog where the card was, fading after it left.
          Rectangle {
            id: ghost
            visible: column.fog && opacity > 0
            opacity: 0
            radius: column.island.s(12)
            color: column.fogColor
          }

          // material (theme edge): the hard ink shadow (Papier) or the halo
          // (Tusche, Lavur) of the visible part of the card
          readonly property var matShade: column.material && column.material.card
            ? (column.material.card.shadow || null) : null
          readonly property var matHalo: column.material && column.material.card
            ? (column.material.card.halo || column.material.card.glow || null) : null
          Rectangle {
            visible: !!slot.matShade && slot.height > 0
            x: slot.matShade ? slot.matShade.dx || 0 : 0
            y: slot.matShade ? slot.matShade.dy || 0 : 0
            width: slot.width
            height: slot.height
            opacity: slot.fade
            color: slot.matShade ? note.rgba(slot.matShade.color, slot.matShade.alpha) : "transparent"
          }
          Item {
            id: haloBox
            readonly property real spread: 40
            visible: !!slot.matHalo && slot.height > 0
            x: -spread
            y: -spread + (column.material && column.material.card && column.material.card.halo ? 6 : 0)
            width: slot.width + 2 * spread
            height: slot.height + 2 * spread
            opacity: slot.fade
            layer.enabled: visible
            layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: slot.matHalo ? Math.min(64, slot.matHalo.blur || 32) : 32; autoPaddingEnabled: false }
            Rectangle {
              x: haloBox.spread; y: haloBox.spread
              width: parent.width - 2 * haloBox.spread; height: parent.height - 2 * haloBox.spread
              color: slot.matHalo ? note.rgba(slot.matHalo.color, slot.matHalo.alpha) : "transparent"
            }
          }

          Item {
            id: cardClip
            width: slot.width
            height: slot.height
            clip: true

            NoteCard {
              id: note
              y: column.fog ? slot.fogGap : -(1 - slot.presence) * rowH
              width: parent.width
              island: column.island
              entry: slot.entry
              kind: slot.kind
              moreCount: column.hiddenCount
              bubble: column.bubble
              fog: column.fog
              material: column.material
              textIn: slot.ink
              topaz: column.topaz && !column.material
              first: slot.index === 0
              active: slot.open
              // A row that is going (dismissed, answered) keeps no label rather
              // than flipping to "paused" while it rolls away.
              stateLabel: slot.open ? "now" : !slot.queued ? "" : (slot.entry && slot.entry.shown ? "paused" : "next")
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
          }

          // Mechanical: constant speed, hard stop (Amiga screens), Omarchy's
          // short durations. Reduced motion: final geometry, faded.
          // The target is set here, not bound: a binding to `open` may not
          // have updated yet when onOpenChanged starts the animation.
          function run(anim) {
            arrive.stop(); unroll.stop(); depart.stop(); arriveFog.stop(); departFog.stop()
            if (anim === unroll) {
              unroll.to = open ? 1 : 0
              unroll.duration = open ? 220 : 180
              // interrupted the fog arrival before its text faded in
              if (column.fog) ink = 1
            }
            anim.start()
          }
          // Fog: a drop, then it swells into the row (eased, liquid rather
          // than mechanical), the body follows, the text fades in last.
          SequentialAnimation {
            id: arriveFog
            NumberAnimation { target: slot; property: "presence"; to: 1; duration: 190; easing.type: Easing.OutQuad }
            NumberAnimation { target: slot; property: "spread"; to: 1; duration: 280; easing.type: Easing.OutCubic }
            ScriptAction { script: { slot.arrived = true; if (slot.open) { unroll.to = 1; unroll.duration = 200; unroll.start() } } }
            PauseAnimation { duration: slot.open ? 180 : 0 }
            NumberAnimation { target: slot; property: "ink"; to: 1; duration: 140; easing.type: Easing.Linear }
          }
          // Back: text first, then the blob shrinks to a drop (a faint fog
          // stays where it was) and the drop is pulled into the bar.
          SequentialAnimation {
            id: departFog
            NumberAnimation { target: slot; property: "ink"; to: 0; duration: 110; easing.type: Easing.Linear }
            ScriptAction {
              script: {
                ghost.x = blob.x; ghost.y = blob.y; ghost.width = blob.width; ghost.height = blob.height
                ghost.opacity = 0.16
              }
            }
            ParallelAnimation {
              SequentialAnimation {
                ParallelAnimation {
                  NumberAnimation { target: slot; property: "openness"; to: 0; duration: 220; easing.type: Easing.InOutCubic }
                  NumberAnimation { target: slot; property: "spread"; to: 0; duration: 220; easing.type: Easing.InOutCubic }
                }
                NumberAnimation { target: slot; property: "presence"; to: 0; duration: 170; easing.type: Easing.InQuad }
              }
              NumberAnimation { target: ghost; property: "opacity"; to: 0; duration: 700; easing.type: Easing.InQuad }
            }
            ScriptAction { script: column.finishLeave(slot.key) }
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
            // The fog shapes live in the column's fog layers (they leave
            // with this row: it still owns them).
            blob.parent = fogShapes; neck.parent = fogShapes; ghost.parent = ghostLayer
            scallops.parent = fogShapes; rimScallops.parent = rimShapes; rimBlob.parent = rimShapes; rimNeck.parent = rimShapes
            if (column.reduced) {
              presence = 1; spread = 1; arrived = true; fade = 0; ink = 1
              openness = open ? 1 : 0
              fadeIn.start()
            } else if (column.fog) {
              spread = 0; ink = 0
              run(arriveFog)
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
            if (leaving) run(column.fog ? departFog : depart)
            else {
              // Back before it was gone: finish whatever its arrival left.
              presence = 1; spread = 1; arrived = true; ink = 1; ghost.opacity = 0
              run(unroll)
            }
          }
        }
      }
    }
  }
}
