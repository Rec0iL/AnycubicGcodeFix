import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Remembers where things came from: recent conversions (click to reveal).
Popup {
    id: dlg
    property Item bgSource: null

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    dim: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(640, (parent ? parent.width : 640) - 40)
    height: Math.min(520, (parent ? parent.height : 600) - 40)

    Overlay.modal: Rectangle { color: Qt.rgba(0.06, 0.08, 0.12, 0.40) }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 320; easing.type: Easing.OutBack }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 150 } }

    background: Item {}
    contentItem: GlassCard {
        source: dlg.bgSource
        tintAlpha: 1.0
        blurred: false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "History"
                    font.pixelSize: 22; font.weight: Font.Bold; font.family: Theme.font; color: Theme.text
                    Layout.fillWidth: true
                }
                PillButton { label: "Clear"; danger: true; onClicked: backend.clearHistory() }
                PillButton { label: "Close"; primary: true; onClicked: dlg.close() }
            }
            Text {
                visible: list.count === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 60
                text: "Nothing fixed yet"
                font.pixelSize: 16; font.family: Theme.font; color: Theme.textSoft
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: backend.history
                delegate: Rectangle {
                    required property var modelData
                    width: list.width
                    height: 56
                    radius: 14
                    color: Theme.glass(hov.containsMouse ? 0.75 : 0.45)
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.margins: 14
                        spacing: 2
                        Text {
                            width: parent.width; elide: Text.ElideMiddle
                            text: (modelData.status === "done" ? "✓ " : modelData.status === "error" ? "✗ " : "– ")
                                  + modelData.name
                            font.pixelSize: 14; font.weight: Font.DemiBold; font.family: Theme.font
                            color: modelData.status === "error" ? Theme.danger : Theme.text
                        }
                        Text {
                            width: parent.width; elide: Text.ElideMiddle
                            text: "from " + modelData.sourceDir + (modelData.output ? "  →  " + modelData.output : "")
                            font.pixelSize: 11; font.family: Theme.font; color: Theme.textSoft
                        }
                    }
                    MouseArea {
                        id: hov; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backend.reveal(modelData.output !== "" ? modelData.output
                                                  : modelData.sourceDir + "/" + modelData.name)
                    }
                }
            }
        }
    }
}
