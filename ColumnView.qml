import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var column
  property string focusedTicketId
  property bool columnFocused: false
  property int columnWidth

  signal addTicketRequested(string columnId)
  signal renameRequested(string columnId)
  signal recolorRequested(string columnId)
  signal deleteRequested(string columnId)
  signal ticketClicked(string ticketId)
  signal ticketFocused(string ticketId)
  signal columnFocusRequested(string columnId)
  signal ticketDropRequested(string ticketId, string toColumnId, int toIndex)
  signal ticketDragMoved(real globalX)
  signal ticketDragEnded()
  signal columnReorderRequested(string columnId, int toIndex)

  width: columnWidth
  implicitWidth: columnWidth

  readonly property string columnId: column && column.id ? column.id : ""
  readonly property var tickets: column && column.tickets ? column.tickets : []
  readonly property string today: Model.todayKey(new Date())

  function dropIndexAt(localY) {
    var y = localY + ticketFlick.contentY
    var n = ticketRepeater.count
    var i, card, mid
    for (i = 0; i < n; i++) {
      card = ticketRepeater.itemAt(i)
      if (!card) continue
      mid = card.y + card.height / 2
      if (y < mid) return i
    }
    return n
  }

  function tryAcceptTicketDrop(ticketId, globalX, globalY) {
    if (!ticketId) return false
    var p = dropArea.mapFromGlobal(globalX, globalY)
    if (p.x < 0 || p.y < 0 || p.x > dropArea.width || p.y > dropArea.height)
      return false
    ticketDropRequested(ticketId, columnId, dropIndexAt(p.y))
    return true
  }

  function routeTicketDrop(ticketId, globalX, globalY) {
    var row = root.parent
    if (!row || !row.children) return
    var i, sib
    for (i = 0; i < row.children.length; i++) {
      sib = row.children[i]
      if (sib && sib.tryAcceptTicketDrop && sib.tryAcceptTicketDrop(ticketId, globalX, globalY))
        return
    }
  }

  function reorderIndexFromX(globalX) {
    var row = root.parent
    if (!row || !row.children) return 0
    var siblings = []
    var i, ch
    for (i = 0; i < row.children.length; i++) {
      ch = row.children[i]
      if (ch && ch.column && ch.columnWidth !== undefined)
        siblings.push(ch)
    }
    siblings.sort(function(a, b) { return a.x - b.x })
    var localX = row.mapFromGlobal(globalX, 0).x
    for (i = 0; i < siblings.length; i++) {
      if (localX < siblings[i].x + siblings[i].width / 2)
        return i
    }
    return Math.max(0, siblings.length - 1)
  }

  Rectangle {
    id: colorStrip
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Style.space(3)
    radius: 1
    color: column && column.color ? column.color : Model.FALLBACK_COLOR
  }

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: colorStrip.bottom
    anchors.leftMargin: Style.space(4)
    anchors.rightMargin: Style.space(4)
    anchors.topMargin: Style.space(6)
    height: Math.max(nameLabel.implicitHeight, actionRow.implicitHeight)

    MouseArea {
      id: headerDrag
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.SizeHorCursor
      property bool dragging: false
      property real pressX: 0

      onPressed: function(mouse) {
        dragging = false
        pressX = mouse.x
      }
      onPositionChanged: function(mouse) {
        if (pressed && Math.abs(mouse.x - pressX) > 6)
          dragging = true
      }
      onReleased: function(mouse) {
        if (!dragging) return
        var g = mapToGlobal(mouse.x, mouse.y)
        root.columnReorderRequested(root.columnId, root.reorderIndexFromX(g.x))
      }
    }

    Text {
      id: nameLabel
      anchors.left: parent.left
      anchors.right: actionRow.left
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      text: (column && column.name ? column.name : "") + "  " + root.tickets.length
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
      elide: Text.ElideRight
    }

    Row {
      id: actionRow
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Repeater {
        model: [
          { icon: "󰏫", tip: "Rename column", act: "rename" },
          { icon: "󰏘", tip: "Column color", act: "color" },
          { icon: "󰩹", tip: "Delete column", act: "delete" }
        ]

        Button {
          required property var modelData
          implicitWidth: Style.space(26)
          implicitHeight: Style.space(26)
          horizontalPadding: 0
          verticalPadding: 0
          iconText: modelData.icon
          tooltipText: modelData.tip
          bordered: true
          fontSize: Style.font.caption
          iconSize: Style.font.body
          onClicked: {
            if (modelData.act === "rename") root.renameRequested(root.columnId)
            else if (modelData.act === "color") root.recolorRequested(root.columnId)
            else root.deleteRequested(root.columnId)
          }
        }
      }
    }
  }

  Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.bottom: addWrap.top
    anchors.leftMargin: Style.space(4)
    anchors.rightMargin: Style.space(4)
    anchors.topMargin: Style.space(6)

    DropArea {
      id: dropArea
      anchors.fill: parent
      keys: ["ticket"]

      Rectangle {
        anchors.fill: parent
        visible: dropArea.containsDrag || (root.columnFocused && root.tickets.length === 0)
        color: Util.alpha(Color.accent, dropArea.containsDrag ? 0.12 : 0.08)
        border.width: root.columnFocused && root.tickets.length === 0 ? 1 : 0
        border.color: Color.accent
        radius: Style.cornerRadius
      }
    }

    Flickable {
      id: ticketFlick
      anchors.fill: parent
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      contentWidth: width
      contentHeight: Math.max(ticketCol.implicitHeight, height)
      interactive: ticketCol.implicitHeight > height

      MouseArea {
        z: -1
        width: ticketFlick.width
        height: Math.max(ticketCol.implicitHeight, ticketFlick.height)
        onClicked: root.columnFocusRequested(root.columnId)
      }

      Column {
        id: ticketCol
        width: ticketFlick.width
        spacing: Style.space(4)

        Repeater {
          id: ticketRepeater
          model: root.tickets

          TicketCard {
            required property var modelData
            width: ticketCol.width
            ticket: modelData
            focused: modelData && modelData.id === root.focusedTicketId
            today: root.today
            onClicked: root.ticketClicked(modelData.id)
            onFocusRequested: root.ticketFocused(modelData.id)
            onDragMoved: function(gx) { root.ticketDragMoved(gx) }
            onDragReleased: function(gx, gy) {
              root.routeTicketDrop(modelData.id, gx, gy)
              root.ticketDragEnded()
            }
          }
        }
      }
    }
  }

  Item {
    id: addWrap
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: Style.space(28)

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 1
      color: Util.alpha(Color.foreground, 0.14)
    }

    Text {
      id: addPlus
      anchors.centerIn: parent
      text: "+"
      color: addHover.hovered ? Color.accent : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    HoverHandler { id: addHover }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.addTicketRequested(root.columnId)
    }
  }
}
