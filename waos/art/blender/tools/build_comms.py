# -*- coding: utf-8 -*-
"""
build_comms.py - Modela las 5 antenas de comunicaciones según el contrato técnico de PROMPTS_ANTIGRAVITY.md.
"""

import os
import sys
import math
import bpy
import bmesh
import mathutils

ROOT = r"c:\Users\DCONN\OneDrive\Escritorio\JUEGO\NSAC\NasaSpaceApps2026\waos"
helpers_path = os.path.join(ROOT, "art", "blender", "tools", "waos_helpers.py")
exec(open(helpers_path, encoding="utf-8").read())


# -------------------------------------------------------------------------
# 1. uhf (Socket: socket_top)
# Soporte cuadrado de 0.10 x 0.10 x 0.01 con 4 antenas de cinta métrica
# de 0.17 m x 6 mm x 0.3 mm, desplegadas en cruz a 90° entre sí y perpendiculares a +Z.
# Material: mat_mli_plata
# -------------------------------------------------------------------------
def build_uhf(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("uhf")
    r.location = offset

    sup_w = 0.10
    sup_t = 0.01

    # Soporte cuadrado en Z = 0 a 0.01
    soporte = caja("uhf_soporte", (sup_w, sup_w, sup_t), (ox, oy, oz + sup_t / 2.0), "mat_aluminio")

    # Domo / hub central de alimentación en mat_negro
    hub = cilindro("uhf_hub", 0.018, 0.006, (ox, oy, oz + sup_t + 0.003), "mat_negro", verts=20)

    # 4 antenas de cinta métrica (0.17 m largo x 0.006 m ancho x 0.001 m grosor)
    # Desplegadas en cruz a 90° entre sí y perpendiculares a +Z
    tape_l = 0.17
    tape_w = 0.006
    tape_t = 0.001
    tape_z = oz + sup_t + tape_t / 2.0

    piezas = [soporte, hub]

    # Cinta 1: +X
    c1 = caja("uhf_tape_xp", (tape_l, tape_w, tape_t), (ox + sup_w / 2.0 + tape_l / 2.0, oy, tape_z), "mat_mli_plata")
    # Cinta 2: -X
    c2 = caja("uhf_tape_xn", (tape_l, tape_w, tape_t), (ox - sup_w / 2.0 - tape_l / 2.0, oy, tape_z), "mat_mli_plata")
    # Cinta 3: +Y
    c3 = caja("uhf_tape_yp", (tape_w, tape_l, tape_t), (ox, oy + sup_w / 2.0 + tape_l / 2.0, tape_z), "mat_mli_plata")
    # Cinta 4: -Y
    c4 = caja("uhf_tape_yn", (tape_w, tape_l, tape_t), (ox, oy - sup_w / 2.0 - tape_l / 2.0, tape_z), "mat_mli_plata")

    # Bisagras / carretes de sujeción de cinta en los bordes del soporte
    b_xp = caja("uhf_hinge_xp", (0.010, 0.012, 0.006), (ox + sup_w / 2.0 - 0.005, oy, oz + sup_t + 0.003), "mat_celdas_marco")
    b_xn = caja("uhf_hinge_xn", (0.010, 0.012, 0.006), (ox - sup_w / 2.0 + 0.005, oy, oz + sup_t + 0.003), "mat_celdas_marco")
    b_yp = caja("uhf_hinge_yp", (0.012, 0.010, 0.006), (ox, oy + sup_w / 2.0 - 0.005, oz + sup_t + 0.003), "mat_celdas_marco")
    b_yn = caja("uhf_hinge_yn", (0.012, 0.010, 0.006), (ox, oy - sup_w / 2.0 + 0.005, oz + sup_t + 0.003), "mat_celdas_marco")

    piezas.extend([c1, c2, c3, c4, b_xp, b_xn, b_yp, b_yn])
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 2. sband (Socket: socket_back)
# Antena de parche: placa de 0.08 x 0.08 x 0.004 en mat_blanco
# con un cuadrado de mat_cobre de 0.05 encima.
# -------------------------------------------------------------------------
def build_sband(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("sband")
    r.location = offset

    sub_w = 0.08
    sub_t = 0.004
    patch_w = 0.05
    patch_t = 0.001

    # Placa sustrato / radomo en mat_blanco en Z = 0 a 0.004
    sustrato = caja("sband_sub", (sub_w, sub_w, sub_t), (ox, oy, oz + sub_t / 2.0), "mat_blanco")

    # Parche radiador de cobre de 0.05 x 0.05 encima
    parche = caja("sband_patch", (patch_w, patch_w, patch_t), (ox, oy, oz + sub_t + patch_t / 2.0), "mat_cobre")

    # Punto de alimentación coaxial
    feed = cilindro("sband_feed", 0.002, 0.002, (ox + 0.012, oy + 0.012, oz + sub_t + patch_t), "mat_aluminio", verts=12)

    # Tornillos de montaje en las 4 esquinas del sustrato
    piezas = [sustrato, parche, feed]
    s_off = sub_w / 2.0 - 0.006
    for idx, (sx, sy) in enumerate([(-s_off, -s_off), (s_off, -s_off), (-s_off, s_off), (s_off, s_off)]):
        screw = cilindro(f"sband_screw_{idx}", 0.0015, 0.002, (ox + sx, oy + sy, oz + sub_t), "mat_aluminio", verts=12)
        piezas.append(screw)

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 3. xpatch (Socket: socket_back)
# Parche de 0.06 x 0.06 x 0.004, con dos parches iguales lado a lado separados 2 cm.
# -------------------------------------------------------------------------
def build_xpatch(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("xpatch")
    r.location = offset

    sub_w = 0.06
    sub_t = 0.004
    sep = 0.02  # 2 cm separación
    center_sep = sub_w + sep  # 0.08 m entre centros de parches

    patch_w = 0.038
    patch_t = 0.001

    piezas = []

    # Placa base de montaje compartida que une los dos parches
    mount_plate = caja("xpatch_mount", (center_sep + sub_w, sub_w + 0.01, 0.002), (ox, oy, oz + 0.001), "mat_aluminio")
    piezas.append(mount_plate)

    # Dos parches lado a lado a lo largo de X
    for idx, c_x in enumerate([-center_sep / 2.0, center_sep / 2.0]):
        # Sustrato cerámico blanco
        sub = caja(f"xpatch_sub_{idx}", (sub_w, sub_w, sub_t), (ox + c_x, oy, oz + 0.002 + sub_t / 2.0), "mat_blanco")
        # Parche de cobre
        patch = caja(f"xpatch_elem_{idx}", (patch_w, patch_w, patch_t), (ox + c_x, oy, oz + 0.002 + sub_t + patch_t / 2.0), "mat_cobre")
        # Feed pin
        feed = cilindro(f"xpatch_feed_{idx}", 0.0015, 0.002, (ox + c_x + 0.008, oy + 0.008, oz + 0.002 + sub_t + patch_t), "mat_aluminio", verts=12)
        piezas.extend([sub, patch, feed])

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 4. xhga (Socket: socket_top)
# Plato parabólico de 0.60 m de diámetro y 0.09 m de profundidad en mat_blanco,
# con subreflector sobre 3 puntales, un mástil de 0.30 m y un cardán de 2 ejes en la base.
# -------------------------------------------------------------------------
def build_xhga(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("xhga")
    r.location = offset

    # Cardán de 2 ejes en la base (Z de 0 a 0.08)
    gimbal_base = caja("xhga_gimbal_base", (0.09, 0.09, 0.03), (ox, oy, oz + 0.015), "mat_aluminio")
    az_actuator = cilindro("xhga_az_motor", 0.035, 0.035, (ox, oy, oz + 0.03 + 0.035 / 2.0), "mat_aluminio", verts=20)
    el_yoke = caja("xhga_el_yoke", (0.08, 0.05, 0.03), (ox, oy, oz + 0.065 + 0.015), "mat_aluminio")

    # Mástil de 0.30 m en mat_aluminio (desde Z = 0.08 hasta Z = 0.38)
    mast_len = 0.30
    mast_r = 0.018
    mast_z = oz + 0.08 + mast_len / 2.0
    mast = cilindro("xhga_mast", mast_r, mast_len, (ox, oy, mast_z), "mat_aluminio", verts=20)

    # Plato parabólico: diámetro 0.60 m (radio 0.30 m), profundidad 0.09 m en mat_blanco
    dish_dia = 0.60
    dish_depth = 0.09
    dish_base_z = oz + 0.08 + mast_len
    dish = plato("xhga_dish", dish_dia, dish_depth, (ox, oy, dish_base_z), "mat_blanco")

    # Bocina alimentadora central en el fondo del plato
    feed_horn = cono("xhga_feed", 0.012, 0.024, 0.045, (ox, oy, dish_base_z + 0.025), "mat_cobre")

    # Subreflector sobre 3 puntales:
    # Subreflector parabólico o cónico pequeño en el foco (Z = dish_base_z + dish_depth + 0.06)
    sub_z = dish_base_z + dish_depth + 0.06
    subreflector = cono("xhga_subreflector", 0.035, 0.005, 0.020, (ox, oy, sub_z), "mat_aluminio")

    # 3 puntales de soporte (struts a 120° conectados desde el borde del plato al subreflector)
    piezas_struts = []
    dish_rim_r = dish_dia / 2.0 * 0.96
    dish_rim_z = dish_base_z + dish_depth

    for idx, ang_deg in enumerate([0, 120, 240]):
        ang = math.radians(ang_deg)
        rim_x = ox + dish_rim_r * math.cos(ang)
        rim_y = oy + dish_rim_r * math.sin(ang)

        # Vector desde el borde del plato al subreflector
        p_rim = mathutils.Vector((rim_x, rim_y, dish_rim_z))
        p_sub = mathutils.Vector((ox, oy, sub_z))
        delta = p_sub - p_rim
        strut_len = delta.length
        strut_center = (p_rim + p_sub) / 2.0

        q = mathutils.Vector((0, 0, 1)).rotation_difference(delta.normalized())
        strut = cilindro(f"xhga_strut_{idx}", 0.0035, strut_len, (strut_center.x, strut_center.y, strut_center.z), "mat_aluminio", verts=12, rot=q.to_euler())
        piezas_struts.append(strut)

    # Bridas traseras de refuerzo del plato en mat_aluminio
    dish_bracket = cilindro("xhga_dish_hub", 0.06, 0.015, (ox, oy, dish_base_z), "mat_aluminio", verts=20)

    piezas = [gimbal_base, az_actuator, el_yoke, mast, dish, feed_horn, subreflector, dish_bracket] + piezas_struts
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 5. ka (Socket: socket_top)
# Plato orientable al estilo de la HGA de LRO: 0.75 m de diámetro
# sobre un mástil de 1.2 m en mat_aluminio, con cardán de 2 ejes visible y un alimentador central.
# -------------------------------------------------------------------------
def build_ka(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("ka")
    r.location = offset

    # Cardán de 2 ejes visible en la base (Z de 0 a 0.12)
    base_plate = caja("ka_base_plate", (0.14, 0.14, 0.03), (ox, oy, oz + 0.015), "mat_aluminio")
    az_motor = cilindro("ka_az_motor", 0.05, 0.05, (ox, oy, oz + 0.03 + 0.025), "mat_aluminio", verts=24)
    el_bracket = caja("ka_el_bracket", (0.12, 0.08, 0.04), (ox, oy, oz + 0.08 + 0.02), "mat_aluminio")

    # Mástil tubular de 1.2 m en mat_aluminio (desde Z = 0.12 hasta Z = 1.32)
    mast_len = 1.20
    mast_r = 0.024
    mast_z = oz + 0.12 + mast_len / 2.0
    mast = cilindro("ka_mast", mast_r, mast_len, (ox, oy, mast_z), "mat_aluminio", verts=24)

    # Cardán / articulación superior del plato
    top_pivot_z = oz + 0.12 + mast_len + 0.03
    top_pivot = cilindro("ka_top_pivot", 0.04, 0.05, (ox, oy, top_pivot_z), "mat_aluminio", verts=20, rot=(0.0, math.radians(90), 0.0))
    top_bracket = caja("ka_top_bracket", (0.10, 0.10, 0.04), (ox, oy, top_pivot_z + 0.03), "mat_aluminio")

    # Plato orientable de 0.75 m de diámetro (radio 0.375m), profundidad 0.12 m en mat_blanco
    dish_dia = 0.75
    dish_depth = 0.12
    dish_base_z = top_pivot_z + 0.05
    dish = plato("ka_dish", dish_dia, dish_depth, (ox, oy, dish_base_z), "mat_blanco")

    # Alimentador central (prime focus feed horn): mástil central con bocina de cobre
    feed_len = 0.18
    feed_mast = cilindro("ka_feed_mast", 0.008, feed_len, (ox, oy, dish_base_z + feed_len / 2.0), "mat_aluminio", verts=16)
    feed_horn = cono("ka_feed_horn", 0.022, 0.010, 0.04, (ox, oy, dish_base_z + feed_len + 0.015), "mat_cobre")

    # Nervaduras de refuerzo posteriores del plato en mat_aluminio
    rib_x = caja("ka_rib_x", (dish_dia * 0.85, 0.015, 0.025), (ox, oy, dish_base_z - 0.01), "mat_aluminio")
    rib_y = caja("ka_rib_y", (0.015, dish_dia * 0.85, 0.025), (ox, oy, dish_base_z - 0.01), "mat_aluminio")

    piezas = [base_plate, az_motor, el_bracket, mast, top_pivot, top_bracket, dish, feed_mast, feed_horn, rib_x, rib_y]
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# Ejecutor principal para Prompt 4
# -------------------------------------------------------------------------
def ejecutar_prompt_4():
    print("Iniciando Prompt 4: Modelado de las 5 antenas de comunicaciones...")

    antenas = [
        ("uhf", build_uhf),
        ("sband", build_sband),
        ("xpatch", build_xpatch),
        ("xhga", build_xhga),
        ("ka", build_ka),
    ]

    reporte = []

    # PASO 1: Generar, exportar y registrar cada antena en su propia escena limpia
    for id_str, builder_func in antenas:
        print(f"\n--- Construyendo y exportando antena: {id_str} ---")
        limpiar_escena()

        obj_r = builder_func(offset=(0.0, 0.0, 0.0))

        dim = bbox_m(obj_r)
        tris = contar_tris(obj_r)

        glb_path = exportar_glb(obj_r, "comms", id_str)
        entry = registrar("comms", id_str, obj_r)
        prev_path = preview(obj_r, id_str)

        info = {
            "id": id_str,
            "bbox_m": dim,
            "tris": tris,
            "glb_path": glb_path,
            "glb_size": os.path.getsize(glb_path),
            "prev_path": prev_path,
            "prev_size": os.path.getsize(prev_path)
        }
        reporte.append(info)
        print(f"[{id_str}] Tris: {tris}, BBox: {dim}, GLB: {os.path.getsize(glb_path)}B, Prev: {os.path.getsize(prev_path)}B")

    # PASO 2: Construir la escena general para art/blender/comms.blend
    print("\n--- Generando escena de trabajo art/blender/comms.blend ---")
    limpiar_escena()

    offsets_x = {
        "uhf": 0.0,
        "sband": 0.6,
        "xpatch": 1.2,
        "xhga": 2.2,
        "ka": 3.6
    }

    for id_str, builder_func in antenas:
        ox = offsets_x[id_str]
        builder_func(offset=(ox, 0.0, 0.0))

    blend_path = os.path.join(ROOT, "art", "blender", "comms.blend")
    os.makedirs(os.path.dirname(blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Archivo blend guardado exitosamente: {blend_path}")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_4()
