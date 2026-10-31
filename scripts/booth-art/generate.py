import math
import pathlib

OUT = pathlib.Path(__file__).parent / "svg"

PLUM = "#120A14"
PLUM_1 = "#1D1220"
PLUM_2 = "#2A1A2D"
PLUM_3 = "#3B2640"
RED = "#D62F47"
RED_DK = "#8E1F31"
RED_DEEP = "#4A1220"
AMBER = "#FFC857"
AMBER_DK = "#C98F2B"
WHITE = "#F7F0F2"
WHITE_DK = "#CFC2C8"

ALARM_BG = "#2A0C16"
ALARM_1 = "#3C1220"
ALARM_2 = "#541828"
ALARM_RED = "#FF4D5A"


def svg(body, bg=PLUM):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900">'
        f'<rect width="1600" height="900" fill="{bg}"/>{body}</svg>'
    )


def rect(x, y, w, h, fill, r=0, rot=0, cx=None, cy=None):
    transform = ""
    if rot:
        transform = f' transform="rotate({rot} {cx if cx is not None else x + w / 2} {cy if cy is not None else y + h / 2})"'
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"{transform}/>'


def circle(cx, cy, r, fill):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"/>'


def poly(points, fill):
    pts = " ".join(f"{x},{y}" for x, y in points)
    return f'<polygon points="{pts}" fill="{fill}"/>'


def donut(cx, cy, ro, ri, fill):
    d = (
        f"M{cx - ro},{cy}a{ro},{ro} 0 1,0 {2 * ro},0a{ro},{ro} 0 1,0 {-2 * ro},0z"
        f"M{cx - ri},{cy}a{ri},{ri} 0 1,0 {2 * ri},0a{ri},{ri} 0 1,0 {-2 * ri},0z"
    )
    return f'<path d="{d}" fill="{fill}" fill-rule="evenodd"/>'


def bar(x1, y1, x2, y2, thickness, fill):
    length = math.hypot(x2 - x1, y2 - y1)
    angle = math.degrees(math.atan2(y2 - y1, x2 - x1))
    return (
        f'<rect x="{x1}" y="{y1 - thickness / 2}" width="{length}" height="{thickness}" rx="{thickness / 2}" '
        f'fill="{fill}" transform="rotate({angle} {x1} {y1})"/>'
    )


def backdrop(a, b):
    return (
        poly([(0, 900), (0, 560), (900, 900)], a)
        + poly([(1600, 0), (1600, 380), (760, 0)], b)
    )


def morse():
    rows = [
        (270, ["d", "D", "d", "d", "D", "d", "D", "D"], AMBER),
        (450, ["D", "d", "D", "d", "d", "D", "d", "d", "D"], WHITE),
        (630, ["d", "d", "D", "D", "d", "D", "d", "D"], RED),
    ]
    body = backdrop(PLUM_1, PLUM_2)
    for y, seq, color in rows:
        x = 190
        for symbol in seq:
            w = 56 if symbol == "d" else 170
            body += rect(x, y - 28, w, 56, color, r=28)
            x += w + 34
    body += rect(150, 120, 1300, 22, PLUM_3, r=11) + rect(150, 758, 1300, 22, PLUM_3, r=11)
    return svg(body)


def tower():
    body = backdrop(PLUM_1, PLUM_2) + rect(0, 760, 1600, 140, PLUM_1)
    colors = [RED, AMBER, WHITE, RED_DK]
    cup_w, cup_h, gap = 150, 120, 14
    base_y = 760
    rows = 4
    for level in range(rows):
        count = rows - level
        row_w = count * cup_w + (count - 1) * gap
        start = 800 - row_w / 2
        y = base_y - (level + 1) * cup_h - level * gap
        for i in range(count):
            x = start + i * (cup_w + gap)
            color = colors[(i + level) % len(colors)]
            body += poly([(x, y), (x + cup_w, y), (x + cup_w - 22, y + cup_h), (x + 22, y + cup_h)], color)
            body += rect(x + 14, y, cup_w - 28, 14, PLUM, r=7)
    top_y = base_y - rows * cup_h - (rows - 1) * gap
    x = 800 - cup_w / 2 + 70
    y = top_y - cup_h - 40
    body += (
        f'<g transform="rotate(14 {x + cup_w / 2} {y + cup_h})">'
        + poly([(x, y), (x + cup_w, y), (x + cup_w - 22, y + cup_h), (x + 22, y + cup_h)], AMBER)
        + rect(x + 14, y, cup_w - 28, 14, PLUM, r=7)
        + "</g>"
    )
    return svg(body)


def painting():
    body = backdrop(PLUM_1, PLUM_2)
    body += rect(330, 130, 940, 640, AMBER, r=26) + rect(366, 166, 868, 568, PLUM, r=10)
    palette = [RED, AMBER, WHITE, RED_DK, PLUM_3, WHITE_DK]
    cols, rows = 6, 4
    size = 120
    gap = 20
    start_x = 800 - (cols * size + (cols - 1) * gap) / 2
    start_y = 450 - (rows * size + (rows - 1) * gap) / 2
    tilts = [-3, 2, 4, -2, 3, -4, 1, 3, -1, -3, 2, 4]
    for r in range(rows):
        for c in range(cols):
            if (r, c) in {(0, 5), (3, 0), (2, 3)}:
                continue
            x = start_x + c * (size + gap)
            y = start_y + r * (size + gap)
            color = palette[(r * 2 + c * 3) % len(palette)]
            body += rect(x, y, size, size, color, r=6, rot=tilts[(r * cols + c) % len(tilts)])
    return svg(body)


def right_place():
    body = backdrop(PLUM_1, PLUM_2)
    body += rect(250, 250, 1100, 400, PLUM_3, r=22) + rect(280, 280, 1040, 340, PLUM, r=10)
    sizes = [60, 76, 92, 108, 124]
    colors = [WHITE, AMBER, RED, WHITE_DK, AMBER]
    x = 340
    for i, s in enumerate(sizes):
        slot_w = 170
        cx = x + slot_w / 2
        body += rect(cx - 78, 450 - 78, 156, 156, PLUM_2, r=14)
        if i < 4:
            body += rect(cx - s / 2, 450 - s / 2, s, s, colors[i], r=12 if i % 2 else s / 2)
        x += slot_w + 20
    outside = sizes[4]
    body += (
        '<g transform="rotate(-12 1185 800)">'
        + rect(1185 - outside / 2, 800 - outside / 2, outside, outside, colors[4], r=14)
        + "</g>"
    )
    body += poly([(1185, 668), (1140, 722), (1230, 722)], RED)
    return svg(body)


def pattern():
    body = backdrop(PLUM_1, PLUM_2)
    size, gap = 170, 28
    start_x = 800 - (3 * size + 2 * gap) / 2
    start_y = 450 - (3 * size + 2 * gap) / 2
    order = [(0, 0), (1, 0), (1, 1), (2, 1), (2, 2), (1, 2), (0, 2)]
    centers = {}
    for r in range(3):
        for c in range(3):
            x = start_x + c * (size + gap)
            y = start_y + r * (size + gap)
            centers[(r, c)] = (x + size / 2, y + size / 2)
            body += rect(x, y, size, size, PLUM_3, r=26)
    for (a, b) in zip(order, order[1:]):
        body += bar(*centers[a], *centers[b], 26, AMBER_DK)
    for i, key in enumerate(order):
        x, y = centers[key]
        color = RED if i == 0 else (WHITE if i == len(order) - 1 else AMBER)
        body += rect(x - size / 2, y - size / 2, size, size, color, r=26)
    return svg(body)


def message():
    body = backdrop(PLUM_1, PLUM_2)
    notes = [(430, 400, AMBER, -9), (560, 330, WHITE, 6), (700, 380, RED, -3)]
    for x, y, color, tilt in notes:
        body += rect(x, y, 300, 300, color, r=10, rot=tilt)
    body += (
        '<path d="M600 560 q40 -90 80 -20 t80 -10 t80 -10" fill="none" stroke="'
        + PLUM
        + '" stroke-width="14" stroke-linecap="round"/>'
    )
    body += poly([(1340, 300), (1020, 400), (1130, 470)], WHITE)
    body += poly([(1340, 300), (1130, 470), (1160, 610)], WHITE_DK)
    body += poly([(1130, 470), (1160, 610), (1090, 520)], RED)
    body += bar(900, 640, 1150, 640, 18, PLUM_3) + bar(960, 700, 1230, 700, 18, PLUM_3)
    return svg(body)


def lock():
    body = backdrop(PLUM_1, PLUM_2)
    ring_w, ring_h, t = 520, 340, 74
    def link(cx, cy, color):
        outer = f"M{cx - ring_w / 2 + 170},{cy - ring_h / 2}h{ring_w - 340}a170,170 0 0 1 0,{ring_h}h{-(ring_w - 340)}a170,170 0 0 1 0,{-ring_h}z"
        inner_w, inner_h = ring_w - 2 * t, ring_h - 2 * t
        r = inner_h / 2
        inner = f"M{cx - inner_w / 2 + r},{cy - inner_h / 2}h{inner_w - 2 * r}a{r},{r} 0 0 1 0,{inner_h}h{-(inner_w - 2 * r)}a{r},{r} 0 0 1 0,{-inner_h}z"
        return f'<path d="{outer}{inner}" fill="{color}" fill-rule="evenodd"/>'
    a = link(640, 450, AMBER)
    b = link(960, 450, WHITE)
    body += a + b
    body += (
        '<clipPath id="over"><rect x="690" y="270" width="220" height="180"/></clipPath>'
        f'<g clip-path="url(#over)">{a}</g>'
    )
    body += rect(210, 640, 1180, 24, RED, r=12) + rect(210, 236, 1180, 24, RED, r=12)
    return svg(body)


def scary_memory():
    body = poly([(0, 900), (0, 600), (820, 900)], ALARM_1) + poly([(1600, 0), (1600, 360), (780, 0)], ALARM_2)
    def stripes(y):
        s = rect(0, y, 1600, 54, ALARM_BG)
        for i in range(-2, 34):
            x = i * 64
            s += poly([(x, y + 54), (x + 32, y), (x + 64, y), (x + 32, y + 54)], AMBER)
        return s
    body += stripes(36) + stripes(810)
    for x0, y0, x1, y1 in [(300, 160, 300, 280), (300, 160, 420, 160)]:
        body += bar(x0, y0, x1, y1, 22, WHITE)
    for x0, y0, x1, y1 in [(1300, 160, 1300, 280), (1300, 160, 1180, 160), (300, 740, 300, 620), (300, 740, 420, 740), (1300, 740, 1300, 620), (1300, 740, 1180, 740)]:
        body += bar(x0, y0, x1, y1, 22, WHITE)
    def figure(cx, color, arm):
        out = circle(cx, 310, 56, color)
        out += rect(cx - 36, 390, 72, 180, color, r=30)
        out += bar(cx - 30, 410, cx - 130, 410 - arm, 34, color)
        out += bar(cx + 30, 410, cx + 130, 410 + arm // 2, 34, color)
        out += bar(cx - 20, 560, cx - 70, 700, 36, color)
        out += bar(cx + 20, 560, cx + 70, 700, 36, color)
        return out
    body += figure(620, ALARM_RED, 110) + figure(980, AMBER, 70)
    return svg(body, bg=ALARM_BG)


def heist():
    body = poly([(0, 900), (0, 600), (820, 900)], ALARM_1) + poly([(1600, 0), (1600, 360), (780, 0)], ALARM_2)
    def stripes(y):
        s = rect(0, y, 1600, 54, ALARM_BG)
        for i in range(-2, 34):
            x = i * 64
            s += poly([(x, y + 54), (x + 32, y), (x + 64, y), (x + 32, y + 54)], AMBER)
        return s
    body += stripes(36) + stripes(810)
    left, right = 190, 1410
    for y in [200, 330, 460, 590, 720]:
        body += rect(left - 36, y - 36, 72, 72, WHITE, r=14) + rect(right - 36, y - 36, 72, 72, WHITE, r=14)
    beams = [(200, 720), (330, 590), (460, 460), (590, 330), (720, 200)]
    for i, (ya, yb) in enumerate(beams):
        color = ALARM_RED if i % 2 == 0 else AMBER
        body += bar(left + 36, ya, right - 36, yb, 12, color)
    body += poly([(800, 390), (850, 460), (800, 530), (750, 460)], WHITE)
    return svg(body, bg=ALARM_BG)


ART = {
    "booth-1": morse,
    "booth-2": tower,
    "booth-3": painting,
    "booth-4": right_place,
    "booth-5": pattern,
    "booth-6": message,
    "booth-7": lock,
    "sabotage-6": scary_memory,
    "sabotage-7a": heist,
}

if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    for name, make in ART.items():
        (OUT / f"{name}.svg").write_text(make())
        print(name)
