import os, random, numpy as np
from pathlib import Path
from PIL import Image
import yaml

def sigmoid(x): return 1. / (1. + np.exp(-x))
def relu(x):    return np.maximum(0., x)

class MLP:
    def __init__(self, in_dim, hidden, out_dim, act="sigmoid"):
        rng = np.random.default_rng(42)
        self.W1 = rng.normal(0, 0.2, (hidden, in_dim)).astype(np.float32)
        self.b1 = np.zeros((hidden,), dtype=np.float32)
        self.W2 = rng.normal(0, 0.2, (out_dim, hidden)).astype(np.float32)
        self.b2 = np.zeros((out_dim,), dtype=np.float32)
        self.act = sigmoid if act == "sigmoid" else relu

    def forward(self, x):
        h = self.act(x @ self.W1.T + self.b1)
        z = h @ self.W2.T + self.b2
        return z, h

    def softmax(self, z):
        z = z - z.max(axis=1, keepdims=True)
        e = np.exp(z); return e / e.sum(axis=1, keepdims=True)

def _read_rgb(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0

def _read_mask(path):
    return np.asarray(Image.open(path).convert("L")) > 127

def _pick(ys, xs, k):
    if ys.size == 0: return np.empty((0,2), int)
    return np.stack([np.random.choice(ys, k, replace=True),
                     np.random.choice(xs, k, replace=True)], axis=1)

def image_to_samples(img_path, mask_path, n, is_fire):
    img = _read_rgb(img_path)
    H,W,_ = img.shape
    if mask_path and mask_path.exists():
        mask = _read_mask(mask_path)
        ys_pos, xs_pos = np.where(mask)
        ys_neg, xs_neg = np.where(~mask)
        pos = _pick(ys_pos, xs_pos, n//2)
        neg = _pick(ys_neg, xs_neg, n - pos.shape[0])
        pts = np.vstack([pos, neg])
        X = img[pts[:,0], pts[:,1], :]
        y = np.array([1]*pos.shape[0] + [0]*neg.shape[0])
        return X, y
    else:
        ys = np.random.randint(0, H, n)
        xs = np.random.randint(0, W, n)
        X = img[ys, xs, :]
        y = np.full((n,), 1 if is_fire else 0)
        return X, y

def discover_pairs(cfg):
    root = Path(cfg["dataset"]["root"])
    img_root = root / cfg["dataset"]["image_dir"]
    mask_root = root / cfg["dataset"]["mask_root"]
    fire_dir = img_root / cfg["dataset"]["fire_subdir"]
    nf_dir = img_root / cfg["dataset"]["not_fire_subdir"]
    mask_fire = mask_root / cfg["dataset"]["mask_fire_subdir"]

    pairs = []
    for p in fire_dir.glob("*.*"):
        mask = mask_fire / (p.stem + ".png")
        pairs.append((p, mask if mask.exists() else None, True))
    for p in nf_dir.glob("*.*"):
        pairs.append((p, None, False))
    random.shuffle(pairs)
    return pairs

def build_dataset(cfg):
    pairs = discover_pairs(cfg)
    split = int(0.8*len(pairs))
    train_pairs, val_pairs = pairs[:split], pairs[split:]
    def assemble(pp):
        Xs,ys = [],[]
        for img,mask,is_fire in pp:
            X,y = image_to_samples(img,mask,cfg["dataset"]["samples_per_image"],is_fire)
            Xs.append(X); ys.append(y)
        return np.vstack(Xs), np.concatenate(ys)
    return assemble(train_pairs), assemble(val_pairs)

def one_hot(y,C):
    oh = np.zeros((y.size,C))
    oh[np.arange(y.size),y]=1
    return oh

def train(cfg):
    (Xtr,ytr),(Xva,yva)=build_dataset(cfg)
    mdl=MLP(3,cfg["model"]["hidden"],2,cfg["model"]["activation"])
    ytr_oh=one_hot(ytr,2)
    lr=float(cfg["train"]["lr"])
    for ep in range(cfg["train"]["epochs"]):
        idx=np.random.permutation(Xtr.shape[0])
        for s in range(0,len(idx),cfg["train"]["batch_size"]):
            b=idx[s:s+cfg["train"]["batch_size"]]
            xb,yb=Xtr[b],ytr_oh[b]
            z,h=mdl.forward(xb); p=mdl.softmax(z)
            dz=(p-yb)/xb.shape[0]
            dW2=dz.T@h; db2=dz.sum(0)
            dh=dz@mdl.W2
            ha=h*(1-h) if cfg["model"]["activation"]=="sigmoid" else (h>0).astype(float)
            dz1=dh*ha
            dW1=dz1.T@xb; db1=dz1.sum(0)
            print("lr type:", type(lr), "dW2 type:", type(dW2))
            mdl.W2-=lr*dW2; mdl.b2-=lr*db2
            mdl.W1-=lr*dW1; mdl.b1-=lr*db1
        acc=(mdl.softmax(mdl.forward(Xva)[0]).argmax(1)==yva).mean()
        print(f"Epoch {ep+1}: val acc={acc*100:.2f}%")
    Path("artifacts").mkdir(exist_ok=True)
    np.save("artifacts/W1.npy",mdl.W1);np.save("artifacts/b1.npy",mdl.b1)
    np.save("artifacts/W2.npy",mdl.W2);np.save("artifacts/b2.npy",mdl.b2)
    return mdl

if __name__=="__main__":
    cfg=yaml.safe_load(open("config.yaml"))
    train(cfg)
