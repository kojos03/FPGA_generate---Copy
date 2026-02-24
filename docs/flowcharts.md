# Wildfire NN on ZCU106 – Design Flowcharts

Below are Mermaid flowcharts covering the full workflow, the RTL datapath, the control/timing path, and a neuron’s internal structure.

## 1) End-to-end project workflow

```mermaid
graph TD
    A[Dataset\n(data/wildfire)] --> B[Train MLP in Python\npython/train_mlp.py]
    B --> C[Quantize / Export fixed-point\npython/export_fixedpoint.py]
    C --> D[Generate LUT + coeff files\npython/gen_sigmoid_lut.py\npython/export_to_xilinx.py]
    D -->|activation_lut.coe, weights/bias txt| E[Vivado project\nvivado_thesis/thesis_ultrascale_1]
    E --> F[Synthesis]
    F --> G[Implementation\n(opt/place/route + reports)]
    G --> H[Bitstream on ZCU106\nxczu7ev]

    %% Optional validation paths
    C --> I[Evaluate fixed-point vs float\npython/evaluate_and_plot.py]
    E --> J[RTL simulation (ModelSim)\n sim/sim.mpf]
```

## 2) Top-level RTL datapath (nn_rgb)

```mermaid
graph LR
    subgraph Video_In
      VI[vs_in, hs_in, de_in]
      RGB["r_in[7:0], g_in[7:0], b_in[7:0]"]
    end

    VI --> IF[Input FFs]
    RGB --> IF

    IF -->|to_integer(unsigned(...))| C0[connection(0..2) = R,G,B]

    subgraph Layer1[Layer 1 (Hidden) – 7 neurons]
      direction LR
      L1N1[neuron j=0]
      L1N2[neuron j=1]
      L1N3[neuron j=2]
      L1N4[neuron j=3]
      L1N5[neuron j=4]
      L1N6[neuron j=5]
      L1N7[neuron j=6]
    end

    C0 -->|inputsIn = connection(2 downto 0)| Layer1
    Layer1 -->|outputs| C1[connection(3..9)]

    subgraph Layer2[Layer 2 (Output) – 2 neurons]
      direction LR
      L2N1[neuron j=0]
      L2N2[neuron j=1]
    end

    C1 -->|inputsIn = connection(9 downto 3)| Layer2
    Layer2 -->|outputs| C2[connection(10..11)]

    subgraph PostProcess
      Y0["Y = (5R + 9G + 2B)/16\n10-cycle delay line y[0..10]"]
      CMP["Compare outputs\nconnection(10), connection(11)"]
      MAP["Color mapping:\n>127 and max-> yellow/blue else gray"]
    end

    C0 --> Y0
    C2 --> CMP --> MAP

    subgraph Video_Out
      VO[vs_out, hs_out, de_out]
      RGB2[r_out, g_out, b_out]
    end

    MAP --> RGB2
```

## 3) Control/timing alignment (control.vhd)

```mermaid
graph LR
    VI[vs_in, hs_in, de_in] --> DLY[Shift-register delay\nlength = generic delay (9)] --> VO[vs_out, hs_out, de_out]
```

## 4) Neuron internals (neuron.vhd)

```mermaid
graph TD
  IN["inputsIn (vector)\ninteger[0..255]"] --> MULS
    W[weightsIn (const array)\n(bias + per-input weights)] --> MULS

    subgraph MULS[Parallel multipliers]
      direction TB
      M1[input(0) * w0]
      M2[input(1) * w1]
      M3[...]
      Mk[input(N-1) * wN-1]
    end

    MULS --> SUM[Adder tree / accumulation]
    W -->|bias| BIAS[Add bias]
    SUM --> BIAS --> SUM2[sumForActivation]

    SUM2 --> CLAMP["Clamp to [-32768..32767]\nform 16-bit address"]
    CLAMP -->|addr(15..4)| ACT[sigmoid_IP]
    ACT --> Q[q(7..0)]
    Q --> OUT[output integer 0..255]
```

Notes

- connection bus mapping (from config.vhd constants):
  - Inputs: connection(0..2) = {R,G,B}
  - Hidden layer outputs: connection(3..9) (7 neurons)
  - Output layer outputs: connection(10..11) (2 neurons)
- Weights are compile-time constants from CONFIG.positions/weights; each neuron receives a contiguous slice.
- sigmoid_lut.vhd here implements a polynomial S-curve (can be swapped with a ROM initialized from coeffs/activation_lut.coe if desired).
