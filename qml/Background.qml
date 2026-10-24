import QtQuick
import QtQuick.Effects

// Animated background: GLSL build-plate shader + floating 3D-printing shapes.
Item {
    id: root

    property real energy: 0          // 0 calm .. 1 excited (smoothed)
    property bool lowPower: false
    property real t: 0               // animation clock, speeds up with energy

    Behavior on energy { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

    FrameAnimation {
        running: root.visible
        onTriggered: root.t += frameTime * (root.lowPower ? 0.5 : 1.0) * (1.0 + root.energy * 1.2)
    }

    ShaderEffect {
        anchors.fill: parent
        property real time: root.t
        property size resolution: Qt.size(width, height)
        property real energy: root.energy
        property real quality: root.lowPower ? 0.0 : 1.0
        property real night: Theme.night
        fragmentShader: "../shaders/bg.frag.qsb"
    }

    // ---- floating shapes -----------------------------------------------------
    readonly property var shapes: [
        // kind,    x,    y,    size, speed, phase, teal?
        ["cube",   0.07, 0.13, 70, 0.55, 0.0, false],
        ["spool",  0.84, 0.09, 74, 0.45, 1.3, true],
        ["layers", 0.47, 0.05, 58, 0.60, 2.1, false],
        ["nozzle", 0.90, 0.42, 64, 0.50, 3.4, false],
        ["cube",   0.04, 0.50, 56, 0.40, 4.2, true],
        ["spool",  0.72, 0.74, 64, 0.55, 5.0, false],
        ["layers", 0.20, 0.82, 60, 0.48, 0.7, true],
        ["nozzle", 0.50, 0.91, 54, 0.52, 1.9, true],
        ["cube",   0.93, 0.84, 52, 0.42, 2.8, false],
        ["dot",    0.33, 0.30, 26, 0.65, 3.9, true],
        ["dot",    0.64, 0.27, 20, 0.58, 4.7, false],
        ["dot",    0.12, 0.70, 30, 0.46, 5.6, false],
        ["dot",    0.80, 0.58, 22, 0.62, 0.4, true],
        ["dot",    0.38, 0.64, 18, 0.50, 1.1, false]
    ]

    Repeater {
        model: root.shapes
        delegate: Decor {
            id: k
            required property var modelData
            readonly property real sp: modelData[4] * (root.lowPower ? 0.5 : 1)
            readonly property real ph: modelData[5]
            kind: modelData[0]
            size: modelData[3]
            alt: modelData[6]
            opacity: 0.55 + 0.25 * Math.sin(root.t * 0.5 + ph) + 0.1 * root.energy
            transformOrigin: Item.Center
            x: modelData[1] * (root.width - width) + Math.sin(root.t * sp * 0.6 + ph) * 26
            y: modelData[2] * (root.height - height) + Math.cos(root.t * sp * 0.5 + ph * 1.3) * 20
                 - root.energy * Math.abs(Math.sin(root.t * 3 + ph)) * 12
            rotation: kind === "dot" ? 0 : Math.sin(root.t * sp * 0.7 + ph) * (6 + root.energy * 8)
            scale: 1 + 0.05 * Math.sin(root.t * 1.4 + ph) + root.energy * 0.07
        }
    }
}
