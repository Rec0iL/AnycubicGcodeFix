import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: win
    visible: true
    width: 1040
    height: 740
    minimumWidth: 1000
    minimumHeight: 680
    title: "Anycubic GcodeFix"
    color: Theme.windowBg

    readonly property var s: backend.settings
    Binding { target: Theme; property: "mode"; value: win.s.theme }
    readonly property bool hasJobs: backend.jobCount > 0
    readonly property var materials: ["auto", "PLA", "PETG", "ABS", "TPU"]

    // --- background ------------------------------------------------------------
    Background {
        id: bg
        anchors.fill: parent
        lowPower: win.s.lowPower
        energy: drop.containsDrag ? 1.0 : backend.busy ? 0.55 : 0.0
    }

    // --- whole window accepts drops -------------------------------------------
    DropArea {
        id: drop
        anchors.fill: parent
        onDropped: (ev) => {
            if (ev.hasUrls) backend.addUrls(ev.urls.map(u => u.toString()))
        }
    }

    FileDialog {
        id: filePicker
        title: "Choose G-code files"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["G-code (*.gcode *.gco *.gc *.g)", "All files (*)"]
        currentFolder: backend.toFileUrl(win.s.lastDir)
        onAccepted: backend.addUrls(selectedFiles.map(u => u.toString()))
    }
    FolderDialog {
        id: folderPicker
        title: "Choose a folder with G-code"
        currentFolder: backend.toFileUrl(win.s.lastDir)
        onAccepted: backend.addUrls([selectedFolder.toString()])
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 16

        // ---- header ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Mascot {
                size: 46
                mood: backend.mascotState
                excited: drop.containsDrag
                Layout.preferredWidth: 46
                Layout.preferredHeight: 55
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: -2
                Text {
                    text: "Anycubic GcodeFix"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    font.family: Theme.font
                    color: Theme.text
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: "G-code your Kobra S1 accepts"
                    font.pixelSize: 12
                    font.family: Theme.mono
                    color: Theme.textSoft
                }
            }
            Text {
                text: "Filament"
                font.pixelSize: 13; font.weight: Font.DemiBold; font.family: Theme.font
                color: Theme.textSoft
            }
            Segmented {
                model: ["Auto", "PLA", "PETG", "ABS", "TPU"]
                currentIndex: Math.max(0, win.materials.indexOf(win.s.material))
                onActivated: (i) => backend.setSetting("material", win.materials[i])
            }
            PillButton {
                label: Theme.dark ? "☀" : "☾"
                fontSize: 18
                implicitWidth: 44
                onClicked: backend.setSetting("theme", Theme.dark ? "light" : "dark")
            }
            PillButton { label: "History"; onClicked: history.open() }
            PillButton { label: "⚙"; fontSize: 18; implicitWidth: 44; tip: "Settings"; onClicked: settings.open() }
            PillButton {
                label: "♥"; fontSize: 18; implicitWidth: 44
                labelColor: Theme.accent
                tip: "Like it? Support on Ko-fi"
                onClicked: backend.openKofi()
            }
        }

        // ---- main area -------------------------------------------------------
        Item {
            id: area
            Layout.fillWidth: true
            Layout.fillHeight: true

            GlassCard {
                id: zoneCard
                source: bg
                tintAlpha: win.hasJobs ? 0.34 : 0.22
                blurAmount: 0.45
                blurMax: 24
                width: parent.width
                height: win.hasJobs ? 120 : area.height
                Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                DropZone {
                    anchors.fill: parent
                    hovering: drop.containsDrag
                    compact: win.hasJobs
                    mood: backend.mascotState
                    onBrowseFiles: filePicker.open()
                    onBrowseFolder: folderPicker.open()
                }
            }

            ListView {
                id: queue
                anchors.top: zoneCard.bottom
                anchors.topMargin: 14
                anchors.bottom: footer.top
                anchors.bottomMargin: 6
                width: parent.width
                clip: true
                model: backend.jobs
                visible: win.hasJobs
                spacing: 0
                boundsBehavior: Flickable.StopAtBounds
                delegate: JobCard {}
                add: Transition { NumberAnimation { property: "opacity"; to: 1; duration: 250 } }
                displaced: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }
                remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 200 } }
            }

            // ---- footer: overall progress ------------------------------------
            Item {
                id: footer
                anchors.bottom: parent.bottom
                width: parent.width
                height: win.hasJobs ? 52 : 0
                visible: win.hasJobs
                opacity: win.hasJobs ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Rectangle {
                    anchors.fill: parent
                    radius: 26
                    color: Theme.glass(0.5)
                    border.width: 1
                    border.color: Theme.glassBorder
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 8
                    spacing: 14
                    Text {
                        text: backend.doneCount + " / " + backend.jobCount
                        font.pixelSize: 15; font.weight: Font.Bold; font.family: Theme.mono
                        color: Theme.text
                    }
                    GlowBar {
                        Layout.fillWidth: true
                        implicitHeight: 14
                        value: backend.overallProgress
                        active: backend.busy
                        from: Theme.accent
                        to: Theme.accent2
                    }
                    Text {
                        text: Math.round(backend.overallProgress * 100) + "%"
                        font.pixelSize: 15; font.weight: Font.Bold; font.family: Theme.mono
                        color: Theme.textSoft
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignRight
                    }
                    PillButton { label: "Clear finished"; fontSize: 13; implicitHeight: 34; onClicked: backend.clearFinished() }
                }
            }
        }
    }

    // ---- toast -----------------------------------------------------------------
    Rectangle {
        id: toast
        property alias text: toastText.text
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 90 + (shown ? 0 : 30)
        opacity: shown ? 1 : 0
        property bool shown: false
        width: toastText.implicitWidth + 40
        height: 42
        radius: 21
        color: Qt.rgba(0.11, 0.14, 0.2, 0.94)
        border.width: 1
        border.color: Qt.alpha(Theme.accent, 0.6)
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
        Text {
            id: toastText
            anchors.centerIn: parent
            color: "white"; font.pixelSize: 14; font.family: Theme.font
        }
        Timer { id: toastTimer; interval: 3500; onTriggered: toast.shown = false }
    }
    Connections {
        target: backend
        function onToast(msg) { toast.text = msg; toast.shown = true; toastTimer.restart() }
    }

    // ---- dialogs ---------------------------------------------------------------
    SettingsDialog { id: settings; objectName: "settingsDlg"; bgSource: bg }
    HistoryDialog { id: history; bgSource: bg }
}
