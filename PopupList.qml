import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var model: []
  property string currentValue: ""
  property bool actions: false
  property bool deleteEnabled: true

  signal picked(var item)
  signal renameRequested(var item)
  signal deleteRequested(var item)

  height: list.implicitHeight + Style.space(8)
  z: 40
  color: Color.popups.background
  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
  radius: Style.cornerRadius

  Column {
    id: list
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(4)
    spacing: 0

    Repeater {
      model: root.model

      Item {
        required property var modelData
        width: list.width
        height: Style.spacing.popupRowHeight

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: hover.hovered || modelData.value === root.currentValue
            ? Style.hoverFillFor(Color.foreground, Color.accent)
            : "transparent"
        }

        HoverHandler { id: hover }

        MouseArea {
          anchors.left: parent.left
          anchors.right: actionsRow.visible ? actionsRow.left : parent.right
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          cursorShape: Qt.PointingHandCursor
          onClicked: root.picked(modelData)
        }

        Text {
          anchors.left: parent.left
          anchors.right: actionsRow.visible ? actionsRow.left : parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.spacing.controlPaddingX
          anchors.rightMargin: Style.space(4)
          text: modelData.label
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          verticalAlignment: Text.AlignVCenter
        }

        Row {
          id: actionsRow
          visible: root.actions
          width: visible ? implicitWidth : 0
          anchors.right: parent.right
          anchors.rightMargin: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)
          z: 1

          Button {
            implicitWidth: Style.space(22)
            implicitHeight: Style.space(22)
            horizontalPadding: 0
            verticalPadding: 0
            iconText: "󰏫"
            tooltipText: "Rename board"
            bordered: false
            fontSize: Style.font.caption
            iconSize: Style.font.body
            onClicked: root.renameRequested(modelData)
          }

          Button {
            implicitWidth: Style.space(22)
            implicitHeight: Style.space(22)
            horizontalPadding: 0
            verticalPadding: 0
            iconText: "󰅖"
            tooltipText: "Delete board"
            bordered: false
            fontSize: Style.font.caption
            iconSize: Style.font.body
            enabled: root.deleteEnabled
            onClicked: root.deleteRequested(modelData)
          }
        }
      }
    }
  }
}
