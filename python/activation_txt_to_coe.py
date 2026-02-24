# activation_txt_to_coe.py
from pathlib import Path

txt = Path("../FPGA_generate/coeffs/activation_lut.txt")
vals = [int(x) for x in txt.read_text().strip().splitlines()]

coe = Path("../FPGA_generate/coeffs/activation_lut.coe")
with open(coe, "w") as f:
    f.write("memory_initialization_radix=10;\n")
    f.write("memory_initialization_vector=\n")
    for i, v in enumerate(vals):
        end = ";\n" if i == len(vals) - 1 else ",\n"
        f.write(f"{v}{end}")
print("Wrote", coe)
