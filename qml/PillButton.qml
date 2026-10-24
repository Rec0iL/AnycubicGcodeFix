import QtQuick
import QtQuick.Controls.Basic

// Glassy pill / round button.
Item {
    id: btn
    property string label: ""
    property bool primary: false
    property bool danger: false
    property int fontSize: 14
    property string tip: ""
    property color labelColor: "transparent"   // transparent = automatic
    signal clicked()

    implicitWidth: txt.implicitWidth + 32
    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        scale: ma.pressed ? 0.95 : (ma.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        color: btn.primary ? Theme.accent
             : btn.danger ? Theme.dangerBg
             : Theme.glass(ma.containsMouse ? 0.7 : 0.5)
        border.width: 1
        border.color: Theme.fieldBorder
        gradient: btn.primary ? grad : null
        Gradient {
            id: grad
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Theme.accent2 }
        }
        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            font.pixelSize: btn.fontSize
            font.weight: Font.DemiBold
            font.family: Theme.font
            color: btn.labelColor.a > 0 ? btn.labelColor : (btn.primary ? "#3a1e05" : (btn.danger ? Theme.danger : Theme.text))
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
        ToolTip.visible: containsMouse && btn.tip !== ""
        ToolTip.delay: 400
        ToolTip.text: btn.tip
    }
}
