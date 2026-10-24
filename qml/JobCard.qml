import QtQuick
import QtQuick.Layouts

// One row in the queue.
Item {
    id: card
    required property int jobId
    required property string name
    required property string source
    required property string sourceDir
    required property string output
    required property real progress
    required property string status
    required property string message
    required property string warning
    required property string thumb
    required property int index

    width: ListView.view ? ListView.view.width : 400
    height: 84

    // pop-in
    opacity: 0
    scale: 0.94
    Component.onCompleted: appear.start()
    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 320 }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack }
    }

    readonly property bool finished: status === "done" || status === "error" || status === "skipped"
    readonly property color barFrom: status === "skipped" ? Qt.alpha(Theme.textSoft, 0.5) : status === "error" ? "#ff9a9d" : status === "done" ? Theme.teal : Theme.accent
    readonly property color barTo: status === "skipped" ? Qt.alpha(Theme.textSoft, 0.35) : status === "error" ? Theme.danger : status === "done" ? "#8fe9d3" : Theme.accent2

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 8
        radius: 20
        color: Theme.glass(0.52)
        border.width: 1
        border.color: card.status === "error" ? Qt.alpha(Theme.danger, 0.8)
                    : card.warning !== "" ? Qt.alpha(Theme.warn, 0.8) : Theme.glassBorder

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14; anchors.rightMargin: 12
            spacing: 14

            // status: mascot while waiting / working / failing, the generated preview when done
            Rectangle {
                Layout.preferredWidth: 96; Layout.preferredHeight: 54
                radius: 14
                color: Qt.rgba(0.1, 0.13, 0.19, card.thumb !== "" ? 0.55 : 0.0)
                border.width: card.thumb !== "" ? 1 : 0
                border.color: Theme.fieldBorder
                clip: true
                Image {
                    anchors.fill: parent; anchors.margins: 2
                    visible: card.thumb !== ""
                    source: card.thumb
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Mascot {
                    visible: card.thumb === ""
                    anchors.centerIn: parent
                    size: 38
                    mood: card.status === "working" ? "working" : card.status === "error" ? "error" : "idle"
                    opacity: card.status === "queued" ? 0.55 : 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    Layout.fillWidth: true
                    text: card.name
                    elide: Text.ElideMiddle
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    font.family: Theme.font
                    color: Theme.text
                }
                GlowBar {
                    Layout.fillWidth: true
                    value: card.status === "queued" ? 0 : card.progress
                    active: card.status === "working"
                    from: card.barFrom
                    to: card.barTo
                }
                Text {
                    Layout.fillWidth: true
                    text: card.warning !== "" ? "⚠ " + card.warning
                          : card.finished ? card.message + (card.output ? "  ·  → " + card.output.split("/").pop() : "")
                          : card.message + "  ·  from " + card.sourceDir
                    elide: Text.ElideMiddle
                    font.pixelSize: 12
                    font.family: Theme.font
                    color: card.status === "error" ? Theme.danger : card.warning !== "" ? Theme.warn : Theme.textSoft
                }
            }

            Text {
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                text: card.status === "done" ? "✓" : card.status === "error" ? "!" :
                      card.status === "skipped" ? "–" : Math.round(card.progress * 100) + "%"
                font.pixelSize: 15
                font.weight: Font.Bold
                font.family: Theme.font
                color: card.status === "done" ? Theme.ok : card.status === "error" ? Theme.danger : Theme.textSoft
            }

            Item {   // reveal in file manager
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                Rectangle {
                    anchors.fill: parent; radius: 15
                    color: Theme.glass(revealMa.containsMouse ? 0.8 : 0.4)
                }
                Text { anchors.centerIn: parent; text: "↗"; font.pixelSize: 16; color: Theme.text }
                MouseArea {
                    id: revealMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.reveal(card.output !== "" ? card.output : card.source)
                }
            }
            Item {   // remove
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                opacity: card.status === "working" ? 0.3 : 1
                Rectangle {
                    anchors.fill: parent; radius: 15
                    color: Theme.glass(rmMa.containsMouse ? 0.8 : 0.4)
                }
                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; color: Theme.text }
                MouseArea {
                    id: rmMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.removeJob(card.jobId)
                }
            }
        }
    }
}
