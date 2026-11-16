# -*- coding: utf-8 -*-
"""
waos_helpers.py - Herramientas y funciones de ayuda para modelado y exportación
de piezas 3D para WAOS en Blender.
"""

import os
import json
import math
import bpy
import bmesh
import mathutils

# Resolver la raíz del proyecto Godot (waos/)
_THIS_DIR = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ""
if _THIS_DIR:
    ROOT = os.path.normpath(os.path.join(_THIS_DIR, "..", "..", ".."))
else:
    ROOT = r"c:\Users\DCONN\OneDrive\Escritorio\JUEGO\NSAC\NasaSpaceApps2026\waos"

# Definición de materiales del contrato
MATERIALS_DEF = {
    "mat_aluminio":     {"hex": "#B9BEC8", "metallic": 1.0, "roughness": 0.35},
    "mat_mli_oro":      {"hex": "#C9A23A", "metallic": 1.0, "roughness": 0.25},
    "mat_mli_plata":    {"hex": "#D9DCE2", "metallic": 1.0, "roughness": 0.20},
    "mat_blanco":       {"hex": "#E8E9EC", "metallic": 0.0, "roughness": 0.60},
    "mat_negro":        {"hex": "#1E2128", "metallic": 0.2, "roughness": 0.50},
    "mat_celdas":       {"hex": "#1F2F66", "metallic": 0.6, "roughness": 0.25},
    "mat_celdas_marco": {"hex": "#8A90A0", "metallic": 0.8, "roughness": 0.40},
    "mat_cobre":        {"hex": "#B06A3B", "metallic": 1.0, "roughness": 0.35},
    "mat_lente":        {"hex": "#0E1622", "metallic": 0.0, "roughness": 0.05},
    "mat_kapton":       {"hex": "#C47A1E", "metallic": 0.0, "roughness": 0.45},
}


def _hex_to_linear(hex_str):
    """Convierte hex sRGB (#RRGGBB) a tupla RGBA lineal para Blender Principled BSDF."""
    hex_str = hex_str.lstrip('#')
    s_r = int(hex_str[0:2], 16) / 255.0
    s_g = int(hex_str[2:4], 16) / 255.0
    s_b = int(hex_str[4:6], 16) / 255.0

    def to_lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (to_lin(s_r), to_lin(s_g), to_lin(s_b), 1.0)


def limpiar_escena():
    """Limpia todos los objetos y datos huérfanos de la escena actual."""
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in bpy.data.cameras:
        if block.users == 0:
            bpy.data.cameras.remove(block)
    for block in bpy.data.lights:
        if block.users == 0:
            bpy.data.lights.remove(block)


def material(nombre):
    """Crea o reutiliza uno de los 10 materiales de la tabla del contrato con sus valores exactos."""
    if nombre in bpy.data.materials:
        mat = bpy.data.materials[nombre]
        if nombre in MATERIALS_DEF:
            data = MATERIALS_DEF[nombre]
            h = data["hex"].lstrip('#')
            s_r, s_g, s_b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
            mat.diffuse_color = (s_r, s_g, s_b, 1.0)
            mat.metallic = data["metallic"]
            mat.roughness = data["roughness"]
        return mat

    if nombre not in MATERIALS_DEF:
        raise ValueError(f"Material desconocido: '{nombre}'. No está en el contrato técnico.")

    data = MATERIALS_DEF[nombre]
    mat = bpy.data.materials.new(nombre)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")

    if bsdf:
        bsdf.inputs['Base Color'].default_value = _hex_to_linear(data["hex"])
        bsdf.inputs['Metallic'].default_value = data["metallic"]
        bsdf.inputs['Roughness'].default_value = data["roughness"]

    # Configurar también Viewport Display (diffuse_color, metallic, roughness) para Workbench
    h = data["hex"].lstrip('#')
    s_r, s_g, s_b = int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0
    mat.diffuse_color = (s_r, s_g, s_b, 1.0)
    mat.metallic = data["metallic"]
    mat.roughness = data["roughness"]

    return mat


def _asignar_material(obj, mat):
    if isinstance(mat, str):
        mat = material(mat)
    if mat:
        if len(obj.data.materials) == 0:
            obj.data.materials.append(mat)
        else:
            obj.data.materials[0] = mat


def _aplicar_auto_smooth(obj, angle_deg=30.0):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle_deg))
    except Exception:
        # Fallback para versiones previas
        if hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(angle_deg)


def caja(nombre, tamano, pos, mat, bevel=0.0):
    """Crea una caja de dimensiones tamano (sx, sy, sz) en pos, con material mat y opcional bevel."""
    if isinstance(tamano, (int, float)):
        sx, sy, sz = float(tamano), float(tamano), float(tamano)
    else:
        sx, sy, sz = float(tamano[0]), float(tamano[1]), float(tamano[2])

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=pos)
    obj = bpy.context.active_object
    obj.name = nombre
    if obj.data:
        obj.data.name = nombre + "_mesh"

    obj.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    _asignar_material(obj, mat)
    _aplicar_auto_smooth(obj, 30.0)

    if bevel > 0.0:
        mod = obj.modifiers.new(name="Bevel", type='BEVEL')
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = 'ANGLE'
        mod.angle_limit = math.radians(30.0)
        mod.use_clamp_overlap = True

    return obj


def cilindro(nombre, radio, alto, pos, mat, verts=24, rot=(0, 0, 0)):
    """Crea un cilindro en metros con rotación opcional."""
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts,
        radius=float(radio),
        depth=float(alto),
        location=pos,
        rotation=rot
    )
    obj = bpy.context.active_object
    obj.name = nombre
    if obj.data:
        obj.data.name = nombre + "_mesh"

    _asignar_material(obj, mat)
    _aplicar_auto_smooth(obj, 30.0)
    return obj


def esfera(nombre, radio, pos, mat, segs=24):
    """Crea una esfera UV en metros."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segs,
        ring_count=max(8, segs // 2),
        radius=float(radio),
        location=pos
    )
    obj = bpy.context.active_object
    obj.name = nombre
    if obj.data:
        obj.data.name = nombre + "_mesh"

    _asignar_material(obj, mat)
    _aplicar_auto_smooth(obj, 30.0)
    return obj


def cono(nombre, r1, r2, alto, pos, mat, rot=(0, 0, 0)):
    """Crea un cono truncado o tobera."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=24,
        radius1=float(r1),
        radius2=float(r2),
        depth=float(alto),
        location=pos,
        rotation=rot
    )
    obj = bpy.context.active_object
    obj.name = nombre
    if obj.data:
        obj.data.name = nombre + "_mesh"

    _asignar_material(obj, mat)
    _aplicar_auto_smooth(obj, 30.0)
    return obj


def plato(nombre, diametro, profundidad, pos, mat):
    """Crea un paraboloide (plato de antena) con círculos extruidos concéntricos."""
    R = float(diametro) / 2.0
    P = float(profundidad)
    rings = 6
    segs = 24

    mesh = bpy.data.meshes.new(nombre + "_mesh")
    obj = bpy.data.objects.new(nombre, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()
    center_v = bm.verts.new((pos[0], pos[1], pos[2]))
    prev_ring = []

    for ring_idx in range(1, rings + 1):
        frac = ring_idx / rings
        r = R * frac
        z = P * (frac ** 2)
        current_ring = []
        for s in range(segs):
            theta = 2.0 * math.pi * s / segs
            x = pos[0] + r * math.cos(theta)
            y = pos[1] + r * math.sin(theta)
            v = bm.verts.new((x, y, pos[2] + z))
            current_ring.append(v)

        if ring_idx == 1:
            for s in range(segs):
                v1 = current_ring[s]
                v2 = current_ring[(s + 1) % segs]
                bm.faces.new((center_v, v1, v2))
        else:
            for s in range(segs):
                v1 = prev_ring[s]
                v2 = prev_ring[(s + 1) % segs]
                v3 = current_ring[(s + 1) % segs]
                v4 = current_ring[s]
                bm.faces.new((v1, v2, v3, v4))
        prev_ring = current_ring

    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    # Grosor mínimo para que sea una superficie sólida en glTF
    mod = obj.modifiers.new("Solidify", 'SOLIDIFY')
    mod.thickness = 0.004

    _asignar_material(obj, mat)
    _aplicar_auto_smooth(obj, 30.0)
    return obj


def socket(nombre, pos, apunta):
    """Crea un objeto Empty (Plain Axes, tamaño 0.05) con su eje +Z local apuntando hacia 'apunta'."""
    obj = bpy.data.objects.new(nombre, None)
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = 0.05
    obj.location = (float(pos[0]), float(pos[1]), float(pos[2]))

    target_vec = mathutils.Vector(apunta).normalized()
    ref_z = mathutils.Vector((0.0, 0.0, 1.0))
    rot_diff = ref_z.rotation_difference(target_vec)
    obj.rotation_euler = rot_diff.to_euler()

    bpy.context.collection.objects.link(obj)
    return obj


def raiz(id_str):
    """Crea el objeto Empty raíz para el modelo."""
    obj = bpy.data.objects.new(id_str, None)
    obj.empty_display_type = 'PLAIN_AXES'
    obj.empty_display_size = 0.1
    obj.location = (0.0, 0.0, 0.0)
    bpy.context.collection.objects.link(obj)
    return obj


def emparentar(hijos, padre):
    """Emparenta una lista o tupla de objetos hijos al objeto padre."""
    if not isinstance(hijos, (list, tuple, set)):
        hijos = [hijos]
    for h in hijos:
        if h and h != padre:
            h.parent = padre


def _todos_los_descendientes(obj):
    """Devuelve una lista con obj y todos sus descendientes de forma recursiva."""
    res = [obj]
    for child in obj.children:
        res.extend(_todos_los_descendientes(child))
    return res


def contar_tris(obj_raiz):
    """Cuenta el total de triángulos de la jerarquía bajo obj_raiz."""
    total = 0
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for o in _todos_los_descendientes(obj_raiz):
        if o.type == 'MESH' and o.data:
            eval_obj = o.evaluated_get(depsgraph)
            eval_mesh = eval_obj.to_mesh()
            eval_mesh.calc_loop_triangles()
            total += len(eval_mesh.loop_triangles)
            eval_obj.to_mesh_clear()
    return total


def bbox_m(obj_raiz):
    """Dimensiones [x, y, z] del AABB en metros, en ejes de Blender."""
    min_co = [float('inf'), float('inf'), float('inf')]
    max_co = [float('-inf'), float('-inf'), float('-inf')]
    found = False

    depsgraph = bpy.context.evaluated_depsgraph_get()
    for o in _todos_los_descendientes(obj_raiz):
        if o.type == 'MESH' and o.data:
            eval_obj = o.evaluated_get(depsgraph)
            eval_mesh = eval_obj.to_mesh()
            matrix = o.matrix_world
            for v in eval_mesh.vertices:
                world_c = matrix @ v.co
                for i in range(3):
                    if world_c[i] < min_co[i]:
                        min_co[i] = world_c[i]
                    if world_c[i] > max_co[i]:
                        max_co[i] = world_c[i]
            eval_obj.to_mesh_clear()
            found = True

    if not found:
        return [0.0, 0.0, 0.0]

    return [round(max_co[i] - min_co[i], 4) for i in range(3)]


def _bbox_min_max(obj_raiz):
    """Retorna (min_co, max_co) en coordenadas de mundo calculadas con vértices reales."""
    min_co = [float('inf'), float('inf'), float('inf')]
    max_co = [float('-inf'), float('-inf'), float('-inf')]
    found = False

    depsgraph = bpy.context.evaluated_depsgraph_get()
    for o in _todos_los_descendientes(obj_raiz):
        if o.type == 'MESH' and o.data:
            eval_obj = o.evaluated_get(depsgraph)
            eval_mesh = eval_obj.to_mesh()
            matrix = o.matrix_world
            for v in eval_mesh.vertices:
                world_c = matrix @ v.co
                for i in range(3):
                    if world_c[i] < min_co[i]:
                        min_co[i] = world_c[i]
                    if world_c[i] > max_co[i]:
                        max_co[i] = world_c[i]
            eval_obj.to_mesh_clear()
            found = True

    if not found:
        return mathutils.Vector((0, 0, 0)), mathutils.Vector((1, 1, 1))

    return mathutils.Vector(min_co), mathutils.Vector(max_co)


def exportar_glb(obj_raiz, categoria, id_str):
    """Selecciona la raíz con toda su descendencia, aplica transformaciones y exporta según el contrato."""
    rel_path = os.path.join("assets", "models", categoria, f"{id_str}.glb")
    abs_path = os.path.join(ROOT, rel_path)
    os.makedirs(os.path.dirname(abs_path), exist_ok=True)

    # Deseleccionar todo y seleccionar raíz con descendencia
    bpy.ops.object.select_all(action='DESELECT')
    descendientes = _todos_los_descendientes(obj_raiz)
    for o in descendientes:
        o.select_set(True)

    bpy.context.view_layer.objects.active = obj_raiz

    # Aplicar escala a mallas para evitar escalas no uniformes en glTF
    for o in descendientes:
        if o.type == 'MESH':
            bpy.context.view_layer.objects.active = o
            try:
                bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            except Exception:
                pass

    bpy.context.view_layer.objects.active = obj_raiz

    # Exportar glTF según contrato
    bpy.ops.export_scene.gltf(
        filepath=abs_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False
    )
    return abs_path


def preview(obj_raiz, id_str):
    """Render Workbench de 512x512 a art/previews/<id>.png, con cámara isométrica que encuadre el AABB, fondo #0B1020 y luz de estudio."""
    preview_dir = os.path.join(ROOT, "art", "previews")
    os.makedirs(preview_dir, exist_ok=True)
    out_path = os.path.join(preview_dir, f"{id_str}.png")

    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = out_path
    scene.render.film_transparent = False

    # Configuración de shading de Workbench
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.background_type = 'VIEWPORT'

    bg_rgb = (0x0B / 255.0, 0x10 / 255.0, 0x20 / 255.0)
    scene.display.shading.background_color = bg_rgb
    if scene.world:
        scene.world.color = bg_rgb

    # Calcular encuadre según AABB
    min_co, max_co = _bbox_min_max(obj_raiz)
    center = (min_co + max_co) / 2.0
    dim = max_co - min_co
    max_dim = max(dim.x, dim.y, dim.z, 0.1)

    # Crear o reutilizar cámara de preview
    cam_name = "_waos_preview_cam"
    cam_obj = bpy.data.objects.get(cam_name)
    if not cam_obj:
        cam_data = bpy.data.cameras.new(cam_name)
        cam_obj = bpy.data.objects.new(cam_name, cam_data)
        bpy.context.collection.objects.link(cam_obj)
    else:
        cam_data = cam_obj.data

    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = max_dim * 1.55
    cam_data.clip_start = 0.05
    cam_data.clip_end = max(2000.0, (max_dim * 4.0 + 2.0) * 3.0)

    # Posición isométrica mirando hacia el centro
    # Desde +X, -Y (nadir hacia la cámara), +Z arriba
    direction = mathutils.Vector((1.0, -1.2, 0.8)).normalized()
    dist = max_dim * 4.0 + 2.0
    cam_obj.location = center + direction * dist

    to_center = (center - cam_obj.location).normalized()
    rot_quat = to_center.to_track_quat('-Z', 'Y')
    cam_obj.rotation_euler = rot_quat.to_euler()

    old_camera = scene.camera
    scene.camera = cam_obj

    # Ocultar temporalmente otros objetos en render
    desc_set = set(_todos_los_descendientes(obj_raiz))
    hidden_states = {}
    for o in scene.objects:
        if o != cam_obj:
            hidden_states[o] = o.hide_render
            if o not in desc_set:
                o.hide_render = True

    # Renderizar
    bpy.ops.render.render(write_still=True)

    # Restaurar visibilidad
    for o, st in hidden_states.items():
        o.hide_render = st

    # Restaurar cámara o limpiar
    scene.camera = old_camera
    bpy.data.objects.remove(cam_obj)
    bpy.data.cameras.remove(cam_data)

    return out_path


def registrar(categoria, id_str, obj_raiz):
    """Actualiza assets/models/manifest.json con los datos del modelo."""
    manifest_dir = os.path.join(ROOT, "assets", "models")
    os.makedirs(manifest_dir, exist_ok=True)
    manifest_path = os.path.join(manifest_dir, "manifest.json")

    manifest = {}
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                manifest = json.load(f)
        except Exception:
            manifest = {}

    descendientes = _todos_los_descendientes(obj_raiz)

    # Detectar sockets
    sockets = [
        o.name for o in descendientes
        if o.name.startswith("socket_")
    ]

    # Detectar materiales usados
    materiales_set = set()
    for o in descendientes:
        if o.type == 'MESH' and o.data:
            for m in o.data.materials:
                if m and m.name:
                    materiales_set.add(m.name)

    dims = bbox_m(obj_raiz)
    tris = contar_tris(obj_raiz)

    entry = {
        "file": f"res://assets/models/{categoria}/{id_str}.glb",
        "categoria": categoria,
        "bbox_m": dims,
        "tris": tris,
        "sockets": sorted(sockets),
        "materiales": sorted(list(materiales_set))
    }

    manifest[id_str] = entry

    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)

    return entry
