import numpy as np,yaml
from pathlib import Path
from PIL import Image

cfg=yaml.safe_load(open("config.yaml"))
W1=np.load("artifacts/W1.npy"); b1=np.load("artifacts/b1.npy")
W2=np.load("artifacts/W2.npy"); b2=np.load("artifacts/b2.npy")

def infer(x):
    h=1/(1+np.exp(-(x@W1.T+b1)))
    z=h@W2.T+b2
    p=np.exp(z-z.max()); p/=p.sum()
    return p[1]

imgs=list((Path(cfg["dataset"]["root"])/cfg["dataset"]["image_dir"]).rglob("*.jpg"))
img=np.asarray(Image.open(imgs[0]).convert("RGB"),dtype=float)/255.0
H,W,_=img.shape
ys=np.random.randint(0,H,1000); xs=np.random.randint(0,W,1000)
out=Path("artifacts/testvectors"); out.mkdir(parents=True,exist_ok=True)
with open(out/"pixels_in.txt","w") as a, open(out/"golden_prob_fire.txt","w") as b:
    for y,x in zip(ys,xs):
        r,g,bv=img[y,x]; a.write(f"{r:.6f} {g:.6f} {bv:.6f}\n")
        b.write(f"{infer(np.array([r,g,bv])):.6f}\n")
print("Wrote test vectors to artifacts/testvectors/")
