# -*- coding: utf-8 -*-
"""
build_instruments.py - Modela los 8 instrumentos científicos según el contrato técnico de PROMPTS_ANTIGRAVITY.md.
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
# 1. cubecam (Cámara multiespectral de 1.5U)
# Caja de 0.10 x 0.10 x 0.15 en mat_negro con tubo de lente de 0.06 de diámetro y apertura mat_lente
# -------------------------------------------------------------------------
def build_cubecam(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("cubecam")
    r.location = offset

    w = 0.10
    total_l = 0.15
    body_l = 0.115
    lens_l = total_l - body_l  # 0.035m
    lens_dia = 0.06
    lens_r = lens_dia / 2.0  # 0.03m

    # Brida de montaje en Z = 0
    flange = caja("cubecam_flange", (w, w, 0.005), (ox, oy, oz + 0.0025), "mat_aluminio")

    # Caja del cuerpo en mat_negro
    body = caja("cubecam_body", (w - 0.004, w - 0.004, body_l - 0.005), (ox, oy, oz + 0.005 + (body_l - 0.005) / 2.0), "mat_negro")

    # Radiador térmico pasivo lateral en mat_blanco
    rad = caja("cubecam_rad", (0.002, 0.07, 0.07), (ox + w / 2.0 - 0.001, oy, oz + 0.06), "mat_blanco")

    # Tubo de lente cilíndrico de 0.06 m de diámetro
    lens_z = oz + body_l + lens_l / 2.0
    barrel = cilindro("cubecam_barrel", lens_r, lens_l, (ox, oy, lens_z), "mat_negro", verts=24)

    # Anillo de apertura en mat_aluminio
    rim = cilindro("cubecam_rim", lens_r, 0.003, (ox, oy, oz + total_l - 0.0015), "mat_aluminio", verts=24)

    # Lente óptica en el extremo +Z en mat_lente
    optic = cilindro("cubecam_optic", lens_r * 0.85, 0.002, (ox, oy, oz + total_l), "mat_lente", verts=24)

    piezas = [flange, body, rad, barrel, rim, optic]
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 2. cam (LROC - Lunar Reconnaissance Orbiter Camera)
# 2 telescopios cilíndricos de 0.27 m de diámetro x 0.70 m en paralelo,
# cada uno con parasol y apertura mat_lente, más una cámara gran angular de 0.15 m en el centro
# y base común en mat_mli_oro.
# -------------------------------------------------------------------------
def build_cam(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("cam")
    r.location = offset

    tel_dia = 0.27
    tel_r = tel_dia / 2.0  # 0.135m
    tel_len = 0.70
    baffle_len = 0.18
    main_len = tel_len - baffle_len  # 0.52m
    sep_x = 0.18  # Centros a +/- 0.18m

    # Base común en mat_mli_oro en Z = 0 a 0.04
    base_t = 0.04
    base_plate = caja("cam_base_plate", (0.70, 0.35, base_t), (ox, oy, oz + base_t / 2.0), "mat_mli_oro")

    piezas = [base_plate]

    # 2 telescopios en paralelo (NAC-Left y NAC-Right)
    for idx, cx in enumerate([-sep_x, sep_x]):
        prefix = f"cam_nac_{idx}"
        # Cuerpo principal del telescopio envuelto en MLI dorada
        tel_body = cilindro(f"{prefix}_body", tel_r, main_len, (ox + cx, oy, oz + base_t + main_len / 2.0), "mat_mli_oro", verts=28)
        # Parasol / bafle frontal en mat_negro
        baffle_z = oz + base_t + main_len + baffle_len / 2.0
        baffle = cilindro(f"{prefix}_baffle", tel_r * 1.02, baffle_len, (ox + cx, oy, baffle_z), "mat_negro", verts=28)
        # Borde exterior de aluminio
        ring = cilindro(f"{prefix}_rim", tel_r * 1.03, 0.010, (ox + cx, oy, oz + base_t + tel_len - 0.005), "mat_aluminio", verts=28)
        # Apertura de lente en el extremo +Z
        lens = cilindro(f"{prefix}_lens", tel_r * 0.88, 0.005, (ox + cx, oy, oz + base_t + tel_len), "mat_lente", verts=24)
        piezas.extend([tel_body, baffle, ring, lens])

    # Cámara gran angular (WAC) en el centro (longitud 0.15 m)
    wac_h = 0.15
    wac_r = 0.045
    wac_body = cilindro("cam_wac_body", wac_r, wac_h * 0.75, (ox, oy, oz + base_t + (wac_h * 0.75) / 2.0), "mat_negro", verts=20)
    wac_baffle = cono("cam_wac_baffle", wac_r, wac_r * 1.25, wac_h * 0.25, (ox, oy, oz + base_t + wac_h * 0.75 + (wac_h * 0.25) / 2.0), "mat_negro")
    wac_lens = cilindro("cam_wac_lens", wac_r * 0.80, 0.004, (ox, oy, oz + base_t + wac_h), "mat_lente", verts=16)
    piezas.extend([wac_body, wac_baffle, wac_lens])

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 3. ir (Diviner - LRO)
# Caja de 0.50 x 0.30 x 0.35 con dos aperturas rectangulares y un actuador de elevación en la base;
# radiador de enfriamiento en un costado, en mat_blanco.
# -------------------------------------------------------------------------
def build_ir(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("ir")
    r.location = offset

    dx, dy, dz = 0.50, 0.30, 0.35
    actuator_h = 0.06
    body_h = dz - actuator_h  # 0.29m

    # Actuador de elevación en la base (Z de 0 a 0.06)
    actuator = cilindro("ir_actuator", 0.08, actuator_h, (ox, oy, oz + actuator_h / 2.0), "mat_aluminio", verts=24)
    act_bracket = caja("ir_act_bracket", (0.24, 0.18, 0.02), (ox, oy, oz + actuator_h - 0.01), "mat_aluminio")

    # Caja principal del instrumento en mat_mli_oro
    body_cz = oz + actuator_h + body_h / 2.0
    body = caja("ir_body", (dx - 0.02, dy, body_h), (ox, oy, body_cz), "mat_mli_oro", bevel=0.01)

    # Dos aperturas ópticas rectangulares en el extremo +Z
    ap_w = 0.14
    ap_d = 0.08
    ap_z = oz + dz
    ap1_surround = caja("ir_ap1_surround", (ap_w, ap_d, 0.015), (ox - 0.12, oy, ap_z - 0.0075), "mat_negro")
    ap1_glass = caja("ir_ap1_glass", (ap_w * 0.85, ap_d * 0.80, 0.002), (ox - 0.12, oy, ap_z), "mat_lente")

    ap2_surround = caja("ir_ap2_surround", (ap_w, ap_d, 0.015), (ox + 0.12, oy, ap_z - 0.0075), "mat_negro")
    ap2_glass = caja("ir_ap2_glass", (ap_w * 0.85, ap_d * 0.80, 0.002), (ox + 0.12, oy, ap_z), "mat_lente")

    # Radiador de enfriamiento en el costado +X en mat_blanco
    rad_t = 0.015
    rad = caja("ir_radiator", (rad_t, dy * 0.80, body_h * 0.80), (ox + dx / 2.0 - rad_t / 2.0, oy, body_cz), "mat_blanco")
    louver = caja("ir_louver", (0.003, dy * 0.70, body_h * 0.70), (ox + dx / 2.0 + 0.001, oy, body_cz), "mat_mli_plata")

    piezas = [actuator, act_bracket, body, ap1_surround, ap1_glass, ap2_surround, ap2_glass, rad, louver]
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 4. neut (LEND - LRO)
# Cuerpo cilíndrico de 0.35 x 0.40 rodeado de 4 a 6 módulos cilíndricos de moderador
# (polietileno, mat_blanco) y una cara superior con colimador.
# -------------------------------------------------------------------------
def build_neut(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("neut")
    r.location = offset

    main_dia = 0.35
    main_r = main_dia / 2.0  # 0.175m
    main_h = 0.40

    # Placa base de montaje
    deck = caja("neut_deck", (0.42, 0.42, 0.015), (ox, oy, oz + 0.0075), "mat_aluminio")

    # Cuerpo cilíndrico central en mat_negro
    body_cz = oz + 0.015 + main_h / 2.0
    body = cilindro("neut_body", main_r, main_h, (ox, oy, body_cz), "mat_negro", verts=28)

    # 6 módulos cilíndricos de moderador (polietileno blanco) alrededor del cuerpo
    num_mods = 6
    mod_dia = 0.075
    mod_r = mod_dia / 2.0
    mod_h = main_h * 0.90
    orbit_r = main_r + mod_r * 0.85
    mod_cz = oz + 0.015 + mod_h / 2.0

    piezas_mods = []
    for i in range(num_mods):
        ang = 2.0 * math.pi * i / num_mods
        mx = ox + orbit_r * math.cos(ang)
        my = oy + orbit_r * math.sin(ang)
        pmod = cilindro(f"neut_mod_{i}", mod_r, mod_h, (mx, my, mod_cz), "mat_blanco", verts=16)
        # Abrazaderas metálicas
        band = cilindro(f"neut_band_{i}", mod_r * 1.04, 0.015, (mx, my, mod_cz), "mat_aluminio", verts=16)
        piezas_mods.extend([pmod, band])

    # Colimador en la cara superior (+Z)
    col_z = oz + 0.015 + main_h
    col_base = cono("neut_colimator_cone", main_r * 0.95, main_r * 0.70, 0.035, (ox, oy, col_z + 0.0175), "mat_aluminio")
    col_aperture = cilindro("neut_col_aperture", main_r * 0.50, 0.005, (ox, oy, col_z + 0.035), "mat_negro", verts=24)

    piezas = [deck, body, col_base, col_aperture] + piezas_mods
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 5. uv (LAMP - LRO)
# Caja de 0.35 x 0.15 x 0.15 con apertura rectangular mat_lente en el extremo.
# -------------------------------------------------------------------------
def build_uv(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("uv")
    r.location = offset

    # Medidas: 0.15 ancho (X) x 0.15 alto (Y) x 0.35 largo (Z hacia nadir)
    w = 0.15
    total_l = 0.35

    # Placa base en Z = 0
    flange = caja("uv_flange", (w + 0.02, w + 0.02, 0.008), (ox, oy, oz + 0.004), "mat_aluminio")

    # Caja del cuerpo en mat_mli_oro
    body_l = total_l - 0.04
    body = caja("uv_body", (w, w, body_l), (ox, oy, oz + 0.008 + body_l / 2.0), "mat_mli_oro", bevel=0.01)

    # Radiador lateral del detector en mat_blanco
    rad = caja("uv_detector_rad", (0.006, w * 0.75, body_l * 0.50), (ox + w / 2.0 + 0.003, oy, oz + 0.12), "mat_blanco")

    # Bafle y parasol frontal en mat_negro
    baffle_z = oz + total_l - 0.02
    baffle = caja("uv_baffle", (w * 0.90, w * 0.90, 0.04), (ox, oy, baffle_z), "mat_negro")

    # Apertura rectangular en el extremo +Z en mat_lente
    optic = caja("uv_optic", (0.09, 0.05, 0.003), (ox, oy, oz + total_l), "mat_lente")

    piezas = [flange, body, rad, baffle, optic]
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 6. rad (CRaTER - LRO)
# Cilindro de 0.15 de diámetro x 0.25 sobre una placa de 0.20 x 0.20, con abertura en el extremo.
# -------------------------------------------------------------------------
def build_rad(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("rad")
    r.location = offset

    cyl_dia = 0.15
    cyl_r = cyl_dia / 2.0  # 0.075m
    cyl_h = 0.24
    plat_w = 0.20

    # Placa de montaje de 0.20 x 0.20 x 0.010
    deck = caja("rad_deck", (plat_w, plat_w, 0.010), (ox, oy, oz + 0.005), "mat_aluminio")

    # Cilindro telescópico principal en mat_mli_oro
    cyl_cz = oz + 0.010 + cyl_h / 2.0
    telescope = cilindro("rad_telescope", cyl_r, cyl_h, (ox, oy, cyl_cz), "mat_mli_oro", verts=24)

    # Anillos de calibración / blindaje en mat_aluminio
    ring1 = cilindro("rad_ring1", cyl_r * 1.03, 0.015, (ox, oy, oz + 0.08), "mat_aluminio", verts=24)
    ring2 = cilindro("rad_ring2", cyl_r * 1.03, 0.015, (ox, oy, oz + 0.16), "mat_aluminio", verts=24)

    # Borde frontal y apertura en el extremo +Z
    top_rim = cilindro("rad_rim", cyl_r * 1.02, 0.010, (ox, oy, oz + 0.010 + cyl_h - 0.005), "mat_negro", verts=24)
    aperture = cilindro("rad_aperture", cyl_r * 0.70, 0.002, (ox, oy, oz + 0.010 + cyl_h), "mat_lente", verts=20)

    piezas = [deck, telescope, ring1, ring2, top_rim, aperture]
    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 7. sar (Radar de apertura sintética)
# Antena plana de 3.0 x 0.70 x 0.06, con mosaico de 8x2 parches en mat_blanco y mat_negro,
# y caja de electrónica de 0.4 x 0.3 x 0.2 detrás (lado del origen).
# Se monta en socket_sar y queda paralela a la cara nadir: el lado largo sigue el eje Z del bus.
# En coordenadas locales de socket_sar: eje Z del bus = eje Y local!
# -------------------------------------------------------------------------
def build_sar(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("sar")
    r.location = offset

    # Medidas: X=0.70m, Y=3.00m (sigue eje Z de la nave), Z=0.06m espesor de la antena plana
    panel_x = 0.70
    panel_y = 3.00
    panel_t = 0.06

    elec_x = 0.40
    elec_y = 0.30
    elec_z = 0.20

    # Caja de electrónica detrás (lado del origen, Z de 0 a 0.20)
    elec_box = caja("sar_electronics", (elec_x, elec_y, elec_z), (ox, oy, oz + elec_z / 2.0), "mat_aluminio")

    # Mástiles / trusses estructurales de separación entre electrónica y panel de antena
    strut_h = 0.04
    strut_z = oz + elec_z + strut_h / 2.0
    st1 = caja("sar_strut1", (0.04, 0.80, strut_h), (ox - 0.15, oy, strut_z), "mat_aluminio")
    st2 = caja("sar_strut2", (0.04, 0.80, strut_h), (ox + 0.15, oy, strut_z), "mat_aluminio")

    # Antena plana (Z de 0.24 a 0.30)
    panel_z = oz + elec_z + strut_h + panel_t / 2.0
    antenna_panel = caja("sar_antenna_panel", (panel_x, panel_y, panel_t), (ox, oy, panel_z), "mat_negro")

    piezas = [elec_box, st1, st2, antenna_panel]

    # Mosaico de 8 x 2 parches radiadores en la cara frontal (+Z)
    cols = 2  # a lo largo de X (0.70m)
    rows = 8  # a lo largo de Y (3.00m)
    margin_x = 0.04
    margin_y = 0.04
    patch_w = (panel_x - (cols + 1) * margin_x) / cols  # ~0.29m
    patch_l = (panel_y - (rows + 1) * margin_y) / rows  # ~0.33m
    patch_z = panel_z + panel_t / 2.0 + 0.001

    for row in range(rows):
        py = oy - panel_y / 2.0 + margin_y + row * (patch_l + margin_y) + patch_l / 2.0
        for col in range(cols):
            px = ox - panel_x / 2.0 + margin_x + col * (patch_w + margin_x) + patch_w / 2.0
            patch = caja(f"sar_patch_{row}_{col}", (patch_w, patch_l, 0.003), (px, py, patch_z), "mat_blanco")
            piezas.append(patch)

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# 8. mag (Magnetómetro fluxgate con mástil desplegable)
# Mástil desplegable de 2.0 m en 3 segmentos de tubo de 2 cm con bisagras,
# un sensor cúbico de 0.08 m en la punta y un segundo sensor más pequeño a 2/3 del mástil.
# Se monta en socket_boom y el mástil crece hacia +Z local.
# -------------------------------------------------------------------------
def build_mag(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("mag")
    r.location = offset

    boom_len = 2.00
    tube_dia = 0.02
    tube_r = tube_dia / 2.0  # 0.01m
    num_segs = 3
    seg_len = boom_len / num_segs  # ~0.667m

    # Base de montaje en el origen
    base = caja("mag_base", (0.06, 0.06, 0.02), (ox, oy, oz + 0.01), "mat_aluminio")
    piezas = [base]

    z_curr = oz + 0.02

    # Segmento 1
    s1 = cilindro("mag_seg_1", tube_r, seg_len, (ox, oy, z_curr + seg_len / 2.0), "mat_aluminio", verts=16)
    z_curr += seg_len
    # Bisagra 1
    h1 = cilindro("mag_hinge_1", 0.018, 0.03, (ox, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
    piezas.extend([s1, h1])

    # Segmento 2
    s2 = cilindro("mag_seg_2", tube_r, seg_len, (ox, oy, z_curr + seg_len / 2.0), "mat_aluminio", verts=16)
    z_curr += seg_len

    # Sensor secundario a 2/3 del mástil (gradiómetro)
    gradio = caja("mag_gradiometer", (0.045, 0.045, 0.045), (ox + 0.035, oy, z_curr), "mat_kapton")
    h2 = cilindro("mag_hinge_2", 0.018, 0.03, (ox, oy, z_curr), "mat_celdas_marco", verts=16, rot=(0.0, math.radians(90), 0.0))
    piezas.extend([s2, gradio, h2])

    # Segmento 3
    s3 = cilindro("mag_seg_3", tube_r, seg_len, (ox, oy, z_curr + seg_len / 2.0), "mat_aluminio", verts=16)
    z_curr += seg_len

    # Sensor cúbico principal de 0.08 m en la punta
    tip_sensor = caja("mag_main_sensor", (0.08, 0.08, 0.08), (ox, oy, z_curr + 0.04), "mat_mli_oro")
    tip_collar = cilindro("mag_tip_collar", 0.022, 0.02, (ox, oy, z_curr), "mat_aluminio", verts=16)
    piezas.extend([s3, tip_sensor, tip_collar])

    emparentar(piezas, r)
    return r


# -------------------------------------------------------------------------
# Ejecutor principal para Prompt 5
# -------------------------------------------------------------------------
def ejecutar_prompt_5():
    print("Iniciando Prompt 5: Modelado de los 8 instrumentos científicos...")

    instrumentos = [
        ("cubecam", build_cubecam),
        ("cam", build_cam),
        ("ir", build_ir),
        ("neut", build_neut),
        ("uv", build_uv),
        ("rad", build_rad),
        ("sar", build_sar),
        ("mag", build_mag),
    ]

    reporte = []

    # PASO 1: Generar, exportar y registrar cada instrumento en su propia escena limpia
    for id_str, builder_func in instrumentos:
        print(f"\n--- Construyendo y exportando instrumento: {id_str} ---")
        limpiar_escena()

        obj_r = builder_func(offset=(0.0, 0.0, 0.0))

        dim = bbox_m(obj_r)
        tris = contar_tris(obj_r)

        glb_path = exportar_glb(obj_r, "instruments", id_str)
        entry = registrar("instruments", id_str, obj_r)
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

    # PASO 2: Construir la escena general para art/blender/instruments.blend
    print("\n--- Generando escena de trabajo art/blender/instruments.blend ---")
    limpiar_escena()

    offsets_x = {
        "cubecam": 0.0,
        "cam": 0.6,
        "ir": 1.6,
        "neut": 2.6,
        "uv": 3.4,
        "rad": 4.1,
        "sar": 5.4,
        "mag": 7.0
    }

    for id_str, builder_func in instrumentos:
        ox = offsets_x[id_str]
        builder_func(offset=(ox, 0.0, 0.0))

    blend_path = os.path.join(ROOT, "art", "blender", "instruments.blend")
    os.makedirs(os.path.dirname(blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Archivo blend guardado exitosamente: {blend_path}")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_5()
