import QtQuick
import qs.Commons
import qs.Commons as Commons

// Discrete status cells: no glow, soft edges or decorative glass gradients.
Item {
  id: edge
  property color tone: Commons.Color.accent
  property real level: 0.3
  property real progress: -1
  property bool pulse: false
  property real pulsePeriod: 1400
  property int sweepKey: 0
  property real breath: 1
  property real sweepPosition: -1
  readonly property int cells: Math.max(1, Math.min(24, Math.floor(width / Style.space(9))))
  height: 2
  SequentialAnimation on breath {
    running: edge.pulse && edge.visible && !Style.reduceMotion
    loops: Animation.Infinite
    NumberAnimation { to: 0.5; duration: edge.pulsePeriod / 2; easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: edge.pulsePeriod / 2; easing.type: Easing.InOutSine }
    onRunningChanged: if (!running) edge.breath = 1
  }
  Repeater {
    model: edge.cells
    Rectangle {
      required property int index
      readonly property real step: edge.width / edge.cells
      readonly property bool filled: edge.progress < 0 || index < Math.ceil(Math.max(0, Math.min(1, edge.progress)) * edge.cells)
      x: Math.round(index * step)
      width: Math.max(1, Math.round(step) - Style.space(2))
      height: edge.height
      color: edge.tone
      opacity: edge.sweepPosition >= 0 && index === Math.min(edge.cells - 1, Math.floor(edge.sweepPosition * edge.cells))
        ? 1 : (filled ? Math.max(0.2, edge.level) * edge.breath : 0.12)
    }
  }
  onSweepKeyChanged: if (!Style.reduceMotion) sweep.restart()
  SequentialAnimation {
    id: sweep
    NumberAnimation { target: edge; property: "sweepPosition"; from: 0; to: 1; duration: Style.duration(450) }
    PropertyAction { target: edge; property: "sweepPosition"; value: -1 }
  }
}
