import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "." as Local
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.ypmrg.omarchy-easy-kanban"

  property bool popupOpen: false
  readonly property bool opened: popupOpen
  property var store: null
  property bool storeReady: false
  property bool recovered: false
  property bool dirty: false
  property string lastWritten: ""
  property string saveError: ""
  property string actionError: ""
  property int reminderCursor: 0
  property int reminderBudget: 0
  property var reminderList: []
  property var reminderItem: null
  property string reminderToday: ""

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy"
  readonly property string statePath: stateDir + "/easy-kanban.json"

  property bool dirsReady: false
  property bool fileExisted: false
  property bool backedUp: false

  readonly property int columnCount: {
    var board = Model.activeBoard(store)
    return (board && board.columns && board.columns.length > 0) ? board.columns.length : 1
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    popupOpen = true
  }

  function close() {
    popupOpen = false
  }

  function reloadFromDisk() {
    if (!root.dirsReady) return
    stateFile.reload()
  }

  function applyMutation(result) {
    if (!result || !result.ok) {
      actionError = (result && result.error) ? result.error : ""
      return
    }
    store = result.state
    actionError = ""
    dirty = true
    scheduleSave()
  }

  function needsBackup() {
    return recovered && fileExisted && !backedUp
  }

  function saveBlocked() {
    if (!storeReady || !dirty) return true
    if (needsBackup()) {
      if (!backupProc.running) backupProc.running = true
      return true
    }
    return false
  }

  function scheduleSave() {
    if (!saveBlocked()) saveTimer.restart()
  }

  function flushSave() {
    if (saveBlocked()) return
    saveTimer.stop()
    var payload = JSON.stringify(Model.savePayload(store), null, 2) + "\n"
    root.lastWritten = payload
    stateFile.setText(payload)
  }

  readonly property string recapLine: storeReady
    ? Model.recapLine(store, Model.todayKey(new Date()))
    : "Easy Kanban"

  readonly property int cardChromeX: panel.padding * 2
    + Border.left(panel.borderSpec) + Border.right(panel.borderSpec)
  readonly property int minInnerWidth: Style.space(440)
  readonly property int innerBoardWidth: Math.max(
    minInnerWidth,
    Model.panelWidth(
      columnCount, Style.space(240), Style.space(10), Style.space(12), 100000
    )
  )
  readonly property int desiredCardWidth: innerBoardWidth + cardChromeX
  readonly property int halfScreenWidth: {
    var available = panel.availableCardWidth
    return available > 0 ? Math.max(1, Math.floor(available / 2)) : desiredCardWidth
  }
  readonly property int boardContentWidth: Math.min(desiredCardWidth, halfScreenWidth)

  function parse(raw, existed) {
    if (root.dirty) return
    if (root.storeReady && kanban && kanban.overlayOpen) return
    if (root.storeReady && String(raw) === root.lastWritten) return
    var firstLoad = !root.storeReady
    var result = Model.parseState(raw, new Date())
    if (!firstLoad && result.recovered) return
    store = result.state
    recovered = result.recovered
    if (firstLoad) {
      fileExisted = existed
      storeReady = true
      if (result.recovered && existed && !backedUp)
        backupProc.running = true
    }
  }

  function checkReminders() {
    if (!storeReady || notifyProc.running) return
    reminderToday = Model.todayKey(new Date())
    reminderList = Model.reminderCandidates(store, reminderToday)
    reminderCursor = 0
    reminderBudget = 5
    sendNextReminder()
  }

  function sendNextReminder() {
    if (notifyProc.running || reminderBudget <= 0) return
    if (!reminderList || reminderCursor >= reminderList.length) return
    var item = reminderList[reminderCursor]
    if (!item) return
    reminderItem = item
    notifyProc.command = [
      "omarchy-notification-send",
      "-g",
      "󰓫",
      Model.notificationTitle(item.boardName),
      Model.notificationBody(item)
    ]
    notifyProc.running = true
  }

  onStoreReadyChanged: {
    if (storeReady)
      checkReminders()
  }

  function armKeys() {
    Qt.callLater(function() {
      kanban.ensureFocus()
      kanban.forceActiveFocus()
    })
  }

  onPopupOpenChanged: {
    if (!popupOpen) {
      kanban.dismissOverlays()
      return
    }
    root.reloadFromDisk()
    armKeys()
  }

  Component.onCompleted: mkdirProc.running = true

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
    running: false
    onExited: {
      root.dirsReady = true
      stateFile.reload()
    }
  }

  Process {
    id: backupProc
    command: ["cp", root.statePath, root.statePath + ".bak"]
    running: false
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.backedUp = true
        if (root.dirty)
          root.scheduleSave()
        return
      }
      root.saveError = "Could not save board"
    }
  }

  Process {
    id: notifyProc
    command: ["omarchy-notification-send"]
    running: false
    onExited: function(exitCode) {
      var item = root.reminderItem
      root.reminderItem = null
      if (exitCode === 0 && item) {
        root.applyMutation(Model.markTicketReminded(root.store, item.ticketId, root.reminderToday))
        root.reminderCursor += 1
        root.reminderBudget -= 1
        root.sendNextReminder()
        return
      }
      root.reminderBudget = 0
    }
  }

  FileView {
    id: stateFile
    path: root.statePath
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onLoaded: {
      if (!root.dirsReady) return
      root.parse(text(), true)
    }
    onLoadFailed: {
      if (!root.dirsReady || root.storeReady) return
      root.parse("", false)
    }
    onSaved: {
      root.dirty = false
      root.saveError = ""
      root.recovered = false
    }
    onSaveFailed: root.saveError = "Could not save board"
    onFileChanged: reload()
  }

  Timer {
    id: saveTimer
    interval: 200
    repeat: false
    onTriggered: root.flushSave()
  }

  Timer {
    id: reminderTimer
    interval: 60000
    repeat: true
    running: true
    onTriggered: root.checkReminders()
  }

  Component {
    id: columnsIcon
    Item {
      // Lucide columns-3
      implicitWidth: Style.bar.iconCanvas
      implicitHeight: Style.bar.iconCanvas
      readonly property color ink: button.active && button.useActiveColor
        ? button.activeColor
        : button.foreground
      readonly property real s: Math.min(width, height)
      readonly property real pad: s * 3 / 24
      readonly property real stroke: Math.max(1.4, s * 2 / 24)

      Rectangle {
        x: pad
        y: pad
        width: parent.width - pad * 2
        height: parent.height - pad * 2
        radius: Math.max(2, parent.s * 2 / 24)
        color: "transparent"
        border.width: parent.stroke
        border.color: parent.ink
      }

      Rectangle {
        x: parent.width * 9 / 24 - parent.stroke / 2
        y: pad
        width: parent.stroke
        height: parent.height - pad * 2
        color: parent.ink
      }

      Rectangle {
        x: parent.width * 15 / 24 - parent.stroke / 2
        y: pad
        width: parent.stroke
        height: parent.height - pad * 2
        color: parent.ink
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    iconComponent: columnsIcon
    active: root.popupOpen
    tooltipText: root.popupOpen ? "" : root.recapLine
    onPressed: root.popupOpen = !root.popupOpen
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.popupOpen
    focusTarget: kanban
    contentWidth: panel.fittedContentWidth(root.boardContentWidth)
    contentHeight: panel.fittedContentHeight(Style.space(520))

    Local.Panel {
      id: kanban
      anchors.fill: parent
      focus: true
      store: root.store
      saveError: root.saveError
      actionError: root.actionError
      recovered: root.recovered && root.fileExisted
      allowColumnScroll: root.desiredCardWidth > root.halfScreenWidth
      onMutationRequested: function(result) { root.applyMutation(result) }
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (overlayOpen)
            dismissOverlays()
          else
            root.close()
          event.accepted = true
          return
        }
        if (handleKey(event))
          event.accepted = true
      }
    }
  }

  Connections {
    target: kanban
    function onOverlayOpenChanged() {
      if (kanban.overlayOpen || !root.popupOpen) return
      root.armKeys()
      root.reloadFromDisk()
    }
  }
}
