pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.ksvg as KSvg
import "styles"
import "logic.js" as Logic

// Rendering only: no KWin dependency, so it can also be previewed outside KWin.
Item {
    id: root

    property var settings
    // Entries from Logic.desktopInfo(): { id, name, occupied, icons, extra }.
    property var desktops: []
    property int currentIndex: 0
    property int columns: 1
    // Grid position of the highlight (column, row). Between cells while it moves:
    // each desktop shows as active in proportion to how close the highlight is.
    // Follows currentIndex unless the OSD drives it (animations, swipe gestures).
    property point highlight: {
        const p = Logic.gridPoint(currentIndex, columns);
        return Qt.point(p.x, p.y);
    }

    // "Once the switch is done" motion: a cross-fade from fromIndex to currentIndex
    // driven by crossProgress, instead of the moving highlight point.
    readonly property bool crossfade: s.highlightMotion === 1
    property int fromIndex: currentIndex
    property real crossProgress: 1

    function weightOf(index) {
        return crossfade
            ? Logic.crossfadeWeight(index, fromIndex, currentIndex, crossProgress)
            : Logic.highlightWeight(index, columns, highlight.x, highlight.y);
    }

    function mix(a, b, t) {
        return Logic.mixColor(a, b, t);
    }

    readonly property var s: settings

    readonly property color activeColor: s.useThemeColors ? Kirigami.Theme.highlightColor : s.activeColor
    readonly property color inactiveColor: s.useThemeColors ? Kirigami.Theme.textColor : s.inactiveColor
    readonly property color textColor: s.useThemeColors ? Kirigami.Theme.textColor : s.textColor
    readonly property color activeTextColor: s.useThemeColors ? Kirigami.Theme.highlightedTextColor : s.activeTextColor
    readonly property color occupiedColor: s.useThemeColors ? Kirigami.Theme.textColor : s.occupiedColor
    readonly property real inactiveOpacity: Math.max(0, Math.min(100, s.inactiveOpacity)) / 100
    readonly property real backgroundOpacity: Math.max(0, Math.min(100, s.backgroundOpacity)) / 100
    // Easing of the highlight transitions, indexed by the AnimationEasing setting.
    readonly property int easing: [Easing.Linear, Easing.OutCubic, Easing.OutBack, Easing.InOutQuad][s.animationEasing] ?? Easing.OutCubic
    // Full and square highlights sit under the content, so the content switches to the highlighted text color.
    readonly property bool highlightFills: s.highlight === 0 || s.highlight === 1
    readonly property font labelFont: Qt.font({
        family: Kirigami.Theme.defaultFont.family,
        pixelSize: s.fontSize > 0 ? s.fontSize : Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.1)
    })
    readonly property font captionFont: Qt.font({
        family: labelFont.family,
        pixelSize: Math.round(labelFont.pixelSize * 1.2),
        bold: true
    })

    function labelFor(index) {
        const entry = desktops[index];
        return Logic.labelFor(index, entry ? entry.name : "", s.labelSource, s.labelTemplate, s.labels);
    }

    // Widest content of all cells, whatever their state: circle cells all take
    // the diameter of the widest one instead of growing with their own label.
    readonly property real widestContent: {
        let widest = 0;
        for (let i = 0; i < grid.children.length; i++) {
            const cell = grid.children[i];
            if (cell.stableWidth !== undefined) {
                widest = Math.max(widest, cell.stableWidth);
            }
        }
        return widest;
    }

    readonly property string captionText: {
        const entry = desktops[currentIndex];
        return Logic.labelFor(currentIndex, entry ? entry.name : "", 1, "", []);
    }

    // Plasma backgrounds are drawn here rather than by the window, so the whole
    // indicator fades through Item.opacity. Animating the window opacity works too, but
    // KWin's internal QPA logs a warning on every frame of the fade.
    readonly property bool plasmaFrame: s.backgroundMode === 0 || s.backgroundMode === 1
    readonly property real frameWidth: plasmaFrame ? frameSvg.margins.left + frameSvg.margins.right : 0
    readonly property real frameHeight: plasmaFrame ? frameSvg.margins.top + frameSvg.margins.bottom : 0

    implicitWidth: column.implicitWidth + 2 * s.padding + frameWidth
    implicitHeight: column.implicitHeight + 2 * s.padding + frameHeight

    KSvg.FrameSvgItem {
        id: frameSvg
        anchors.fill: parent
        visible: root.plasmaFrame
        opacity: root.backgroundOpacity
        imagePath: root.s.backgroundMode === 1 ? "solid/dialogs/background" : "dialogs/background"
    }

    Rectangle {
        anchors.fill: parent
        visible: root.s.backgroundMode === 3
        opacity: root.backgroundOpacity
        color: root.s.backgroundColor
        radius: root.s.backgroundRadius
    }

    Column {
        id: column
        anchors.centerIn: parent
        spacing: root.s.spacing

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.s.caption === 1
            text: root.captionText
            textFormat: Text.PlainText
            color: root.textColor
            font: root.captionFont
        }

        Grid {
            id: grid
            anchors.horizontalCenter: parent.horizontalCenter
            columns: Math.max(1, root.columns)
            spacing: root.s.spacing
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            // One repeater per style; only the selected one gets a model.
            Repeater {
                model: root.s.style === 0 ? root.desktops : 0
                delegate: PillCell { indicator: root }
            }
            Repeater {
                model: root.s.style === 1 ? root.desktops : 0
                delegate: LabelCell { indicator: root }
            }
            Repeater {
                model: root.s.style === 2 ? root.desktops : 0
                delegate: IconCell { indicator: root }
            }
            Repeater {
                model: root.s.style === 3 ? root.desktops : 0
                delegate: TaskCell { indicator: root }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.s.caption === 2
            text: root.captionText
            textFormat: Text.PlainText
            color: root.textColor
            font: root.captionFont
        }
    }
}
