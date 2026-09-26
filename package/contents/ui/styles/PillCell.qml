import QtQuick
import "../logic.js" as Logic

// Pill style: one marker per desktop (pill, circle, square, diamond or bar). Size,
// color and opacity follow the highlight weight, so the active shape slides from
// one desktop to the next as the highlight moves.
Item {
    id: cell

    required property int index
    required property var modelData
    required property var indicator

    readonly property var s: indicator.settings
    readonly property real weight: indicator.weightOf(index)
    readonly property var geo: Logic.markerGeometryAt(s.pillShape, weight, {
        width: s.pillWidth,
        height: s.pillHeight,
        activeWidth: s.pillActiveWidth,
        activeHeight: s.pillActiveHeight,
        radius: s.pillRadius
    })

    implicitWidth: geo.width
    implicitHeight: geo.height

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: cell.geo.innerWidth
        height: cell.geo.innerHeight
        radius: Math.min(cell.geo.radius, width / 2, height / 2)
        rotation: cell.geo.rotation
        color: cell.indicator.mix(cell.indicator.inactiveColor, cell.indicator.activeColor, cell.weight)
        opacity: Logic.lerp(cell.indicator.inactiveOpacity, 1, cell.weight)
    }

    // Outline on desktops that hold windows, drawn inside the marker so every
    // marker keeps the same size. A sibling of the marker so it keeps full opacity
    // while the marker is dimmed; it fades out as the desktop becomes active.
    Rectangle {
        anchors.centerIn: parent
        width: pill.width
        height: pill.height
        radius: pill.radius
        rotation: pill.rotation
        visible: cell.s.markOccupied && cell.modelData.occupied
        color: "transparent"
        border.width: Math.max(1, Math.min(2, Math.min(width, height) / 6))
        border.color: cell.indicator.occupiedColor
        opacity: 0.9 * (1 - cell.weight)
    }
}
