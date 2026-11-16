# -*- coding: utf-8 -*-
"""
build_panels.py - Modela los 7 paneles solares según el contrato técnico de PROMPTS_ANTIGRAVITY.md.
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


def crear_rejilla_celdas(nombre, w, l, cols, rows, pos_y, z_start, mat_celda="mat_celdas"):
    """
    Crea una superficie frontal de celdas solares en la cara -Y local,
    organizada en cuadrícula con separaciones visibles.
    """
    mesh = bpy.data.meshes.new(nombre + "_mesh")
    obj = bpy.data.objects.new(nombre, mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()
    margin_w = w * 0.02
    margin_l = l * 0.02
    cell_w = (w - (cols + 1) * margin_w) / cols
    cell_l = (l - (rows + 1) * margin_l) / rows

    x_start = -w / 2.0 + margin_w

    for r in range(rows):
        z0 = z_start + margin_l + r * (cell_l + margin_l)
        z1 = z0 + cell_l
        for c in range(cols):
            x0 = x_start + c * (cell_w + margin_w)
            x1 = x0 + cell_w
            # Cara que mira hacia -Y local
            v1 = bm.verts.new((x0, pos_y, z0))
            v2 = bm.verts.new((x1, pos_y, z0))
            v3 = bm.verts.new((x1, pos_y, z1))
            v4 = bm.verts.new((x0, pos_y, z1))
            bm.faces.new((v1, v2, v3, v4))

    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()

    _asignar_material(obj, mat_celda)
    _aplicar_auto_smooth(obj, 30.0)
    return obj


# -------------------------------------------------------------------------
# Panel 1: pan8 (0.013 m², 0.30 x 0.044 m)
# Placa adosada al cuerpo, sin yugo: grosor 3 mm, origen en el centro de la placa.
# -------------------------------------------------------------------------
def build_pan8(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("pan8")
    r.location = offset
    w = 0.30
    l = 0.044
    t = 0.003  # 3 mm

    # Placa base en mat_celdas_marco centrada en el origen
    # Cara frontal en -Y (-t/2), cara trasera en +Y (+t/2)
    base = caja("pan8_base", (w, t, l), (ox, oy, oz), "mat_celdas_marco")

    # Celdas en la cara frontal (-Y)
    celdas = crear_rejilla_celdas(
        "pan8_celdas",
        w * 0.96,
        l * 0.90,
        cols=6,
        rows=1,
        pos_y=oy - t / 2.0 - 0.0005,
        z_start=oz - (l * 0.90) / 2.0
    )

    piezas = [base, celdas]
    emparentar(piezas, r)
    return r, w * l


# -------------------------------------------------------------------------
# Panel 2: pan30 (0.047 m², 0.34 x 0.137 m)
# Panel desplegable CubeSat, 1 hoja con bisagra de resorte. Yugo de 2 cm.
# -------------------------------------------------------------------------
def build_pan30(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("pan30")
    r.location = offset
    w = 0.34
    l = 0.137
    t = 0.003
    yugo_len = 0.02

    # Yugo en Z de 0 a 0.02
    yugo = caja("pan30_yugo", (0.04, 0.006, yugo_len), (ox, oy, oz + yugo_len / 2.0), "mat_aluminio")

    # Bisagra en Z = yugo_len
    bisagra = cilindro("pan30_bisagra", 0.004, 0.06, (ox, oy, oz + yugo_len), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))

    # Hoja de panel desde Z = yugo_len hasta Z = yugo_len + l
    leaf_center_z = oz + yugo_len + l / 2.0
    hoja = caja("pan30_hoja", (w, t, l), (ox, oy, leaf_center_z), "mat_celdas_marco")

    # Celdas solares en la cara -Y
    celdas = crear_rejilla_celdas(
        "pan30_celdas",
        w * 0.96,
        l * 0.96,
        cols=8,
        rows=3,
        pos_y=oy - t / 2.0 - 0.0005,
        z_start=oz + yugo_len + (l * 0.02)
    )

    # Nervaduras de refuerzo en la cara trasera (+Y)
    rib1 = caja("pan30_rib1", (w * 0.90, 0.002, 0.004), (ox, oy + t / 2.0 + 0.001, leaf_center_z), "mat_aluminio")

    piezas = [yugo, bisagra, hoja, celdas, rib1]
    emparentar(piezas, r)
    return r, w * l


# -------------------------------------------------------------------------
# Panel 3: pan90 (0.140 m², 0.34 x 0.41 m)
# 3 hojas desplegadas con bisagras visibles. Yugo de 3 cm.
# -------------------------------------------------------------------------
def build_pan90(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("pan90")
    r.location = offset
    w = 0.34
    l_total = 0.41
    num_hojas = 3
    l_leaf = l_total / num_hojas  # ~0.1367m
    t = 0.003
    yugo_len = 0.03

    piezas = []

    # Yugo
    yugo = caja("pan90_yugo", (0.05, 0.008, yugo_len), (ox, oy, oz + yugo_len / 2.0), "mat_aluminio")
    piezas.append(yugo)

    z_curr = oz + yugo_len

    for i in range(num_hojas):
        # Bisagra antes de la hoja
        bisagra = cilindro(f"pan90_bisagra_{i}", 0.004, 0.08, (ox, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
        piezas.append(bisagra)

        leaf_cz = z_curr + l_leaf / 2.0
        hoja = caja(f"pan90_hoja_{i}", (w, t, l_leaf - 0.004), (ox, oy, leaf_cz), "mat_celdas_marco")
        celdas = crear_rejilla_celdas(
            f"pan90_celdas_{i}",
            w * 0.95,
            l_leaf * 0.92,
            cols=8,
            rows=3,
            pos_y=oy - t / 2.0 - 0.0005,
            z_start=z_curr + 0.004
        )
        piezas.extend([hoja, celdas])
        z_curr += l_leaf

    emparentar(piezas, r)
    return r, w * l_total


# -------------------------------------------------------------------------
# Panel 4: pan400 (0.61 m², 0.60 x 1.02 m)
# Ala SmallSat de 2 hojas, yugo de 0.15 m y motor de apuntado en la raíz.
# -------------------------------------------------------------------------
def build_pan400(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("pan400")
    r.location = offset
    w = 0.60
    l_total = 1.02
    num_hojas = 2
    l_leaf = l_total / num_hojas  # 0.51m
    t = 0.008
    yugo_len = 0.15

    piezas = []

    # Motor de apuntado (cilindro en la raíz)
    motor = cilindro("pan400_motor", 0.045, 0.06, (ox, oy, oz + 0.03), "mat_aluminio", verts=24)
    # Yugo (brazo articulado) de 0.03 a 0.15m
    arm_len = yugo_len - 0.04
    arm = caja("pan400_yugo_arm", (0.06, 0.02, arm_len), (ox, oy, oz + 0.04 + arm_len / 2.0), "mat_aluminio")
    piezas.extend([motor, arm])

    z_curr = oz + yugo_len

    for i in range(num_hojas):
        bisagra = cilindro(f"pan400_bisagra_{i}", 0.008, 0.16, (ox, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
        piezas.append(bisagra)

        leaf_cz = z_curr + l_leaf / 2.0
        hoja = caja(f"pan400_hoja_{i}", (w, t, l_leaf - 0.008), (ox, oy, leaf_cz), "mat_celdas_marco")
        celdas = crear_rejilla_celdas(
            f"pan400_celdas_{i}",
            w * 0.96,
            l_leaf * 0.95,
            cols=6,
            rows=6,
            pos_y=oy - t / 2.0 - 0.0008,
            z_start=z_curr + 0.008
        )
        # Costillas estructurales traseras (+Y)
        rib_v1 = caja(f"pan400_rib_{i}_1", (0.006, 0.004, l_leaf * 0.85), (ox - w * 0.25, oy + t / 2.0 + 0.002, leaf_cz), "mat_aluminio")
        rib_v2 = caja(f"pan400_rib_{i}_2", (0.006, 0.004, l_leaf * 0.85), (ox + w * 0.25, oy + t / 2.0 + 0.002, leaf_cz), "mat_aluminio")
        piezas.extend([hoja, celdas, rib_v1, rib_v2])
        z_curr += l_leaf

    emparentar(piezas, r)
    return r, w * l_total


# -------------------------------------------------------------------------
# Panel 5: pan1500 (2.30 m², 1.00 x 2.30 m)
# Ala rígida de 3 hojas, yugo de 0.4 m y motor de apuntado.
# -------------------------------------------------------------------------
def build_pan1500(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("pan1500")
    r.location = offset
    w = 1.00
    l_total = 2.30
    num_hojas = 3
    l_leaf = l_total / num_hojas  # ~0.767m
    t = 0.012
    yugo_len = 0.40

    piezas = []

    # Motor de apuntado
    motor = cilindro("pan1500_motor", 0.07, 0.10, (ox, oy, oz + 0.05), "mat_aluminio", verts=24)
    # Brazo / yugo con estructura triangular
    y_strut1 = caja("pan1500_yugo_s1", (0.04, 0.02, yugo_len - 0.08), (ox - 0.12, oy, oz + 0.08 + (yugo_len - 0.08) / 2.0), "mat_aluminio")
    y_strut2 = caja("pan1500_yugo_s2", (0.04, 0.02, yugo_len - 0.08), (ox + 0.12, oy, oz + 0.08 + (yugo_len - 0.08) / 2.0), "mat_aluminio")
    y_cross = caja("pan1500_yugo_cross", (0.28, 0.02, 0.03), (ox, oy, oz + yugo_len - 0.015), "mat_aluminio")
    piezas.extend([motor, y_strut1, y_strut2, y_cross])

    z_curr = oz + yugo_len

    for i in range(num_hojas):
        bisagra1 = cilindro(f"pan1500_bisagra_{i}_L", 0.010, 0.12, (ox - w * 0.35, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
        bisagra2 = cilindro(f"pan1500_bisagra_{i}_R", 0.010, 0.12, (ox + w * 0.35, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
        piezas.extend([bisagra1, bisagra2])

        leaf_cz = z_curr + l_leaf / 2.0
        hoja = caja(f"pan1500_hoja_{i}", (w, t, l_leaf - 0.012), (ox, oy, leaf_cz), "mat_celdas_marco")
        celdas = crear_rejilla_celdas(
            f"pan1500_celdas_{i}",
            w * 0.96,
            l_leaf * 0.96,
            cols=8,
            rows=8,
            pos_y=oy - t / 2.0 - 0.001,
            z_start=z_curr + 0.012
        )
        # Refuerzos diagonales traseros
        rib_d1 = caja(f"pan1500_rib_{i}_1", (w * 0.85, 0.006, 0.008), (ox, oy + t / 2.0 + 0.003, leaf_cz), "mat_aluminio")
        piezas.extend([hoja, celdas, rib_d1])
        z_curr += l_leaf

    emparentar(piezas, r)
    return r, w * l_total


# -------------------------------------------------------------------------
# Panel 6: pan4500 (6.90 m², 1.80 x 3.83 m)
# Ala grande al estilo de Landsat: 4 hojas, yugo de 0.6 m y motor de apuntado.
# -------------------------------------------------------------------------
def build_pan4500(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("pan4500")
    r.location = offset
    w = 1.80
    l_total = 3.83
    num_hojas = 4
    l_leaf = l_total / num_hojas  # ~0.9575m
    t = 0.018
    yugo_len = 0.60

    piezas = []

    # Motor de apuntado robusto
    motor = cilindro("pan4500_motor", 0.10, 0.16, (ox, oy, oz + 0.08), "mat_aluminio", verts=24)
    # Yugo reticular de celosía
    y_strut1 = caja("pan4500_yugo_s1", (0.06, 0.03, yugo_len - 0.12), (ox - 0.25, oy, oz + 0.10 + (yugo_len - 0.12) / 2.0), "mat_aluminio")
    y_strut2 = caja("pan4500_yugo_s2", (0.06, 0.03, yugo_len - 0.12), (ox + 0.25, oy, oz + 0.10 + (yugo_len - 0.12) / 2.0), "mat_aluminio")
    y_beam = caja("pan4500_yugo_beam", (0.60, 0.04, 0.05), (ox, oy, oz + yugo_len - 0.025), "mat_aluminio")
    piezas.extend([motor, y_strut1, y_strut2, y_beam])

    z_curr = oz + yugo_len

    for i in range(num_hojas):
        b1 = cilindro(f"pan4500_b_{i}_1", 0.015, 0.20, (ox - w * 0.35, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
        b2 = cilindro(f"pan4500_b_{i}_2", 0.015, 0.20, (ox + w * 0.35, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
        piezas.extend([b1, b2])

        leaf_cz = z_curr + l_leaf / 2.0
        hoja = caja(f"pan4500_hoja_{i}", (w, t, l_leaf - 0.016), (ox, oy, leaf_cz), "mat_celdas_marco")
        celdas = crear_rejilla_celdas(
            f"pan4500_celdas_{i}",
            w * 0.96,
            l_leaf * 0.96,
            cols=10,
            rows=8,
            pos_y=oy - t / 2.0 - 0.001,
            z_start=z_curr + 0.016
        )
        rib_back1 = caja(f"pan4500_rib_{i}_1", (w * 0.90, 0.010, 0.012), (ox, oy + t / 2.0 + 0.005, leaf_cz), "mat_aluminio")
        piezas.extend([hoja, celdas, rib_back1])
        z_curr += l_leaf

    emparentar(piezas, r)
    return r, w * l_total


# -------------------------------------------------------------------------
# Panel 7: rosa (9.50 m², 1.60 x 5.90 m)
# Ala enrollable al estilo de ROSA/DART:
# Manta flexible de celdas tensada entre dos mástiles laterales (tubos de 4 cm)
# y un rollo cilíndrico en el extremo de 0.12 m de diámetro y 1.6 m de largo.
# -------------------------------------------------------------------------
def build_rosa(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("rosa")
    r.location = offset
    w = 1.60
    l = 5.90
    boom_dia = 0.04
    boom_r = boom_dia / 2.0
    roll_dia = 0.12
    roll_r = roll_dia / 2.0

    piezas = []

    # Soporte base de despliegue en Z = 0
    base_deployer = caja("rosa_base_deployer", (w + 0.10, 0.08, 0.08), (ox, oy, oz + 0.04), "mat_aluminio")
    piezas.append(base_deployer)

    # Dos mástiles longitudinales delgados (tubos de 4 cm) a los lados (X = -w/2 y X = +w/2)
    # Extendiéndose a lo largo de Z desde 0 hasta l
    mast_l = cilindro("rosa_mast_L", boom_r, l, (ox - w / 2.0, oy, oz + l / 2.0), "mat_celdas_marco", verts=16)
    mast_r = cilindro("rosa_mast_R", boom_r, l, (ox + w / 2.0, oy, oz + l / 2.0), "mat_celdas_marco", verts=16)
    piezas.extend([mast_l, mast_r])

    # Manta flexible de celdas (grosor 2 mm) entre los dos mástiles
    blanket_w = w - boom_dia
    blanket_t = 0.002
    blanket = caja("rosa_blanket", (blanket_w, blanket_t, l), (ox, oy, oz + l / 2.0), "mat_kapton")

    # Superficie frontal de celdas (-Y)
    celdas = crear_rejilla_celdas(
        "rosa_celdas",
        blanket_w * 0.98,
        l * 0.98,
        cols=10,
        rows=16,
        pos_y=oy - blanket_t / 2.0 - 0.0005,
        z_start=oz + 0.05
    )
    piezas.extend([blanket, celdas])

    # Rollo cilíndrico en el extremo (+Z = l), diámetro 0.12m, largo 1.6m a lo largo de X
    roll = cilindro(
        "rosa_tip_roll",
        roll_r,
        w,
        (ox, oy, oz + l + roll_r),
        "mat_celdas_marco",
        verts=24,
        rot=(0.0, math.radians(90), 0.0)
    )
    piezas.append(roll)

    emparentar(piezas, r)
    return r, w * l


# -------------------------------------------------------------------------
# Ejecutor principal para Prompt 2
# -------------------------------------------------------------------------
def ejecutar_prompt_2():
    print("Iniciando Prompt 2: Modelado de los 7 paneles solares...")

    paneles = [
        ("pan8", build_pan8, 0.013),
        ("pan30", build_pan30, 0.047),
        ("pan90", build_pan90, 0.140),
        ("pan400", build_pan400, 0.61),
        ("pan1500", build_pan1500, 2.30),
        ("pan4500", build_pan4500, 6.90),
        ("rosa", build_rosa, 9.50),
    ]

    reporte = []

    # PASO 1: Generar, exportar y registrar cada panel en su propia escena limpia
    for id_str, builder_func, area_target in paneles:
        print(f"\n--- Construyendo y exportando panel: {id_str} ---")
        limpiar_escena()

        obj_r, area_calc = builder_func(offset=(0.0, 0.0, 0.0))

        dim = bbox_m(obj_r)
        tris = contar_tris(obj_r)

        glb_path = exportar_glb(obj_r, "panels", id_str)
        entry = registrar("panels", id_str, obj_r)
        prev_path = preview(obj_r, id_str)

        error_pct = ((area_calc - area_target) / area_target) * 100.0

        info = {
            "id": id_str,
            "area_target_m2": area_target,
            "area_calc_m2": round(area_calc, 4),
            "error_pct": round(error_pct, 2),
            "bbox_m": dim,
            "tris": tris,
            "glb_path": glb_path,
            "glb_size": os.path.getsize(glb_path),
            "prev_path": prev_path,
            "prev_size": os.path.getsize(prev_path)
        }
        reporte.append(info)
        print(f"[{id_str}] Area: {area_calc:.4f} m² (target: {area_target} m², error: {error_pct:+.2f}%), Tris: {tris}, BBox: {dim}, GLB: {os.path.getsize(glb_path)}B")

    # PASO 2: Construir la escena general para art/blender/panels.blend
    print("\n--- Generando escena de trabajo art/blender/panels.blend ---")
    limpiar_escena()

    offsets_x = {
        "pan8": 0.0,
        "pan30": 0.6,
        "pan90": 1.4,
        "pan400": 2.5,
        "pan1500": 4.5,
        "pan4500": 7.5,
        "rosa": 12.0
    }

    for id_str, builder_func, _ in paneles:
        ox = offsets_x[id_str]
        builder_func(offset=(ox, 0.0, 0.0))

    blend_path = os.path.join(ROOT, "art", "blender", "panels.blend")
    os.makedirs(os.path.dirname(blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Archivo blend guardado exitosamente: {blend_path}")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_2()
