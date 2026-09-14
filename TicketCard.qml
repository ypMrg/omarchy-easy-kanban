import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BorderSurface {
  id: root

  property var ticket
  property bool focused
  property string today

  signal clicked()
  signal focusRequested()
  signal dragMoved(real globalX)
  signal dragReleased(real globalX, real globalY)

  readonly property bool due: ticket ? Model.dueToday(ticket.deadline, today) : false
  readonly property bool late: ticket ? Model.overdue(ticket.deadline, today) : false
  readonly property color ink: late ? Color.urgent : Color.foreground
  readonly property string createdLabel: ticket ? Model.formatDay(ticket.createdAt) : ""
  readonly property string dueLabel: ticket ? Model.formatDay(ticket.deadline) : ""

  implicitHeight: body.implicitHeight + Style.space(10)
  color: Color.background
  radius: Style.cornerRadius
  borderSpec: focused ? Border.flat(Color.accent, 1) : Border.flat(Util.alpha(Color.foreground, 0.22), Style.normalBorderWidth)
  clip: true

  Column {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(6)
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: ticket && ticket.title ? ticket.title : ""
      color: root.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: ticket && ticket.description && ticket.description.length > 0
      text: ticket && ticket.description ? ticket.description : ""
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
      maximumLineCount: 1
      elide: Text.ElideRight
    }

    Row {
      width: parent.width
      spacing: Style.space(6)
      visible: root.createdLabel !== ""

      Text {
        text: "Created"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        text: root.createdLabel
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(6)
      visible: root.dueLabel !== ""

      Text {
        text: root.late ? "Overdue" : (root.due ? "Due today" : "Due")
        color: root.late ? Color.urgent : (root.due ? Color.accent : Color.muted)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      Text {
        text: root.dueLabel
        color: root.late ? Color.urgent : Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }

  MouseArea {
    id: pad
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: dragging || drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    drag.target: ghost
    drag.threshold: 6
    drag.smoothed: false
    property bool dragging: false

    onPressed: function() {
      dragging = false
      root.focusRequested()
      var dest = ghost.parent
      if (!dest) return
      var p = root.mapToItem(dest, 0, 0)
      ghost.x = p.x
      ghost.y = p.y
    }
    onPositionChanged: function(mouse) {
      if (!drag.active) return
      dragging = true
      var g = mapToGlobal(mouse.x, mouse.y)
      root.dragMoved(g.x)
    }
    onReleased: function(mouse) {
      if (dragging) {
        var g = mapToGlobal(mouse.x, mouse.y)
        root.dragReleased(g.x, g.y)
      }
      ghost.x = 0
      ghost.y = 0
    }
    onClicked: function() {
      if (!dragging) root.clicked()
    }
  }

  Item {
    id: ghost
    visible: pad.drag.active
    opacity: 0.7
    width: root.width
    height: root.height
    z: 10000
    parent: root.Window.window && root.Window.window.contentItem ? root.Window.window.contentItem : root
    Drag.active: visible
    Drag.keys: ["ticket"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    ShaderEffectSource {
      anchors.fill: parent
      sourceItem: root
      hideSource: false
      live: true
      recursive: false
    }
  }
}
