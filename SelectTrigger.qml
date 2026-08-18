import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string label
  property bool open: false

  signal toggled()

  implicitHeight: Style.spacing.controlHeight
  height: implicitHeight

  BorderSurface {
    anchors.fill: parent
    radius: Style.cornerRadius
    readonly property bool hot: hover.hovered || root.open
    color: Style.controlFill(false, hot, Color.foreground, Color.accent)
    borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", Color.foreground, Color.accent)

    HoverHandler { id: hover }

    Text {
      anchors.left: parent.left
      anchors.right: chevron.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.spacing.controlPaddingX
      anchors.rightMargin: Style.space(6)
      text: root.label
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      id: chevron
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.rightMargin: Style.spacing.controlPaddingX
      text: "󰅀"
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.toggled()
    }
  }
}
