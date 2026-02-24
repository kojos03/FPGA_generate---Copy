# Converts activation_lut.txt + weights/bias .txt -> Xilinx .coe and a VHDL pkg.
# Run from NN_RGB_FPGA/python
import numpy as np, yaml
from pathlib import Path

CFG = yaml.safe_load(open("config.yaml"))
OUT = Path("../FPGA_generate/coeffs")
VHDL_OUT = Path("../FPGA_generate/vhdl"); VHDL_OUT.mkdir(parents=True, exist_ok=True)

def load_ints(p): return [int(x) for x in Path(p).read_text().strip().splitlines()]

# ---- 1) COE for sigmoid LUT (depth = lut_size, radix 10)
def write_coe(values, path, radix=10):
    with open(path, "w") as f:
        f.write(f"memory_initialization_radix={radix};\n")
        f.write("memory_initialization_vector=\n")
        for i,v in enumerate(values):
            end = ";\n" if i==len(values)-1 else ",\n"
            f.write(f"{v}{end}")

act = load_ints(OUT/"activation_lut.txt")
write_coe(act, OUT/"activation_lut.coe", radix=10)

# ---- 2) VHDL package with weights/bias (constants, signed Q format)
tb, fb = CFG["quant"]["total_bits"], CFG["quant"]["frac_bits"]
def arr(name, data, rows, cols):
    # data is row-major flattened
    # VHDL signed ranges: tb bits => (tb-1 downto 0)
    lines = []
    lines.append(f"  type {name}_row_t is array (0 to {cols-1}) of signed({tb-1} downto 0);")
    lines.append(f"  type {name}_t     is array (0 to {rows-1}) of signed({tb-1} downto 0);") if cols==1 else \
    lines.append(f"  type {name}_mat_t is array (0 to {rows-1}) of {name}_row_t;")
    return "\n".join(lines)

def vec_init(vec):   # returns VHDL aggregate for a 1D vector
    return "(" + ", ".join([f"to_signed({int(v)}, {tb})" for v in vec]) + ")"

def mat_init(mat, rows, cols):
    s = "("
    for r in range(rows):
        row = mat[r*cols:(r+1)*cols]
        s += "(" + ", ".join([f"to_signed({int(v)}, {tb})" for v in row]) + ")"
        s += ", " if r<rows-1 else ""
    s += ")"
    return s

W1 = load_ints(OUT/"weights_layer1.txt")  # hidden x 3
B1 = load_ints(OUT/"bias_layer1.txt")     # hidden
W2 = load_ints(OUT/"weights_layer2.txt")  # 2 x hidden
B2 = load_ints(OUT/"bias_layer2.txt")     # 2

hidden = len(B1); in_dim = 3; out_dim = len(B2)

pkg = []
pkg.append("library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;")
pkg.append("package nn_coeff_pkg is")
pkg.append(f"  constant FRAC_BITS : integer := {fb};")
pkg.append(arr("W1", W1, hidden, in_dim))
pkg.append(arr("B1", B1, hidden, 1))
pkg.append(arr("W2", W2, out_dim, hidden))
pkg.append(arr("B2", B2, out_dim, 1))
pkg.append(f"  constant W1_CONST : { 'W1_mat_t' } := {mat_init(W1, hidden, in_dim)};")
pkg.append(f"  constant B1_CONST : { 'B1_t' }     := {vec_init(B1)};")
pkg.append(f"  constant W2_CONST : { 'W2_mat_t' } := {mat_init(W2, out_dim, hidden)};")
pkg.append(f"  constant B2_CONST : { 'B2_t' }     := {vec_init(B2)};")
pkg.append("end package;")
Path(VHDL_OUT/"nn_coeff_pkg.vhd").write_text("\n".join(pkg), encoding="utf-8")

print("Wrote:")
print(" -", OUT/"activation_lut.coe")
print(" -", VHDL_OUT/"nn_coeff_pkg.vhd")
