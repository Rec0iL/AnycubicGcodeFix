import QtQuick
import QtQuick.Shapes

// Floating background shapes with a 3D-printing theme.
// kind: cube | spool | layers | nozzle | dot
Item {
    id: d
    property string kind: "cube"
    property real size: 60
    property bool alt: false            // use the teal tint instead of orange
    readonly property color tint: alt ? Theme.decor2 : Theme.decor
    width: size; height: size

    Item {
        width: 100; height: 100
        scale: d.size / 100
        transformOrigin: Item.TopLeft

        // ---- isometric cube
        Shape {
            visible: d.kind === "cube"
            ShapePath { strokeColor: Qt.alpha(d.tint, 0.85); strokeWidth: 3.5; joinStyle: ShapePath.RoundJoin
                        fillColor: Qt.alpha(d.tint, 0.50); PathSvg { path: "M 50 8 L 90 30 L 50 52 L 10 30 Z" } }
            ShapePath { strokeColor: Qt.alpha(d.tint, 0.85); strokeWidth: 3.5; joinStyle: ShapePath.RoundJoin
                        fillColor: Qt.alpha(d.tint, 0.30); PathSvg { path: "M 10 30 L 50 52 L 50 94 L 10 72 Z" } }
            ShapePath { strokeColor: Qt.alpha(d.tint, 0.85); strokeWidth: 3.5; joinStyle: ShapePath.RoundJoin
                        fillColor: Qt.alpha(d.tint, 0.18); PathSvg { path: "M 90 30 L 50 52 L 50 94 L 90 72 Z" } }
        }
        // ---- filament spool
        Item {
            visible: d.kind === "spool"
            Repeater {
                model: [[88, 0.16], [68, 0.26], [48, 0.16]]
                delegate: Rectangle {
                    required property var modelData
                    width: modelData[0]; height: width; radius: width / 2
                    x: 50 - width / 2; y: 50 - height / 2
                    color: Qt.alpha(d.tint, modelData[1])
                    border.width: 3.5; border.color: Qt.alpha(d.tint, 0.8)
                }
            }
            Rectangle { x: 41; y: 41; width: 18; height: 18; radius: 9; color: "transparent"
                        border.width: 3.5; border.color: Qt.alpha(d.tint, 0.85) }
        }
        // ---- stacked layers
        Item {
            visible: d.kind === "layers"
            Repeater {
                model: [[16, 8, 76], [38, 4, 84], [60, 0, 92]]
                delegate: Rectangle {
                    required property var modelData
                    x: modelData[1]; y: modelData[0]; width: modelData[2]; height: 18; radius: 9
                    color: Qt.alpha(d.tint, 0.38)
                    border.width: 3.5; border.color: Qt.alpha(d.tint, 0.85)
                }
            }
        }
        // ---- nozzle with a drop
        Shape {
            visible: d.kind === "nozzle"
            ShapePath { strokeColor: Qt.alpha(d.tint, 0.85); strokeWidth: 3.5; joinStyle: ShapePath.RoundJoin
                        fillColor: Qt.alpha(d.tint, 0.30)
                        PathSvg { path: "M 28 6 L 72 6 L 72 30 L 28 30 Z M 36 30 L 64 30 L 55 60 L 50 72 L 45 60 Z" } }
            ShapePath { strokeColor: Qt.alpha(d.tint, 0.85); strokeWidth: 3.5
                        fillColor: Qt.alpha(d.tint, 0.55)
                        PathSvg { path: "M 50 80 Q 60 92 50 98 Q 40 92 50 80 Z" } }
        }
        // ---- bokeh dot
        Rectangle {
            visible: d.kind === "dot"
            x: 10; y: 10; width: 80; height: 80; radius: 40
            color: Qt.alpha(d.tint, 0.28)
            border.width: 4; border.color: Qt.alpha(d.tint, 0.5)
        }
    }
}
