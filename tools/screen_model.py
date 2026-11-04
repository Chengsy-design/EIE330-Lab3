"""Independent expected-screen model for EIE330 Lab 3.

The font constants and the layout are written again here, outside Verilog, so
that the simulated frame (results/screen.hex) can be compared with a model
that was not produced by the RTL.  Bit 7 of each row is the leftmost pixel.
"""

WIDTH = 640
HEIGHT = 480
BG = 0x0008

COLORS = {
    'M': 0xFFFF,
    'U': 0xFFE0,
    'S': 0x07FF,
    'T': 0x07E0,
}

# 8x8 bitmaps, row 0 at the top.
FONT = {
    'M': [0xC3, 0xE7, 0xFF, 0xDB, 0xC3, 0xC3, 0xC3, 0xC3],
    'U': [0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xE7, 0x7E],
    'S': [0x7E, 0xE7, 0xE0, 0x7E, 0x07, 0x07, 0xE7, 0x7E],
    'T': [0xFF, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18],
}

# (character, left x, top y, colour)
BOXES = [
    ('M', 72, 208, COLORS['M']),
    ('U', 216, 208, COLORS['U']),
    ('S', 360, 208, COLORS['S']),
    ('T', 504, 208, COLORS['T']),
]

CHAR_SIZE = 64
CHAR_Y0 = 208


def expected_pixel(x, y):
    """Return the RGB565 value the design should produce at (x, y)."""
    if not (CHAR_Y0 <= y < CHAR_Y0 + CHAR_SIZE):
        return BG
    for ch, x0, y0, colour in BOXES:
        if x0 <= x < x0 + CHAR_SIZE:
            row = FONT[ch][(y - y0) >> 3]
            col = 7 - ((x - x0) >> 3)
            return colour if ((row >> col) & 1) else BG
    return BG


def expected_frame():
    """Return a 480x640 list of rows of RGB565 values."""
    return [[expected_pixel(x, y) for x in range(WIDTH)] for y in range(HEIGHT)]


def rgb565_to_rgb(c):
    r5 = (c >> 11) & 0x1F
    g6 = (c >> 5) & 0x3F
    b5 = c & 0x1F
    return (r5 * 255 // 31, g6 * 255 // 63, b5 * 255 // 31)


def load_screen(path):
    with open(path) as f:
        vals = [int(line.strip(), 16) for line in f if line.strip()]
    if len(vals) != WIDTH * HEIGHT:
        raise ValueError(f'{path}: {len(vals)} pixels, expected {WIDTH * HEIGHT}')
    return [vals[y * WIDTH:(y + 1) * WIDTH] for y in range(HEIGHT)]
