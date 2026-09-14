import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property bool opened
  property string mode: "read"
  property string title
  property string description
  property string deadlineText
  property string createdAt
  property var columnOptions
  property string columnId

  signal submitted(var fields)
  signal deleteRequested()
  signal editRequested()
  signal canceled()

  visible: opened
  focus: opened
  z: 20
  readonly property bool isNew: mode === "create"
  readonly property bool reading: mode === "read"
  readonly property bool writing: mode === "edit" || mode === "create"
  property bool moveOpen: false

  readonly property bool canSave: Model.validTitle(title) !== null
      && Model.validDeadline(deadlineText).ok
      && Model.validDescription(description) !== null

  readonly property int descMin: Style.space(40)
  readonly property int descMax: Style.space(220)

  readonly property string createdLabel: Model.formatDay(createdAt)
  readonly property string dueLabel: Model.formatDay(deadlineText)
  readonly property string columnLabel: Model.labelOf(columnOptions, columnId)
  readonly property color selectionFill: Style.selectionFillFor(Color.foreground, Color.accent)

  function focusBody() {
    if (root.writing)
      titleField.forceActiveFocus()
    else if (root.reading)
      titleRead.forceActiveFocus()
  }

  function armEditor() {
    root.moveOpen = false
    if (opened)
      Qt.callLater(root.focusBody)
  }

  onOpenedChanged: root.armEditor()
  onModeChanged: root.armEditor()

  function submit() {
    if (!canSave) return
    var desc = Model.validDescription(root.description)
    if (desc === null) return
    var deadline = Model.validDeadline(root.deadlineText)
    if (!deadline.ok) return
    root.submitted({
      title: root.title,
      description: desc,
      deadline: deadline.value,
      columnId: root.columnId
    })
  }

  function eatEsc(event) {
    if (event.key !== Qt.Key_Escape) return false
    root.canceled()
    event.accepted = true
    return true
  }

  function fittedDescHeight(contentH, extra) {
    var natural = Math.max(0, Number(contentH) || 0) + (Number(extra) || 0)
    return Math.round(Math.min(root.descMax, Math.max(root.descMin, natural)))
  }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (root.moveOpen) {
        root.moveOpen = false
        event.accepted = true
        return
      }
      root.canceled()
      event.accepted = true
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.7)
    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (root.moveOpen) root.moveOpen = false
        else root.canceled()
      }
    }
  }

  BorderSurface {
    id: card
    width: Math.min(parent.width - Style.space(48), Style.space(520))
    height: Math.min(parent.height - Style.space(48), form.implicitHeight + Style.space(32))
    anchors.centerIn: parent
    color: Color.background
    borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
    radius: Style.cornerRadius

    MouseArea {
      anchors.fill: parent
      onClicked: root.moveOpen = false
    }

    Column {
      id: form
      width: card.width - Style.space(32)
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.space(16)
      spacing: Style.space(10)

      Text {
        width: parent.width
        text: root.mode === "create" ? "New ticket"
          : (root.mode === "edit" ? "Edit ticket" : "Ticket")
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.reading
        height: visible ? implicitHeight : 0

        TextEdit {
          id: titleRead
          width: parent.width
          readOnly: true
          selectByMouse: true
          activeFocusOnPress: true
          text: root.title
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
          wrapMode: TextEdit.Wrap
          selectedTextColor: Color.foreground
          selectionColor: root.selectionFill
          Keys.onPressed: function(event) { root.eatEsc(event) }
        }

        Repeater {
          model: [
            { text: root.columnLabel !== "" ? "Column  " + root.columnLabel : "", ink: Color.muted },
            { text: root.createdLabel !== "" ? "Created  " + root.createdLabel : "", ink: Color.muted },
            { text: root.dueLabel !== "" ? "Due  " + root.dueLabel : "", ink: Color.foreground }
          ]
          Text {
            required property var modelData
            width: parent.width
            visible: modelData.text !== ""
            text: modelData.text
            color: modelData.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Item {
          id: readDescBox
          width: parent.width
          visible: root.description !== ""
          height: visible ? Math.min(root.descMax, descRead.contentHeight) : 0

          Flickable {
            id: readDescFlick
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: descRead.contentHeight
            interactive: readDescBox.readOverflow
            flickDeceleration: 1500

            function ensureCursorVisible() {
              var r = descRead.cursorRectangle
              if (r.y < contentY)
                contentY = Math.max(0, r.y)
              else if (r.y + r.height > contentY + height)
                contentY = Math.min(Math.max(0, contentHeight - height), r.y + r.height - height)
            }

            TextEdit {
              id: descRead
              width: readDescFlick.width
              readOnly: true
              selectByMouse: true
              activeFocusOnPress: true
              text: root.description
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: TextEdit.Wrap
              selectedTextColor: Color.foreground
              selectionColor: root.selectionFill
              onCursorRectangleChanged: readDescFlick.ensureCursorVisible()
              Keys.onPressed: function(event) { root.eatEsc(event) }
            }

            QQC.ScrollBar.vertical: QQC.ScrollBar {
              policy: readDescBox.readOverflow ? QQC.ScrollBar.AlwaysOn : QQC.ScrollBar.AlwaysOff
            }
          }

          readonly property bool readOverflow: descRead.contentHeight > height + 1
        }

        Row {
          spacing: Style.space(8)
          anchors.right: parent.right

          Button { text: "Edit"; onClicked: root.editRequested() }
          Button { text: "Delete"; onClicked: root.deleteRequested() }
          Button { text: "Close"; onClicked: root.canceled() }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(10)
        visible: root.writing
        height: visible ? implicitHeight : 0

        TextField {
          id: titleField
          width: parent.width
          placeholderText: "Title"
          text: root.title
          onTextEdited: root.title = text
          onAccepted: root.submit()
          Keys.onPressed: function(event) { root.eatEsc(event) }
        }

        Item {
          id: descBox
          width: parent.width
          height: root.fittedDescHeight(descField.contentHeight, descField.topPadding + descField.bottomPadding)
          readonly property bool descOverflow: descField.contentHeight + descField.topPadding + descField.bottomPadding > height + 1
          readonly property var descBorder: Border.controlSpec(descField.activeFocus ? "focus" : (descHover.hovered ? "hover-cursor" : "normal"), Color.foreground, Color.accent)

          BorderSurface {
            anchors.fill: parent
            color: Style.controlFill(descField.activeFocus, descHover.hovered, Color.foreground, Color.accent)
            borderSpec: descBox.descBorder
            radius: Style.cornerRadius
          }

          HoverHandler { id: descHover }

          WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
              if (!descBox.descOverflow) return
              var maxY = Math.max(0, descFlick.contentHeight - descFlick.height)
              descFlick.contentY = Math.max(0, Math.min(maxY, descFlick.contentY - event.angleDelta.y / 4))
              event.accepted = true
            }
          }

          Flickable {
            id: descFlick
            anchors.fill: parent
            anchors.margins: 1
            anchors.rightMargin: descBox.descOverflow ? Style.space(12) : 1
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: descField.topPadding + descField.contentHeight + descField.bottomPadding
            interactive: descBox.descOverflow
            flickDeceleration: 1500

            function ensureCursorVisible() {
              var r = descField.cursorRectangle
              var y = descField.topPadding + r.y
              if (y < contentY)
                contentY = Math.max(0, y)
              else if (y + r.height > contentY + height)
                contentY = Math.min(Math.max(0, contentHeight - height), y + r.height - height)
            }

            TextEdit {
              id: descField
              width: descFlick.width
              height: Math.max(descFlick.height, contentHeight + topPadding + bottomPadding)
              wrapMode: TextEdit.Wrap
              selectByMouse: true
              activeFocusOnPress: true
              text: root.description
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              color: Color.foreground
              selectedTextColor: Color.foreground
              selectionColor: root.selectionFill
              leftPadding: Style.spacing.controlPaddingX
              rightPadding: Style.spacing.controlPaddingX
              topPadding: Style.spacing.inputPaddingY
              bottomPadding: Style.spacing.inputPaddingY
              onTextChanged: {
                if (root.description !== text)
                  root.description = text
              }
              onCursorRectangleChanged: descFlick.ensureCursorVisible()
              Keys.onPressed: function(event) { root.eatEsc(event) }
            }

            QQC.ScrollBar.vertical: QQC.ScrollBar {
              policy: descBox.descOverflow ? QQC.ScrollBar.AlwaysOn : QQC.ScrollBar.AlwaysOff
            }
          }

          Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Style.spacing.controlPaddingX
            anchors.topMargin: Style.spacing.inputPaddingY
            visible: descField.text.length === 0 && !descField.activeFocus
            text: "Description"
            color: Qt.darker(Color.foreground, 1.6)
            font.family: Style.font.family
            font.pixelSize: Style.font.body
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: deadlineField
            width: parent.width - clearBtn.implicitWidth - parent.spacing
            placeholderText: "YYYY-MM-DD"
            text: root.deadlineText
            onTextEdited: root.deadlineText = text
            onAccepted: root.submit()
            Keys.onPressed: function(event) { root.eatEsc(event) }
          }

          Button {
            id: clearBtn
            text: "Clear"
            onClicked: root.deadlineText = ""
          }
        }

        Item {
          id: moveBlock
          width: parent.width
          height: visible ? Style.spacing.controlHeight + Style.font.caption + Style.spacing.labelGap : 0
          visible: root.mode === "edit"

          Text {
            id: moveLabel
            text: "Move to"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          SelectTrigger {
            id: moveTrigger
            anchors.top: moveLabel.bottom
            anchors.topMargin: Style.spacing.labelGap
            anchors.left: parent.left
            anchors.right: parent.right
            label: root.columnLabel
            open: root.moveOpen
            onToggled: root.moveOpen = !root.moveOpen
          }

          PopupList {
            visible: root.moveOpen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: moveTrigger.top
            anchors.bottomMargin: Style.space(4)
            model: root.columnOptions || []
            currentValue: root.columnId
            onPicked: function(item) {
              root.columnId = item.value
              root.moveOpen = false
            }
          }
        }

        Row {
          spacing: Style.space(8)
          anchors.right: parent.right

          Button {
            text: "Cancel"
            onClicked: root.canceled()
          }
          Button {
            text: root.isNew ? "Create" : "Save"
            enabled: root.canSave
            onClicked: root.submit()
          }
        }
      }
    }
  }
}
