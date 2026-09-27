import QtQuick
import QtTest
import "../package/contents/ui"
import "../settings-app/src/qml/fields.js" as Fields

// The settings app form, the script schema and Settings.qml must list the same keys.
TestCase {
    name: "Fields"

    Settings {
        id: settings
    }

    function test_sameKeysAsSettingsSchema() {
        const formKeys = [];
        Fields.tabs.forEach(tab => tab.groups.forEach(group => group.fields.forEach(f => formKeys.push(f.key))));
        const schemaKeys = Object.keys(settings.schema);
        compare(formKeys.slice().sort(), schemaKeys.slice().sort());
    }

    // Default values keyed like main.xml (and the settings app store).
    function defaults(overrides) {
        const values = {};
        for (const key in settings.schema) {
            values[key] = settings.schema[key][1];
        }
        return Object.assign(values, overrides || {});
    }

    function test_rulesOnlyUseKnownKeys() {
        const schema = settings.schema;
        for (const key in Fields.enabledWhen) {
            verify(schema[key] !== undefined, "rule for unknown setting " + key);
            const seen = [];
            const probe = new Proxy(defaults(), { get: (target, name) => { seen.push(name); return target[name]; } });
            const result = Fields.enabledWhen[key](probe);
            compare(typeof result, "boolean", key);
            seen.forEach(name => verify(schema[name] !== undefined, key + " reads unknown setting " + name));
        }
    }

    function test_rulesWithDefaults() {
        const on = key => Fields.enabledWhen[key](defaults());
        // Defaults: anchor mode, pill style, pill shape, theme colors, Plasma background.
        verify(on("Anchor"));
        verify(!on("PercentX"));
        verify(on("PillRadius"));
        verify(!on("CellShape"));
        verify(!on("Highlight"));
        verify(!on("LabelSource"));
        verify(!on("ActiveColor"));
        verify(on("BackgroundOpacity"));
        verify(!on("BackgroundColor"));
    }

    function test_rulesFollowChoices() {
        const on = (key, overrides) => Fields.enabledWhen[key](defaults(overrides));
        verify(on("PercentX", { PositionMode: 1 }));
        verify(!on("SnapDistance", { SnapToAnchors: false }));
        verify(!on("PillWidth", { PillShape: 1 }));
        verify(!on("PillRadius", { PillShape: 2 }));
        verify(on("SquareSize", { Style: 1, Highlight: 1 }));
        verify(!on("SquareSize", { Style: 1, Highlight: 2 }));
        verify(on("LineWidth", { Style: 2, Highlight: 3 }));
        verify(on("LabelList", { Style: 1, LabelSource: 3 }));
        verify(!on("LabelList", { Style: 1, LabelSource: 2 }));
        verify(on("FontSize", { Caption: 1 }));
        verify(on("InactiveColor", { UseThemeColors: false }));
        verify(!on("OccupiedColor", { UseThemeColors: false, Style: 3 }));
        verify(!on("BackgroundOpacity", { BackgroundMode: 2 }));
        verify(on("BackgroundRadius", { BackgroundMode: 3 }));
    }

    function test_settingsDeclaresEverySchemaEntry() {
        for (const key in settings.schema) {
            const name = key.charAt(0).toLowerCase() + key.slice(1);
            verify(settings[name] !== undefined, "Settings.qml lacks property " + name);
        }
    }

    function test_combosHaveItemsAndSpinsHaveRanges() {
        Fields.tabs.forEach(tab => tab.groups.forEach(group => group.fields.forEach(f => {
            if (f.kind === "combo") {
                verify(f.items.length > 1, f.key);
            }
            if (f.kind === "spin" || f.kind === "dspin") {
                verify(f.max > f.min, f.key);
            }
        })));
    }

    // One step for the app and config.ui, bigger on long ranges (mouse wheel, arrows).
    function test_spinsHaveAStep() {
        Fields.tabs.forEach(tab => tab.groups.forEach(group => group.fields.forEach(f => {
            if (f.kind === "spin") {
                verify(Number.isInteger(f.step) && f.step >= 1, f.key + " has a step");
                verify(f.max - f.min <= 200 || f.step > 1, f.key + " moves faster than 1 on a long range");
            }
        })));
    }
}
