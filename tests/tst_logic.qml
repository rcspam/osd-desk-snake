import QtQuick
import QtTest
import "../package/contents/ui/logic.js" as Logic

TestCase {
    name: "Logic"

    readonly property var area: ({ x: 100, y: 50, width: 1000, height: 800 })
    readonly property var size: ({ width: 200, height: 100 })

    // Anchor positions: 0 top-left ... 8 bottom-right, margin inward.
    function test_anchorPosition_data() {
        return [
            { tag: "top-left", anchor: 0, x: 110, y: 60 },
            { tag: "top-center", anchor: 1, x: 500, y: 60 },
            { tag: "top-right", anchor: 2, x: 890, y: 60 },
            { tag: "center-left", anchor: 3, x: 110, y: 400 },
            { tag: "center", anchor: 4, x: 500, y: 400 },
            { tag: "center-right", anchor: 5, x: 890, y: 400 },
            { tag: "bottom-left", anchor: 6, x: 110, y: 740 },
            { tag: "bottom-center", anchor: 7, x: 500, y: 740 },
            { tag: "bottom-right", anchor: 8, x: 890, y: 740 }
        ];
    }
    function test_anchorPosition(data) {
        const p = Logic.anchorPosition(area, size, data.anchor, 10, 0, 0);
        compare(p.x, data.x);
        compare(p.y, data.y);
    }

    function test_anchorPosition_offsets() {
        const p = Logic.anchorPosition(area, size, 4, 10, 25, -40);
        compare(p.x, 525);
        compare(p.y, 360);
    }

    function test_anchorPosition_invalidAnchorFallsBackToCenter() {
        const p = Logic.anchorPosition(area, size, 42, 10, 0, 0);
        compare(p.x, 500);
        compare(p.y, 400);
    }

    function test_anchorPosition_roundsToPixels() {
        const p = Logic.anchorPosition({ x: 0, y: 0, width: 101, height: 101 }, { width: 10, height: 10 }, 4, 0, 0, 0);
        compare(p.x, 46);
        compare(p.y, 46);
    }

    // Dropping the indicator: area 100,50 1000x800, size 200x100, margin 10.
    function drop(x, y, cfg) {
        return Logic.dropResult(area, size, { x: x, y: y }, Object.assign({ positionMode: 0, anchor: 7, margin: 10, snap: true, snapDistance: 48 }, cfg || {}));
    }

    function test_nearestAnchor() {
        compare(Logic.nearestAnchor(area, size, { x: 120, y: 70 }, 10), 0);
        compare(Logic.nearestAnchor(area, size, { x: 520, y: 380 }, 10), 4);
        compare(Logic.nearestAnchor(area, size, { x: 880, y: 730 }, 10), 8);
    }

    function test_dropResult_snapsWhenClose() {
        // Bottom-right anchor sits at 890,740.
        compare(drop(870, 720), { Anchor: 8, OffsetX: 0, OffsetY: 0 });
    }

    function test_dropResult_nearestAnchorWithOffsetWhenFar() {
        // Nearest is the center (500,400), 100 px away: too far to snap.
        compare(drop(560, 480), { Anchor: 4, OffsetX: 60, OffsetY: 80 });
    }

    function test_dropResult_withoutSnapKeepsAnchor() {
        // Current anchor bottom (500,740), exact offset kept even when very close to another anchor.
        compare(drop(885, 735, { snap: false }), { Anchor: 7, OffsetX: 385, OffsetY: -5 });
    }

    function test_dropResult_offsetsAreWholePixels() {
        compare(drop(560.4, 480.6, { snap: false, anchor: 4 }), { Anchor: 4, OffsetX: 60, OffsetY: 81 });
    }

    function test_dropResult_freeModeGivesPercentOfCenter() {
        // Center at 700,450 -> 60% of 1000 from x=100, 50% of 800 from y=50.
        compare(drop(600, 400, { positionMode: 1 }), { PercentX: 60, PercentY: 50 });
    }

    function test_dropResult_freeModeKeepsOneDecimal() {
        compare(drop(601, 401, { positionMode: 1 }), { PercentX: 60.1, PercentY: 50.1 });
    }

    function test_dropResult_freeModeIgnoresSnap() {
        const r = drop(870, 720, { positionMode: 1, snap: true });
        verify(r.Anchor === undefined);
    }

    function test_dropResult_freeModeClamped() {
        compare(drop(-500, 5000, { positionMode: 1 }), { PercentX: 0, PercentY: 100 });
    }

    function test_freePosition_centerOfArea() {
        const p = Logic.freePosition(area, size, 50, 50);
        compare(p.x, 500);
        compare(p.y, 400);
    }

    function test_freePosition_clampedInsideArea() {
        const p = Logic.freePosition(area, size, 0, 100);
        compare(p.x, 100);
        compare(p.y, 750);
    }

    function test_gridSize_followKWin() {
        compare(Logic.gridSize(6, 3, 2, 0), { columns: 3, rows: 2 });
        compare(Logic.gridSize(6, 6, 1, 0), { columns: 6, rows: 1 });
    }

    function test_gridSize_followKWinWithBadValues() {
        compare(Logic.gridSize(5, 0, 0, 0), { columns: 5, rows: 1 });
        compare(Logic.gridSize(5, 2, 1, 0), { columns: 2, rows: 3 });
    }

    function test_gridSize_forcedRowAndColumn() {
        compare(Logic.gridSize(4, 2, 2, 1), { columns: 4, rows: 1 });
        compare(Logic.gridSize(4, 2, 2, 2), { columns: 1, rows: 4 });
    }

    function test_gridSize_empty() {
        compare(Logic.gridSize(0, 3, 2, 0), { columns: 0, rows: 0 });
    }

    function test_labelFor_data() {
        return [
            { tag: "number", source: 0, index: 2, name: "Web", expected: "3" },
            { tag: "name", source: 1, index: 2, name: "Web", expected: "Web" },
            { tag: "empty name falls back", source: 1, index: 2, name: "", expected: "3" },
            { tag: "template", source: 2, index: 0, name: "Web", template: "D%d %n", expected: "D1 Web" },
            { tag: "template repeated", source: 2, index: 1, name: "", template: "%d-%d", expected: "2-2" },
            { tag: "list", source: 3, index: 1, name: "", list: ["A", "B"], expected: "B" },
            { tag: "list too short", source: 3, index: 5, name: "", list: ["A", "B"], expected: "6" }
        ];
    }
    function test_labelFor(data) {
        compare(Logic.labelFor(data.index, data.name, data.source, data.template || "", data.list || []), data.expected);
    }

    function test_splitList() {
        compare(Logic.splitList(" Web , Code,,Mail\nChat "), ["Web", "Code", "Mail", "Chat"]);
        compare(Logic.splitList(""), []);
        compare(Logic.splitList(undefined), []);
    }

    function test_iconFor() {
        compare(Logic.iconFor(0, ["firefox", "kate"], "virtual-desktops"), "firefox");
        compare(Logic.iconFor(3, ["firefox", "kate"], "virtual-desktops"), "virtual-desktops");
    }

    function test_toBool() {
        compare(Logic.toBool(true, false), true);
        compare(Logic.toBool("true", false), true);
        compare(Logic.toBool("false", true), false);
        compare(Logic.toBool(0, true), false);
        compare(Logic.toBool(undefined, true), true);
        compare(Logic.toBool("garbage", false), false);
    }

    function test_toInt() {
        compare(Logic.toInt("42", 0), 42);
        compare(Logic.toInt(3.6, 0), 4);
        compare(Logic.toInt("abc", 7), 7);
        compare(Logic.toInt(undefined, 7), 7);
    }

    function test_toReal() {
        compare(Logic.toReal("60.1", 0), 60.1);
        compare(Logic.toReal(85, 0), 85);
        compare(Logic.toReal("", 50), 50);
        compare(Logic.toReal(null, 50), 50);
        compare(Logic.toReal("abc", 50), 50);
    }

    function test_parseColor_data() {
        return [
            { tag: "kconfig rgb", value: "255,0,0", expected: "#ffff0000" },
            { tag: "kconfig rgba", value: "0,128,255,128", expected: "#800080ff" },
            { tag: "hex rgb", value: "#00ff00", expected: "#ff00ff00" },
            { tag: "hex argb", value: "#8000ff00", expected: "#8000ff00" },
            { tag: "spaces", value: " 1, 2, 3 ", expected: "#ff010203" },
            { tag: "out of range clamped", value: "300,-5,0", expected: "#ffff0000" },
            { tag: "garbage", value: "nope", expected: "#ff123456" },
            { tag: "empty", value: "", expected: "#ff123456" },
            { tag: "undefined", value: undefined, expected: "#ff123456" }
        ];
    }
    function test_parseColor(data) {
        compare(Logic.parseColor(data.value, "#123456"), data.expected);
    }

    function test_parseColor_colorValue() {
        compare(Logic.parseColor(Qt.rgba(1, 0, 0, 0.5), "#123456"), "#80ff0000");
    }

    readonly property var desktops: [{ id: "a", name: "One" }, { id: "b", name: "Two" }, { id: "c", name: "Three" }]

    function win(desktopIds, extra) {
        const w = {
            desktops: desktops.filter(d => desktopIds.indexOf(d.id) >= 0),
            onAllDesktops: false,
            normalWindow: true,
            skipTaskbar: false,
            icon: "app-" + desktopIds.join("")
        };
        return Object.assign(w, extra || {});
    }

    function test_desktopInfo_occupancyAndIcons() {
        const info = Logic.desktopInfo(desktops, [win(["a"]), win(["a"]), win(["c"])], 5);
        compare(info.length, 3);
        compare(info[0].name, "One");
        compare(info[0].occupied, true);
        compare(info[0].icons.length, 2);
        compare(info[0].extra, 0);
        compare(info[1].occupied, false);
        compare(info[1].icons.length, 0);
        compare(info[2].occupied, true);
    }

    function test_desktopInfo_ignoresSpecialWindows() {
        const info = Logic.desktopInfo(desktops, [
            win(["a"], { onAllDesktops: true }),
            win(["b"], { normalWindow: false }),
            win(["c"], { skipTaskbar: true })
        ], 5);
        compare(info[0].occupied, false);
        compare(info[1].occupied, false);
        compare(info[2].occupied, false);
    }

    function test_desktopInfo_iconLimit() {
        const info = Logic.desktopInfo(desktops, [win(["b"]), win(["b"]), win(["b"]), win(["b"])], 2);
        compare(info[1].icons.length, 2);
        compare(info[1].extra, 2);
    }

    readonly property var dims: ({ width: 14, height: 10, activeWidth: 44, activeHeight: 12, radius: 3 })

    function test_markerGeometry_pill() {
        compare(Logic.markerGeometry(0, false, dims), { width: 14, height: 10, radius: 3, rotation: 0, innerWidth: 14, innerHeight: 10 });
        compare(Logic.markerGeometry(0, true, dims), { width: 44, height: 12, radius: 3, rotation: 0, innerWidth: 44, innerHeight: 12 });
    }

    function test_markerGeometry_pillRadiusCapped() {
        const g = Logic.markerGeometry(0, false, { width: 14, height: 10, activeWidth: 44, activeHeight: 12, radius: 50 });
        compare(g.radius, 5);
    }

    function test_markerGeometry_circleUsesHeightAsDiameter() {
        compare(Logic.markerGeometry(1, false, dims), { width: 10, height: 10, radius: 5, rotation: 0, innerWidth: 10, innerHeight: 10 });
        compare(Logic.markerGeometry(1, true, dims), { width: 12, height: 12, radius: 6, rotation: 0, innerWidth: 12, innerHeight: 12 });
    }

    function test_markerGeometry_square() {
        compare(Logic.markerGeometry(2, true, dims), { width: 44, height: 12, radius: 0, rotation: 0, innerWidth: 44, innerHeight: 12 });
    }

    function test_markerGeometry_diamondFitsItsRotation() {
        const g = Logic.markerGeometry(3, false, dims);
        compare(g.rotation, 45);
        compare(g.innerWidth, 10);
        compare(g.innerHeight, 10);
        compare(g.width, 14);
        compare(g.height, 14);
        compare(g.radius, 0);
    }

    function test_markerGeometry_barIsThin() {
        compare(Logic.markerGeometry(4, false, dims), { width: 14, height: 3, radius: 1.5, rotation: 0, innerWidth: 14, innerHeight: 3 });
        compare(Logic.markerGeometry(4, true, dims).width, 44);
        compare(Logic.markerGeometry(4, false, { width: 14, height: 3, activeWidth: 44, activeHeight: 3, radius: 3 }).height, 2);
    }

    function test_cellGeometry_rounded() {
        compare(Logic.cellGeometry(0, 10, 40, 36, 8), { width: 40, height: 36, radius: 8 });
        compare(Logic.cellGeometry(0, 60, 40, 36, 8), { width: 76, height: 36, radius: 8 });
    }

    function test_cellGeometry_roundedRadiusCapped() {
        compare(Logic.cellGeometry(0, 10, 40, 36, 100).radius, 18);
    }

    function test_cellGeometry_circleIsSquareBox() {
        compare(Logic.cellGeometry(1, 10, 40, 36, 8), { width: 40, height: 40, radius: 20 });
        compare(Logic.cellGeometry(1, 60, 40, 36, 8), { width: 76, height: 76, radius: 38 });
    }

    function test_cellGeometry_square() {
        compare(Logic.cellGeometry(2, 10, 40, 36, 8), { width: 40, height: 36, radius: 0 });
    }

    function test_shapeRadius() {
        compare(Logic.shapeRadius(0, 30, 20, 8), 8);
        compare(Logic.shapeRadius(0, 30, 10, 8), 5);
        compare(Logic.shapeRadius(1, 30, 20, 8), 10);
        compare(Logic.shapeRadius(2, 30, 20, 8), 0);
    }

    function test_gridPoint() {
        compare(Logic.gridPoint(0, 3), { x: 0, y: 0 });
        compare(Logic.gridPoint(4, 3), { x: 1, y: 1 });
        compare(Logic.gridPoint(5, 1), { x: 0, y: 5 });
        // Like the Grid item: no column count means one column.
        compare(Logic.gridPoint(2, 0), { x: 0, y: 2 });
    }

    function test_highlightWeight() {
        // Grid of 3 columns, highlight exactly on index 4 (1,1).
        compare(Logic.highlightWeight(4, 3, 1, 1), 1);
        compare(Logic.highlightWeight(3, 3, 1, 1), 0);
        // Halfway between index 0 and 1.
        compare(Logic.highlightWeight(0, 3, 0.5, 0), 0.5);
        compare(Logic.highlightWeight(1, 3, 0.5, 0), 0.5);
        compare(Logic.highlightWeight(2, 3, 0.5, 0), 0);
        // A quarter of the way down from index 1 to index 4.
        compare(Logic.highlightWeight(1, 3, 1, 0.25), 0.75);
    }

    function test_crossfadeWeight() {
        // From desktop 0 to desktop 4, 30 % of the way: only those two take part.
        compare(Logic.crossfadeWeight(0, 0, 4, 0.3), 0.7);
        compare(Logic.crossfadeWeight(4, 0, 4, 0.3), 0.3);
        compare(Logic.crossfadeWeight(2, 0, 4, 0.3), 0);
        // Same desktop: fully active whatever the progress.
        compare(Logic.crossfadeWeight(3, 3, 3, 0), 1);
    }

    function test_markerGeometryAt_interpolates() {
        const halfway = Logic.markerGeometryAt(0, 0.5, dims);
        compare(halfway.width, 29);
        compare(halfway.height, 11);
        compare(halfway.innerWidth, 29);
        compare(Logic.markerGeometryAt(0, 0, dims), Logic.markerGeometry(0, false, dims));
        compare(Logic.markerGeometryAt(0, 1, dims), Logic.markerGeometry(0, true, dims));
        compare(Logic.markerGeometryAt(3, 0.5, dims).rotation, 45);
    }

    function test_gestureOffset() {
        // Swiping left brings the desktop on the right, as KWin does.
        compare(Logic.gestureOffset("left", 0.4), { x: 0.4, y: 0 });
        compare(Logic.gestureOffset("right", 0.4), { x: -0.4, y: 0 });
        compare(Logic.gestureOffset("up", 0.4), { x: 0, y: 0.4 });
        compare(Logic.gestureOffset("down", 0.4), { x: 0, y: -0.4 });
        compare(Logic.gestureOffset("left", 3), { x: 1, y: 0 });
    }

    function test_clampToGrid() {
        compare(Logic.clampToGrid({ x: -0.3, y: 2.5 }, 3, 2), { x: 0, y: 1 });
        compare(Logic.clampToGrid({ x: 1.4, y: 0.2 }, 3, 2), { x: 1.4, y: 0.2 });
    }

    function test_mixColor() {
        compare(Logic.mixColor("#ff000000", "#ffffffff", 0.5), "#ff808080");
        compare(Logic.mixColor("#ff102030", "#ff405060", 0), "#ff102030");
        compare(Logic.mixColor("#00ff0000", "#ffff0000", 1), "#ffff0000");
    }

    function test_infoSignature_stableForSameData() {
        const a = Logic.desktopInfo(desktops, [win(["a"], { internalId: "w1" })], 5);
        const b = Logic.desktopInfo(desktops, [win(["a"], { internalId: "w1" })], 5);
        compare(Logic.infoSignature(a), Logic.infoSignature(b));
    }

    function test_infoSignature_changesWhenAWindowMoves() {
        const a = Logic.desktopInfo(desktops, [win(["a"], { internalId: "w1" })], 5);
        const b = Logic.desktopInfo(desktops, [win(["b"], { internalId: "w1" })], 5);
        verify(Logic.infoSignature(a) !== Logic.infoSignature(b));
    }

    function test_infoSignature_changesWhenAWindowIsReplaced() {
        const a = Logic.desktopInfo(desktops, [win(["a"], { internalId: "w1" })], 5);
        const b = Logic.desktopInfo(desktops, [win(["a"], { internalId: "w2" })], 5);
        verify(Logic.infoSignature(a) !== Logic.infoSignature(b));
    }

    function test_infoSignature_changesWhenADesktopIsRenamed() {
        const renamed = [{ id: "a", name: "Web" }, desktops[1], desktops[2]];
        verify(Logic.infoSignature(Logic.desktopInfo(desktops, [], 5)) !== Logic.infoSignature(Logic.desktopInfo(renamed, [], 5)));
    }

    function test_desktopInfo_windowOnSeveralDesktops() {
        const info = Logic.desktopInfo(desktops, [win(["a", "c"])], 5);
        compare(info[0].occupied, true);
        compare(info[1].occupied, false);
        compare(info[2].occupied, true);
    }

    // The sliding highlight: the rect of the highlight point, between the cell rects.
    function test_slideRect() {
        const rects = [
            { x: 0, y: 0, width: 40, height: 30, radius: 4 },
            { x: 60, y: 0, width: 80, height: 30, radius: 8 },
            { x: 0, y: 50, width: 40, height: 30, radius: 4 }
        ];
        // On a cell: that cell.
        compare(Logic.slideRect(rects, 2, 1, 0), rects[1]);
        // Halfway along a row: position and size in between.
        compare(Logic.slideRect(rects, 2, 0.5, 0), { x: 30, y: 0, width: 60, height: 30, radius: 6 });
        // Halfway down a column.
        compare(Logic.slideRect(rects, 2, 0, 0.5), { x: 0, y: 25, width: 40, height: 30, radius: 4 });
        // Toward a missing cell (incomplete last row): stays on the existing one.
        compare(Logic.slideRect(rects, 2, 1, 0.5), rects[1]);
        // Out of the grid (swipe overshoot): clamped to the edge cell.
        compare(Logic.slideRect(rects, 2, -0.4, 0), rects[0]);
        compare(Logic.slideRect([], 2, 0, 0), null);
    }

    // Lowest cell sizes that still change something, from the content widths.
    function test_cellSizeFloors() {
        // Circles: both sizes stop at the widest content plus its margin.
        compare(Logic.cellSizeFloors(1, 62.4, 12), { CellWidth: 79, CellHeight: 79 });
        // Other shapes: the width stops at the narrowest content, the height is free.
        compare(Logic.cellSizeFloors(0, 62.4, 12), { CellWidth: 28, CellHeight: 1 });
        compare(Logic.cellSizeFloors(2, 62.4, 12.5), { CellWidth: 29, CellHeight: 1 });
    }

    // How far the content, the dot and the line reach beyond the cell shape.
    function test_cellExtents() {
        // Everything inside a 36 px cell: nothing to add.
        compare(Logic.cellExtents(36, 17, [{ offset: 1, height: 4 }, { offset: 3, height: 4 }]), { top: 0, bottom: 0 });
        // Text taller than the cell: half of the difference on each side.
        compare(Logic.cellExtents(10, 30, []), { top: 10, bottom: 10 });
        // A dot far below: (36 + 17) / 2 + 20 + 6 - 36 = 16.5 under the cell.
        compare(Logic.cellExtents(36, 17, [{ offset: 20, height: 6 }]), { top: 0, bottom: 16.5 });
        // A line pulled far up: (36 + 17) / 2 - 40 = -13.5, above the cell.
        compare(Logic.cellExtents(36, 17, [null, { offset: -40, height: 2 }]), { top: 13.5, bottom: 0 });
    }

    // The occupied dot sits `distance` px under the centered label or icon.
    function test_markY() {
        // 36 px cell, 20 px content: the content ends at y = 28.
        compare(Logic.markY(36, 20, 2), 30);
        compare(Logic.markY(36, 20, -4), 24);
        verify(Logic.markY(36, 20, 6) > Logic.markY(36, 20, 2), "a larger distance moves the dot away from the text");
    }
}
