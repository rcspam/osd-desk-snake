.pragma library

// New value of a spin box for a wheel event. Qt Quick's SpinBox ignores
// WheelEvent.inverted, so with natural scrolling a touchpad raised the value
// when the finger went down. This follows the finger or the wheel instead:
// up raises the value. One step per notch (120), fractions rounded like Qt.
function wheelValue(value, from, to, stepSize, angleX, angleY, inverted) {
    const angle = angleY !== 0 ? angleY : angleX;
    const notches = (inverted ? -angle : angle) / 120;
    return Math.max(from, Math.min(to, value + Math.round(stepSize * notches)));
}
