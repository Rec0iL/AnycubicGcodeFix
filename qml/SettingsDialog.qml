import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs

Popup {
    id: dlg
    property Item bgSource: null
    readonly property var s: backend.settings
    readonly property var swatches: ["#FF7A1A", "#212721", "#F2F2F2", "#E5484D", "#2F80ED", "#17A99B", "#F5C518", "#8E5BD9"]

    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    dim: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(560, (parent ? parent.width : 560) - 40)
    height: Math.min(col.implicitHeight + 64, (parent ? parent.height : 700) - 40)

    Overlay.modal: Rectangle { color: Qt.rgba(0.06, 0.08, 0.12, 0.40) }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 320; easing.type: Easing.OutBack }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 150 } }

    FolderDialog {
        id: outPicker
        title: "Choose output folder"
        onAccepted: {
            backend.setSetting("customDir", backend.toLocalPath(selectedFolder.toString()))
            backend.setSetting("outputMode", "custom")
        }
    }

    background: Item {}
    contentItem: GlassCard {
        source: dlg.bgSource
        tintAlpha: 1.0
        blurred: false

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Settings"
                    font.pixelSize: 24; font.weight: Font.Bold; font.family: Theme.font; color: Theme.text
                    Layout.fillWidth: true
                }
                PillButton { label: "Done"; primary: true; onClicked: dlg.close() }
            }

            component Row_: RowLayout {
                id: rr
                property string title: ""
                property string hint: ""
                default property alias controls: holder.data
                Layout.fillWidth: true
                Layout.preferredWidth: 100000
                spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { text: rr.title; font.pixelSize: 15; font.weight: Font.DemiBold
                           font.family: Theme.font; color: Theme.text }
                    Text { visible: rr.hint !== ""; text: rr.hint; font.pixelSize: 12
                           font.family: Theme.font; color: Theme.textSoft; wrapMode: Text.WordWrap
                           Layout.fillWidth: true }
                }
                Row { id: holder; spacing: 8 }
            }

            Row_ {
                title: "Appearance"
                hint: dlg.s.theme === "auto" ? "Following your system theme" : ""
                Segmented {
                    model: ["Auto", "Light", "Dark"]
                    currentIndex: ["auto", "light", "dark"].indexOf(dlg.s.theme)
                    onActivated: (i) => backend.setSetting("theme", ["auto", "light", "dark"][i])
                }
            }
            Row_ {
                title: "Filament"
                hint: dlg.s.material === "auto" ? "Auto = read from the file, else guessed from its nozzle temperature"
                                                : "Used for the header, density and default temperatures"
                Segmented {
                    model: ["Auto", "PLA", "PETG", "ABS", "TPU"]
                    currentIndex: ["auto", "PLA", "PETG", "ABS", "TPU"].indexOf(dlg.s.material)
                    onActivated: (i) => backend.setSetting("material", ["auto", "PLA", "PETG", "ABS", "TPU"][i])
                }
            }
            Row_ {
                title: "Filament colour"
                hint: "Shown on the printer's screen"
                Row {
                    spacing: 7
                    Repeater {
                        model: dlg.swatches
                        delegate: Rectangle {
                            required property string modelData
                            width: 24; height: 24; radius: 12
                            color: modelData
                            border.width: dlg.s.color.toLowerCase() === modelData.toLowerCase() ? 3 : 1
                            border.color: dlg.s.color.toLowerCase() === modelData.toLowerCase() ? Theme.text : Theme.fieldBorder
                            scale: sw.containsMouse ? 1.15 : 1
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            MouseArea { id: sw; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setSetting("color", modelData) }
                        }
                    }
                }
            }
            Row_ {
                title: "Keep the file's temperatures"
                hint: "Off = always use Anycubic's defaults for the filament"
                PillSwitch { checked: dlg.s.useFileTemps; onToggled: (v) => backend.setSetting("useFileTemps", v) }
            }
            Row_ {
                title: "Pressure advance (M900)"
                hint: "Same K value Anycubic's own PLA / PETG profiles use"
                PillSwitch { checked: dlg.s.pressureAdvance; onToggled: (v) => backend.setSetting("pressureAdvance", v) }
            }
            Row_ {
                title: "Add Anycubic's purge line"
                hint: "Leave off if the file already primes the nozzle itself"
                PillSwitch { checked: dlg.s.purgeLine; onToggled: (v) => backend.setSetting("purgeLine", v) }
            }
            Row_ {
                title: "Save to"
                hint: dlg.s.outputMode === "custom" && dlg.s.customDir !== "" ? dlg.s.customDir
                                                                               : "Right next to the original"
                Segmented {
                    model: ["Source folder", "Custom"]
                    currentIndex: dlg.s.outputMode === "custom" ? 1 : 0
                    onActivated: (i) => {
                        if (i === 1 && dlg.s.customDir === "") outPicker.open()
                        else backend.setSetting("outputMode", i === 1 ? "custom" : "source")
                    }
                }
                PillButton { visible: dlg.s.outputMode === "custom"; label: "Browse…"; onClicked: outPicker.open() }
            }
            Row_ {
                title: "If the output already exists"
                Segmented {
                    model: ["Rename", "Overwrite"]
                    currentIndex: dlg.s.overwrite === "overwrite" ? 1 : 0
                    onActivated: (i) => backend.setSetting("overwrite", i === 1 ? "overwrite" : "rename")
                }
            }
            Row_ {
                title: "Low-power background"
                hint: "Calmer shader, no specks - easier on the GPU."
                PillSwitch { checked: dlg.s.lowPower; onToggled: (v) => backend.setSetting("lowPower", v) }
            }
            Row_ {
                title: "Support the project"
                hint: "Free & open source - a coffee keeps it going"
                PillButton { label: "GitHub"; onClicked: backend.openRepo() }
                PillButton { label: "♥  Ko-fi"; primary: true; onClicked: backend.openKofi() }
            }
        }
    }
}
