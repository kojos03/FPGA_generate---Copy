import numpy as np, os
from pathlib import Path

HERE = Path(__file__).parent
ART = HERE / "artifacts"

W1=np.load(ART/"W1.npy"); b1=np.load(ART/"b1.npy")
W2=np.load(ART/"W2.npy"); b2=np.load(ART/"b2.npy")

# Q(12,8) round-trip
frac_bits = 8
S = 1 << frac_bits
def q(x): 
    return np.clip(np.round(x*S), -(1<<(12-1)), (1<<(12-1))-1)

W1q, b1q = q(W1)/S, q(b1)/S
W2q, b2q = q(W2)/S, q(b2)/S

def softmax(z):
    z = z - z.max()
    e = np.exp(z); return e/e.sum()

x = np.array([0.3, 0.2, 0.1], dtype=np.float32)

# float path
h  = 1/(1+np.exp(-(x@W1.T + b1))); z  = h@W2.T + b2;  p  = softmax(z)
# quantized path
hq = 1/(1+np.exp(-(x@W1q.T + b1q))); zq = hq@W2q.T + b2q; pq = softmax(zq)

print(p, pq)
