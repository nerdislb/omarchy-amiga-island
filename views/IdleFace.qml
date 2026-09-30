import QtQuick
import qs.Commons

// What the resting island shows (the "idleFace" setting):
//   ticker - a glance that flips through the time, date, battery, next
//            meeting, today's festival and silenced state (default);
//   clock  - just the time;
//   none   - the plain framed tile.
Item {
  id: face

  property var island: null
  readonly property string mode: island.idleFace
  readonly property var item: island.idleItem

  Flip {
    anchors.fill: parent
    visible: face.mode === "ticker" || face.mode === "clock"
    text: face.item ? face.item.text : ""
    color: face.item && face.item.color ? face.item.color : Util.alpha(island.fg, 0.9)
    fontFamily: island.fontFamily
    pixelSize: island.f(12)
  }

}
