"""Signed distance helpers for sculpting characters in code (a copy of
tools/eco/sdf.py; numpy, metres, Blender axes: Z up, facing +Y, their right is +X). Every function takes points P of shape (N, 3)."""
import numpy as np

V = lambda *a: np.array(a, dtype=np.float64)


def norm(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


def length(v):
    return np.sqrt((v * v).sum(-1))


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def union(ds, k):
    out = ds[0]
    for d in ds[1:]:
        out = smin(out, d, k)
    return out


def rot(axis, deg):
    """3x3 rotation matrix about an axis."""
    axis = norm(axis)
    a = np.radians(deg)
    c, s = np.cos(a), np.sin(a)
    x, y, z = axis
    return np.array([
        [c + x * x * (1 - c), x * y * (1 - c) - z * s, x * z * (1 - c) + y * s],
        [y * x * (1 - c) + z * s, c + y * y * (1 - c), y * z * (1 - c) - x * s],
        [z * x * (1 - c) - y * s, z * y * (1 - c) + x * s, c + z * z * (1 - c)]])


def local(P, c, R=None):
    q = P - c
    return q if R is None else q @ R  # R columns are the local axes


def sphere(P, c, r):
    return length(P - c) - r


def ellipsoid(P, c, r, R=None):
    q = local(P, c, R)
    r = np.asarray(r, dtype=np.float64)
    k0 = length(q / r)
    k1 = length(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def capsule(P, a, b, r):
    pa = P - a
    ba = b - a
    h = np.clip((pa @ ba) / (ba @ ba), 0, 1)
    return length(pa - h[:, None] * ba) - r


def round_cone(P, a, b, r1, r2):
    """Tapered capsule from a (radius r1) to b (radius r2) (Inigo Quilez)."""
    ba = b - a
    l2 = ba @ ba
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = P - a
    y = pa @ ba
    z = y - l2
    xv = pa * l2 - y[:, None] * ba
    x2 = (xv * xv).sum(-1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
    d1 = np.sqrt(x2 + z2) * il2 - r2
    d2 = np.sqrt(x2 + y2) * il2 - r1
    return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))


def rbox(P, c, half, R=None, rad=0.0):
    q = np.abs(local(P, c, R)) - (np.asarray(half) - rad)
    return length(np.maximum(q, 0)) + np.minimum(q.max(-1), 0) - rad


def cylinder(P, a, b, r):
    """Capped cylinder from a to b."""
    ba = b - a
    pa = P - a
    baba = ba @ ba
    paba = pa @ ba
    x = length(pa * baba - paba[:, None] * ba) - r * baba
    y = np.abs(paba - baba * 0.5) - baba * 0.5
    x2, y2 = x * x, y * y * baba
    d = np.where(np.maximum(x, y) < 0, -np.minimum(x2, y2),
                 np.where(x > 0, x2, 0) + np.where(y > 0, y2, 0))
    return np.sign(d) * np.sqrt(np.abs(d)) / baba


def ring(P, c, R, ax, ay, thick, height):
    """Flat band around an elliptic loop in the local XY plane of R (belt, strap)."""
    q = local(P, c, R)
    e = length(q[:, :2] / np.array([ax, ay])) - 1.0
    radial = np.abs(e) * min(ax, ay) - thick
    vertical = np.abs(q[:, 2]) - height
    return np.maximum(radial, vertical)


def shell(d, t):
    return np.abs(d) - t


def plane(P, p0, n):
    """Positive on the side the normal points to."""
    return (P - p0) @ norm(n)
