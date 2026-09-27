import QtQuick
import "../logic.js" as Logic

// Shared frame for the label, icon and task styles: Kara-like highlight
// (full, square, line, full + line) plus the "occupied" dot.
Item {
    id: frame

    required property int index
    required property var modelData
    required property var indicator

    property bool showOccupiedDot: true
    property real contentWidth: 0
    // Height of the centered label or icon, the dot sits under it.
    property real contentHeight: 0
    default property alias content: contentArea.data

    readonly property var s: indicator.settings
    // 0..1, how close the moving highlight is to this desktop.
    readonly property real weight: indicator.weightOf(index)
    readonly property bool active: weight > 0.5
    // Color and opacity for whatever the style draws inside the frame.
    readonly property color foreground: indicator.highlightFills
        ? indicator.mix(indicator.textColor, indicator.activeTextColor, weight)
        : indicator.textColor
    readonly property real foregroundOpacity: Logic.lerp(indicator.inactiveOpacity, 1, weight)

    readonly property var geo: Logic.cellGeometry(s.cellShape, contentWidth, s.cellWidth, s.cellHeight, s.cellRadius)

    implicitWidth: geo.width
    implicitHeight: geo.height

    // Full (0), or dimmed full under a line (3).
    Rectangle {
        anchors.fill: parent
        visible: frame.s.highlight === 0 || frame.s.highlight === 3
        radius: frame.geo.radius
        color: frame.indicator.activeColor
        opacity: frame.weight * (frame.s.highlight === 3 ? 0.35 : 1)
    }

    // Square (1).
    Rectangle {
        anchors.centerIn: parent
        visible: frame.s.highlight === 1
        // Grows with wide content (names) so the text stays inside; stays square for circles.
        readonly property real wanted: Math.max(frame.s.squareSize, frame.contentWidth + 10)
        width: frame.s.cellShape === 1 ? Math.min(wanted, parent.width, parent.height) : Math.min(wanted, parent.width)
        height: frame.s.cellShape === 1 ? width : Math.min(frame.s.squareSize, parent.height)
        radius: Logic.shapeRadius(frame.s.cellShape, width, height, frame.s.cellRadius)
        color: frame.indicator.activeColor
        opacity: frame.weight
        scale: 0.6 + 0.4 * frame.weight
    }

    // Line (2) or line over a dimmed full (3).
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        visible: frame.s.highlight === 2 || frame.s.highlight === 3
        width: Math.min(frame.s.lineWidth, parent.width) * frame.weight
        height: frame.s.lineHeight
        radius: height / 2
        color: frame.indicator.activeColor
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Logic.markY(frame.height, frame.contentHeight, frame.s.markOffset)
        visible: frame.showOccupiedDot && frame.s.markOccupied && frame.modelData.occupied
        width: frame.s.markSize
        height: frame.s.markSize
        radius: frame.s.markSize / 2
        color: frame.indicator.occupiedColor
        opacity: Math.max(0, Math.min(100, frame.s.markOpacity)) / 100 * (1 - frame.weight)
    }

    Item {
        id: contentArea
        anchors.fill: parent
    }
}
