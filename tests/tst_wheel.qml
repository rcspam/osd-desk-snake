import QtQuick
import QtTest
import "../settings-app/src/qml/wheel.js" as Wheel

// Spin boxes of the settings app follow the finger or the wheel, whatever the
// natural scrolling setting: up raises the value.
TestCase {
    name: "Wheel"

    function test_wheelValue_data() {
        return [
            { tag: "mouse wheel up", y: 120, inverted: false, value: 15 },
            { tag: "mouse wheel down", y: -120, inverted: false, value: 5 },
            // Natural scrolling: the system flips the delta and says so.
            { tag: "touchpad finger up", y: -120, inverted: true, value: 15 },
            { tag: "touchpad finger down", y: 120, inverted: true, value: 5 },
            { tag: "half a notch", y: 60, inverted: false, value: 13 },
            { tag: "clamped at the top", y: 1200, inverted: false, value: 20 },
            { tag: "clamped at the bottom", y: -1200, inverted: false, value: 0 }
        ];
    }
    function test_wheelValue(data) {
        // value 10, range 0..20, step 5
        compare(Wheel.wheelValue(10, 0, 20, 5, 0, data.y, data.inverted), data.value);
    }

    function test_horizontalWheel() {
        compare(Wheel.wheelValue(10, 0, 20, 5, 120, 0, false), 15);
    }
}
