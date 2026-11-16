# -*- coding: utf-8 -*-
"""
build_propulsion.py - Modela los 7 conjuntos de propulsión según el contrato técnico de PROMPTS_ANTIGRAVITY.md.
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
# 1. coldgas (Gas frío)
# 1 cilindro de 0.06 x 0.10 m, 4 microtoberas de 5 mm en las esquinas en mat_cobre
# -------------------------------------------------------------------------
def build_coldgas(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("coldgas")
    r.location = offset

    # Placa base de montaje en Z = 0
    plate_w = 0.088
    plate_t = 0.004
    base_plate = caja("cg_plate", (plate_w, plate_w, plate_t), (ox, oy, oz + plate_t / 2.0), "mat_aluminio")

    # Tanque cilíndrico de gas frío (diámetro 0.06m -> radio 0.03m, largo 0.10m a lo largo de X)
    # Colocado inmediatamente debajo de la placa
    tank_dia = 0.06
    tank_r = tank_dia / 2.0
    tank_len = 0.09
    tank_z = oz + plate_t + tank_r
    # Cilindro horizontal a lo largo de X
    tank_body = cilindro("cg_tank", tank_r, tank_len, (ox, oy, tank_z), "mat_mli_plata", verts=24, rot=(0.0, math.radians(90), 0.0))
    # Tapas redondeadas en los extremos
    cap_l = esfera("cg_tank_cap_l", tank_r * 0.98, (ox - tank_len / 2.0, oy, tank_z), "mat_mli_plata", segs=16)
    cap_r = esfera("cg_tank_cap_r", tank_r * 0.98, (ox + tank_len / 2.0, oy, tank_z), "mat_mli_plata", segs=16)

    # Brida / cinta de fijación del tanque en mat_kapton
    strap = caja("cg_strap", (0.012, tank_dia * 1.05, tank_dia * 1.05), (ox, oy, tank_z), "mat_kapton")

    # 4 microtoberas de 5 mm (0.005m boca) en las 4 esquinas de la placa, apuntando hacia +Z
    piezas = [base_plate, tank_body, cap_l, cap_r, strap]
    c_offset = plate_w / 2.0 - 0.010
    corners = [
        (-c_offset, -c_offset),
        (c_offset, -c_offset),
        (-c_offset, c_offset),
        (c_offset, c_offset)
    ]

    noz_len = 0.012
    noz_z = oz + plate_t + tank_dia + noz_len / 2.0
    for idx, (cx, cy) in enumerate(corners):
        # Tobera cónica: base radio 0.0015, boca radio 0.0025 (5mm diam)
        noz = cono(f"cg_nozzle_{idx}", 0.0015, 0.0025, noz_len, (ox + cx, oy + cy, noz_z), "mat_cobre")
        piezas.append(noz)

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 2. mono_cube (Monopropelente miniatura)
# 1 esfera de 0.20 m, módulo de 0.10 x 0.10 x 0.05 con 4 toberas de 1 N
# -------------------------------------------------------------------------
def build_mono_cube(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("mono_cube")
    r.location = offset

    tank_dia = 0.20
    tank_r = tank_dia / 2.0  # 0.10m

    # Placa base de montaje en Z = 0
    plate_w = 0.11
    plate_t = 0.006
    base_plate = caja("mc_plate", (plate_w, plate_w, plate_t), (ox, oy, oz + plate_t / 2.0), "mat_aluminio")

    # Tanque esférico semi-empotrado (centro en Z = tank_r * 0.6)
    tank_z = oz + plate_t + tank_r * 0.60
    tank = esfera("mc_tank", tank_r, (ox, oy, tank_z), "mat_mli_plata", segs=24)
    strap = cilindro("mc_strap", tank_r * 1.02, 0.015, (ox, oy, tank_z), "mat_aluminio", verts=24)

    # Módulo de propulsión de 0.10 x 0.10 x 0.05
    mod_w = 0.10
    mod_h = 0.05
    mod_z = tank_z + tank_r * 0.60 + mod_h / 2.0
    module_box = caja("mc_module", (mod_w, mod_w, mod_h), (ox, oy, mod_z), "mat_aluminio")

    # 4 toberas de 1 N en las esquinas del módulo
    piezas = [base_plate, tank, strap, module_box]
    c_off = mod_w / 2.0 - 0.016
    corners = [
        (-c_off, -c_off),
        (c_off, -c_off),
        (-c_off, c_off),
        (c_off, c_off)
    ]

    noz_h = 0.025
    noz_z = mod_z + mod_h / 2.0 + noz_h / 2.0
    for idx, (cx, cy) in enumerate(corners):
        noz = cono(f"mc_nozzle_{idx}", 0.003, 0.009, noz_h, (ox + cx, oy + cy, noz_z), "mat_cobre")
        piezas.append(noz)

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 3. mono_small (Hidracina SmallSat)
# 1 esfera de 0.54 m, 4 propulsores de 22 N inclinados 10° y 4 de 1 N de control
# -------------------------------------------------------------------------
def build_mono_small(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("mono_small")
    r.location = offset

    tank_dia = 0.54
    tank_r = tank_dia / 2.0  # 0.27m

    # Plataforma de montaje en Z = 0
    plat_w = 0.56
    plat_t = 0.015
    deck = caja("ms_deck", (plat_w, plat_w, plat_t), (ox, oy, oz + plat_t / 2.0), "mat_aluminio")

    # Tanque esférico de hidracina (semiempotrado en el bus, asoma hacia +Z)
    tank_z = oz + plat_t + tank_r * 0.50
    tank = esfera("ms_tank", tank_r, (ox, oy, tank_z), "mat_blanco", segs=28)
    girdle = cilindro("ms_girdle", tank_r * 1.015, 0.03, (ox, oy, tank_z), "mat_aluminio", verts=32)

    piezas = [deck, tank, girdle]

    # 4 propulsores principales de 22 N inclinados 10° hacia afuera
    main_r = 0.16
    main_angles = [45, 135, 225, 315]
    noz_len = 0.06
    noz_z = tank_z + tank_r * 0.70

    for idx, ang_deg in enumerate(main_angles):
        rad = math.radians(ang_deg)
        cx = ox + main_r * math.cos(rad)
        cy = oy + main_r * math.sin(rad)
        # Inclinación 10° hacia afuera radialmente
        tilt = math.radians(10)
        rx = -tilt * math.sin(rad)
        ry = tilt * math.cos(rad)

        pod = caja(f"ms_pod_{idx}", (0.04, 0.04, 0.03), (cx, cy, noz_z - 0.02), "mat_aluminio")
        noz = cono(f"ms_main_noz_{idx}", 0.008, 0.022, noz_len, (cx, cy, noz_z + noz_len / 2.0), "mat_cobre", rot=(rx, ry, 0.0))
        piezas.extend([pod, noz])

    # 4 propulsores de 1 N de control (RCS) en las esquinas de la plataforma
    rcs_off = plat_w / 2.0 - 0.03
    rcs_corners = [
        (-rcs_off, -rcs_off),
        (rcs_off, -rcs_off),
        (-rcs_off, rcs_off),
        (rcs_off, rcs_off)
    ]
    rcs_z = oz + plat_t + 0.015
    for idx, (cx, cy) in enumerate(rcs_corners):
        rcs_block = caja(f"ms_rcs_block_{idx}", (0.025, 0.025, 0.025), (ox + cx, oy + cy, rcs_z), "mat_aluminio")
        rcs_noz = cono(f"ms_rcs_noz_{idx}", 0.002, 0.006, 0.018, (ox + cx, oy + cy, rcs_z + 0.02), "mat_cobre")
        piezas.extend([rcs_block, rcs_noz])

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 4. mono_large (Hidracina grande, como LRO)
# 2 esferas de 0.95 m, 4 motores de 90 N y 8 de 22 N
# -------------------------------------------------------------------------
def build_mono_large(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("mono_large")
    r.location = offset

    tank_dia = 0.95
    tank_r = tank_dia / 2.0  # 0.475m

    # Plataforma de empuje en Z = 0
    plat_x = 1.45
    plat_y = 0.90
    plat_t = 0.025
    deck = caja("ml_deck", (plat_x, plat_y, plat_t), (ox, oy, oz + plat_t / 2.0), "mat_aluminio")

    # 2 esferas de 0.95m semi-empotradas lado a lado en X
    tank_sep_x = 0.44
    tank_z = oz + plat_t + tank_r * 0.45

    t1 = esfera("ml_tank_1", tank_r, (ox - tank_sep_x, oy, tank_z), "mat_mli_plata", segs=24)
    t2 = esfera("ml_tank_2", tank_r, (ox + tank_sep_x, oy, tank_z), "mat_mli_plata", segs=24)

    g1 = cilindro("ml_girdle_1", tank_r * 1.015, 0.04, (ox - tank_sep_x, oy, tank_z), "mat_aluminio", verts=24)
    g2 = cilindro("ml_girdle_2", tank_r * 1.015, 0.04, (ox + tank_sep_x, oy, tank_z), "mat_aluminio", verts=24)

    piezas = [deck, t1, t2, g1, g2]

    # 4 motores principales de 90 N en el centro
    m90_len = 0.14
    m90_r_mouth = 0.045
    m90_z = tank_z + tank_r * 0.65 + m90_len / 2.0
    m90_coords = [
        (-0.12, -0.10),
        (0.12, -0.10),
        (-0.12, 0.10),
        (0.12, 0.10)
    ]
    for idx, (mx, my) in enumerate(m90_coords):
        m90 = cono(f"ml_m90_{idx}", 0.015, m90_r_mouth, m90_len, (ox + mx, oy + my, m90_z), "mat_cobre")
        piezas.append(m90)

    # 8 propulsores de 22 N (pares en las 4 esquinas de la plataforma)
    rcs_cx = plat_x / 2.0 - 0.06
    rcs_cy = plat_y / 2.0 - 0.06
    corners = [
        (-rcs_cx, -rcs_cy),
        (rcs_cx, -rcs_cy),
        (-rcs_cx, rcs_cy),
        (rcs_cx, rcs_cy)
    ]

    rcs_z = oz + plat_t + 0.04
    for c_idx, (cx, cy) in enumerate(corners):
        block = caja(f"ml_rcs_blk_{c_idx}", (0.06, 0.06, 0.04), (ox + cx, oy + cy, rcs_z), "mat_aluminio")
        piezas.append(block)
        # 2 toberas por esquina
        for n_idx in [0, 1]:
            dx_off = (n_idx - 0.5) * 0.03
            n22 = cono(f"ml_m22_{c_idx}_{n_idx}", 0.006, 0.016, 0.04, (ox + cx + dx_off, oy + cy, rcs_z + 0.035), "mat_cobre")
            piezas.append(n22)

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 5. biprop (MMH/NTO con motor de apogeo)
# 2 tanques de 1.26 m, motor de apogeo central con tobera de mat_cobre de 0.6 m de largo y 0.35 m de boca, más 8 propulsores
# -------------------------------------------------------------------------
def build_biprop(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("biprop")
    r.location = offset

    tank_dia = 1.26
    tank_r = tank_dia / 2.0  # 0.63m

    # Estructura de empuje en Z = 0
    plat_w = 1.55
    plat_t = 0.03
    deck = caja("bp_deck", (plat_w, plat_w, plat_t), (ox, oy, oz + plat_t / 2.0), "mat_aluminio")

    # 2 tanques de 1.26m semiempotrados
    tank_sep = 0.48
    tank_z = oz + plat_t + tank_r * 0.35
    t1 = esfera("bp_fuel_tank", tank_r, (ox - tank_sep, oy, tank_z), "mat_mli_oro", segs=24)
    t2 = esfera("bp_ox_tank", tank_r, (ox + tank_sep, oy, tank_z), "mat_mli_plata", segs=24)

    # Bridas ecuatoriales
    g1 = cilindro("bp_girdle_1", tank_r * 1.015, 0.05, (ox - tank_sep, oy, tank_z), "mat_aluminio", verts=24)
    g2 = cilindro("bp_girdle_2", tank_r * 1.015, 0.05, (ox + tank_sep, oy, tank_z), "mat_aluminio", verts=24)

    piezas = [deck, t1, t2, g1, g2]

    # Motor de apogeo central (AKM / LAE)
    # Tobera de mat_cobre de 0.6 m de largo y 0.35 m de boca (radio 0.175m)
    akm_len = 0.60
    akm_mouth_r = 0.35 / 2.0  # 0.175m
    akm_throat_r = 0.05
    akm_z = oz + plat_t + akm_len / 2.0

    # Cámara de combustión e inyector en la base
    akm_chamber = cilindro("bp_akm_chamber", 0.09, 0.14, (ox, oy, oz + plat_t + 0.07), "mat_aluminio", verts=24)
    # Tobera cónica principal de cobre
    akm_nozzle = cono("bp_akm_nozzle", akm_throat_r, akm_mouth_r, akm_len, (ox, oy, akm_z + 0.06), "mat_cobre")
    piezas.extend([akm_chamber, akm_nozzle])

    # 8 propulsores de control (pares en las 4 esquinas de la plataforma)
    rcs_off = plat_w / 2.0 - 0.08
    corners = [
        (-rcs_off, -rcs_off),
        (rcs_off, -rcs_off),
        (-rcs_off, rcs_off),
        (rcs_off, rcs_off)
    ]

    rcs_z = oz + plat_t + 0.04
    for c_idx, (cx, cy) in enumerate(corners):
        block = caja(f"bp_rcs_blk_{c_idx}", (0.08, 0.08, 0.05), (ox + cx, oy + cy, rcs_z), "mat_aluminio")
        piezas.append(block)
        for n_idx in [0, 1]:
            dx_off = (n_idx - 0.5) * 0.04
            n_rcs = cono(f"bp_rcs_noz_{c_idx}_{n_idx}", 0.007, 0.018, 0.045, (ox + cx + dx_off, oy + cy, rcs_z + 0.04), "mat_cobre")
            piezas.append(n_rcs)

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 6. hall (Efecto Hall 600 W)
# 1 esfera de xenón de 0.36 m, propulsor Hall: anillo de 0.10 m de diám y 0.08 m de alto, con canal anular mat_negro y cátodo lateral
# -------------------------------------------------------------------------
def build_hall(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("hall")
    r.location = offset

    tank_dia = 0.36
    tank_r = tank_dia / 2.0  # 0.18m

    # Placa base en Z = 0
    plate_w = 0.40
    plate_t = 0.012
    deck = caja("hall_deck", (plate_w, plate_w, plate_t), (ox, oy, oz + plate_t / 2.0), "mat_aluminio")

    # Tanque esférico de xenón
    tank_z = oz + plate_t + tank_r * 0.70
    tank = esfera("hall_tank", tank_r, (ox, oy + 0.05, tank_z), "mat_mli_plata", segs=28)
    band = cilindro("hall_tank_band", tank_r * 1.015, 0.025, (ox, oy + 0.05, tank_z), "mat_kapton", verts=32)

    # Propulsor Hall montado al lado del tanque o enfrente
    # Anillo de 0.10m de diámetro (radio 0.05m) y 0.08m de alto
    hall_dia = 0.10
    hall_r = hall_dia / 2.0  # 0.05m
    hall_h = 0.08
    hall_x = ox
    hall_y = oy - 0.10
    hall_z = oz + plate_t + hall_h / 2.0 + 0.04

    # Soporte del propulsor
    hall_bracket = caja("hall_bracket", (0.08, 0.08, 0.04), (hall_x, hall_y, oz + plate_t + 0.02), "mat_aluminio")

    # Cuerpo exterior cilíndrico del propulsor en mat_aluminio
    hall_body = cilindro("hall_body", hall_r, hall_h, (hall_x, hall_y, hall_z), "mat_aluminio", verts=24)

    # Canal anular cerámico en mat_negro en la cara de salida (+Z)
    channel_out_r = hall_r * 0.85
    channel_in_r = hall_r * 0.45
    channel = cono("hall_channel", channel_out_r, channel_out_r, 0.008, (hall_x, hall_y, hall_z + hall_h / 2.0), "mat_negro")
    center_pole = cilindro("hall_center_pole", channel_in_r, 0.010, (hall_x, hall_y, hall_z + hall_h / 2.0), "mat_cobre", verts=20)

    # Cátodo neutralizador lateral: pequeño cilindro en mat_cobre / mat_aluminio inclinado
    cat_r = 0.012
    cat_h = 0.045
    cat_x = hall_x + hall_r + 0.018
    cat_y = hall_y
    cat_z = hall_z + 0.015
    cathode = cilindro("hall_cathode", cat_r, cat_h, (cat_x, cat_y, cat_z), "mat_cobre", verts=16, rot=(0.0, math.radians(20), 0.0))

    piezas = [deck, tank, band, hall_bracket, hall_body, channel, center_pole, cathode]
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 7. nextc (Iónico de rejillas, como NEXT-C)
# 1 esfera de xenón de 0.71 m, propulsor de 0.36 m de diám x 0.40 m, con rejilla circular frontal hecha de geometría (anillos concéntricos), cardán de 2 ejes y cátodo neutralizador
# -------------------------------------------------------------------------
def build_nextc(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("nextc")
    r.location = offset

    tank_dia = 0.71
    tank_r = tank_dia / 2.0  # 0.355m

    # Plataforma de empuje en Z = 0
    plat_w = 0.80
    plat_t = 0.02
    deck = caja("nc_deck", (plat_w, plat_w, plat_t), (ox, oy, oz + plat_t / 2.0), "mat_aluminio")

    # Tanque esférico de xenón
    tank_z = oz + plat_t + tank_r * 0.50
    tank = esfera("nc_tank", tank_r, (ox, oy + 0.12, tank_z), "mat_mli_plata", segs=32)
    band = cilindro("nc_tank_band", tank_r * 1.015, 0.04, (ox, oy + 0.12, tank_z), "mat_kapton", verts=32)

    # Cardán de 2 ejes (gimbal) en la base del propulsor
    gimbal_x = ox
    gimbal_y = oy - 0.15
    gimbal_z = oz + plat_t + 0.05
    gimbal_ring1 = cilindro("nc_gimbal_ring1", 0.22, 0.02, (gimbal_x, gimbal_y, gimbal_z), "mat_aluminio", verts=24)
    gimbal_yoke = caja("nc_gimbal_yoke", (0.44, 0.04, 0.06), (gimbal_x, gimbal_y, gimbal_z + 0.03), "mat_aluminio")

    # Propulsor iónico: cilindro de 0.36m de diámetro (radio 0.18m) x 0.40m de largo
    th_dia = 0.36
    th_r = th_dia / 2.0  # 0.18m
    th_len = 0.40
    th_z = gimbal_z + 0.06 + th_len / 2.0
    thruster_body = cilindro("nc_thruster_body", th_r, th_len, (gimbal_x, gimbal_y, th_z), "mat_aluminio", verts=28)

    # Rejilla circular frontal hecha de geometría (anillos concéntricos) en la cara +Z
    grid_z = th_z + th_len / 2.0
    # Placa base de la óptica iónica en mat_negro
    grid_plate = cilindro("nc_grid_plate", th_r * 0.94, 0.006, (gimbal_x, gimbal_y, grid_z), "mat_negro", verts=28)

    # Anillos concéntricos metálicos para la rejilla
    piezas_grid = [grid_plate]
    ring_radii = [0.15, 0.11, 0.07, 0.03]
    for idx, rr in enumerate(ring_radii):
        ring_mesh = cilindro(f"nc_grid_ring_{idx}", rr, 0.008, (gimbal_x, gimbal_y, grid_z + 0.002), "mat_aluminio", verts=24)
        piezas_grid.append(ring_mesh)

    # Cátodo neutralizador en el lateral de la rejilla
    cat_r = 0.016
    cat_len = 0.09
    cat_x = gimbal_x + th_r * 0.88
    cat_y = gimbal_y - th_r * 0.40
    cat_z = grid_z - 0.02
    cathode = cilindro("nc_cathode", cat_r, cat_len, (cat_x, cat_y, cat_z), "mat_cobre", verts=16, rot=(0.0, math.radians(15), 0.0))

    piezas = [deck, tank, band, gimbal_ring1, gimbal_yoke, thruster_body, cathode] + piezas_grid
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# Ejecutor principal para Prompt 3
# -------------------------------------------------------------------------
def ejecutar_prompt_3():
    print("Iniciando Prompt 3: Modelado de los 7 conjuntos de propulsión...")

    propulsiones = [
        ("coldgas", build_coldgas),
        ("mono_cube", build_mono_cube),
        ("mono_small", build_mono_small),
        ("mono_large", build_mono_large),
        ("biprop", build_biprop),
        ("hall", build_hall),
        ("nextc", build_nextc),
    ]

    reporte = []

    # PASO 1: Generar, exportar y registrar cada conjunto en su propia escena limpia
    for id_str, builder_func in propulsiones:
        print(f"\n--- Construyendo y exportando propulsión: {id_str} ---")
        limpiar_escena()

        obj_r = builder_func(offset=(0.0, 0.0, 0.0))

        dim = bbox_m(obj_r)
        tris = contar_tris(obj_r)

        glb_path = exportar_glb(obj_r, "propulsion", id_str)
        entry = registrar("propulsion", id_str, obj_r)
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

    # PASO 2: Construir la escena general para art/blender/propulsion.blend
    print("\n--- Generando escena de trabajo art/blender/propulsion.blend ---")
    limpiar_escena()

    offsets_x = {
        "coldgas": 0.0,
        "mono_cube": 0.5,
        "mono_small": 1.4,
        "mono_large": 2.8,
        "biprop": 4.8,
        "hall": 7.0,
        "nextc": 8.8
    }

    for id_str, builder_func in propulsiones:
        ox = offsets_x[id_str]
        builder_func(offset=(ox, 0.0, 0.0))

    blend_path = os.path.join(ROOT, "art", "blender", "propulsion.blend")
    os.makedirs(os.path.dirname(blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Archivo blend guardado exitosamente: {blend_path}")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_3()
