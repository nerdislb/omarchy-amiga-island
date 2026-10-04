import QtQuick
import qs.Commons

// "Braucht dich": an agent is waiting for input or approval (herdr
// "blocked"). Styled like a requester window — title bar with drag
// stripes, the question, and buttons left (positive) to right (negative).
// Approving happens in the agent itself ("Open"); the bar never answers
// for you.
Item {
  id: view

  property var island: null
  readonly property var agent: island ? island.attentionAgent : null
  readonly property var others: island ? island.desktop.blocked.slice(1) : []

  function since(a) {
    if (!a || !island) return ""
    var seen = island.desktop.seen[a.pane]
    if (!seen) return ""
    var m = Math.max(0, Math.round((Date.now() - seen.since) / 60000))
    return m < 1 ? "just now" : "for " + m + " min"
  }

  // title bar
  Rectangle {
    id: titleBar
    width: parent.width
    height: island.s(24)
    color: island.orangeColor
    Rectangle {
      x: island.s(8); anchors.verticalCenter: parent.verticalCenter
      width: island.s(12); height: width
      color: "transparent"; border.width: 1; border.color: island.accentText
      Rectangle { anchors.centerIn: parent; width: 4; height: 4; color: island.accentText }
    }
    Text { textFormat: Text.PlainText;
      x: island.s(28); anchors.verticalCenter: parent.verticalCenter
      text: "An agent is waiting for you"
      font.family: island.fontFamily
      font.pixelSize: island.f(13)
      font.bold: true
      renderType: Text.NativeRendering
      color: island.accentText
    }
    Column {
      anchors.right: parent.right; anchors.rightMargin: island.s(10); anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Repeater { model: 4; Rectangle { width: island.s(90); height: 1; color: Util.alpha(island.accentText, 0.55) } }
    }
  }

  Column {
    x: island.s(18)
    y: titleBar.height + island.s(12)
    width: parent.width - island.s(36)
    spacing: island.s(4)

    Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
      width: parent.width
      elide: Text.ElideRight
      text: view.agent ? (view.agent.agent || "Agent") + (view.agent.project ? " · " + view.agent.project : "") : ""
      font.family: island.fontFamily; font.pixelSize: island.f(11)
      color: island.fgDim
    }
    Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
      width: parent.width
      elide: Text.ElideRight
      text: view.agent ? (view.agent.title || "waiting for input") : ""
      font.family: island.fontFamily; font.pixelSize: island.f(15); font.bold: true
      color: island.fg
    }
    Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
      text: view.since(view.agent) + (view.others.length ? "  ·  +" + view.others.length + " more" : "")
      font.family: island.fontFamily; font.pixelSize: island.f(11)
      color: island.orangeColor
    }
  }

  Row {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: island.s(14)
    x: island.s(18)
    width: parent.width - island.s(36)
    spacing: island.s(10)

    Repeater {
      model: [
        { label: "Open", action: "open", primary: true },
        { label: "Later (10 min)", action: "snooze", primary: false },
        { label: "Dismiss", action: "close", primary: false }
      ]
      Rectangle {
        id: btn
        required property var modelData
        width: (parent.width - island.s(20)) / 3
        height: island.s(30)
        radius: Math.min(Style.cornerRadius, Style.space(2))
        color: modelData.primary ? Util.alpha(island.orangeColor, mouse.pressed ? 0.45 : mouse.containsMouse ? 0.34 : 0.24)
          : Util.alpha(island.fg, mouse.pressed ? 0.2 : mouse.containsMouse ? 0.12 : 0.06)
        border.width: 1
        border.color: modelData.primary ? island.orangeColor : Util.alpha(island.fg, 0.2)
        Text { renderType: Text.NativeRendering; textFormat: Text.PlainText;
          anchors.centerIn: parent
          text: btn.modelData.label
          font.family: island.fontFamily; font.pixelSize: island.f(12); font.bold: btn.modelData.primary
          color: btn.modelData.primary ? island.orangeColor : island.fg
        }
        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            var a = view.agent
            if (btn.modelData.action === "open") island.desktop.focusAgent(a)
            else if (btn.modelData.action === "snooze" && a) island.desktop.snooze(a.pane)
            island.collapse()
          }
        }
      }
    }
  }
}
