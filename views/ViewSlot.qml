import QtQuick
import qs.Commons

// Keep each view at its natural size. Only crossfade; no glass blur or zoom.
Item {
  id: slot
  property bool active: false
  readonly property real dpr: parent && parent.dpr > 0 ? parent.dpr : 1
  x: parent ? Math.round((parent.width - width) / 2 * dpr) / dpr : 0
  y: parent ? Math.round((parent.height - height) / 2 * dpr) / dpr : 0
  opacity: active ? 1 : 0
  visible: opacity > 0.01
  enabled: active
  Behavior on opacity {
    NumberAnimation { duration: Style.duration(slot.active ? 110 : 60); easing.type: Easing.OutCubic }
  }
}
