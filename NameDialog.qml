import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property bool opened
  property string kind
  property string mode
  property string name
  property string color

  signal submitted(string name, string color)
  signal canceled()

  visible: opened
  focus: opened
  z: 20

  readonly property bool withColor: kind === "column"
  readonly property string heading: {
    if (kind === "board")
      return mode === "rename" ? "Rename board" : "New board"
    if (mode === "rename") return "Rename column"
    if (mode === "color") return "Column color"
    return "Add column"
  }
  readonly property bool canSave: Model.validName(name) !== null
      && (!withColor || Model.normalizeHex(colorPalette.draft) !== null)

  onOpenedChanged: {
    if (opened)
      Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function submit() {
    if (!canSave) return
    root.submitted(root.name, colorPalette.draft)
  }

  function eatEsc(event) {
    if (event.key !== Qt.Key_Escape) return
    root.canceled()
    event.accepted = true
  }

  Keys.onPressed: function(event) { root.eatEsc(event) }

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.7)
    MouseArea {
      anchors.fill: parent
      onClicked: root.canceled()
    }
  }

  BorderSurface {
    width: Math.min(parent.width - Style.space(32), Style.space(360))
    height: body.implicitHeight + Style.space(28)
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: Style.space(20)
    color: Color.background
    borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
    radius: Style.cornerRadius

    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    Column {
      id: body
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(14)
      spacing: Style.space(10)

      Text {
        text: root.heading
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }

      TextField {
        id: nameField
        width: parent.width
        placeholderText: "Name"
        text: root.name
        onTextEdited: root.name = text
        onAccepted: root.submit()
        Keys.onPressed: function(event) { root.eatEsc(event) }
      }

      ColorPalette {
        id: colorPalette
        width: parent.width
        visible: root.withColor
        height: visible ? implicitHeight : 0
        value: root.color
        onColorPicked: function(hex) { root.color = hex }
      }

      Row {
        spacing: Style.space(8)
        anchors.right: parent.right

        Button {
          text: "Cancel"
          onClicked: root.canceled()
        }

        Button {
          text: "Save"
          enabled: root.canSave
          onClicked: root.submit()
        }
      }
    }
  }
}
