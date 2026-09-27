#!/usr/bin/env python3
"""Generate the files derived from the settings schema and the form table.

- package/contents/ui/config.ui: the KWin script settings form. Every field
  widget is named kcfg_<Key> so KConfigDialogManager binds it to the matching
  entry of contents/config/main.xml.
- settings-app/src/qml/fields.js: the same form for the live settings app.
- package/contents/ui/schema.js: types and defaults from main.xml, read by
  Settings.qml, so defaults are only written once (in main.xml).

Edit main.xml and the TABS table, then run:
    python3 tools/gen_config_ui.py
"""
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_XML = ROOT / "package/contents/config/main.xml"
OUT = ROOT / "package/contents/ui/config.ui"
OUT_JS = ROOT / "settings-app/src/qml/fields.js"
OUT_SCHEMA = ROOT / "package/contents/ui/schema.js"

# Field kinds:
#   ("spin", key, label, min, max, suffix, tooltip)
#   ("dspin", key, label, min, max, suffix, tooltip)   one decimal
#   ("check", key, text, tooltip)
#   ("combo", key, label, [items], tooltip)
#   ("line", key, label, placeholder, tooltip)
#   ("color", key, label, tooltip)
TABS = [
    ("General", [
        ("Timing", [
            ("spin", "ShowDelay", "Delay before showing:", 0, 2000, " ms",
             "Wait before showing the indicator. Switches made during the delay only show the last one."),
            ("spin", "FadeInDuration", "Fade in:", 0, 2000, " ms", "How long the indicator takes to appear."),
            ("spin", "DisplayDuration", "Display time:", 100, 10000, " ms", "How long the indicator stays fully visible."),
            ("spin", "FadeOutDuration", "Fade out:", 0, 2000, " ms", "How long the indicator takes to disappear."),
            ("combo", "AppearEffect", "Appear effect:", ["Fade", "Fade and zoom"], ""),
        ]),
        ("Highlight animation", [
            ("combo", "HighlightMotion", "Motion:", ["Follow the desktop switch", "Once the switch is done"],
             "Follow: the highlight slides with the desktops and follows swipe gestures. "
             "Once done: the previous desktop fades out while the new one fades in."),
            ("spin", "AnimationDuration", "Duration:", 0, 2000, " ms", "Transition from the previous desktop to the new one."),
            ("combo", "AnimationEasing", "Curve:", ["Linear", "Smooth", "Overshoot", "Ease in and out"], ""),
        ]),
        ("Content", [
            ("check", "HideWithSingleDesktop", "Do not show with a single desktop", ""),
            ("combo", "Caption", "Desktop name:", ["Hidden", "Above the indicator", "Below the indicator"],
             "Shows the name of the current desktop as a caption."),
            ("combo", "Layout", "Layout:", ["Follow the desktop grid", "Single row", "Single column"],
             "Arrangement of the desktops inside the indicator."),
        ]),
    ]),
    ("Position", [
        ("Placement", [
            ("combo", "PositionMode", "Mode:", ["Anchor", "Free position"],
             "Anchor: one of nine screen points. Free position: percentages of the screen."),
            ("check", "AvoidPanels", "Keep clear of panels", "Places the indicator in the screen area not covered by panels."),
        ]),
        ("Anchor mode", [
            ("combo", "Anchor", "Anchor:", ["Top left", "Top", "Top right", "Left", "Center", "Right",
                                              "Bottom left", "Bottom", "Bottom right"], ""),
            ("check", "SnapToAnchors", "Snap to anchors when dragging",
             "With the settings app open, the indicator can be dragged. When dropped near an anchor, it sticks to it."),
            ("spin", "SnapDistance", "Snap distance:", 0, 500, " px", ""),
            ("spin", "Margin", "Margin:", 0, 2000, " px", "Distance from the anchored screen edges."),
            ("spin", "OffsetX", "Horizontal offset:", -5000, 5000, " px", "Positive values move right."),
            ("spin", "OffsetY", "Vertical offset:", -5000, 5000, " px", "Positive values move down."),
        ]),
        ("Free position mode", [
            ("dspin", "PercentX", "Horizontal position:", 0, 100, " %", "Position of the indicator center, from the left edge."),
            ("dspin", "PercentY", "Vertical position:", 0, 100, " %", "Position of the indicator center, from the top edge."),
        ]),
    ]),
    ("Style", [
        ("Style", [
            ("combo", "Style", "Style:", ["Pills", "Labels", "Icons", "Open windows"], ""),
            ("combo", "Highlight", "Highlight:", ["Full", "Square", "Line", "Full with line"],
             "Highlight of the current desktop for the labels, icons and open windows styles."),
            ("check", "MarkOccupied", "Mark desktops that contain windows", ""),
            ("spin", "InactiveOpacity", "Inactive opacity:", 0, 100, " %", "Opacity of the other desktops."),
            ("spin", "Spacing", "Spacing:", 0, 200, " px", ""),
            ("spin", "Padding", "Padding:", 0, 200, " px", "Space between the desktops and the background edge."),
        ]),
        ("Pills", [
            ("combo", "PillShape", "Shape:", ["Pill", "Circle", "Square", "Diamond", "Bar"],
             "Circle and diamond use the heights as size."),
            ("spin", "PillWidth", "Width:", 1, 500, " px", ""),
            ("spin", "PillHeight", "Height:", 1, 500, " px", ""),
            ("spin", "PillActiveWidth", "Current desktop width:", 1, 500, " px", ""),
            ("spin", "PillActiveHeight", "Current desktop height:", 1, 500, " px", ""),
            ("spin", "PillRadius", "Corner radius:", 0, 250, " px", ""),
        ]),
        ("Cells (labels, icons, open windows)", [
            ("combo", "CellShape", "Shape:", ["Rounded", "Circle", "Square"],
             "Shape of the cells and of the full and square highlights."),
            ("spin", "CellWidth", "Minimum width:", 1, 500, " px", ""),
            ("spin", "CellHeight", "Height:", 1, 500, " px", ""),
            ("spin", "CellRadius", "Corner radius:", 0, 250, " px", ""),
            ("spin", "SquareSize", "Square highlight size:", 1, 500, " px", ""),
            ("spin", "LineWidth", "Line highlight width:", 1, 500, " px", ""),
            ("spin", "LineHeight", "Line highlight thickness:", 1, 100, " px", ""),
        ]),
    ]),
    ("Labels and icons", [
        ("Labels", [
            ("combo", "LabelSource", "Text:", ["Desktop number", "Desktop name", "Template", "Custom list"], ""),
            ("line", "LabelTemplate", "Template:", "D%d", "%d is replaced by the desktop number, %n by its name."),
            ("line", "LabelList", "Custom list:", "Web, Code, Mail",
             "One label per desktop, separated by commas. Missing entries show the number."),
            ("spin", "FontSize", "Font size:", 0, 200, " px", "0 uses the theme font size."),
            ("check", "Bold", "Bold text", ""),
            ("check", "ActiveBold", "Bold text for the current desktop", ""),
        ]),
        ("Icons", [
            ("line", "IconList", "Icons:", "internet-web-browser, utilities-terminal",
             "One icon name per desktop, separated by commas."),
            ("line", "IconFallback", "Fallback icon:", "virtual-desktops", "Used for desktops beyond the list."),
            ("spin", "IconSize", "Icon size:", 8, 256, " px", ""),
        ]),
        ("Open windows", [
            ("spin", "TaskIconSize", "Window icon size:", 8, 256, " px", ""),
            ("spin", "MaxTaskIcons", "Icons per desktop:", 1, 20, "", "Extra windows are shown as +n."),
        ]),
    ]),
    ("Colors", [
        ("Colors", [
            ("check", "UseThemeColors", "Use the Plasma theme colors", "Uncheck to use the colors below."),
            ("color", "ActiveColor", "Current desktop:", ""),
            ("color", "InactiveColor", "Other desktops (pills):", ""),
            ("color", "TextColor", "Text:", ""),
            ("color", "ActiveTextColor", "Text on the highlight:", ""),
            ("color", "OccupiedColor", "Desktop with windows mark:", ""),
        ]),
        ("Background", [
            ("combo", "BackgroundMode", "Background:", ["Plasma theme", "Plasma theme, solid", "None", "Custom color"], ""),
            ("color", "BackgroundColor", "Custom color:", ""),
            ("spin", "BackgroundOpacity", "Opacity:", 0, 100, " %", "Opacity of the background only, the desktops stay opaque."),
            ("spin", "BackgroundRadius", "Custom corner radius:", 0, 250, " px", ""),
        ]),
    ]),
]


# Link at the top of config.ui: .ui files cannot run code, but a label link is
# opened through the desktop, which starts the settings app registered for this
# URL scheme (x-scheme-handler/osd-desk-snake, see its .desktop file).
# The script alone (KDE Store) comes without the app: the second link, always
# valid, points to its install instructions.
APP_LINK = ('<a href="osd-desk-snake://settings">Open OSD Desk Snake Settings</a> '
            'for live preview and mouse positioning, or '
            '<a href="osd-desk-snake://presets">manage presets</a>. Not installed? '
            '<a href="https://github.com/rcspam/osd-desk-snake#install">Get it</a>.')
APP_LINK_TIP = "That app saves every change right away; this window closes when it opens."

# Last tab of config.ui. Presets need code (list, save, apply), which this page
# cannot run, so the tab only leads to the Presets tab of the settings app.
PRESETS_TAB = "Presets"
PRESETS_TEXT = ('Presets keep every setting under a name: switch looks in one click, '
                'and share them as .osdsnake files. They are managed in OSD Desk Snake Settings.'
                '<br/><br/><a href="osd-desk-snake://presets">Open the presets</a>'
                '<br/><br/>Not installed? '
                '<a href="https://github.com/rcspam/osd-desk-snake#install">Get it</a>.')

# When a setting has an effect, as a JS expression over the current values `v`
# (keys as in main.xml). Settings not listed always apply. The settings app greys
# out the others live; config.ui can only follow a leading checkbox term.
WHEN = {
    "Anchor": "v.PositionMode === 0",
    "SnapToAnchors": "v.PositionMode === 0",
    "SnapDistance": "v.SnapToAnchors && v.PositionMode === 0",
    "Margin": "v.PositionMode === 0",
    "OffsetX": "v.PositionMode === 0",
    "OffsetY": "v.PositionMode === 0",
    "PercentX": "v.PositionMode === 1",
    "PercentY": "v.PositionMode === 1",

    "Highlight": "v.Style !== 0",
    "MarkOccupied": "v.Style !== 3",
    "PillShape": "v.Style === 0",
    "PillWidth": "v.Style === 0 && v.PillShape !== 1 && v.PillShape !== 3",
    "PillHeight": "v.Style === 0",
    "PillActiveWidth": "v.Style === 0 && v.PillShape !== 1 && v.PillShape !== 3",
    "PillActiveHeight": "v.Style === 0",
    "PillRadius": "v.Style === 0 && v.PillShape === 0",
    "CellShape": "v.Style !== 0",
    "CellWidth": "v.Style !== 0",
    "CellHeight": "v.Style !== 0",
    "CellRadius": "v.Style !== 0 && v.CellShape === 0",
    "SquareSize": "v.Style !== 0 && v.Highlight === 1",
    "LineWidth": "v.Style !== 0 && (v.Highlight === 2 || v.Highlight === 3)",
    "LineHeight": "v.Style !== 0 && (v.Highlight === 2 || v.Highlight === 3)",

    "LabelSource": "v.Style === 1",
    "LabelTemplate": "v.Style === 1 && v.LabelSource === 2",
    "LabelList": "v.Style === 1 && v.LabelSource === 3",
    "FontSize": "v.Style === 1 || v.Style === 3 || v.Caption !== 0",
    "Bold": "v.Style === 1 || v.Style === 3",
    "ActiveBold": "v.Style === 1 || v.Style === 3",
    "IconList": "v.Style === 2",
    "IconFallback": "v.Style === 2",
    "IconSize": "v.Style === 2",
    "TaskIconSize": "v.Style === 3",
    "MaxTaskIcons": "v.Style === 3",

    "ActiveColor": "!v.UseThemeColors",
    "InactiveColor": "!v.UseThemeColors && v.Style === 0",
    "TextColor": "!v.UseThemeColors && (v.Style !== 0 || v.Caption !== 0)",
    "ActiveTextColor": "!v.UseThemeColors && v.Style !== 0 && (v.Highlight === 0 || v.Highlight === 1)",
    "OccupiedColor": "!v.UseThemeColors && v.MarkOccupied && v.Style !== 3",
    "BackgroundOpacity": "v.BackgroundMode !== 2",
    "BackgroundColor": "v.BackgroundMode === 3",
    "BackgroundRadius": "v.BackgroundMode === 3",
}


def iter_fields():
    for _, groups in TABS:
        for _, fields in groups:
            yield from fields


def checkbox_rule(key):
    """(checkbox key, enabled when checked?) for a WHEN rule starting with a checkbox term."""
    m = re.match(r"^(!?)v\.(\w+)(\s*&&|$)", WHEN.get(key, ""))
    if not m or kind_of(m.group(2)) != "check":
        return None
    return m.group(2), m.group(1) != "!"


def kind_of(key):
    return next((spec[0] for spec in iter_fields() if spec[1] == key), None)


class Ui:
    def __init__(self):
        self.lines = []
        self.counter = 0
        self.labels = {}

    def uid(self, prefix):
        self.counter += 1
        return f"{prefix}_{self.counter}"

    def add(self, text, depth):
        self.lines.append(" " * depth + text)

    def string_prop(self, name, value, depth):
        self.add(f'<property name="{name}"><string>{escape(value)}</string></property>', depth)

    def field(self, spec, row, depth):
        kind, key = spec[0], spec[1]
        name = f"kcfg_{key}"
        if kind == "check":
            _, _, text, tip = spec
            self.add(f'<item row="{row}" column="0" colspan="2">', depth)
            self.add(f'<widget class="QCheckBox" name="{name}">', depth + 1)
            self.string_prop("text", text, depth + 2)
            if tip:
                self.string_prop("toolTip", tip, depth + 2)
            self.initial_state(key, depth + 2)
            self.add("</widget>", depth + 1)
            self.add("</item>", depth)
            return

        label = spec[2]
        tip = spec[-1]
        label_name = self.uid("label")
        self.labels[key] = label_name
        self.add(f'<item row="{row}" column="0">', depth)
        self.add(f'<widget class="QLabel" name="{label_name}">', depth + 1)
        self.string_prop("text", label, depth + 2)
        self.initial_state(key, depth + 2)
        self.add("</widget>", depth + 1)
        self.add("</item>", depth)

        self.add(f'<item row="{row}" column="1">', depth)
        if kind == "spin":
            _, _, _, lo, hi, suffix, _ = spec
            self.add(f'<widget class="QSpinBox" name="{name}">', depth + 1)
            self.add(f'<property name="minimum"><number>{lo}</number></property>', depth + 2)
            self.add(f'<property name="maximum"><number>{hi}</number></property>', depth + 2)
            if suffix:
                self.string_prop("suffix", suffix, depth + 2)
        elif kind == "dspin":
            _, _, _, lo, hi, suffix, _ = spec
            self.add(f'<widget class="QDoubleSpinBox" name="{name}">', depth + 1)
            self.add('<property name="decimals"><number>1</number></property>', depth + 2)
            self.add('<property name="singleStep"><double>0.5</double></property>', depth + 2)
            self.add(f'<property name="minimum"><double>{lo}</double></property>', depth + 2)
            self.add(f'<property name="maximum"><double>{hi}</double></property>', depth + 2)
            if suffix:
                self.string_prop("suffix", suffix, depth + 2)
        elif kind == "combo":
            self.add(f'<widget class="QComboBox" name="{name}">', depth + 1)
            for item in spec[3]:
                self.add("<item>", depth + 2)
                self.string_prop("text", item, depth + 3)
                self.add("</item>", depth + 2)
        elif kind == "line":
            self.add(f'<widget class="QLineEdit" name="{name}">', depth + 1)
            self.string_prop("placeholderText", spec[3], depth + 2)
        elif kind == "color":
            self.add(f'<widget class="KColorButton" name="{name}">', depth + 1)
            self.add('<property name="alphaChannelEnabled"><bool>true</bool></property>', depth + 2)
        else:
            raise ValueError(kind)
        if tip:
            self.string_prop("toolTip", tip, depth + 2)
        self.initial_state(key, depth + 2)
        self.add("</widget>", depth + 1)
        self.add("</item>", depth)

    def initial_state(self, key, depth):
        # Widgets enabled by a checkbox start disabled; loading a checked value enables them.
        rule = checkbox_rule(key)
        if rule and rule[1]:
            self.add('<property name="enabled"><bool>false</bool></property>', depth)

    def connections(self, depth):
        self.add("<connections>", depth)
        for key in WHEN:
            rule = checkbox_rule(key)
            if not rule:
                continue
            sender, enabled_when_checked = rule
            slot = "setEnabled(bool)" if enabled_when_checked else "setDisabled(bool)"
            for receiver in (f"kcfg_{key}", self.labels.get(key)):
                if not receiver:
                    continue
                self.add("<connection>", depth + 1)
                self.add(f"<sender>kcfg_{sender}</sender>", depth + 2)
                self.add("<signal>toggled(bool)</signal>", depth + 2)
                self.add(f"<receiver>{receiver}</receiver>", depth + 2)
                self.add(f"<slot>{slot}</slot>", depth + 2)
                self.add("</connection>", depth + 1)
        self.add("</connections>", depth)

    def presets_tab(self, depth):
        self.add('<widget class="QWidget" name="presetsTab">', depth)
        self.add(f'<attribute name="title"><string>{escape(PRESETS_TAB)}</string></attribute>', depth + 1)
        self.add('<layout class="QVBoxLayout" name="presetsLayout">', depth + 1)
        self.add("<item>", depth + 2)
        self.add('<widget class="QLabel" name="presetsText">', depth + 3)
        self.string_prop("text", PRESETS_TEXT, depth + 4)
        self.add('<property name="textFormat"><enum>Qt::RichText</enum></property>', depth + 4)
        self.add('<property name="openExternalLinks"><bool>true</bool></property>', depth + 4)
        self.add('<property name="wordWrap"><bool>true</bool></property>', depth + 4)
        self.add("</widget>", depth + 3)
        self.add("</item>", depth + 2)
        self.add("<item>", depth + 2)
        self.add('<spacer name="presetsSpacer">', depth + 3)
        self.add('<property name="orientation"><enum>Qt::Vertical</enum></property>', depth + 4)
        self.add("</spacer>", depth + 3)
        self.add("</item>", depth + 2)
        self.add("</layout>", depth + 1)
        self.add("</widget>", depth)

    def build(self):
        self.add('<?xml version="1.0" encoding="UTF-8"?>', 0)
        self.add("<!-- Generated by tools/gen_config_ui.py, edit that script instead. -->", 0)
        self.add('<ui version="4.0">', 0)
        self.add("<class>OsdDeskSnakeConfig</class>", 1)
        self.add('<widget class="QWidget" name="OsdDeskSnakeConfig">', 1)
        self.add('<layout class="QVBoxLayout" name="mainLayout">', 2)
        self.add("<item>", 3)
        self.add('<widget class="QLabel" name="appLink">', 4)
        self.string_prop("text", APP_LINK, 5)
        self.string_prop("toolTip", APP_LINK_TIP, 5)
        self.add('<property name="textFormat"><enum>Qt::RichText</enum></property>', 5)
        self.add('<property name="openExternalLinks"><bool>true</bool></property>', 5)
        self.add('<property name="wordWrap"><bool>true</bool></property>', 5)
        self.add("</widget>", 4)
        self.add("</item>", 3)
        self.add("<item>", 3)
        self.add('<widget class="QTabWidget" name="tabs">', 4)
        for title, groups in TABS:
            self.add(f'<widget class="QWidget" name="{self.uid("tab")}">', 5)
            self.add(f'<attribute name="title"><string>{escape(title)}</string></attribute>', 6)
            self.add(f'<layout class="QVBoxLayout" name="{self.uid("tabLayout")}">', 6)
            # Each tab scrolls, so the dialog opens at a normal size instead of
            # growing to the height of the tallest tab.
            self.add("<item>", 7)
            self.add(f'<widget class="QScrollArea" name="{self.uid("scroll")}">', 8)
            self.add('<property name="frameShape"><enum>QFrame::NoFrame</enum></property>', 9)
            self.add('<property name="widgetResizable"><bool>true</bool></property>', 9)
            self.add(f'<widget class="QWidget" name="{self.uid("scrollContents")}">', 9)
            self.add(f'<layout class="QVBoxLayout" name="{self.uid("contentLayout")}">', 10)
            for group_title, fields in groups:
                self.add("<item>", 11)
                self.add(f'<widget class="QGroupBox" name="{self.uid("group")}">', 12)
                self.string_prop("title", group_title, 13)
                self.add(f'<layout class="QFormLayout" name="{self.uid("form")}">', 13)
                for row, spec in enumerate(fields):
                    self.field(spec, row, 14)
                self.add("</layout>", 13)
                self.add("</widget>", 12)
                self.add("</item>", 11)
            self.add("<item>", 11)
            self.add(f'<spacer name="{self.uid("spacer")}">', 12)
            self.add('<property name="orientation"><enum>Qt::Vertical</enum></property>', 13)
            self.add("</spacer>", 12)
            self.add("</item>", 11)
            self.add("</layout>", 10)
            self.add("</widget>", 9)
            self.add("</widget>", 8)
            self.add("</item>", 7)
            self.add("</layout>", 6)
            self.add("</widget>", 5)
        self.presets_tab(5)
        self.add("</widget>", 4)
        self.add("</item>", 3)
        self.add("</layout>", 2)
        self.add("</widget>", 1)
        self.add("<customwidgets>", 1)
        self.add("<customwidget>", 2)
        self.add("<class>KColorButton</class>", 3)
        self.add("<extends>QPushButton</extends>", 3)
        self.add("<header>kcolorbutton.h</header>", 3)
        self.add("</customwidget>", 2)
        self.add("</customwidgets>", 1)
        self.add("<resources/>", 1)
        self.connections(1)
        self.add("</ui>", 0)
        return "\n".join(self.lines) + "\n"


def keys():
    return (spec[1] for spec in iter_fields())


def strings():
    """All user-visible strings, for the translation template."""
    yield APP_LINK
    yield APP_LINK_TIP
    yield PRESETS_TAB
    yield PRESETS_TEXT
    for title, groups in TABS:
        yield title
        for group_title, fields in groups:
            yield group_title
            for spec in fields:
                kind = spec[0]
                if kind == "check":
                    yield spec[2]
                    yield spec[3]
                    continue
                yield spec[2]
                yield spec[-1]
                if kind == "combo":
                    yield from spec[3]
                if kind in ("spin", "dspin"):
                    yield spec[5]


def js_model():
    """TABS as plain objects: { title, groups: [{ title, fields: [{ kind, key, ... }] }] }."""
    tabs = []
    for title, groups in TABS:
        out_groups = []
        for group_title, fields in groups:
            out_fields = []
            for spec in fields:
                kind, key = spec[0], spec[1]
                field = {"kind": kind, "key": key}
                if kind == "check":
                    field.update(text=spec[2], tooltip=spec[3])
                else:
                    field.update(label=spec[2], tooltip=spec[-1])
                if kind in ("spin", "dspin"):
                    field.update(min=spec[3], max=spec[4], suffix=spec[5])
                elif kind == "combo":
                    field.update(items=list(spec[3]))
                elif kind == "line":
                    field.update(placeholder=spec[3])
                out_fields.append(field)
            out_groups.append({"title": group_title, "fields": out_fields})
        tabs.append({"title": title, "groups": out_groups})
    rules = ",\n".join(f"    {key}: v => {expr}" for key, expr in WHEN.items())
    return ("// Generated by tools/gen_config_ui.py, edit that script instead.\n"
            ".pragma library\n\n"
            "var tabs = " + json.dumps(tabs, indent=4, ensure_ascii=False) + ";\n\n"
            "// When a setting has an effect; the others are greyed out.\n"
            "var enabledWhen = {\n" + rules + "\n};\n")


def schema_js():
    """main.xml entries as { Key: [type, default] } for Settings.qml."""
    ns = "{http://www.kde.org/standards/kcfg/1.0}"
    convert = {
        "Int": ("int", int),
        "Bool": ("bool", lambda text: text == "true"),
        "Double": ("real", float),
        "String": ("string", str),
        "Color": ("color", str),
    }
    entries = {}
    for entry in ET.parse(SCHEMA_XML).getroot().iter(ns + "entry"):
        kind, parse = convert[entry.get("type")]
        default = entry.find(ns + "default")
        entries[entry.get("name")] = [kind, parse((default.text or "") if default is not None else "")]
    return ("// Generated by tools/gen_config_ui.py from contents/config/main.xml, edit that file instead.\n"
            ".pragma library\n\n"
            "// Key: [type, default]\n"
            "var entries = {\n"
            + ",\n".join(f"    {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}" for k, v in entries.items())
            + "\n};\n")


if __name__ == "__main__":
    OUT.write_text(Ui().build(), encoding="utf-8")
    OUT_JS.write_text(js_model(), encoding="utf-8")
    OUT_SCHEMA.write_text(schema_js(), encoding="utf-8")
    print(f"wrote {OUT.name}, {OUT_JS.name} and {OUT_SCHEMA.name} ({len(list(keys()))} fields)")
