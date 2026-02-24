import numpy as np,yaml
from pathlib import Path
cfg=yaml.safe_load(open("config.yaml"))
N=cfg["export"]["lut_size"]
lo,hi=cfg["export"]["lut_range"]
xs=np.linspace(lo,hi,N)
ys=1/(1+np.exp(-xs))
q=np.round(ys*(1<<cfg["quant"]["frac_bits"])).astype(int)
out=Path(cfg["export"]["out_dir"]); out.mkdir(parents=True,exist_ok=True)
np.savetxt(out/"activation_lut.txt",q,fmt="%d")
print("Wrote activation_lut.txt")
