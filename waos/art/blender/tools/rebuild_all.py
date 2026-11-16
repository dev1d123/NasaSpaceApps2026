"""Reconstruye todos los modelos sin z-fighting: Blender → .glb → análisis → ajustes → repetir.

Uso:  python art/blender/tools/rebuild_all.py [ruta_a_blender.exe]
Los ajustes acumulados quedan en art/blender/tools/zfight_ajustes.json (fuente de verdad
de las correcciones; se vuelve a aplicar en cada reconstrucción).
"""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import zfight_check as z

BLENDER = sys.argv[1] if len(sys.argv) > 1 else r"C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
CATS = ["buses", "panels", "propulsion", "comms", "instruments", "ground", "ref"]
AJ = os.path.join(HERE, "zfight_ajustes.json")
# Las bandas de los tanques son gemelas y se cruzan: con el reparto por volumen se
# alternaban en cada pasada sin separarse. Se fija a mano cuál se mueve.
MANUAL = {"propulsion": {"bp_girdle_2": {"offset": [0, 0, 0.0015]}, "ml_girdle_2": {"offset": [0, 0, 0.0015]}}}

def cargar():
    return json.load(open(AJ, encoding="utf-8")) if os.path.exists(AJ) else json.loads(json.dumps(MANUAL))

def fusionar(total, nuevo):
    for cat, objs in nuevo.items():
        t = total.setdefault(cat, {})
        for o, a in objs.items():
            cur = t.setdefault(o, {})
            if "offset" in a:
                cur["offset"] = [cur.get("offset", [0, 0, 0])[i] + a["offset"][i] for i in range(3)]
            if "scale" in a:
                cur["scale"] = cur.get("scale", 1.0) * a["scale"]

def reconstruir(cats, total):
    for cat in cats:
        tmp = os.path.join(HERE, f"_aj_{cat}.json")
        json.dump(total.get(cat, {}), open(tmp, "w", encoding="utf-8"))
        out = subprocess.run([BLENDER, "-b", "--factory-startup", "--python", os.path.join(HERE, "rebuild_models.py"), "--", cat, tmp],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=ROOT)
        os.remove(tmp)
        lines = [l for l in out.stdout.splitlines() if "[rebuild]" in l or "Error" in l or "Traceback" in l]
        print("\n".join(lines) if lines else out.stdout[-800:] + out.stderr[-800:])

def analizar():
    nuevo, conflictos = {}, []
    for f in sorted(z.glob.glob(os.path.join(ROOT, "assets", "models", "**", "*.glb"), recursive=True)):
        iss = z.analyze(f)
        if iss:
            cat = os.path.basename(os.path.dirname(f))
            conflictos.append((os.path.basename(f), len(iss)))
            nuevo.setdefault(cat, {}).update(z.ajustes_para(f, [(oi, oj, n, same) for oi, mi, oj, mj, same, a, n in iss]))
    return nuevo, conflictos

total = cargar()
cats = CATS
for pasada in range(1, 6):
    print(f"--- Pasada {pasada}: {', '.join(cats)}")
    reconstruir(cats, total)
    nuevo, conflictos = analizar()
    print("Conflictos:", conflictos or "ninguno")
    if not conflictos:
        break
    fusionar(total, nuevo)
    cats = sorted(nuevo)
json.dump(total, open(AJ, "w", encoding="utf-8"), indent=1)
