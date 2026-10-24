import QtQuick

// Rounded gradient progress bar with an animated shimmer.
Item {
    id: bar
    property real value: 0
    property bool active: true
    property color from: Theme.accent
    property color to: Theme.accent2
    implicitHeight: 12

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(0.45, 0.5, 0.6, 0.22)
    }
    Item {
        id: fill
        height: parent.height
        width: Math.max(parent.height, parent.width * bar.value)
        visible: bar.value > 0
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        clip: true
        Rectangle {
            width: bar.width
            height: bar.height
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: bar.from }
                GradientStop { position: 1; color: bar.to }
            }
        }
        // sweeping highlight
        Rectangle {
            visible: bar.active && bar.value < 1
            width: 60; height: parent.height
            rotation: 0
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#00ffffff" }
                GradientStop { position: 0.5; color: "#88ffffff" }
                GradientStop { position: 1; color: "#00ffffff" }
            }
            NumberAnimation on x {
                running: bar.active && bar.value < 1 && bar.visible
                from: -60; to: bar.width
                duration: 1300
                loops: Animation.Infinite
            }
        }
    }
}
