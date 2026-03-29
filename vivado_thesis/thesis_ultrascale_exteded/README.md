# thesis_ultrascale_exteded Vivado Project

## Project path
- `vivado_thesis/thesis_ultrascale_exteded`

## Target part
- `xczu7ev-ffvc1156-2-e` (reused from existing thesis Vivado project in this repository)

## Synthesis top module
- `nn_rgb`

## Design sources
- `VHDL/config.vhd`
- `VHDL/control.vhd`
- `VHDL/multiplier.vhd`
- `VHDL/sigmoid_lut.vhd`
- `VHDL/sigmoid_IP.vhd`
- `VHDL/neuron.vhd`
- `VHDL/frame_stats.vhd`
- `VHDL/fire_frame_aggregator.vhd`
- `VHDL/temporal_tracker.vhd`
- `VHDL/decision_layer.vhd`
- `VHDL/nn_rgb.vhd`

## Simulation sources
- `VHDL/tb_nn_rgb.vhd` (sim top in this project)
- `VHDL/sim_nn_rgb.vhd` (alternative simulation testbench)

## Recreate project (scripted)
From this folder (`vivado_thesis/thesis_ultrascale_exteded`):

```powershell
C:\Xilinx\xilinx1\Vivado\2024.1\bin\vivado.bat -mode batch -source create_thesis_ultrascale_exteded.tcl
```

## Open project in Vivado
```powershell
C:\Xilinx\xilinx1\Vivado\2024.1\bin\vivado.bat thesis_ultrascale_exteded.xpr
```

## Notes
- This setup intentionally separates design sources (`sources_1`) and simulation sources (`sim_1`).
- No board pin constraint file is auto-added here because no valid project-level board XDC was found in this repo root for the extended design. Add your board-specific XDC before bitstream generation.
- Vivado reports a Windows path-length warning for this folder depth. If needed, use `subst` to map a shorter drive path before launching heavy IP/BD flows.
