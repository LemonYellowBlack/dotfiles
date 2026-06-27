import numpy as np
from PIL import Image, ImageFilter
import sys
import random
import os

# Kanagawa palette
COLORS = np.array([
    [0x1f, 0x1f, 0x28],  # sumi ink (deep background)
    [0x2d, 0x4f, 0x67],  # wave blue
    [0x7e, 0x9c, 0xd8],  # crystal blue
    [0x6a, 0x95, 0x89],  # wave teal
    [0xc0, 0xa3, 0x6e],  # autumn gold
    [0xd2, 0x7e, 0x99],  # sakura pink
    [0x95, 0x7f, 0xb8],  # oni violet
    [0x54, 0x65, 0x6d],  # fuji grey (dark accent)
], dtype=np.float64)

# Accept seed from command line, or generate a random one
if len(sys.argv) > 1:
    seed = int(sys.argv[1])
else:
    seed = random.randint(0, 999999)

print(f"Seed: {seed}  (rerun with: python3 kanagawa_wallpaper.py {seed})")
rng = np.random.default_rng(seed)

W, H = 3840, 2160

x = np.linspace(0, 1, W)
y = np.linspace(0, 1, H)
xx, yy = np.meshgrid(x, y)

# Double-warp: two passes of sine distortion = organic fluid swirls
def warp(u, v, strength, freq, phase):
    wu = u + strength * np.sin(freq * np.pi * v + phase[0]) \
           + strength * 0.5 * np.sin(freq * 1.7 * np.pi * u + phase[1])
    wv = v + strength * np.cos(freq * np.pi * u + phase[2]) \
           + strength * 0.5 * np.cos(freq * 1.7 * np.pi * v + phase[3])
    return wu, wv

# Randomize warp parameters
p1 = rng.uniform(0, 2 * np.pi, 4)
p2 = rng.uniform(0, 2 * np.pi, 4)
f1 = rng.uniform(1.8, 3.2)
f2 = rng.uniform(3.0, 5.0)
s1 = rng.uniform(0.20, 0.35)
s2 = rng.uniform(0.12, 0.22)

wx,  wy  = warp(xx,  yy,  strength=s1, freq=f1, phase=p1)
wx2, wy2 = warp(wx,  wy,  strength=s2, freq=f2, phase=p2)

# Randomly place 8 anchors, each assigned a random color from the palette
n_anchors = 8
positions = rng.uniform(0.05, 0.95, (n_anchors, 2))
color_indices = rng.choice(len(COLORS), size=n_anchors, replace=True)
anchors = [(positions[i, 0], positions[i, 1], color_indices[i]) for i in range(n_anchors)]

r = np.zeros((H, W))
g = np.zeros((H, W))
b = np.zeros((H, W))
w_sum = np.zeros((H, W))

for cx, cy, ci in anchors:
    dist2 = (wx2 - cx) ** 2 + (wy2 - cy) ** 2
    weight = 1.0 / (dist2 + 1e-5)
    r += weight * COLORS[ci][0]
    g += weight * COLORS[ci][1]
    b += weight * COLORS[ci][2]
    w_sum += weight

r /= w_sum
g /= w_sum
b /= w_sum

arr = np.stack([r, g, b], axis=2).clip(0, 255).astype(np.uint8)

img = Image.fromarray(arr)
img = img.filter(ImageFilter.GaussianBlur(radius=0))

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wallpapers")
os.makedirs(out_dir, exist_ok=True)
out = os.path.join(out_dir, f"kanagawa_{seed}.png")
img.save(out)
print(f"Saved to {out}")
