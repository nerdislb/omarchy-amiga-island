import QtQuick
import qs.Commons

// A dot that breathes, for recording and privacy indicators.
Rectangle {
  id: dot

  property real size: 10
  property bool pulsing: true

  width: size
  height: size
  radius: size / 2

  SequentialAnimation on opacity {
    running: dot.pulsing && dot.visible && !Style.reduceMotion
    loops: Animation.Infinite
    NumberAnimation { to: 0.35; duration: Style.duration(800); easing.type: Easing.InOutSine }
    NumberAnimation { to: 1; duration: Style.duration(800); easing.type: Easing.InOutSine }
  }
}
