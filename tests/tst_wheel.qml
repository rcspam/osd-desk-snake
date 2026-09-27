import QtQuick
import QtTest
import "../settings-app/src/qml/wheel.js" as Wheel

// Spin boxes of the settings app follow the finger or the wheel, whatever the
// natural scrolling setting: up raises the value. One notch is one step.
TestCase {
    name: "Wheel"

    // value 10, range 0..20, step 5
    function scroll(y, inverted) {
        return Wheel.wheelStep(10, 0, 20, 5, 0, y, inverted, 0).value;
    }

    function test_wheelStep_data() {
        return [
            { tag: "mouse wheel up", y: 120, inverted: false, value: 15 },
            { tag: "mouse wheel down", y: -120, inverted: false, value: 5 },
            // Natural scrolling: the system flips the delta and says so.
            { tag: "touchpad finger up", y: -120, inverted: true, value: 15 },
            { tag: "touchpad finger down", y: 120, inverted: true, value: 5 },
            { tag: "clamped at the top", y: 1200, inverted: false, value: 20 },
            { tag: "clamped at the bottom", y: -1200, inverted: false, value: 0 }
        ];
    }
    function test_wheelStep(data) {
        compare(scroll(data.y, data.inverted), data.value);
    }

    function test_horizontalWheel() {
        compare(Wheel.wheelStep(10, 0, 20, 5, 120, 0, false, 0).value, 15);
    }

    // A touchpad sends many small deltas: they add up to whole steps instead
    // of being rounded away (step 1) or each moving by 1 (step 5).
    function test_smallDeltasAddUp() {
        let state = { value: 10, rest: 0 };
        for (let i = 0; i < 8; i++) {
            state = Wheel.wheelStep(state.value, 0, 100, 1, 0, 15, false, state.rest);
        }
        compare(state.value, 11, "eight 15-unit deltas make one notch, one step of 1");

        state = { value: 10, rest: 0 };
        for (let i = 0; i < 4; i++) {
            state = Wheel.wheelStep(state.value, 0, 100, 5, 0, 15, false, state.rest);
        }
        compare(state.value, 12, "half a notch at step 5: 2 whole units so far");
        compare(state.rest, 0.5);
    }

    function test_restDroppedAtALimit() {
        const state = Wheel.wheelStep(20, 0, 20, 5, 0, 60, false, 0);
        compare(state.value, 20);
        compare(state.rest, 0);
    }
}
