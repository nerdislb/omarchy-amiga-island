import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Ui

// Reuse Omarchy's control palette instead of an Apple disc.
Item {
  id: button
  property string glyph: ""
  property int glyphSize: 18
  property color color: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool available: true
  signal clicked()
  implicitWidth: Math.round(glyphSize * 2)
  implicitHeight: implicitWidth
  Ui.PanelActionButton {
    anchors.fill: parent
    iconText: button.glyph
    fontSize: button.glyphSize
    fontFamily: button.fontFamily
    foreground: button.color
    hoverColor: Commons.Color.accent
    enabled: button.available
    opacity: button.available ? 1 : 0.35
    bordered: true
    radius: Math.min(Style.cornerRadius, Style.space(2))
    onClicked: button.clicked()
  }
}
