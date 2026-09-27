.pragma library

// Wheel scrolling on a spin box. Qt Quick's SpinBox ignores WheelEvent.inverted,
// so with natural scrolling a touchpad raised the value when the finger went
// down; and it rounds each event on its own, so the small deltas of a touchpad
// either never moved a step-1 field or moved a step-5 field by 1 each.
// This follows the finger or the wheel (up raises the value) and adds the
// deltas up: one notch (120), or the same travel on a touchpad, is one step.
//
// rest: the part of a step not applied yet, from the previous call.
// Returns { value, rest } to keep for the next call.
function wheelStep(value, from, to, stepSize, angleX, angleY, inverted, rest) {
    const angle = angleY !== 0 ? angleY : angleX;
    const steps = rest + stepSize * (inverted ? -angle : angle) / 120;
    const whole = Math.trunc(steps);
    const next = Math.max(from, Math.min(to, value + whole));
    // At a limit, drop what is left so turning back reacts at once.
    return { value: next, rest: next === value + whole ? steps - whole : 0 };
}
