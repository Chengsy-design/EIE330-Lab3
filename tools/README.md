# Report figure tools — EIE330 Lab 3

These four scripts turn the simulation output into the figures of the report. They
were written with AI assistance (**DeepSeek**) at the team's specification: the team
fixed the inputs and the expected output of each script, reviewed the code line by
line, and ran every figure in the report with them. The RTL, the testbenches and the
verification criteria were written by the team, and every number in the report comes
from running these tools on the recorded simulation output.

| file | role | input | output |
|---|---|---|---|
| `vcd_util.py` | minimal VCD parser (stdlib only) | `results/*.vcd` | time series per signal |
| `screen_model.py` | independent expected-screen model; RGB565 expansion | — | 640x480 expected frame |
| `make_figures.py` | plots the measured figures | `results/*.vcd`, `results/screen.hex` | `line_timing.pdf`*, `frame_timing.pdf`*, `reset_timing.pdf`, `pixel_scanlines.pdf`, `screen_expected.png`, `screen_sim.png`, `screen_compare.png`, `results/screen_check.txt` |
| `make_tikz.py` | writes the bitmap figure as TikZ source | font constants in `screen_model.py` | `bitmap_cells.tex` |

\* `make_figures.py` still contains the two line/field timing plots; the final
version of the report keeps only `reset_timing.pdf`, `pixel_scanlines.pdf` and
`screen_compare.png` from this script, because the corresponding sections were cut.

## Usage

```sh
# from this folder, with the simulation results one level down in code/Lab_3_1/results
python3 make_tikz.py   ../LaTeX/figures/bitmap_cells.tex
python3 make_figures.py --results ../code/Lab_3_1/results --out ../LaTeX/figures
```

## Dependencies

- `python3` — `vcd_util.py` and `screen_model.py` are standard library only.
- `numpy`, `matplotlib` (PDF backend, `pdf.fonttype = 42`) and `Pillow` for the plots
  and the screen reconstructions.
- No TeX installation is needed here; `make_tikz.py` only writes LaTeX source.

Caveat: `make_figures.py` (`fig_compare`) hard-codes
`/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf`, a Linux path. On another system,
point it at any DejaVu Sans file before running that function.

## Relationship to the project

The same four files also live in `code/Lab_3_1/scripts/`, which is what the project
`Makefile` runs (`make figures`). This folder is the standalone, reviewable copy kept
outside the RTL project so that the figure tools can be inspected on their own. If
the two copies ever diverge, the ones in `code/Lab_3_1/scripts/` are the ones the
report was built from.
