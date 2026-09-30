#!/usr/bin/env python3
# landkinds.py: which kind of land each tile of a line is, worked out exactly
# as nighttrain.glsl does (the same hash, in the same 32-bit whole numbers),
# to find a stretch worth testing: a town, a lake, the sea, a crossing...
#   python3 tests/landkinds.py [LINE] [FIRST_TILE] [COUNT]
import sys
M = 0xFFFFFFFF
def pcg(x):
    h = (x * 747796405 + 2891336453) & M
    h = (((h >> ((h >> 28) + 4)) ^ h) * 277803737) & M
    return (h >> 22) ^ h
def h01(x): return (pcg(x & M) >> 8) / 16777216.0
BIOME_W = [2.0, 1.5, 2.0, 1.5, 1.0,  1.0, 0.5, 1.0, 0.7, 4.0,  2.0, 1.5, 0.5, 4.0, 0.0,  1.0, 1.0, 5.0, 0.3, 0.3]
KIND_W = [1.0, 5.0, 0.5, 0.7, 0.0, 0.6, 0.4, 0.8,  1.0, 2.0, 3.0, 0.6, 0.0, 1.0, 0.0, 0.5,
          5.0, 0.7, 0.3, 1.2, 0.0, 0.5, 0.0, 1.5,  1.5, 2.5, 0.7, 0.5, 0.0, 1.2, 1.5, 0.4,
          1.0, 0.3, 0.0, 1.0, 4.0, 0.6, 0.4, 0.5]
BIOMES = ["forest", "lakes", "plains", "hills", "coast"]
KINDS = ["plain", "FOREST", "LAKE", "TOWN", "SEA", "BRIDGE", "TUNNEL", "CROSSING"]
def pick(r, weights):
    r *= sum(weights)
    for i, w in enumerate(weights):
        r -= w
        if r < 0: return i
    return 0
def biome_of(region, line):
    return pick(h01(((region * 2654435761) & M) ^ ((line + 1) * 40503)), BIOME_W[line * 5:line * 5 + 5])
def tile_kind(tile, line):
    b = biome_of(tile >> 3, line)
    return pick(h01(((tile * 3266489917) & M) ^ (((line + 7) * 668265263) & M)), KIND_W[b * 8:b * 8 + 8])
line = int(sys.argv[1]) if len(sys.argv) > 1 else 0
first = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
count = int(sys.argv[3]) if len(sys.argv) > 3 else 40
for t in range(first, first + count):
    print(f"tile {t}: {BIOMES[biome_of(t >> 3, line)]:6s} {KINDS[tile_kind(t, line)]}")
