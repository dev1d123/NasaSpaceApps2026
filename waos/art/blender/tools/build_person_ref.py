# -*- coding: utf-8 -*-
"""
build_person_ref.py - Modela la figura humana de escala para WAOS según Prompt 8:
- person_ref: Técnico de integración en traje de sala limpia (1.80 m)
- Categoría: ref
- Altura exacta: 1.80 m, hombros 0.45 m, profundidad ~0.28 m
- Origen: en el suelo entre los dos pies (Z=0), crece hacia +Z
- Mira hacia -Y
- Materiales: mat_blanco (mono/cubrebotas), mat_negro (guantes/mascarilla), mat_lente (gafas), mat_kapton (cinturón)
- Malla única: person_ref_mesh bajo el Empty raíz person_ref
- Presupuesto: <= 3 000 triángulos
"""

import os
import sys
import math
import bpy
import bmesh
import mathutils

ROOT = r"c:\Users\DCONN\OneDrive\Escritorio\JUEGO\NSAC\NasaSpaceApps2026\waos"
helpers_path = os.path.join(ROOT, "art", "blender", "tools", "waos_helpers.py")
exec(open(helpers_path, encoding="utf-8").read(), globals())


def guardar_blend(ruta):
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=ruta)


def crear_person_ref():
    """
    Crea las partes de la figura humana de 1.80 m con proporciones realistas y traje de sala limpia,
    las une en una sola malla 'person_ref_mesh' y la emparenta a la raíz 'person_ref'.
    """
    id_str = "person_ref"
    limpiar_escena()

    partes = []

    # --- 1. CABEZA, CAPUCHA Y ROSTRO ---
    # Capucha (cúpula y cabeza completa): elipsoide estilizado
    # Centro en Z = 1.68 m, radio vertical 0.12 m -> llega exactamente a Z = 1.80 m
    hood = esfera(f"{id_str}_hood", radio=0.105, pos=(0, 0.01, 1.68), mat="mat_blanco", segs=20)
    hood.scale = (0.95, 1.05, 1.14)
    bpy.context.view_layer.objects.active = hood
    bpy.ops.object.transform_apply(scale=True)
    partes.append(hood)

    # Cuello / faldón inferior de capucha (cowl) que se ensancha hacia los hombros
    cowl = cono(f"{id_str}_cowl", r1=0.15, r2=0.09, alto=0.14, pos=(0, 0.005, 1.50), mat="mat_blanco")
    partes.append(cowl)

    # Mascarilla de sala limpia en cara frontal (-Y): cubre desde barbilla (1.56) hasta nariz (1.65)
    mask = caja(f"{id_str}_mask", (0.13, 0.05, 0.08), (0, -0.09, 1.61), "mat_negro", bevel=0.015)
    partes.append(mask)

    # Gafas de seguridad panorámicas / visor en mat_lente (Z = 1.67 a 1.725)
    goggles = caja(f"{id_str}_goggles", (0.145, 0.05, 0.05), (0, -0.092, 1.695), "mat_lente", bevel=0.01)
    partes.append(goggles)

    # Cinta elástica de las gafas en los laterales de la cabeza
    strap_l = caja(f"{id_str}_strap_l", (0.015, 0.12, 0.02), (-0.098, 0.01, 1.695), "mat_negro")
    strap_r = caja(f"{id_str}_strap_r", (0.015, 0.12, 0.02), (0.098, 0.01, 1.695), "mat_negro")
    partes.append(strap_l)
    partes.append(strap_r)

    # --- 2. TORSO Y TRAJE ---
    # Hombros: ancho exterior total = 0.45 m (de X = -0.225 a +0.225)
    # Pecho superior (traje holgado con caída natural)
    chest = caja(f"{id_str}_chest", (0.36, 0.23, 0.28), (0, 0, 1.32), "mat_blanco", bevel=0.04)
    partes.append(chest)

    # Abdomen / talle medio
    abdomen = caja(f"{id_str}_abdomen", (0.32, 0.20, 0.18), (0, 0, 1.12), "mat_blanco", bevel=0.03)
    partes.append(abdomen)

    # Cinturón en mat_kapton (Z = 1.01 a 1.06)
    belt = caja(f"{id_str}_belt", (0.33, 0.21, 0.05), (0, 0, 1.035), "mat_kapton", bevel=0.005)
    partes.append(belt)

    # Pelvis / caderas (Z = 0.88 a 1.01)
    pelvis = caja(f"{id_str}_pelvis", (0.33, 0.21, 0.16), (0, 0, 0.94), "mat_blanco", bevel=0.03)
    partes.append(pelvis)

    # --- 3. PIERNAS Y CUBREBOTAS ---
    # Centros de piernas en X = +- 0.10 m (pies a la anchura de caderas/hombros)
    for sign_x, name_x in [(-1, "L"), (1, "R")]:
        px = sign_x * 0.10

        # Muslo (tapered de cadera a rodilla): Z = 0.50 a 0.88
        thigh = cono(f"{id_str}_thigh_{name_x}", r1=0.068, r2=0.082, alto=0.38, pos=(px, 0.0, 0.69), mat="mat_blanco")
        partes.append(thigh)

        # Rodilla (pliegue anatómico de tela)
        knee = esfera(f"{id_str}_knee_{name_x}", radio=0.072, pos=(px, 0.005, 0.50), mat="mat_blanco", segs=14)
        partes.append(knee)

        # Pantorrilla (Z = 0.12 a 0.50)
        calf = cono(f"{id_str}_calf_{name_x}", r1=0.062, r2=0.070, alto=0.38, pos=(px, 0.0, 0.31), mat="mat_blanco")
        partes.append(calf)

        # Cubrebotas de sala limpia (booties):
        # Altura Z = 0.0 a 0.12. Longitud 0.27 m, ancho 0.11 m.
        # Base de suela exactamente en Z = 0.00
        boot = caja(f"{id_str}_boot_{name_x}", (0.11, 0.26, 0.115), (px, -0.03, 0.06), "mat_blanco", bevel=0.02)
        partes.append(boot)

        # Suela antideslizante en mat_negro
        sole = caja(f"{id_str}_sole_{name_x}", (0.112, 0.264, 0.012), (px, -0.03, 0.006), "mat_negro")
        partes.append(sole)

    # --- 4. BRAZOS Y GUANTES ---
    # Brazos relajados a los lados, ángulo de ~8° respecto al cuerpo
    arm_angle = math.radians(8.0)

    for sign_x, name_x in [(-1, "L"), (1, "R")]:
        # Hombro: centro en X = sign_x * 0.175, radio 0.05 -> borde exterior en +-0.225 (ancho total = 0.45 m)
        sh_x = sign_x * 0.175
        sh_z = 1.40
        shoulder = esfera(f"{id_str}_shoulder_{name_x}", radio=0.052, pos=(sh_x, 0, sh_z), mat="mat_blanco", segs=14)
        partes.append(shoulder)

        # Brazo superior: longitud 0.26 m
        up_len = 0.26
        dx = sign_x * math.sin(arm_angle) * up_len
        dz = -math.cos(arm_angle) * up_len
        elbow_pos = mathutils.Vector((sh_x + dx, 0, sh_z + dz))
        mid_up = (mathutils.Vector((sh_x, 0, sh_z)) + elbow_pos) / 2.0

        upper_arm = cilindro(f"{id_str}_up_arm_{name_x}", radio=0.046, alto=up_len, pos=mid_up, mat="mat_blanco", verts=12, rot=(0, -sign_x * arm_angle, 0))
        partes.append(upper_arm)

        # Codo
        elbow = esfera(f"{id_str}_elbow_{name_x}", radio=0.046, pos=elbow_pos, mat="mat_blanco", segs=12)
        partes.append(elbow)

        # Antebrazo: longitud 0.25 m, ligeramente más vertical (5°)
        fore_len = 0.25
        fore_angle = math.radians(5.0)
        fdx = sign_x * math.sin(fore_angle) * fore_len
        fdz = -math.cos(fore_angle) * fore_len
        wrist_pos = elbow_pos + mathutils.Vector((fdx, 0, fdz))
        mid_fore = (elbow_pos + wrist_pos) / 2.0

        forearm = cilindro(f"{id_str}_forearm_{name_x}", radio=0.042, alto=fore_len, pos=mid_fore, mat="mat_blanco", verts=12, rot=(0, -sign_x * fore_angle, 0))
        partes.append(forearm)

        # Guante (mat_negro):
        # Manguito en la muñeca
        wrist_cuff = cilindro(f"{id_str}_cuff_{name_x}", radio=0.046, alto=0.04, pos=wrist_pos, mat="mat_negro", verts=12)
        partes.append(wrist_cuff)

        # Mano enguantada en pose neutra
        hand_len = 0.14
        hand_pos = wrist_pos + mathutils.Vector((0, 0, -hand_len / 2.0))
        hand = caja(f"{id_str}_hand_{name_x}", (0.038, 0.078, hand_len), hand_pos, "mat_negro", bevel=0.012)
        partes.append(hand)

        # Pulgar relajado apuntando hacia adentro
        thumb_pos = hand_pos + mathutils.Vector((-sign_x * 0.022, -0.02, 0.02))
        thumb = cilindro(f"{id_str}_thumb_{name_x}", radio=0.013, alto=0.05, pos=thumb_pos, mat="mat_negro", verts=8, rot=(math.radians(25.0), 0, -sign_x * math.radians(15.0)))
        partes.append(thumb)

    # --- 5. UNIFICACIÓN DE MALLA EN 'person_ref_mesh' ---
    bpy.ops.object.select_all(action='DESELECT')
    for p in partes:
        p.select_set(True)
    bpy.context.view_layer.objects.active = partes[0]

    bpy.ops.object.join()
    mesh_obj = bpy.context.active_object
    mesh_obj.name = f"{id_str}_mesh"
    if mesh_obj.data:
        mesh_obj.data.name = f"{id_str}_mesh"

    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Ajuste exacto de altura a 1.80 m
    min_z = min(v.co.z for v in mesh_obj.data.vertices)
    max_z = max(v.co.z for v in mesh_obj.data.vertices)
    print(f"Altura previa: {max_z - min_z:.4f} m (min Z: {min_z:.4f}, max Z: {max_z:.4f})")

    # Mover para que min_z sea exactamente 0.00
    if abs(min_z) > 0.0001:
        for v in mesh_obj.data.vertices:
            v.co.z -= min_z

    max_z = max(v.co.z for v in mesh_obj.data.vertices)
    if abs(max_z - 1.80) > 0.0005:
        scale_factor = 1.80 / max_z
        print(f"Ajustando Z exacto a 1.80 m (factor: {scale_factor:.6f})")
        for v in mesh_obj.data.vertices:
            v.co.z *= scale_factor
        mesh_obj.data.update()

    _aplicar_auto_smooth(mesh_obj, 30.0)

    # --- 6. CREAR OBJETO RAÍZ Y EMPARENTAR ---
    r = raiz(id_str)
    mesh_obj.parent = r

    final_dim = bbox_m(r)
    final_tris = contar_tris(r)
    print(f"person_ref generado: AABB={final_dim} m, Tris={final_tris}")

    return r


def ejecutar_prompt_8():
    print("=== Iniciando Prompt 8: Figura humana de escala (person_ref) ===")

    id_str = "person_ref"
    r = crear_person_ref()

    dim = bbox_m(r)
    tris = contar_tris(r)
    print(f"[{id_str}] Triángulos: {tris} (presupuesto <= 3 000)")
    print(f"[{id_str}] Dimensiones AABB: {dim} m")

    # 1. Exportar GLB a assets/models/ref/person_ref.glb
    glb_path = exportar_glb(r, "ref", id_str)
    glb_size = os.path.getsize(glb_path)
    print(f"[{id_str}] Exportado a {glb_path} ({glb_size} bytes)")

    # 2. Registrar en manifest.json con categoría 'ref'
    entry = registrar("ref", id_str, r)
    print(f"[{id_str}] Registrado en manifest.json: {entry}")

    # 3. Generar vista previa con Workbench a art/previews/person_ref.png
    prev_path = preview(r, id_str)
    prev_size = os.path.getsize(prev_path)
    print(f"[{id_str}] Vista previa: {prev_path} ({prev_size} bytes)")

    # 4. Generar vista previa comparativa person_ref_vs_leostar2.png
    print("\n--- Generando vista previa comparativa: person_ref_vs_leostar2 ---")
    limpiar_escena()

    # Importar bus leostar2
    leostar_path = os.path.join(ROOT, "assets", "models", "buses", "leostar2.glb")
    prev_objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=leostar_path)
    new_objs = [o for o in bpy.data.objects if o not in prev_objs]
    leostar_root = [o for o in new_objs if o.parent is None][0]

    # Elevar leostar2 para que su base descanse sobre el suelo Z = 0
    leostar_min, _ = _bbox_min_max(leostar_root)
    leostar_root.location.z -= leostar_min.z
    print(f"Leostar2 ubicado con base en Z=0 (posición: {leostar_root.location})")

    # Importar person_ref recién exportado
    person_glb_path = os.path.join(ROOT, "assets", "models", "ref", f"{id_str}.glb")
    prev_objs2 = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=person_glb_path)
    new_objs2 = [o for o in bpy.data.objects if o not in prev_objs2]
    person_root = [o for o in new_objs2 if o.parent is None][0]

    # Colocar person_ref a 0.5 m de la cara +X de leostar2
    # leostar2 cara +X está en X = +0.5 m.
    # Colocamos person_ref a X = 1.0 m
    person_root.location = (1.0, 0, 0)
    print(f"Person_ref ubicado en: {person_root.location} (a 0.5 m de la cara +X de leostar2)")

    # Raíz temporal para el encuadre
    comp_root = bpy.data.objects.new("comparison_root", None)
    bpy.context.collection.objects.link(comp_root)
    leostar_root.parent = comp_root
    person_root.parent = comp_root

    vs_path = os.path.join(ROOT, "art", "previews", "person_ref_vs_leostar2.png")
    preview(comp_root, "person_ref_vs_leostar2")
    vs_size = os.path.getsize(vs_path)
    print(f"Comparativa renderizada en: {vs_path} ({vs_size} bytes)")

    # 5. Guardar art/blender/ref.blend
    print("\n--- Guardando art/blender/ref.blend ---")
    limpiar_escena()
    r_saved = crear_person_ref()
    blend_path = os.path.join(ROOT, "art", "blender", "ref.blend")
    guardar_blend(blend_path)
    print(f"Guardado archivo de trabajo en: {blend_path}")

    return {
        "id": id_str,
        "tris": tris,
        "bbox_m": dim,
        "glb_path": glb_path,
        "glb_size": glb_size,
        "prev_path": prev_path,
        "prev_size": prev_size,
        "vs_path": vs_path,
        "vs_size": vs_size
    }


if __name__ == "__main__":
    rep = ejecutar_prompt_8()
    print("PROMPT 8 FINALIZADO:", rep)
