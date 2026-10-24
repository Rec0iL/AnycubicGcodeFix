import QtQuick

// Segmented pill selector: model = list of labels, emits activated(index).
Item {
    id: seg
    property var model: []
    property int currentIndex: 0
    property int fontSize: 14
    signal activated(int index)

    implicitHeight: 38
    implicitWidth: row.implicitWidth + 8

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.field
        border.width: 1
        border.color: Theme.fieldBorder
    }
    Rectangle {  // sliding thumb
        id: thumb
        property Item target: row.children[seg.currentIndex] ?? null
        x: 4 + (target ? target.x : 0)
        y: 4
        width: target ? target.width : 0
        height: seg.height - 8
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Theme.accent2 }
        }
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on width { NumberAnimation { duration: 200 } }
    }
    Row {
        id: row
        x: 4; y: 4
        height: seg.height - 8
        Repeater {
            model: seg.model
            delegate: Item {
                required property int index
                required property string modelData
                height: row.height
                width: lbl.implicitWidth + 28
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: parent.modelData
                    font.pixelSize: seg.fontSize
                    font.weight: Font.DemiBold
                    font.family: Theme.font
                    color: seg.currentIndex === parent.index ? "#3a1e05" : Theme.text
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.activated(parent.index)
                }
            }
        }
    }
}
