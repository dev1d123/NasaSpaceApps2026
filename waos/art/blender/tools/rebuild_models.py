"""Reconstruye los modelos de una categoría desde los build_*.py, corrige z-fighting y exporta.

Uso (Blender en segundo plano, archivo vacío):
    blender -b --factory-startup --python art/blender/tools/rebuild_models.py -- <categoria> [ajustes.json]

Cada modelo se construye en el origen (como en la exportación original de los build_*.py)
y antes de exportarlo:
1. Los materiales activan backface culling: el glTF deja de ser doubleSided, así que dos
   piezas apoyadas cara con cara (normales opuestas) ya no compiten por el mismo píxel.
2. Las mallas abiertas (planos sin grosor) reciben Solidify de 0.6 mm para seguir viéndose
   por detrás con el culling activo.
3. Ajustes por pieza desde el JSON que calcula zfight_check.py:
   {"pieza": {"offset": [x, y, z]}} desplaza en metros (ejes de Blender) y
   {"pieza": {"scale": s}} escala desde su origen.
El .blend de la categoría se guarda con una escena por modelo, todos en el origen.
(Los .blend anteriores colocaban los modelos uno al lado de otro y, por cómo emparentaban
las piezas, quedaban desarmados: no sirven como fuente.)
"""
import bpy, bmesh, json, os, re, sys, inspect

HERE = os.path.dirname(os.path.abspath(__file__))
exec(open(os.path.join(HERE, "waos_helpers.py"), encoding="utf-8").read())

SCRIPTS = {
    "buses": "build_buses.py", "panels": "build_panels.py", "propulsion": "build_propulsion.py",
    "comms": "build_comms.py", "instruments": "build_instruments.py", "ground": "build_ground.py",
    "ref": "build_person_ref.py",
}

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
categoria = args[0]
ajustes = json.load(open(args[1], encoding="utf-8")) if len(args) > 1 and os.path.exists(args[1]) else {}
manifest = json.load(open(os.path.join(ROOT, "assets", "models", "manifest.json"), encoding="utf-8"))
ids = [k for k, v in manifest.items() if v.get("categoria") == categoria]

# Cargar las funciones de construcción sin ejecutar el bloque principal del script.
ns = dict(globals())
ns["__name__"] = "waos_build"
exec(open(os.path.join(HERE, SCRIPTS[categoria]), encoding="utf-8").read(), ns)

def constructor(id_str):
    for nombre in (f"build_{id_str}", f"modelar_{id_str}", "crear_person_ref" if id_str == "person_ref" else ""):
        if nombre and nombre in ns:
            return ns[nombre]
    raise KeyError(f"No hay constructor para {id_str}")

def limpio(nombre):
    return re.sub(r"\.\d{3}$", "", nombre.split("|")[-1])

def corregir(desc):
    abiertas = 0
    for o in desc:
        if o.type != "MESH":
            continue
        for slot in o.material_slots:
            if slot.material:
                slot.material.use_backface_culling = True
        bm = bmesh.new()
        bm.from_mesh(o.data)
        borde = any(e.is_boundary for e in bm.edges)
        bm.free()
        if borde and not any(md.type == "SOLIDIFY" for md in o.modifiers):
            md = o.modifiers.new("waos_grosor", "SOLIDIFY")
            md.thickness = 0.0006
            md.offset = 0.0
            md.use_even_offset = True
            abiertas += 1
    aplicados = 0
    for o in desc:
        aj = ajustes.get(limpio(o.name))
        if not aj:
            continue
        if "offset" in aj:
            o.location = [o.location[i] + aj["offset"][i] for i in range(3)]
        if "scale" in aj:
            o.scale = [s * aj["scale"] for s in o.scale]
        aplicados += 1
    return abiertas, aplicados

def exportar_limpio(raiz_obj, id_str):
    """Los nombres no se repiten en un .blend: al construir varios buses en el mismo archivo,
    los sockets salen como 'socket_top.001'. El juego busca 'socket_top'."""
    desc = _todos_los_descendientes(raiz_obj)
    originales = {o: o.name for o in desc}
    apartados = {}
    for o in desc:
        n = limpio(o.name)
        otro = bpy.data.objects.get(n)
        if n != o.name and otro is not None and otro not in originales:
            apartados[otro] = otro.name
            otro.name = "__tmp__" + otro.name
    for o in desc:
        o.name = limpio(o.name)
    try:
        exportar_glb(raiz_obj, categoria, id_str)
    finally:
        for o in desc:
            o.name = "__tmp2__" + originales[o]
        for o in desc:
            o.name = originales[o]
        for otro, nombre in apartados.items():
            otro.name = nombre

principal = bpy.context.scene
for o in list(principal.objects):
    bpy.data.objects.remove(o, do_unlink=True)

resumen = []
for id_str in ids:
    f = constructor(id_str)
    r = f(offset=(0.0, 0.0, 0.0)) if "offset" in inspect.signature(f).parameters else f()
    if isinstance(r, tuple):
        r = r[0]
    if r.location.length > 1e-9:
        print(f"[rebuild] AVISO: la raíz de {id_str} no está en el origen: {tuple(r.location)}")
    desc = _todos_los_descendientes(r)
    abiertas, aplicados = corregir(desc)
    bpy.context.view_layer.update()
    exportar_limpio(r, id_str)
    # Guardar el modelo en su propia escena para que el siguiente se construya en una vacía.
    esc = bpy.data.scenes.new(id_str)
    for o in desc:
        # Liberar los nombres de contrato (socket_top…): algunos build_*.py buscan piezas por
        # nombre y, si siguen ocupados, el siguiente modelo se queda con las del anterior.
        if o.name != id_str:
            o.name = f"{id_str}|{limpio(o.name)}"
        esc.collection.objects.link(o)
        for c in list(o.users_collection):
            if c != esc.collection:
                c.objects.unlink(o)
    resumen.append(f"{id_str}(grosor {abiertas}, ajustes {aplicados})")

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", f"{categoria}.blend"))
print(f"[rebuild] {categoria}: " + ", ".join(resumen))
