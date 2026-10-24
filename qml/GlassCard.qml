import QtQuick
import QtQuick.Effects

// Frosted-glass panel. Blurs `source` (the animated background) behind itself.
Item {
    id: card
    property Item source: null
    property real radius: 26
    property real tintAlpha: 0.38
    property bool blurred: true
    property real blurAmount: 1.0
    property int blurMax: 40
    default property alias content: inner.data

    ShaderEffectSource {
        id: ses
        visible: false
        sourceItem: card.blurred ? card.source : null
        live: true
        anchors.fill: parent
        sourceRect: Qt.rect(0, 0, card.width, card.height)
    }
    // sourceRect must follow the card when it (or an ancestor) moves.
    FrameAnimation {
        running: card.blurred && card.visible && card.source !== null
        onTriggered: {
            const p = card.mapToItem(card.source, 0, 0)
            ses.sourceRect = Qt.rect(p.x, p.y, card.width, card.height)
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: card.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: card.blurred
        source: ses
        blurEnabled: true
        blurMax: card.blurMax
        blur: card.blurAmount
        saturation: 0.15
        maskEnabled: true
        maskSource: mask
    }
    Rectangle {
        anchors.fill: parent
        radius: card.radius
        color: Theme.glass(card.tintAlpha)
        border.width: 1
        border.color: Theme.glassBorder
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.glass(card.tintAlpha + 0.14) }
            GradientStop { position: 1.0; color: Theme.glass(card.tintAlpha - 0.06) }
        }
    }
    Item { id: inner; anchors.fill: parent }
}
