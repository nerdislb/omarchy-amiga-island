import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Guru Meditation: black strip with a blinking red frame under the bar,
// "Software Failure. Click for details." and the unit or program that
// failed. Blinks three times (not with Reduced Motion), hides after a few
// seconds; a click opens the details in a terminal. Red only for real
// failures.
PanelWindow {
  id: win

  property var island: null
  readonly property var guru: island ? island.guru : null
  readonly property bool topaz: island ? island.amigaTopaz : false

  screen: island ? island.targetScreen : null
  visible: guru !== null
  color: "transparent"
  anchors { top: true; left: true; right: true }
  implicitHeight: Style.space(62)
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  WlrLayershell.namespace: "amiga-island-guru"
  WlrLayershell.layer: WlrLayer.Overlay

  property int blinks: 0
  onGuruChanged: { blinks = 0; if (guru) blink.restart() }
  Timer {
    id: blink
    interval: 450
    repeat: true
    onTriggered: { win.blinks++; if (win.blinks >= 6) stop() }
  }
  readonly property bool frameOn: Style.reduceMotion || blinks >= 6 || blinks % 2 === 0

  FontLoader { id: topazFont; source: Qt.resolvedUrl("assets/fonts/nerdworkbench/NerdWorkbenchUI-Regular.ttf") }

  Rectangle {
    id: strip
    anchors.fill: parent
    anchors.leftMargin: Style.gapsOut; anchors.rightMargin: Style.gapsOut; anchors.topMargin: Style.gapsOut
    color: "#000000"
    border.width: Math.max(2, Style.space(3))
    border.color: win.frameOn ? "#ff2222" : "#000000"

    Column {
      anchors.centerIn: parent
      spacing: Style.space(4)
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Software Failure.    Click for details."
        color: "#ff2222"
        font.family: win.topaz && topazFont.status === FontLoader.Ready ? topazFont.name : Style.font.family
        font.pixelSize: win.topaz ? 16 : Style.font.title
        font.bold: !win.topaz
        renderType: Text.NativeRendering
        transform: Scale { origin.x: 0; xScale: 1 }
        width: win.topaz ? implicitWidth : implicitWidth
        leftPadding: 0
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: win.guru ? "Guru Meditation " + win.guru.code + (win.guru.kind === "crash" ? "  ·  crash" : "  ·  service failed") : ""
        color: "#ff2222"
        font.family: win.topaz && topazFont.status === FontLoader.Ready ? topazFont.name : Style.font.family
        font.pixelSize: win.topaz ? 16 : Style.font.body
        renderType: Text.NativeRendering
        transform: Scale { origin.x: 0; xScale: 1 }
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        var g = win.guru
        if (g && g.command) Quickshell.execDetached(["xdg-terminal-exec", "--", "bash", "-lc", g.command + "; echo; read -n1 -p 'Press any key to close'"])
        if (win.island) win.island.guru = null
      }
    }
  }
}
