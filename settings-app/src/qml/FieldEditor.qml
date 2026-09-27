import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "fields.js" as Fields

// One settings field (see fields.js), bound to the SettingsStore. Controls are
// refreshed through sync() whenever the stored value changes, so Revert and
// Defaults update them even after user edits broke their initial bindings.
Loader {
    id: root

    required property var field
    required property var store

    readonly property var value: field.key ? store[field.key] : undefined
    // Greyed out when the setting has no effect with the current choices.
    readonly property var rule: field.key ? Fields.enabledWhen[field.key] : undefined

    enabled: !rule || rule(store)

    QQC2.ToolTip.text: field.tooltip ? i18n(field.tooltip) : ""
    QQC2.ToolTip.visible: hover.hovered && QQC2.ToolTip.text !== ""

    HoverHandler {
        id: hover
    }

    function set(value) {
        store.setValueFromUi(field.key, value);
    }

    sourceComponent: {
        switch (field.kind) {
        case "section":
            return sectionComponent;
        case "spin":
            return spinComponent;
        case "dspin":
            return decimalSpinComponent;
        case "check":
            return checkComponent;
        case "combo":
            return comboComponent;
        case "line":
            return lineComponent;
        default:
            return colorComponent;
        }
    }

    onValueChanged: if (item) item.sync()
    onLoaded: item.sync()

    Component {
        id: sectionComponent

        Kirigami.Separator {
            function sync() {
            }
        }
    }

    Component {
        id: spinComponent

        QQC2.SpinBox {
            from: root.field.min
            to: root.field.max
            stepSize: root.field.step
            editable: true
            textFromValue: (value, locale) => value + root.field.suffix
            valueFromText: (text, locale) => parseInt(text) || 0
            onValueModified: root.set(value)

            function sync() {
                value = root.value;
            }
        }
    }

    // One decimal, as tenths on an integer SpinBox.
    Component {
        id: decimalSpinComponent

        QQC2.SpinBox {
            from: root.field.min * 10
            to: root.field.max * 10
            stepSize: 5
            editable: true
            textFromValue: (value, locale) => Number(value / 10).toLocaleString(locale, "f", 1) + root.field.suffix
            valueFromText: (text, locale) => Math.round((Number.fromLocaleString(locale, text.replace(root.field.suffix, "").trim()) || 0) * 10)
            validator: RegularExpressionValidator {
                regularExpression: /[0-9]+([.,][0-9])?\s*%?/
            }
            onValueModified: root.set(value / 10)

            function sync() {
                value = Math.round(Number(root.value) * 10);
            }
        }
    }

    Component {
        id: checkComponent

        QQC2.CheckBox {
            text: i18n(root.field.text)
            onToggled: root.set(checked)

            function sync() {
                checked = !!root.value;
            }
        }
    }

    Component {
        id: comboComponent

        QQC2.ComboBox {
            model: root.field.items.map(label => i18n(label))
            onActivated: index => root.set(index)

            function sync() {
                currentIndex = root.value;
            }
        }
    }

    Component {
        id: lineComponent

        QQC2.TextField {
            placeholderText: root.field.placeholder
            onTextEdited: root.set(text)

            function sync() {
                if (text !== root.value) {
                    text = root.value;
                }
            }
        }
    }

    Component {
        id: colorComponent

        ColorButton {
            showAlphaChannel: true
            dialogTitle: i18n(root.field.label).replace(/\s*:\s*$/, "")
            onAccepted: color => root.set(color)

            function sync() {
                color = root.value;
            }
        }
    }
}
