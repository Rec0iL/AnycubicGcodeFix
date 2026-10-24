pragma Singleton
import QtQuick

// Light / dark palette. Everything is derived from `night` (0..1) which animates,
// so switching themes cross-fades the whole UI and the shader background.
// Colours: filament orange + teal on a warm "build plate" / dark slate base.
QtObject {
    id: theme

    // "auto" follows the desktop colour scheme; set from Main.qml (settings.theme)
    property string mode: "auto"
    readonly property bool systemDark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property bool dark: mode === "dark" || (mode === "auto" && systemDark)

    property real night: dark ? 1 : 0
    Behavior on night { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }

    function mix(a, b, t) {
        const ca = Qt.color(a), cb = Qt.color(b)
        return Qt.rgba(ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t,
                       ca.b + (cb.b - ca.b) * t, ca.a + (cb.a - ca.a) * t)
    }
    // frosted surface: white-ish in light mode, deep slate in dark mode
    function glass(alpha) {
        const base = mix("#ffffff", "#172030", night)
        return Qt.rgba(base.r, base.g, base.b, Math.max(0, Math.min(1, alpha + night * 0.12)))
    }
    function edge(alpha) {
        return Qt.rgba(1, 1, 1, alpha * (1 - night * 0.72))
    }

    readonly property color windowBg: mix("#f6e4d0", "#0f141c", night)
    readonly property color text: mix("#2b3547", "#eef3fb", night)
    readonly property color textSoft: mix("#66758c", "#9fb0c8", night)
    readonly property color accent: mix("#ff7a1a", "#ff8f3a", night)     // filament orange
    readonly property color accent2: mix("#ffb347", "#ffc46b", night)    // warm amber
    readonly property color teal: mix("#17a99b", "#3fd9c6", night)
    readonly property color ok: mix("#17a99b", "#3fd9c6", night)
    readonly property color warn: mix("#d98a00", "#ffcc4d", night)
    readonly property color danger: mix("#e5484d", "#ff7075", night)
    readonly property color dangerBg: mix("#ffdcdd", "#4a2024", night)
    readonly property color glassBorder: edge(0.70)
    // inset controls (segmented pills, buttons) must stay visible on near-opaque dialogs too
    readonly property color field: mix(Qt.rgba(0.17, 0.21, 0.28, 0.07), Qt.rgba(1, 1, 1, 0.06), night)
    readonly property color fieldBorder: mix(Qt.rgba(0.17, 0.21, 0.28, 0.22), Qt.rgba(1, 1, 1, 0.20), night)
    readonly property color decor: mix("#e0701a", "#ff9a52", night)       // floating background shapes
    readonly property color decor2: mix("#17a99b", "#3fd9c6", night)
    readonly property color metal: mix("#8d99ab", "#b6c2d4", night)

    readonly property string font: "Noto Sans"
    readonly property string mono: "Noto Sans Mono"
}
