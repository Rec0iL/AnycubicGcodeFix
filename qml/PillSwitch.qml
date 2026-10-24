import QtQuick

// Animated on/off switch.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 50
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        border.width: 1
        border.color: Theme.fieldBorder
        color: sw.checked ? Theme.accent : Qt.rgba(0.45, 0.5, 0.6, 0.35)
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            width: 22; height: 22; radius: 11
            y: 3
            x: sw.checked ? parent.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
