pragma Singleton
import QtQuick 2.12

QtObject {
    readonly property bool dark: backend.darkMode
    readonly property color background: dark ? "#18211D" : "#F6F8F4"
    readonly property color sidebar: dark ? "#1D2923" : "#FFFFFF"
    readonly property color surface: dark ? "#24312A" : "#FFFFFF"
    readonly property color surfaceMuted: dark ? "#293B31" : "#F0F3EF"
    readonly property color text: dark ? "#E9F0EB" : "#23372E"
    readonly property color muted: dark ? "#A0B1A6" : "#7C9083"
    readonly property color border: dark ? "#3A4B40" : "#E2E9E2"
    readonly property color accent: dark ? "#82B399" : "#426E59"
    readonly property color accentText: dark ? "#18271E" : "#FFFFFF"
    readonly property color accentSoft: dark ? "#355143" : "#E8F2EB"
    readonly property color warning: dark ? "#EAC18E" : "#A66D32"
    readonly property color warningSoft: dark ? "#433425" : "#FFF1E4"
    readonly property color danger: dark ? "#F3A9A2" : "#AE534A"
    readonly property color disabled: dark ? "#71847A" : "#A5B3A8"
}
