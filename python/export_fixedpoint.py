import numpy as np, yaml
from pathlib import Path, PurePath

cfg=yaml.safe_load(open("config.yaml"))
tb,fb=cfg["quant"]["total_bits"],cfg["quant"]["frac_bits"]
coeff_dir=Path(cfg["export"]["out_dir"]); coeff_dir.mkdir(parents=True,exist_ok=True)

def quant(x): 
    scale=1<<fb
    q=np.round(x*scale).astype(int)
    return np.clip(q,-(1<<(tb-1)),(1<<(tb-1))-1)

W1=np.load("artifacts/W1.npy"); b1=np.load("artifacts/b1.npy")
W2=np.load("artifacts/W2.npy"); b2=np.load("artifacts/b2.npy")
np.savetxt(coeff_dir/"weights_layer1.txt",quant(W1).flatten(),fmt="%d")
np.savetxt(coeff_dir/"bias_layer1.txt",quant(b1),fmt="%d")
np.savetxt(coeff_dir/"weights_layer2.txt",quant(W2).flatten(),fmt="%d")
np.savetxt(coeff_dir/"bias_layer2.txt",quant(b2),fmt="%d")
print("Exported fixed-point coeffs to", coeff_dir)
