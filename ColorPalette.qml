import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property string value
  property string draft

  signal colorPicked(string hex)

  readonly property int columns: 4
  readonly property int gap: Style.space(6)
  readonly property int swatchSize: Style.space(32)

  implicitWidth: columns * swatchSize + (columns - 1) * gap
  implicitHeight: grid.implicitHeight + Style.space(8) + hexField.implicitHeight

  onValueChanged: draft = value
  onVisibleChanged: if (visible) draft = value
  Component.onCompleted: draft = value

  function inkFor(hex) {
    var s = String(hex || "").replace("#", "")
    if (s.length !== 6) return "#FFFFFF"
    var r = parseInt(s.substring(0, 2), 16) / 255
    var g = parseInt(s.substring(2, 4), 16) / 255
    var b = parseInt(s.substring(4, 6), 16) / 255
    var l = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return l > 0.55 ? "#1A1A1A" : "#FFFFFF"
  }

  Grid {
    id: grid
    width: parent.width
    columns: root.columns
    spacing: root.gap

    Repeater {
      model: Model.PALETTE

      Rectangle {
        required property string modelData
        width: root.swatchSize
        height: root.swatchSize
        color: modelData
        radius: Style.cornerRadius
        border.width: modelData === root.value ? 2 : 1
        border.color: modelData === root.value ? Color.accent : Util.alpha(Color.foreground, 0.28)

        Text {
          anchors.centerIn: parent
          visible: modelData === root.value
          text: "✓"
          color: root.inkFor(modelData)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.draft = modelData
            root.colorPicked(modelData)
          }
        }
      }
    }
  }

  TextField {
    id: hexField
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: grid.bottom
    anchors.topMargin: Style.space(8)
    text: root.draft
    placeholderText: "#RRGGBB"
    onTextEdited: root.draft = text
    onEditingFinished: {
      var hex = Model.normalizeHex(root.draft)
      if (hex !== null)
        root.colorPicked(hex)
    }
  }
}
