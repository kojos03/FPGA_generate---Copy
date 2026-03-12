# Latency and Throughput

Throughput is computed with:

$$
T = \frac{B \cdot f_{\max}}{N_{\text{cycles}}},
$$

where \(B\) is block size in bits and \(N_{\text{cycles}}\) is the number of clock cycles per block.

For this design, one processed block is one RGB pixel:

$$
B = 8 + 8 + 8 = 24 \text{ bits}.
$$

The top-level control alignment uses a delay of 9 cycles, so the end-to-end latency is:

$$
L = \frac{N_{\text{cycles}}}{f_{\text{clk}}}
  = \frac{9}{74.25 \times 10^{6}}
  = 1.212 \times 10^{-7} \text{ s}
  = 121.2 \text{ ns}.
$$

Using \(f_{\max} = 74.25\) MHz, \(B = 24\), and \(N_{\text{cycles}} = 9\):

$$
T = \frac{24 \cdot 74.25 \times 10^{6}}{9}
  = 1.98 \times 10^{8} \text{ bit/s}
  = 198 \text{ Mbit/s}.
$$

Since the architecture is pipelined, after the initial fill it accepts one pixel every clock. Therefore, steady-state streaming throughput is:

$$
T_{\text{steady}} = 24 \cdot 74.25 \times 10^{6}
                  = 1.782 \times 10^{9} \text{ bit/s}
                  = 1.782 \text{ Gbit/s},
$$

which is equivalent to \(74.25\) Mpixel/s.
