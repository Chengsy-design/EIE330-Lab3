#!/usr/bin/env python3
"""Generate the Lab 3 report figures from the simulation data.

Usage:
    python3 scripts/make_figures.py [--results results] [--out ../../LaTeX/figures]

Waveforms are written as vector PDF (fonts embedded as Type 42).  Screen
reconstructions are raster PNG because a 640x480 colour image is inherently
raster; they are rendered at 2x with nearest-neighbour scaling.
"""
import argparse
import os
import sys

import numpy as np

import matplotlib
matplotlib.use('Agg')
import matplotlib as mpl
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyArrowPatch
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vcd_util import VCD
import screen_model as sm

INK = '#242521'
ACCENT = '#9B4C2A'
MUTED = '#66675F'
RULE = '#CECEC5'
LIGHT = '#F2F1EC'
ACTIVE = '#E8EEF4'
SYNC = '#F4F2EC'

mpl.rcParams.update({
    'font.family': 'DejaVu Sans',
    'font.size': 7.6,
    'axes.linewidth': 0.6,
    'axes.edgecolor': INK,
    'axes.labelcolor': INK,
    'xtick.color': INK,
    'ytick.color': INK,
    'text.color': INK,
    'pdf.fonttype': 42,
    'ps.fonttype': 42,
    'savefig.bbox': 'tight',
    'savefig.pad_inches': 0.02,
})


def rgb(c):
    return tuple(v / 255 for v in sm.rgb565_to_rgb(c))


def clean(series):
    return [(t, v) for t, v in series if v is not None]


def steps(series, t0, t1):
    """Step points for a VCD series, clipped to [t0, t1].

    The first VCD sample is taken one falling edge after the window start, so
    use its value as the value at t0 when it is within one pixel clock.
    """
    s = clean(series)
    if s and s[0][0] <= t0 + 40:
        pts = [(t0, s[0][1])]
    else:
        pts = [(t0, value_at(series, t0))]
    for t, v in s:
        if t0 < t <= t1:
            pts.append((t, v))
    return np.array([p[0] for p in pts]), np.array([p[1] for p in pts])


def value_at(series, t, default=0):
    val = default
    for tt, vv in clean(series):
        if tt > t:
            break
        val = vv
    return val


def lane(ax, series, t0, t1, y, tf, h=0.62, color=INK, lw=0.95):
    x, v = steps(series, t0, t1)
    ax.plot(tf(x), y + h * v, drawstyle='steps-post', color=color, lw=lw,
            solid_capstyle='butt', zorder=4)
    ax.axhline(y, color=RULE, lw=0.45, zorder=2)
    ax.axhline(y + h, color=RULE, lw=0.45, zorder=2)


def lane_labels(ax, labels, h=0.62):
    ax.set_yticks([y + h / 2 for _, y in labels])
    ax.set_yticklabels([name for name, _ in labels])
    ax.tick_params(axis='y', length=0)
    for s in ax.spines.values():
        s.set_visible(False)


def save(fig, out, name):
    path = os.path.join(out, name)
    fig.savefig(path)
    plt.close(fig)
    print('wrote', path)


# ----------------------------------------------------------------------------
# 1. Line timing
# ----------------------------------------------------------------------------
def fig_line(results, out):
    v = VCD(os.path.join(results, 'tb_vga_line.vcd'))
    t0, t1 = 1280100, 1344100
    s = lambda n: v.series(n)
    us = lambda t: (t - t0) / 1000.0

    fig = plt.figure(figsize=(7.05, 4.15))
    gs = fig.add_gridspec(2, 1, height_ratios=[2.5, 1.0], hspace=0.12)
    ax = fig.add_subplot(gs[0])
    bx = fig.add_subplot(gs[1], sharex=ax)

    ax.set_xlim(0, 64)
    ax.set_ylim(-0.15, 4.35)

    # segment backgrounds
    for base in (0, 32.0):
        ax.axvspan(base, base + 3.84, color=SYNC, zorder=0)
        ax.axvspan(base + 5.76, base + 31.36, color=ACTIVE, zorder=0)
        ax.axvspan(base + 32.0, base + 35.84, color=SYNC, zorder=0)
        ax.axvspan(base + 37.76, base + 63.36, color=ACTIVE, zorder=0)

    for base in (0, 32.0):
        for x in (base + 3.84, base + 5.44, base + 5.76,
                  base + 31.36, base + 31.68, base + 32.0):
            ax.axvline(x, color=RULE, lw=0.45, ls=(0, (2, 2)), zorder=1)

    lane(ax, s('hsync'), t0, t1, 3.0, us)
    lane(ax, s('pix_data_req'), t0, t1, 2.0, us)
    lane(ax, s('rgb_valid'), t0, t1, 1.0, us)
    lane_labels(ax, [('hsync', 3.0), ('pix_data_req', 2.0), ('rgb_valid', 1.0)])
    ax.tick_params(axis='x', labelbottom=False)

    # segment annotations for the first line
    ax.text(1.92, 3.90, 'sync 96 px / 3.84 µs', ha='center', va='bottom',
            fontsize=6.6, color=MUTED)
    ax.text(18.56, 3.90, 'addressable video 640 px / 25.60 µs', ha='center',
            va='bottom', fontsize=6.6, color=ACCENT)
    ax.text(4.8, 0.42, 'BP 40 + LB 8', ha='center', va='center',
            fontsize=5.7, color=MUTED)
    ax.text(31.68, 0.42, 'RB 8 + FP 8', ha='center', va='center',
            fontsize=5.7, color=MUTED)

    # one period arrow
    ax.annotate('', xy=(32.0, 4.24), xytext=(0.0, 4.24),
                arrowprops=dict(arrowstyle='<->', lw=0.55, color=ACCENT))
    ax.text(16.0, 4.27, 'one line scan cycle = 800 pixel clocks = 32.000 µs',
            ha='center', va='bottom', fontsize=6.6, color=ACCENT)

    # 40 ns pixel clock marker
    ax.annotate('1 pixel clock = 40 ns', xy=(5.80, 0.72), xytext=(8.6, 0.55),
                fontsize=6.2, color=MUTED,
                arrowprops=dict(arrowstyle='-', lw=0.4, color=MUTED))

    # bottom counter panel
    bx.set_ylim(-20, 830)
    x, vv = steps(s('cnt_h'), t0, t1)
    bx.plot(us(x), vv, drawstyle='steps-post', color=INK, lw=0.8,
            label='cnt_h')
    x, vv = steps(s('pix_x'), t0, t1)
    vv = np.where(vv > 639, np.nan, vv)
    bx.plot(us(x), vv, drawstyle='steps-post', color=ACCENT, lw=0.8,
            label='pix_x')
    bx.axhline(144, color=RULE, lw=0.5, ls=(0, (1, 2)))
    bx.axhline(783, color=RULE, lw=0.5, ls=(0, (1, 2)))
    bx.text(0.3, 152, 'cnt_h = 144 (first visible)', fontsize=5.9, color=MUTED)
    bx.text(33.0, 700, 'cnt_h = 783 (last visible)', fontsize=5.9, color=MUTED,
            va='bottom')
    bx.set_yticks([0, 144, 400, 783])
    bx.set_xlabel('time from the start of line 40 / µs')
    bx.set_ylabel('count', fontsize=7.0)
    bx.text(8.0, 640, 'cnt_h', color=INK, fontsize=6.6)
    bx.text(8.0, 300, 'pix_x', color=ACCENT, fontsize=6.6)
    bx.tick_params(axis='both', labelsize=6.8)
    ax.tick_params(axis='y', labelsize=7.0)
    bx.set_xlim(0, 64)
    bx.set_xticks(range(0, 65, 4))
    bx.set_xticks(range(0, 65, 2), minor=True)

    save(fig, out, 'line_timing.pdf')


# ----------------------------------------------------------------------------
# 2. Frame timing
# ----------------------------------------------------------------------------
def fig_frame(results, out):
    v = VCD(os.path.join(results, 'tb_vga_frame.vcd'))
    t0 = 16800100
    t1 = t0 + 33600000
    ms = lambda t: (t - t0) / 1e6

    fig, (ax, bx) = plt.subplots(
        2, 1, figsize=(7.05, 3.55), sharex=True,
        gridspec_kw={'height_ratios': [2.0, 1.0], 'hspace': 0.10})
    ax.set_xlim(0, 33.6)
    ax.set_ylim(-0.15, 3.25)

    for base in (0.0, 16.8):
        ax.axvspan(base, base + 0.064, color=SYNC, zorder=0)
        ax.axvspan(base + 1.12, base + 16.48, color=ACTIVE, zorder=0)
        ax.axvspan(base + 16.48, base + 16.8, color=SYNC, zorder=0)

    lane(ax, v.series('vsync'), t0, t1, 2.0, ms)
    lane(ax, v.series('rgb_valid'), t0, t1, 1.0, ms)
    lane_labels(ax, [('vsync', 2.0), ('rgb_valid', 1.0)])
    ax.tick_params(axis='x', labelbottom=False)

    ax.annotate('', xy=(16.8, 3.02), xytext=(0.0, 3.02),
                arrowprops=dict(arrowstyle='<->', lw=0.55, color=ACCENT))
    ax.text(8.4, 3.05, 'one field = 525 lines = 16.800 ms',
            ha='center', va='bottom', fontsize=6.6, color=ACCENT)
    ax.text(8.8, 1.78, 'active video 480 lines / 15.36 ms', ha='center',
            fontsize=6.6, color=ACCENT)
    ax.annotate('vsync 2 lines / 64 µs', xy=(0.10, 2.35), xytext=(1.6, 2.62),
                fontsize=6.2, color=MUTED,
                arrowprops=dict(arrowstyle='-', lw=0.4, color=MUTED))
    ax.annotate('blanking 45 lines / 1.44 ms', xy=(16.62, 0.55),
                xytext=(20.2, 0.55), fontsize=6.0, color=MUTED,
                arrowprops=dict(arrowstyle='-', lw=0.4, color=MUTED))

    bx.set_ylim(-15, 545)
    x, vv = steps(v.series('line_no'), t0, t1)
    bx.plot(ms(x), vv, drawstyle='steps-post', color=INK, lw=0.7)
    bx.axhline(0, color=RULE, lw=0.4)
    bx.axhline(524, color=RULE, lw=0.4)
    bx.set_yticks([0, 240, 480])
    bx.set_ylabel('line', fontsize=7.0)
    bx.set_xlabel('time from the first vsync rising edge / ms')
    bx.set_xticks(range(0, 34, 4))
    bx.set_xticks(range(0, 34, 2), minor=True)
    bx.tick_params(axis='both', labelsize=6.8)
    ax.tick_params(axis='y', labelsize=7.0)
    save(fig, out, 'frame_timing.pdf')


# ----------------------------------------------------------------------------
# 3. Reset timing
# ----------------------------------------------------------------------------
def fig_reset(results, out):
    v = VCD(os.path.join(results, 'tb_vga_reset.vcd'))
    s = lambda n: v.series(n)
    t0 = 3216110
    t1 = 3280110
    us = lambda t: (t - t0) / 1000.0

    fig, (ax, bx) = plt.subplots(
        2, 1, figsize=(7.05, 3.9), sharex=True,
        gridspec_kw={'height_ratios': [2.4, 1.0], 'hspace': 0.10})
    ax.set_xlim(0, 64)
    ax.set_ylim(-0.15, 4.55)
    ax.axvspan(0.005, 0.410, color='#F7E3DE', zorder=2)
    ax.text(0.55, 4.18, 'reset asserted 405 ns', fontsize=6.4, color=ACCENT)

    lane(ax, s('sys_rst_n'), t0, t1, 4.0, us)
    lane(ax, s('hsync'), t0, t1, 3.0, us)
    lane(ax, s('vsync'), t0, t1, 2.0, us)
    lane(ax, s('rgb_valid'), t0, t1, 1.0, us)
    lane_labels(ax, [('sys_rst_n', 4.0), ('hsync', 3.0),
                     ('vsync', 2.0), ('rgb_valid', 1.0)])
    ax.tick_params(axis='x', labelbottom=False)

    ax.annotate('reset: cnt_h = cnt_v = 0, hsync = vsync = 1, rgb = 0000',
                xy=(0.42, 3.65), xytext=(4.8, 4.35), fontsize=6.2, color=MUTED,
                arrowprops=dict(arrowstyle='-', lw=0.4, color=MUTED))
    ax.annotate('vga_clk stops: the clock divider is also reset',
                xy=(0.42, 1.55), xytext=(5.2, 0.95), fontsize=6.2, color=MUTED,
                arrowprops=dict(arrowstyle='-', lw=0.4, color=MUTED))

    bx.set_ylim(-20, 830)
    x, vv = steps(s('cnt_h'), t0, t1)
    bx.plot(us(x), vv, drawstyle='steps-post', color=INK, lw=0.75,
            label='cnt_h')
    x, vv = steps(s('cnt_v'), t0, t1)
    bx.plot(us(x), vv, drawstyle='steps-post', color=ACCENT, lw=0.75,
            label='cnt_v')
    bx.set_yticks([0, 400])
    bx.set_xlabel('time from the reset window start / µs')
    bx.set_ylabel('count', fontsize=7.0)
    bx.text(8.0, 680, 'cnt_h', color=INK, fontsize=6.6)
    bx.text(8.0, 130, 'cnt_v', color=ACCENT, fontsize=6.6)
    bx.set_xticks(range(0, 65, 8))
    bx.set_xticks(range(0, 65, 4), minor=True)
    bx.tick_params(axis='both', labelsize=6.8)
    ax.tick_params(axis='y', labelsize=7.0)

    save(fig, out, 'reset_timing.pdf')


# ----------------------------------------------------------------------------
# 4. Measured scanlines through M
# ----------------------------------------------------------------------------
def fig_pixel_map(results, out):
    frame = sm.load_screen(os.path.join(results, 'screen.hex'))
    rows = [(212, 'row 0', '1100_0011'),
            (228, 'row 2', '1111_1111'),
            (232, 'row 3', '1101_1011')]
    x0, x1 = 64, 144
    fig, axes = plt.subplots(len(rows), 1, figsize=(7.05, 2.75), sharex=True)
    for ax, (y, name, bits) in zip(axes, rows):
        for x in range(x0, x1):
            ax.add_patch(Rectangle((x, 0), 1, 1, facecolor=rgb(frame[y][x]),
                                   edgecolor='none', zorder=1))
        for k in range(9):
            ax.axvline(72 + 8 * k, color='#9A9A92',
                       lw=0.30 if k not in (0, 8) else 0.75, zorder=2)
        ax.add_patch(Rectangle((x0, 0), x1 - x0, 1, fill=False,
                               edgecolor=INK, lw=0.8, zorder=3))
        ax.set_xlim(x0, 168)
        ax.set_ylim(0, 1)
        ax.set_yticks([])
        ax.set_ylabel(name, fontsize=6.8, rotation=0, ha='right', va='center')
        for k, b in enumerate(bits.replace('_', '')):
            ax.text(72 + 8 * k + 4, 1.20, b, ha='center', va='bottom',
                    fontsize=6.6, color=MUTED)
        ax.text(148, 0.5, bits, ha='left', va='center', fontsize=7.0,
                color=ACCENT, family='DejaVu Sans Mono')
        for sp in ax.spines.values():
            sp.set_visible(False)
        ax.tick_params(axis='x', length=0)
    axes[-1].set_xticks([72, 80, 88, 96, 104, 112, 120, 128, 136])
    axes[-1].set_xlabel('screen x / pixel   (M box: 72 … 135; each bitmap cell = 8 × 8 pixels)')
    axes[-1].tick_params(axis='x', labelsize=6.6)
    fig.subplots_adjust(hspace=0.70)
    save(fig, out, 'pixel_scanlines.pdf')


# ----------------------------------------------------------------------------
# 5. Screen reconstructions
# ----------------------------------------------------------------------------
def save_png(frame, path, scale=2):
    img = Image.new('RGB', (sm.WIDTH, sm.HEIGHT))
    img.putdata([sm.rgb565_to_rgb(c) for row in frame for c in row])
    img = img.resize((sm.WIDTH * scale, sm.HEIGHT * scale), Image.NEAREST)
    img.save(path, dpi=(300, 300))
    print('wrote', path)


def fig_compare(out):
    im1 = Image.open(os.path.join(out, 'screen_expected.png')).convert('RGB')
    im2 = Image.open(os.path.join(out, 'screen_sim.png')).convert('RGB')
    w, h = im1.size
    gap = 40
    label_h = 76
    canvas = Image.new('RGB', (2 * w + gap + 20, h + label_h + 10), 'white')
    canvas.paste(im1, (10, label_h))
    canvas.paste(im2, (10 + w + gap, label_h))
    d = ImageDraw.Draw(canvas)
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 46)
    d.text((10, 14), 'design model', font=font, fill=(36, 37, 33))
    d.text((10 + w + gap, 14), 'RTL simulation (0 / 307,200 differ)',
           font=font, fill=(155, 76, 42))
    d.rectangle([9, label_h - 1, 9 + w, label_h + h], outline=(36, 37, 33), width=3)
    d.rectangle([9 + w + gap, label_h - 1, 9 + 2 * w + gap, label_h + h],
                outline=(36, 37, 33), width=3)
    path = os.path.join(out, 'screen_compare.png')
    canvas.save(path, dpi=(300, 300))
    print('wrote', path)


def fig_screens(results, out):
    sim = sm.load_screen(os.path.join(results, 'screen.hex'))
    exp = sm.expected_frame()

    mism = 0
    first = []
    counts = {'M': 0, 'U': 0, 'S': 0, 'T': 0, 'BG': 0}
    for y in range(sm.HEIGHT):
        for x in range(sm.WIDTH):
            e, a = exp[y][x], sim[y][x]
            if e != a:
                mism += 1
                if len(first) < 8:
                    first.append((x, y, e, a))
            if a == sm.COLORS['M']:
                counts['M'] += 1
            elif a == sm.COLORS['U']:
                counts['U'] += 1
            elif a == sm.COLORS['S']:
                counts['S'] += 1
            elif a == sm.COLORS['T']:
                counts['T'] += 1
            else:
                counts['BG'] += 1

    save_png(exp, os.path.join(out, 'screen_expected.png'))
    save_png(sim, os.path.join(out, 'screen_sim.png'))

    with open(os.path.join(results, 'screen_check.txt'), 'w') as f:
        f.write('pixels checked: %d\n' % (sm.WIDTH * sm.HEIGHT))
        f.write('mismatches: %d\n' % mism)
        for item in first:
            f.write('first mismatch: %s\n' % (item,))
        for k, v in counts.items():
            f.write('%s: %d\n' % (k, v))
    print('screen check: %d pixels, %d mismatches' % (sm.WIDTH * sm.HEIGHT, mism))
    for k, v in counts.items():
        print('  %s = %d' % (k, v))
    if mism:
        print('  first mismatches:', first)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--results', default='results')
    ap.add_argument('--out', default='../../LaTeX/figures')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    fig_line(args.results, args.out)
    fig_frame(args.results, args.out)
    fig_reset(args.results, args.out)
    fig_pixel_map(args.results, args.out)
    fig_screens(args.results, args.out)
    fig_compare(args.out)


if __name__ == '__main__':
    main()
