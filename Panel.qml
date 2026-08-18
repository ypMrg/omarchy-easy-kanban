import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root
  anchors.fill: parent

  property var store
  property string saveError
  property string actionError
  property bool recovered
  property string focusedTicketId
  property bool allowColumnScroll: false
  signal mutationRequested(var result)

  property int columnWidth: Style.space(240)
  property int columnGap: Style.space(10)
  property int horizontalPadding: Style.space(12)
  readonly property int controlH: Style.spacing.controlHeight

  property string pendingBoardId: ""
  property string pendingColumnId: ""
  property string pendingTicketId: ""
  property string confirmKind: ""
  readonly property bool canDeleteBoard: !!(store && store.boards && store.boards.length > 1)
  readonly property var active: store ? Model.activeBoard(store) : null
  readonly property string activeId: active && active.id ? active.id : ""
  readonly property bool overlayOpen: nameDialog.opened || ticketEditor.opened
      || confirm.opened || ticketDeleteConfirm.opened || boardSwitcher.open
  readonly property bool textInputActive: {
    var item = root.Window.window ? root.Window.window.activeFocusItem : null
    return !!(item && (item instanceof TextInput || item instanceof TextEdit))
  }
  readonly property string statusText: saveError !== "" ? saveError
    : (actionError !== "" ? actionError : (recovered ? "Board file was reset" : ""))

  function boardOptions() { return Model.options(store ? store.boards : null) }
  function ticketColumnOptions() { return Model.options(active ? active.columns : null) }

  function findIn(items, id) {
    if (!items || !id) return null
    var i
    for (i = 0; i < items.length; i++) {
      if (items[i].id === id) return items[i]
    }
    return null
  }

  function findColumn(columnId) { return findIn(active ? active.columns : null, columnId) }

  function openConfirm(dialog) {
    dialog.selectedIndex = 1
    dialog.opened = true
    Qt.callLater(function() { dialog.forceActiveFocus() })
  }

  function openBoardDialog(mode, boardId) {
    pendingBoardId = boardId || (active ? active.id : "")
    var board = findIn(store ? store.boards : null, pendingBoardId)
    nameDialog.kind = "board"
    nameDialog.mode = mode
    nameDialog.name = mode === "rename" && board ? board.name : ""
    nameDialog.opened = true
  }

  function requestDeleteBoard(boardId) {
    pendingBoardId = boardId || (active ? active.id : "")
    if (!canDeleteBoard) return
    confirmKind = "board"
    openConfirm(confirm)
  }

  function openColumnDialog(columnId, mode) {
    pendingColumnId = columnId || ""
    var col = findColumn(pendingColumnId)
    nameDialog.kind = "column"
    nameDialog.mode = mode
    nameDialog.name = col ? col.name : ""
    nameDialog.color = col ? col.color : Model.FALLBACK_COLOR
    nameDialog.opened = true
  }

  function requestDeleteColumn(columnId) {
    pendingColumnId = columnId
    confirmKind = "column"
    openConfirm(confirm)
  }

  function fillTicketEditor(ticketId) {
    if (!store) return false
    var found = Model.findTicket(store, ticketId)
    if (!found || !found.ticket) return false
    pendingTicketId = ticketId
    focusedTicketId = ticketId
    ticketEditor.title = found.ticket.title || ""
    ticketEditor.description = found.ticket.description || ""
    ticketEditor.deadlineText = found.ticket.deadline ? found.ticket.deadline : ""
    ticketEditor.createdAt = found.ticket.createdAt || ""
    ticketEditor.columnOptions = ticketColumnOptions()
    ticketEditor.columnId = found.column && found.column.id ? found.column.id : ""
    return true
  }

  function requestAddTicket(columnId) {
    pendingTicketId = ""
    ticketEditor.mode = "create"
    ticketEditor.title = ""
    ticketEditor.description = ""
    ticketEditor.deadlineText = ""
    ticketEditor.createdAt = ""
    ticketEditor.columnOptions = ticketColumnOptions()
    ticketEditor.columnId = columnId
    ticketEditor.opened = true
  }

  function openTicket(ticketId, mode) {
    if (!fillTicketEditor(ticketId)) return
    ticketEditor.mode = mode
    ticketEditor.opened = true
  }

  function handleTicketDrop(ticketId, toColumnId, toIndex) {
    if (!store || !active) return
    var result = Model.moveTicket(store, active.id, ticketId, toColumnId, toIndex)
    if (result && result.moved) mutationRequested(result)
  }

  function ticketAt(column, index) {
    var tickets = column && column.tickets ? column.tickets : []
    if (index < 0 || index >= tickets.length) return ""
    return tickets[index].id || ""
  }

  function focusedOnBoard() {
    if (!store || !active || focusedTicketId === "") return null
    var found = Model.findTicket(store, focusedTicketId)
    return (found && found.board && found.board.id === active.id) ? found : null
  }

  function ensureFocus() {
    if (focusedOnBoard()) return
    focusedTicketId = active && active.columns && active.columns.length > 0
      ? ticketAt(active.columns[0], 0) : ""
  }

  onStoreChanged: ensureFocus()
  onActiveIdChanged: ensureFocus()
  Component.onCompleted: ensureFocus()

  function handleKey(event) {
    if (overlayOpen || textInputActive) return false
    var dx = 0
    var dy = 0
    var arrow = event.key === Qt.Key_Left || event.key === Qt.Key_Right
        || event.key === Qt.Key_Up || event.key === Qt.Key_Down
    var ch = event.text ? String(event.text).toLowerCase() : ""
    if (event.key === Qt.Key_Left || ch === "h") dx = -1
    else if (event.key === Qt.Key_Right || ch === "l") dx = 1
    else if (event.key === Qt.Key_Up || ch === "k") dy = -1
    else if (event.key === Qt.Key_Down || ch === "j") dy = 1
    if (dx !== 0 || dy !== 0) {
      if (event.modifiers & Qt.ShiftModifier) {
        if (arrow) handleFocusMove(dx, dy)
      } else {
        handleMoveRequested(dx, dy)
      }
      return true
    }
    if (ch !== "n" || !active || !active.columns || active.columns.length === 0) return false
    var found = focusedOnBoard()
    requestAddTicket(found && found.column ? found.column.id : active.columns[0].id)
    return true
  }

  function handleFocusMove(dx, dy) {
    if (overlayOpen || !store || !active) return
    var columns = active.columns
    if (!columns || columns.length === 0) return
    var found = focusedOnBoard()
    if (!found) {
      ensureFocus()
      return
    }
    if (dx !== 0) {
      var step = dx < 0 ? -1 : 1
      var nextCol = found.columnIndex + step
      while (nextCol >= 0 && nextCol < columns.length) {
        if (columns[nextCol].tickets && columns[nextCol].tickets.length > 0) {
          var destLen = columns[nextCol].tickets.length
          focusedTicketId = ticketAt(columns[nextCol], Math.max(0, Math.min(found.ticketIndex, destLen - 1)))
          return
        }
        nextCol += step
      }
      return
    }
    if (dy !== 0) {
      var nextId = ticketAt(columns[found.columnIndex], found.ticketIndex + (dy < 0 ? -1 : 1))
      if (nextId !== "") focusedTicketId = nextId
    }
  }

  function handleMoveRequested(dx, dy) {
    if (overlayOpen || !store || !active) return
    var found = focusedOnBoard()
    if (!found || !found.column) return
    var toColumnId = found.column.id
    var toIndex = found.ticketIndex
    var columns = active.columns
    if (dx !== 0) {
      var colIdx = found.columnIndex + (dx < 0 ? -1 : 1)
      if (colIdx < 0 || colIdx >= columns.length) return
      toColumnId = columns[colIdx].id
      var destLen = columns[colIdx].tickets ? columns[colIdx].tickets.length : 0
      toIndex = Math.max(0, Math.min(found.ticketIndex, destLen))
    } else if (dy !== 0) {
      toIndex = found.ticketIndex + dy
      if (dy > 0) toIndex += 1
    } else {
      return
    }
    var result = Model.moveTicket(store, active.id, focusedTicketId, toColumnId, toIndex)
    if (result && result.moved) mutationRequested(result)
  }

  function handleColumnReorder(columnId, toIndex) {
    if (!store || !active) return
    mutationRequested(Model.reorderColumn(store, active.id, columnId, toIndex))
  }

  function dismissOverlays() {
    nameDialog.opened = false
    ticketEditor.opened = false
    confirm.opened = false
    ticketDeleteConfirm.opened = false
    boardSwitcher.open = false
    pendingBoardId = ""
    pendingColumnId = ""
    pendingTicketId = ""
    confirmKind = ""
  }

  function submitBoard(name) {
    if (!store) return
    var result = nameDialog.mode === "rename"
      ? Model.renameBoard(store, pendingBoardId || store.activeBoardId, name)
      : Model.createBoard(store, name, new Date())
    mutationRequested(result)
    if (result && result.ok) {
      nameDialog.opened = false
      pendingBoardId = ""
    }
  }

  function submitColumn(name, color) {
    if (!store || !active) return
    var result
    if (nameDialog.mode === "create") {
      result = Model.createColumn(store, active.id, name, color)
      mutationRequested(result)
      if (result && result.ok) nameDialog.opened = false
      return
    }
    var col = findColumn(pendingColumnId)
    if (!col) return
    result = { ok: true, state: store }
    if (name !== col.name) {
      result = Model.renameColumn(result.state, active.id, pendingColumnId, name)
      if (!result || !result.ok) {
        mutationRequested(result)
        return
      }
    }
    var hex = Model.normalizeHex(color)
    if (hex && hex !== col.color) {
      result = Model.recolorColumn(result.state, active.id, pendingColumnId, hex)
      if (!result || !result.ok) {
        mutationRequested(result)
        return
      }
    }
    if (result.state !== store) mutationRequested(result)
    nameDialog.opened = false
  }

  function submitTicket(fields) {
    if (!store || !active || !fields) return
    var result
    if (ticketEditor.isNew) {
      result = Model.createTicket(store, active.id, fields.columnId, {
        title: fields.title,
        description: fields.description,
        deadline: fields.deadline
      }, new Date())
      mutationRequested(result)
      if (result && result.ok) ticketEditor.opened = false
      return
    }
    var found = Model.findTicket(store, pendingTicketId)
    result = Model.updateTicket(store, active.id, pendingTicketId, {
      title: fields.title,
      description: fields.description,
      deadline: fields.deadline
    })
    if (!result || !result.ok) {
      mutationRequested(result)
      return
    }
    if (found && found.column && fields.columnId && fields.columnId !== found.column.id) {
      var dest = findColumn(fields.columnId)
      var toIndex = dest && dest.tickets ? dest.tickets.length : 0
      var moved = Model.moveTicket(result.state, active.id, pendingTicketId, fields.columnId, toIndex)
      if (moved && moved.ok) result = moved
    }
    mutationRequested(result)
    ticketEditor.opened = false
  }

  Item {
    id: header
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: Math.max(headerLeft.implicitHeight, addColumnBtn.implicitHeight)

    Row {
      id: headerLeft
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(8)

      Item {
        id: boardSwitcher
        width: Style.space(180)
        height: root.controlH
        property bool open: false
        readonly property string currentLabel: Model.labelOf(root.store ? root.store.boards : null, root.store ? root.store.activeBoardId : "")

        SelectTrigger {
          anchors.fill: parent
          label: boardSwitcher.currentLabel
          open: boardSwitcher.open
          onToggled: boardSwitcher.open = !boardSwitcher.open
        }
      }

      Button {
        text: "New board"
        implicitHeight: root.controlH
        height: root.controlH
        onClicked: {
          boardSwitcher.open = false
          root.openBoardDialog("create", "")
        }
      }
    }

    Button {
      id: addColumnBtn
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "Add column"
      implicitHeight: root.controlH
      height: root.controlH
      onClicked: {
        boardSwitcher.open = false
        root.openColumnDialog("", "create")
      }
    }
  }

  Text {
    id: statusLabel
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: header.bottom
    anchors.topMargin: visible ? Style.space(6) : 0
    height: visible ? implicitHeight : 0
    visible: root.statusText !== ""
    text: root.statusText
    color: Color.urgent
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.WordWrap
  }

  MouseArea {
    anchors.fill: parent
    z: 4
    enabled: boardSwitcher.open
    hoverEnabled: false
    onClicked: boardSwitcher.open = false
  }

  PopupList {
    visible: boardSwitcher.open
    x: boardSwitcher.mapToItem(root, 0, 0).x
    y: boardSwitcher.mapToItem(root, 0, boardSwitcher.height).y + Style.space(4)
    width: Math.max(boardSwitcher.width + Style.space(56), Style.space(236))
    model: root.boardOptions()
    currentValue: root.store ? root.store.activeBoardId : ""
    actions: true
    deleteEnabled: root.canDeleteBoard
    onPicked: function(item) {
      boardSwitcher.open = false
      if (!root.store || item.value === root.store.activeBoardId) return
      root.mutationRequested(Model.setActiveBoard(root.store, item.value))
    }
    onRenameRequested: function(item) {
      boardSwitcher.open = false
      root.openBoardDialog("rename", item.value)
    }
    onDeleteRequested: function(item) {
      boardSwitcher.open = false
      root.requestDeleteBoard(item.value)
    }
  }

  Flickable {
    id: columnFlick
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: statusLabel.bottom
    anchors.topMargin: Style.space(10)
    anchors.bottom: shortcutHint.top
    anchors.bottomMargin: Style.space(6)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.HorizontalFlick
    contentWidth: root.allowColumnScroll
      ? Math.max(width, columnRow.implicitWidth + root.horizontalPadding)
      : width
    contentHeight: height
    interactive: root.allowColumnScroll && contentWidth > width + 1

    Row {
      id: columnRow
      x: root.horizontalPadding / 2
      height: columnFlick.height
      spacing: root.columnGap

      Repeater {
        model: root.active && root.active.columns ? root.active.columns : []

        ColumnView {
          required property var modelData
          column: modelData
          focusedTicketId: root.focusedTicketId
          columnWidth: root.columnWidth
          height: columnRow.height
          onAddTicketRequested: function(columnId) { root.requestAddTicket(columnId) }
          onRenameRequested: function(columnId) { root.openColumnDialog(columnId, "rename") }
          onRecolorRequested: function(columnId) { root.openColumnDialog(columnId, "color") }
          onDeleteRequested: function(columnId) { root.requestDeleteColumn(columnId) }
          onTicketClicked: function(ticketId) { root.openTicket(ticketId, "read") }
          onTicketFocused: function(ticketId) { root.focusedTicketId = ticketId }
          onTicketDropRequested: function(ticketId, toColumnId, toIndex) {
            root.handleTicketDrop(ticketId, toColumnId, toIndex)
          }
          onColumnReorderRequested: function(columnId, toIndex) {
            root.handleColumnReorder(columnId, toIndex)
          }
        }
      }
    }
  }

  Text {
    id: shortcutHint
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    text: "N new ticket  ·  Shift+arrows focus  ·  Arrows/HJKL move  ·  Esc"
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
  }

  NameDialog {
    id: nameDialog
    anchors.fill: parent
    onCanceled: {
      opened = false
      root.pendingBoardId = ""
    }
    onSubmitted: function(name, color) {
      if (kind === "board") root.submitBoard(name)
      else root.submitColumn(name, color)
    }
  }

  PanelWindow {
    id: ticketLayer
    visible: ticketEditor.opened || ticketDeleteConfirm.opened
    screen: root.QsWindow && root.QsWindow.window ? root.QsWindow.window.screen : null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-easy-kanban-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    TicketEditor {
      id: ticketEditor
      anchors.fill: parent
      onCanceled: opened = false
      onSubmitted: function(fields) { root.submitTicket(fields) }
      onEditRequested: root.openTicket(root.pendingTicketId, "edit")
      onDeleteRequested: root.openConfirm(ticketDeleteConfirm)
    }

    ConfirmDialog {
      id: ticketDeleteConfirm
      anchors.fill: parent
      z: 30
      message: "Delete this ticket?"
      Keys.onPressed: function(event) {
        if (handleKey(event)) event.accepted = true
      }
      onCanceled: opened = false
      onConfirmed: {
        opened = false
        ticketEditor.opened = false
        if (!root.store || !root.active || root.pendingTicketId === "") return
        root.mutationRequested(Model.deleteTicket(root.store, root.active.id, root.pendingTicketId))
        if (root.focusedTicketId === root.pendingTicketId)
          root.focusedTicketId = ""
        root.pendingTicketId = ""
      }
    }
  }

  ConfirmDialog {
    id: confirm
    anchors.fill: parent
    z: 30
    message: root.confirmKind === "board"
      ? "Delete this board and all of its tickets?"
      : "Delete this column and its tickets?"
    Keys.onPressed: function(event) {
      if (handleKey(event)) event.accepted = true
    }
    onCanceled: {
      opened = false
      root.pendingBoardId = ""
      root.pendingColumnId = ""
      root.confirmKind = ""
    }
    onConfirmed: {
      opened = false
      if (root.confirmKind === "board" && root.store) {
        var boardId = root.pendingBoardId !== "" ? root.pendingBoardId : root.store.activeBoardId
        root.mutationRequested(Model.deleteBoard(root.store, boardId))
      } else if (root.store && root.active && root.pendingColumnId !== "") {
        root.mutationRequested(Model.deleteColumn(root.store, root.active.id, root.pendingColumnId))
      }
      root.pendingBoardId = ""
      root.pendingColumnId = ""
      root.confirmKind = ""
    }
  }
}
