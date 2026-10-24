import QtQuick
import QtQuick.Shapes

// Big dashed drop target. Shrinks to a compact strip when the queue has items.
Item {
    id: zone
    property bool hovering: false
    property bool compact: false
    property string mood: "idle"
    signal browseFiles()
    signal browseFolder()

    readonly property int pad: 14

    Shape {
        anchors.fill: parent
        anchors.margins: zone.pad
        ShapePath {
            strokeColor: Qt.alpha(Theme.accent, zone.hovering ? 1.0 : 0.75)
            strokeWidth: zone.hovering ? 4 : 3
            fillColor: zone.hovering ? Qt.alpha(Theme.accent, 0.14) : "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [3, 3]
            capStyle: ShapePath.RoundCap
            PathRectangle {
                x: 0; y: 0
                width: zone.width - zone.pad * 2
                height: zone.height - zone.pad * 2
                radius: 22
            }
            NumberAnimation on dashOffset {
                from: 0; to: 6
                duration: zone.hovering ? 500 : 1800
                loops: Animation.Infinite
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: zone.browseFiles()
    }

    // ---- big layout ----------------------------------------------------------
    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: !zone.compact
        opacity: zone.compact ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Mascot {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 120
            mood: zone.mood
            excited: zone.hovering
            scale: zone.hovering ? 1.12 : 1.0
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: zone.hovering ? "Let go, I'll catch it!" : "Drop G-code here"
            font.pixelSize: 28
            font.weight: Font.Bold
            font.family: Theme.font
            color: Theme.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: "I re-wrap files from FullControl, Orca, Prusa, Cura… so your Anycubic accepts them"
            font.pixelSize: 14
            font.family: Theme.font
            color: Theme.textSoft
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ".gcode  .gco  ·  files or folders  ·  or click to browse"
            font.pixelSize: 12
            font.family: Theme.mono
            color: Theme.textSoft
            opacity: 0.8
        }
        PillButton {
            anchors.horizontalCenter: parent.horizontalCenter
            label: "Browse folder…"
            onClicked: zone.browseFolder()
        }
    }

    // ---- compact layout ------------------------------------------------------
    Row {
        anchors.centerIn: parent
        spacing: 14
        visible: zone.compact
        opacity: zone.compact ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Mascot {
            anchors.verticalCenter: parent.verticalCenter
            size: 50
            mood: zone.mood
            excited: zone.hovering
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: zone.hovering ? "Drop to add more!" : "Drop more G-code, or click to browse"
            font.pixelSize: 16; font.weight: Font.DemiBold; font.family: Theme.font
            color: Theme.text
        }
        PillButton {
            anchors.verticalCenter: parent.verticalCenter
            label: "Folder…"
            onClicked: zone.browseFolder()
        }
    }
}
