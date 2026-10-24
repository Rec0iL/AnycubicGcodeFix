import QtQuick
import QtQuick.Shapes

// "Nozzle-bot": a little print head with a visor face and a drip of filament.
// mood: idle | working | done | error     excited: bigger eyes + faster bounce (drag hover)
Item {
    id: m
    property string mood: "idle"
    property bool excited: false
    property real size: 100
    width: size
    height: size * 1.2

    readonly property color eyeColor: "#7ff3e3"
    readonly property color visorColor: "#1b2433"

    // blink timer drives the eyes' vertical scale
    property real blink: 1.0
    SequentialAnimation on blink {
        running: m.mood === "idle" || m.mood === "done"
        loops: Animation.Infinite
        PauseAnimation { duration: 2600 }
        NumberAnimation { to: 0.08; duration: 90 }
        NumberAnimation { to: 1.0; duration: 120 }
        PauseAnimation { duration: 900 }
        NumberAnimation { to: 0.08; duration: 90 }
        NumberAnimation { to: 1.0; duration: 120 }
    }
    // scanning look while working
    property real look: 0
    SequentialAnimation on look {
        running: m.mood === "working"
        loops: Animation.Infinite
        NumberAnimation { to: 5; duration: 650; easing.type: Easing.InOutSine }
        NumberAnimation { to: -5; duration: 1300; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 650; easing.type: Easing.InOutSine }
    }
    onMoodChanged: if (mood !== "working") look = 0

    Item {
        id: art
        width: 100; height: 120
        scale: m.size / 100
        transformOrigin: Item.TopLeft

      Item {
        id: body
        width: 100; height: 120
        transformOrigin: Item.Center
        property real bob: 0
        y: bob
        SequentialAnimation on bob {
            loops: Animation.Infinite
            running: true
            NumberAnimation { to: m.mood === "working" ? -3 : (m.excited ? -9 : -4)
                              duration: m.mood === "working" ? 200 : (m.excited ? 280 : 1100)
                              easing.type: Easing.InOutSine }
            NumberAnimation { to: 0
                              duration: m.mood === "working" ? 200 : (m.excited ? 280 : 1100)
                              easing.type: Easing.InOutSine }
        }
        rotation: m.mood === "error" ? -4 : 0

        // heat block + nozzle
        Rectangle { x: 33; y: 76; width: 34; height: 14; radius: 4; color: Theme.metal
                    border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.15) }
        Shape {
            ShapePath {
                fillColor: Theme.metal
                strokeColor: Qt.rgba(0, 0, 0, 0.15)
                strokeWidth: 1
                PathSvg { path: "M 40 88 L 60 88 L 55 103 L 52.5 109 L 47.5 109 L 45 103 Z" }
            }
        }
        // filament drip
        Rectangle {
            id: drop
            x: 46.5; width: 7; height: 10; radius: 3.5
            color: Theme.accent
            visible: m.mood === "working"
            property real fall: 0
            y: 108 + fall
            opacity: 1 - fall / 16
            NumberAnimation on fall { from: 0; to: 16; duration: 800; loops: Animation.Infinite
                                      running: m.mood === "working"; easing.type: Easing.InQuad }
        }

        // body
        Rectangle {
            x: 6; y: 4; width: 88; height: 78; radius: 26
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.45)
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.accent2 }
                GradientStop { position: 1; color: Theme.accent }
            }
        }
        Rectangle { x: 20; y: 10; width: 38; height: 7; radius: 3.5; color: "white"; opacity: 0.35 }

        // visor
        Rectangle {
            x: 15; y: 22; width: 70; height: 46; radius: 21
            color: m.visorColor
            border.width: 1.5; border.color: Qt.rgba(0, 0, 0, 0.25)
        }

        // eyes (round)
        Repeater {
            model: [32, 57]
            delegate: Rectangle {
                required property int modelData
                visible: m.mood === "idle" || m.mood === "working"
                x: modelData + m.look; y: 32
                width: 11; height: 15; radius: 5.5
                color: m.eyeColor
                transformOrigin: Item.Center
                scale: 1
                // squint while working, widen when excited
                property real ys: m.mood === "working" ? 0.55 : (m.excited ? 1.2 : 1.0)
                transform: Scale { origin.y: 7.5; yScale: parent ? (ys * m.blink) : 1 }
                Rectangle { x: 5.5; y: 2.5; width: 3.5; height: 3.5; radius: 1.75; color: "white"; opacity: 0.9 }
            }
        }
        // happy eyes ^ ^
        Repeater {
            model: [31, 56]
            delegate: Shape {
                required property int modelData
                visible: m.mood === "done"
                x: modelData; y: 34
                ShapePath {
                    strokeColor: m.eyeColor; strokeWidth: 3.5; capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M 1 11 Q 7.5 -1 14 11" }
                }
            }
        }
        // error eyes x x
        Repeater {
            model: [31, 56]
            delegate: Shape {
                required property int modelData
                visible: m.mood === "error"
                x: modelData; y: 33
                ShapePath {
                    strokeColor: Theme.danger; strokeWidth: 3.5; capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M 1 1 L 13 13 M 13 1 L 1 13" }
                }
            }
        }

        // mouth
        Shape {
            x: 41; y: 52
            ShapePath {
                strokeColor: m.eyeColor; strokeWidth: 3; capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathSvg {
                    path: m.mood === "error" ? "M 1 7 Q 9 -1 17 7"
                        : m.mood === "done" || m.excited ? "M 0 0 Q 9 13 18 0"
                        : m.mood === "working" ? "M 3 3 L 15 3"
                        : "M 2 1 Q 9 8 16 1"
                }
            }
        }
        // cheeks
        Rectangle { x: 19; y: 50; width: 10; height: 6; radius: 3; color: Theme.accent; opacity: 0.6 }
        Rectangle { x: 71; y: 50; width: 10; height: 6; radius: 3; color: Theme.accent; opacity: 0.6 }
      }
    }
}
