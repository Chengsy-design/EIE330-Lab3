#!/usr/bin/env python3
"""Generate the bitmap TikZ figure (LaTeX code, not an image)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import screen_model as sm

OUT = sys.argv[1] if len(sys.argv) > 1 else '../../LaTeX/figures/bitmap_cells.tex'
S = 0.30          # cm per bitmap cell
GAP = 0.55
COLS = {'M': 'white', 'U': 'vgaU', 'S': 'vgaS', 'T': 'vgaT'}
TITLES = {'M': 'M  (FFFF)', 'U': 'U  (FFE0)', 'S': 'S  (07FF)', 'T': 'T  (07E0)'}
POS = {'M': (0.0, 4.7), 'U': (4.1, 4.7), 'S': (0.0, 0.4), 'T': (4.1, 0.4)}

lines = []
lines.append(r'\begin{tikzpicture}[x=1cm,y=1cm,font=\sffamily\scriptsize]')
lines.append(r'\definecolor{vgaBG}{RGB}{0,0,65}')
lines.append(r'\definecolor{vgaU}{RGB}{255,224,0}')
lines.append(r'\definecolor{vgaS}{RGB}{0,255,255}')
lines.append(r'\definecolor{vgaT}{RGB}{0,224,0}')

for ch in 'MUST':
    gx, gy = POS[ch]
    rows = sm.FONT[ch]
    # dark background and grid
    lines.append(r'\fill[vgaBG] (%.3f,%.3f) rectangle ++(%.3f,%.3f);' %
                 (gx, gy, 8 * S, 8 * S))
    for r in range(8):
        for c in range(8):
            if (rows[r] >> (7 - c)) & 1:
                x = gx + c * S
                y = gy + (7 - r) * S
                lines.append(r'\fill[%s] (%.3f,%.3f) rectangle ++(%.3f,%.3f);' %
                             (COLS[ch], x, y, S, S))
    for k in range(9):
        lines.append(r'\draw[black,line width=0.15pt,opacity=0.30] (%.3f,%.3f) -- (%.3f,%.3f);' %
                     (gx + k * S, gy, gx + k * S, gy + 8 * S))
        lines.append(r'\draw[black,line width=0.15pt,opacity=0.30] (%.3f,%.3f) -- (%.3f,%.3f);' %
                     (gx, gy + k * S, gx + 8 * S, gy + k * S))
    lines.append(r'\draw[ink,line width=0.5pt] (%.3f,%.3f) rectangle ++(%.3f,%.3f);' %
                 (gx, gy, 8 * S, 8 * S))
    # row hex labels
    for r in range(8):
        lines.append(r'\node[anchor=west,font=\ttfamily\fontsize{5.6}{6.6}\selectfont,text=accent] at (%.3f,%.3f) {%02X};' %
                     (gx + 8 * S + 0.08, gy + (7 - r) * S + S / 2, rows[r]))
    # title
    lines.append(r'\node[anchor=north,font=\sffamily\bfseries\fontsize{6.4}{7.4}\selectfont] at (%.3f,%.3f) {%s};' %
                 (gx + 4 * S, gy - 0.10, TITLES[ch]))

# column and row indices for the first glyph
gx, gy = POS['M']
for c in range(8):
    lines.append(r'\node[font=\fontsize{5.2}{6}\selectfont,text=muted] at (%.3f,%.3f) {%d};' %
                 (gx + c * S + S / 2, gy + 8 * S + 0.10, 7 - c))
for r in range(8):
    lines.append(r'\node[anchor=east,font=\fontsize{5.2}{6}\selectfont,text=muted] at (%.3f,%.3f) {%d};' %
                 (gx - 0.06, gy + (7 - r) * S + S / 2, r))

# scaling illustration
sx, sy = 9.0, 3.4
lines.append(r'\fill[vgaBG] (%.3f,%.3f) rectangle ++(1.44,1.44);' % (sx, sy))
for r in range(8):
    for c in range(8):
        lines.append(r'\fill[white] (%.3f,%.3f) rectangle ++(0.18,0.18);' %
                     (sx + c * 0.18, sy + (7 - r) * 0.18))
for k in range(9):
    lines.append(r'\draw[ink,line width=0.12pt] (%.3f,%.3f) -- (%.3f,%.3f);' %
                 (sx + k * 0.18, sy, sx + k * 0.18, sy + 1.44))
    lines.append(r'\draw[ink,line width=0.12pt] (%.3f,%.3f) -- (%.3f,%.3f);' %
                 (sx, sy + k * 0.18, sx + 1.44, sy + k * 0.18))
lines.append(r'\draw[ink,line width=0.5pt] (%.3f,%.3f) rectangle ++(1.44,1.44);' % (sx, sy))
lines.append(r'\node[anchor=west,font=\fontsize{5.6}{7}\selectfont,text width=3.0cm] at (%.3f,%.3f) {one bitmap pixel $\rightarrow$ 8$\times$8 screen pixels (64$\times$64 per glyph)};' %
             (sx + 1.62, sy + 0.72))
lines.append(r'\draw[-{Stealth},ink,line width=0.6pt] (%.3f,%.3f) -- (%.3f,%.3f);' %
             (sx - 0.55, sy + 0.72, sx - 0.05, sy + 0.72))
lines.append(r'\fill[white] (%.3f,%.3f) rectangle ++(0.40,0.40);' % (sx - 0.95, sy + 0.52))
lines.append(r'\draw[ink,line width=0.5pt] (%.3f,%.3f) rectangle ++(0.40,0.40);' % (sx - 0.95, sy + 0.52))
lines.append(r'\node[font=\fontsize{5.2}{6}\selectfont,text=muted] at (%.3f,%.3f) {bitmap cell};' %
             (sx - 0.75, sy + 0.30))
lines.append(r'\end{tikzpicture}')

with open(OUT, 'w') as f:
    f.write('\n'.join(lines) + '\n')
print('wrote', OUT)
