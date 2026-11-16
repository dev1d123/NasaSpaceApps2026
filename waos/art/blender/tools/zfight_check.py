"""Detecta z-fighting en los .glb: pares de triangulos coplanares (<= 0.2 mm) que se solapan.

Uso:  python art/blender/tools/zfight_check.py assets/models [--ajustes salida.json]
Con --ajustes calcula, para cada par en la misma cara, cuanto mover o escalar la pieza
mas pequena (1 mm) y lo escribe por categoria para fix_zfighting.py.
"""
import json, struct, sys, glob, os
import numpy as np

def load_glb(path):
    data = open(path, 'rb').read()
    _, _, length = struct.unpack_from('<III', data, 0)
    off = 12; js = None; bin_ = b''
    while off < length:
        clen, ctype = struct.unpack_from('<II', data, off); off += 8
        chunk = data[off:off+clen]; off += clen
        if ctype == 0x4E4F534A: js = json.loads(chunk)
        else: bin_ = chunk
    return js, bin_

COMP = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}

def accessor(js, b, i):
    a = js['accessors'][i]; bv = js['bufferViews'][a['bufferView']]
    n = NCOMP[a['type']]; dt = np.dtype(COMP[a['componentType']])
    start = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', 0) or dt.itemsize * n
    raw = np.frombuffer(b, dtype=np.uint8, count=stride * (a['count'] - 1) + dt.itemsize * n, offset=start)
    out = np.lib.stride_tricks.as_strided(raw, shape=(a['count'], n * dt.itemsize), strides=(stride, 1)).copy()
    return out.view(dt).reshape(a['count'], n)

def node_matrix(nd):
    if 'matrix' in nd: return np.array(nd['matrix']).reshape(4, 4).T
    t = np.array(nd.get('translation', [0, 0, 0])); r = nd.get('rotation', [0, 0, 0, 1]); s = np.array(nd.get('scale', [1, 1, 1]))
    x, y, z, w = r
    R = np.array([[1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)], [2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)], [2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y)]])
    M = np.eye(4); M[:3, :3] = R * s; M[:3, 3] = t
    return M

def triangles(js, b):
    tris = []  # (v0,v1,v2, owner, material, doublesided)
    mats = js.get('materials', [])
    def walk(i, M, path):
        nd = js['nodes'][i]; M = M @ node_matrix(nd); name = nd.get('name', str(i))
        if 'mesh' in nd:
            for pi, p in enumerate(js['meshes'][nd['mesh']]['primitives']):
                P = accessor(js, b, p['attributes']['POSITION']).astype(float)
                P = (M[:3, :3] @ P.T).T + M[:3, 3]
                idx = accessor(js, b, p['indices']).ravel() if 'indices' in p else np.arange(len(P))
                m = p.get('material'); mname = mats[m]['name'] if m is not None else '-'
                ds = mats[m].get('doubleSided', False) if m is not None else False
                T = P[idx.reshape(-1, 3)]
                for t in T: tris.append((t, name, mname, ds))
        for c in nd.get('children', []): walk(c, M, path + [name])
    for s in js['scenes'][js.get('scene', 0)]['nodes']: walk(s, np.eye(4), [])
    return tris

def inside(p, t, n):
    a, b, c = t
    for u, v in ((a, b), (b, c), (c, a)):
        if np.dot(np.cross(v - u, p - u), n) < -1e-9: return False
    return True

def analyze(path, tol=2e-4):
    js, b = load_glb(path)
    tris = triangles(js, b)
    recs = []
    for i, (t, owner, mat, ds) in enumerate(tris):
        n = np.cross(t[1] - t[0], t[2] - t[0]); a = np.linalg.norm(n)
        if a < 1e-12: continue
        n /= a; recs.append((i, t, n, float(np.dot(n, t[0])), owner, mat, ds, a / 2))
    # Agrupar por normal (sin signo) cuantizada
    buckets = {}
    for r in recs:
        n = r[2]; k = n if (n[np.argmax(np.abs(n))] > 0) else -n
        key = tuple(np.round(k, 3)); buckets.setdefault(key, []).append(r)
    issues = []
    for key, rs in buckets.items():
        for x in range(len(rs)):
            i, ti, ni, di, oi, mi, dsi, ai = rs[x]
            ci = ti.mean(axis=0)
            samples = [ci] + [ci + 0.6 * (v - ci) for v in ti]
            for y in range(len(rs)):
                if x == y: continue
                j, tj, nj, dj, oj, mj, dsj, aj = rs[y]
                same = np.dot(ni, nj) > 0
                if not same and not (dsi or dsj): continue
                if abs(np.dot(nj, ci) - dj) > tol: continue
                if any(inside(s, tj, nj if same else -nj) if same else inside(s, tj, nj) for s in samples[:1]) and sum(inside(s, tj, nj) for s in samples) >= 2:
                    if (mi != mj) or (oi != oj) or same:
                        issues.append((oi, mi, oj, mj, same, round(ai, 6), ni))
    return issues

def ajustes_para(path, iss_full):
    """Ajuste por objeto (ejes de Blender) para conflictos en la misma cara."""
    js, b = load_glb(path)
    tris = triangles(js, b)
    ext = {}
    for t, owner, _, _ in tris:
        lo, hi = ext.get(owner, (t.min(0), t.max(0)))
        ext[owner] = (np.minimum(lo, t.min(0)), np.maximum(hi, t.max(0)))
    vol = {k: float(np.prod(np.maximum(hi - lo, 1e-4))) for k, (lo, hi) in ext.items()}
    # Todas las piezas en conflicto, de mayor a menor volumen: la mayor no se mueve y cada
    # una de las siguientes se separa un escalón más (0.8 mm × rango), para que tres o más
    # piezas en el mismo plano terminen en planos distintos.
    normales = {}
    for oi, oj, n, same in iss_full:
        if same:
            normales.setdefault(oi, []).append(n)
            normales.setdefault(oj, []).append(n)
    orden = sorted(normales, key=lambda k: (-round(vol.get(k, 0), 9), k))
    out = {}
    for rango, det in enumerate(orden):
        if rango == 0:
            continue
        ns = np.array(normales[det])
        m = ns.mean(axis=0)
        lo, hi = ext[det]
        half = np.maximum((hi - lo) / 2, 1e-4)
        paso = 0.0008 * rango
        if np.linalg.norm(m) > 0.95:
            g = m / np.linalg.norm(m) * paso                  # glTF (Y arriba)
            out[det] = {"offset": [float(g[0]), float(-g[2]), float(g[1])]}  # a Blender (Z arriba)
        else:
            sc = min(paso * 1.5 / float(half.min()), paso * 3.0 / float(half.max()))
            out[det] = {"scale": 1.0 + max(sc, 0.0005 * rango)}
    return out

if __name__ == '__main__':
    root = sys.argv[1]
    salida = sys.argv[sys.argv.index('--ajustes') + 1] if '--ajustes' in sys.argv else None
    total = 0
    todos = {}
    for f in sorted(glob.glob(os.path.join(root, '**', '*.glb'), recursive=True)):
        iss = analyze(f)
        pairs = {}
        for oi, mi, oj, mj, same, a, n in iss:
            k = tuple(sorted([f'{oi}[{mi}]', f'{oj}[{mj}]'])) + (('misma cara' if same else 'cara opuesta, doble cara'),)
            pairs[k] = pairs.get(k, 0) + 1
        if pairs:
            total += 1
            print(f'{os.path.relpath(f, root)}: {len(iss)} triangulos en conflicto')
            for k, v in sorted(pairs.items(), key=lambda kv: -kv[1])[:4]:
                print(f'   {v:4d}  {k[0]}  <->  {k[1]}  ({k[2]})')
            if salida:
                cat = os.path.basename(os.path.dirname(f))
                todos.setdefault(cat, {}).update(ajustes_para(f, [(oi, oj, n, same) for oi, mi, oj, mj, same, a, n in iss]))
    print(f'Modelos con z-fighting: {total}')
    if salida:
        json.dump(todos, open(salida, 'w', encoding='utf-8'), indent=1)
