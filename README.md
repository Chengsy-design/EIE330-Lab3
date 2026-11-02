# EIE330 Lab 3-1 — Simple VGA Display

Display the four characters **M U S T** on a 640 x 480 @ 60 Hz VGA screen.
The timing engine is reused from the lecture; `vga_pic` is the new character
source.

## Layout

```
Lab_3_1/
├── RTL/
│   ├── pll.v                 divide-by-2 pixel clock (50 MHz -> 25 MHz)
│   ├── vga_ctrl.v            800 x 525 timing engine (reused unchanged)
│   ├── vga_pic.v             8 x 8 fonts, x8 scale, four 64 x 64 boxes
│   └── vga_display_top.v     top level: sys_clk, sys_rst_n, hsync, vsync, rgb
├── Sim/
│   ├── tb_pll.v
│   ├── tb_vga_ctrl.v
│   ├── tb_vga_pic.v
│   └── tb_vga_display_top.v
└── doc/                      intentionally empty
```

## Run the simulations

```sh
cd Sim

iverilog -g2012 -Wall -o tb_pll.vvp tb_pll.v ../RTL/pll.v
vvp tb_pll.vvp

iverilog -g2012 -Wall -o tb_vga_ctrl.vvp tb_vga_ctrl.v ../RTL/vga_ctrl.v
vvp tb_vga_ctrl.vvp

iverilog -g2012 -Wall -o tb_vga_pic.vvp tb_vga_pic.v ../RTL/vga_pic.v
vvp tb_vga_pic.vvp

iverilog -g2012 -Wall -o tb_vga_display_top.vvp \
    tb_vga_display_top.v ../RTL/vga_display_top.v ../RTL/pll.v \
    ../RTL/vga_ctrl.v ../RTL/vga_pic.v
vvp tb_vga_display_top.vvp
```

`tb_vga_display_top` writes `frame.ppm` (a 640 x 480 P6 frame captured from
the top-level `rgb` output) and short-window VCD files for GTKWave.

## Lint and synthesis

```sh
verilator --lint-only -Wall --top-module vga_display_top \
    RTL/pll.v RTL/vga_ctrl.v RTL/vga_pic.v RTL/vga_display_top.v

yosys -p 'read_verilog RTL/pll.v RTL/vga_ctrl.v RTL/vga_pic.v \
    RTL/vga_display_top.v; hierarchy -check -top vga_display_top; \
    proc; flatten; opt; check -assert; stat'
```

## Virtual board

In **Simple VGA Simulator**, select top module `vga_display_top`, add only
the `RTL/` folder, and map:

| GUI signal | RTL signal |
|------------|------------|
| `clk`      | `sys_clk`  |
| `reset`    | `sys_rst_n`|
| `h_sync`   | `hsync`    |
| `v_sync`   | `vsync`    |
| `rgb`      | `rgb[15:0]`|

Expected screen: dark navy background `0x0088`; M red `0xF800`, U green
`0x07E0`, S cyan `0x07FF`, T yellow `0xFFE0`; boxes at x = 144, 240, 336,
432, y = 208, each 64 x 64.
