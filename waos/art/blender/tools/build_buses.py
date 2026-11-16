# -*- coding: utf-8 -*-
"""
build_buses.py - Modela los 7 buses según el contrato técnico de PROMPTS_ANTIGRAVITY.md.
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


def agregar_sockets_bus(obj_raiz, dx, dy, dz, es_cube3u=False):
    """Agrega los 11 sockets requeridos por el contrato técnico a cada bus."""
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0

    # socket_panel_L: centro cara -X -> (-hx, 0, 0), apunta -X
    s_p_l = socket("socket_panel_L", (-hx, 0.0, 0.0), (-1.0, 0.0, 0.0))
    # socket_panel_R: centro cara +X -> (+hx, 0, 0), apunta +X
    s_p_r = socket("socket_panel_R", (hx, 0.0, 0.0), (1.0, 0.0, 0.0))
    # socket_top: centro cara +Z -> (0, 0, +hz), apunta +Z
    s_top = socket("socket_top", (0.0, 0.0, hz), (0.0, 0.0, 1.0))
    # socket_bottom: centro cara -Z -> (0, 0, -hz), apunta -Z
    s_bot = socket("socket_bottom", (0.0, 0.0, -hz), (0.0, 0.0, -1.0))
    # socket_back: cara +Y, a 3/4 de la altura (-hz + 0.75*dz = 0.25*dz), apunta +Y
    s_back = socket("socket_back", (0.0, hy, 0.25 * dz), (0.0, 1.0, 0.0))
    # socket_sar: centro cara -Y -> (0, -hy, 0), apunta -Y
    s_sar = socket("socket_sar", (0.0, -hy, 0.0), (0.0, -1.0, 0.0))
    # socket_boom: arista inferior entre -X y -Y, apunta -X inclinado 30° hacia -Z
    vx = -math.cos(math.radians(30))
    vz = -math.sin(math.radians(30))
    s_boom = socket("socket_boom", (-hx, -hy, -hz), (vx, 0.0, vz))

    # Payloads en la cara -Y en fila horizontal
    if es_cube3u:
        p_x = [-0.035, -0.015, 0.015, 0.035]
    else:
        span = dx * 0.70
        step = span / 3.0
        p_x = [-span / 2.0 + i * step for i in range(4)]

    s_p0 = socket("socket_payload_0", (p_x[0], -hy, 0.0), (0.0, -1.0, 0.0))
    s_p1 = socket("socket_payload_1", (p_x[1], -hy, 0.0), (0.0, -1.0, 0.0))
    s_p2 = socket("socket_payload_2", (p_x[2], -hy, 0.0), (0.0, -1.0, 0.0))
    s_p3 = socket("socket_payload_3", (p_x[3], -hy, 0.0), (0.0, -1.0, 0.0))

    all_sockets = [s_p_l, s_p_r, s_top, s_bot, s_back, s_sar, s_boom, s_p0, s_p1, s_p2, s_p3]
    emparentar(all_sockets, obj_raiz)
    return all_sockets


# -------------------------------------------------------------------------
# Bus 1: cube3u (0.100 x 0.100 x 0.340)
# -------------------------------------------------------------------------
def build_cube3u(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("cube3u")
    r.location = offset
    dx, dy, dz = 0.100, 0.100, 0.340
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0
    h_so = 0.007
    body_z = dz - 2 * h_so  # 0.326m

    chasis = caja("cube3u_chasis", (dx - 0.005, dy - 0.005, body_z), (ox, oy, oz), "mat_negro")

    rw = 0.0085
    r_offset_x = hx - rw / 2.0
    r_offset_y = hy - rw / 2.0

    piezas = [chasis]
    corners = [
        (-r_offset_x, -r_offset_y),
        (r_offset_x, -r_offset_y),
        (-r_offset_x, r_offset_y),
        (r_offset_x, r_offset_y)
    ]

    for idx, (cx, cy) in enumerate(corners):
        rail = caja(f"cube3u_rail_{idx}", (rw, rw, body_z), (ox + cx, oy + cy, oz), "mat_aluminio")
        so_top = caja(f"cube3u_so_top_{idx}", (0.006, 0.006, h_so), (ox + cx, oy + cy, oz + hz - h_so / 2.0), "mat_aluminio")
        so_bot = caja(f"cube3u_so_bot_{idx}", (0.006, 0.006, h_so), (ox + cx, oy + cy, oz - hz + h_so / 2.0), "mat_aluminio")
        piezas.extend([rail, so_top, so_bot])

    pcb_x_p = caja("cube3u_pcb_xp", (0.001, dy * 0.70, body_z * 0.85), (ox + hx - 0.002, oy, oz), "mat_celdas_marco")
    pcb_x_n = caja("cube3u_pcb_xn", (0.001, dy * 0.70, body_z * 0.85), (ox - hx + 0.002, oy, oz), "mat_celdas_marco")
    pcb_y_p = caja("cube3u_pcb_yp", (dx * 0.70, 0.001, body_z * 0.85), (ox, oy + hy - 0.002, oz), "mat_kapton")
    pcb_y_n = caja("cube3u_pcb_yn", (dx * 0.70, 0.001, body_z * 0.85), (ox, oy - hy + 0.002, oz), "mat_celdas_marco")
    piezas.extend([pcb_x_p, pcb_x_n, pcb_y_p, pcb_y_n])

    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=True)
    return r


# -------------------------------------------------------------------------
# Bus 2: cube6u (0.226 x 0.100 x 0.366)
# -------------------------------------------------------------------------
def build_cube6u(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("cube6u")
    r.location = offset
    dx, dy, dz = 0.226, 0.100, 0.366
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0
    h_so = 0.007
    body_z = dz - 2 * h_so

    chasis = caja("cube6u_chasis", (dx - 0.005, dy - 0.005, body_z), (ox, oy, oz), "mat_negro")

    center_rib_top = caja("cube6u_div_top", (0.010, dy, 0.008), (ox, oy, oz + hz - h_so - 0.004), "mat_aluminio")
    center_rib_bot = caja("cube6u_div_bot", (0.010, dy, 0.008), (ox, oy, oz - hz + h_so + 0.004), "mat_aluminio")
    center_rib_front = caja("cube6u_div_front", (0.008, 0.004, body_z), (ox, oy - hy + 0.002, oz), "mat_aluminio")
    center_rib_back = caja("cube6u_div_back", (0.008, 0.004, body_z), (ox, oy + hy - 0.002, oz), "mat_aluminio")

    rw = 0.0085
    r_offset_x = hx - rw / 2.0
    r_offset_y = hy - rw / 2.0

    piezas = [chasis, center_rib_top, center_rib_bot, center_rib_front, center_rib_back]
    corners = [
        (-r_offset_x, -r_offset_y),
        (r_offset_x, -r_offset_y),
        (-r_offset_x, r_offset_y),
        (r_offset_x, r_offset_y)
    ]

    for idx, (cx, cy) in enumerate(corners):
        rail = caja(f"cube6u_rail_{idx}", (rw, rw, body_z), (ox + cx, oy + cy, oz), "mat_aluminio")
        so_top = caja(f"cube6u_so_top_{idx}", (0.006, 0.006, h_so), (ox + cx, oy + cy, oz + hz - h_so / 2.0), "mat_aluminio")
        so_bot = caja(f"cube6u_so_bot_{idx}", (0.006, 0.006, h_so), (ox + cx, oy + cy, oz - hz + h_so / 2.0), "mat_aluminio")
        piezas.extend([rail, so_top, so_bot])

    for c_idx, c_x in enumerate([-hx / 2.0, hx / 2.0]):
        pcb_f = caja(f"cube6u_pcb_f_{c_idx}", (0.080, 0.001, body_z * 0.85), (ox + c_x, oy - hy + 0.002, oz), "mat_celdas_marco")
        pcb_b = caja(f"cube6u_pcb_b_{c_idx}", (0.080, 0.001, body_z * 0.85), (ox + c_x, oy + hy - 0.002, oz), "mat_kapton")
        piezas.extend([pcb_f, pcb_b])

    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=False)
    return r


# -------------------------------------------------------------------------
# Bus 3: cube12u (0.226 x 0.226 x 0.366)
# -------------------------------------------------------------------------
def build_cube12u(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("cube12u")
    r.location = offset
    dx, dy, dz = 0.226, 0.226, 0.366
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0
    h_so = 0.007
    body_z = dz - 2 * h_so

    chasis = caja("cube12u_chasis", (dx - 0.005, dy - 0.005, body_z), (ox, oy, oz), "mat_negro")

    cross_x = caja("cube12u_cross_x", (0.008, dy, body_z), (ox, oy, oz), "mat_aluminio")
    cross_y = caja("cube12u_cross_y", (dx, 0.008, body_z), (ox, oy, oz), "mat_aluminio")

    rw = 0.0085
    r_offset_x = hx - rw / 2.0
    r_offset_y = hy - rw / 2.0

    piezas = [chasis, cross_x, cross_y]
    corners = [
        (-r_offset_x, -r_offset_y),
        (r_offset_x, -r_offset_y),
        (-r_offset_x, r_offset_y),
        (r_offset_x, r_offset_y)
    ]

    for idx, (cx, cy) in enumerate(corners):
        rail = caja(f"cube12u_rail_{idx}", (rw, rw, body_z), (ox + cx, oy + cy, oz), "mat_aluminio")
        so_top = caja(f"cube12u_so_top_{idx}", (0.006, 0.006, h_so), (ox + cx, oy + cy, oz + hz - h_so / 2.0), "mat_aluminio")
        so_bot = caja(f"cube12u_so_bot_{idx}", (0.006, 0.006, h_so), (ox + cx, oy + cy, oz - hz + h_so / 2.0), "mat_aluminio")
        piezas.extend([rail, so_top, so_bot])

    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=False)
    return r


# -------------------------------------------------------------------------
# Bus 4: espa (0.60 x 0.60 x 0.80)
# -------------------------------------------------------------------------
def build_espa(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("espa")
    r.location = offset
    dx, dy, dz = 0.60, 0.60, 0.80
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0

    ring_h = 0.05
    frame_h = 0.015
    body_h = dz - ring_h - frame_h  # 0.735m
    body_center_z = oz - hz + ring_h + body_h / 2.0

    body = caja("espa_body", (dx - 0.02, dy - 0.02, body_h), (ox, oy, body_center_z), "mat_mli_oro", bevel=0.01)

    ring_z = oz - hz + ring_h / 2.0
    ring_outer = cilindro("espa_ring_outer", 0.38 / 2.0, ring_h, (ox, oy, ring_z), "mat_aluminio", verts=32)
    ring_flange = cilindro("espa_ring_flange", 0.32 / 2.0, ring_h * 0.8, (ox, oy, ring_z), "mat_negro", verts=24)

    rad_w = dx * 0.80
    rad_h = body_h * 0.80
    radiador = caja("espa_radiador", (rad_w, 0.010, rad_h), (ox, oy + hy - 0.005, body_center_z), "mat_blanco")

    rad_panel1 = caja("espa_rad_p1", (rad_w * 0.40, 0.002, rad_h * 0.85), (ox - rad_w * 0.22, oy + hy - 0.002, body_center_z), "mat_mli_plata")
    rad_panel2 = caja("espa_rad_p2", (rad_w * 0.40, 0.002, rad_h * 0.85), (ox + rad_w * 0.22, oy + hy - 0.002, body_center_z), "mat_mli_plata")

    frame_top = caja("espa_frame_top", (dx, dy, frame_h), (ox, oy, oz + hz - frame_h / 2.0), "mat_aluminio")
    frame_bot = caja("espa_frame_bot", (dx, dy, frame_h), (ox, oy, oz - hz + ring_h + frame_h / 2.0), "mat_aluminio")

    piezas = [body, ring_outer, ring_flange, radiador, rad_panel1, rad_panel2, frame_top, frame_bot]
    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=False)
    return r


# -------------------------------------------------------------------------
# Bus 5: leostar2 (1.00 x 1.00 x 1.50)
# -------------------------------------------------------------------------
def build_leostar2(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("leostar2")
    r.location = offset
    dx, dy, dz = 1.00, 1.00, 1.50
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0

    adapter_h = 0.12
    top_h = 0.02
    body_h = dz - adapter_h - top_h  # 1.36m
    body_center_z = oz - hz + adapter_h + body_h / 2.0

    # Para un octágono rotado 22.5°, las 4 caras principales quedan alineadas con ±X y ±Y.
    # Distancia desde el origen a las caras planas: R * cos(22.5°).
    # Con R = 0.50 / cos(22.5°), el ancho entre caras planas es exactamente 1.00m.
    r_oct = 0.50 / math.cos(math.radians(22.5))  # ~0.5412m
    oct_rot = (0.0, 0.0, math.radians(22.5))
    body = cilindro("leostar2_body", r_oct, body_h, (ox, oy, body_center_z), "mat_mli_oro", verts=8, rot=oct_rot)

    top_deck = cilindro("leostar2_top", r_oct * 0.98, top_h, (ox, oy, oz + hz - top_h / 2.0), "mat_aluminio", verts=8, rot=oct_rot)

    adap_z = oz - hz + adapter_h / 2.0
    adapter = cono("leostar2_adapter", 0.72 / 2.0, 0.60 / 2.0, adapter_h, (ox, oy, adap_z), "mat_aluminio")

    # Radiadores blancos adosados a las caras planas (llegando a ±0.50m)
    rad_thickness = 0.012
    rad_y = caja("leostar2_rad_y", (0.46, rad_thickness, body_h * 0.75), (ox, oy + hy - rad_thickness / 2.0, body_center_z), "mat_blanco")
    rad_xp = caja("leostar2_rad_xp", (rad_thickness, 0.46, body_h * 0.75), (ox + hx - rad_thickness / 2.0, oy, body_center_z), "mat_blanco")
    rad_xn = caja("leostar2_rad_xn", (rad_thickness, 0.46, body_h * 0.75), (ox - hx + rad_thickness / 2.0, oy, body_center_z), "mat_blanco")

    louver_y = caja("leostar2_louver_y", (0.38, 0.003, body_h * 0.65), (ox, oy + hy - 0.003, body_center_z), "mat_mli_plata")

    piezas = [body, top_deck, adapter, rad_y, rad_xp, rad_xn, louver_y]
    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=False)
    return r


# -------------------------------------------------------------------------
# Bus 6: leostar3 (1.90 x 1.90 x 3.00)
# -------------------------------------------------------------------------
def build_leostar3(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("leostar3")
    r.location = offset
    dx, dy, dz = 1.90, 1.90, 3.00
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0

    adapter_h = 0.22
    body_h = dz - adapter_h  # 2.78m
    body_center_z = oz - hz + adapter_h + body_h / 2.0

    body = caja("leostar3_body", (dx - 0.04, dy - 0.04, body_h), (ox, oy, body_center_z), "mat_mli_oro", bevel=0.02)

    panel_xp = caja("leostar3_silver_xp", (0.020, dy * 0.75, body_h * 0.60), (ox + hx - 0.010, oy, body_center_z), "mat_mli_plata")
    panel_xn = caja("leostar3_silver_xn", (0.020, dy * 0.75, body_h * 0.60), (ox - hx + 0.010, oy, body_center_z), "mat_mli_plata")

    rad_main = caja("leostar3_rad", (dx * 0.80, 0.020, body_h * 0.75), (ox, oy + hy - 0.010, body_center_z), "mat_blanco")
    rad_louver1 = caja("leostar3_louver1", (dx * 0.35, 0.004, body_h * 0.65), (ox - dx * 0.20, oy + hy - 0.003, body_center_z), "mat_mli_plata")
    rad_louver2 = caja("leostar3_louver2", (dx * 0.35, 0.004, body_h * 0.65), (ox + dx * 0.20, oy + hy - 0.003, body_center_z), "mat_mli_plata")

    bench_w = dx * 0.85
    bench_h = 0.12
    bench_depth = 0.08
    bench_z = oz  # Cara -Y
    shelf = caja("leostar3_inst_shelf", (bench_w, bench_depth, bench_h), (ox, oy - hy + bench_depth / 2.0, bench_z), "mat_aluminio")
    shelf_top = caja("leostar3_inst_plate", (bench_w * 0.95, bench_depth * 0.95, 0.015), (ox, oy - hy + bench_depth / 2.0, bench_z + bench_h / 2.0), "mat_negro")

    adap_z = oz - hz + adapter_h / 2.0
    adapter = cono("leostar3_adapter", 1.25 / 2.0, 1.10 / 2.0, adapter_h, (ox, oy, adap_z), "mat_aluminio")

    piezas = [body, panel_xp, panel_xn, rad_main, rad_louver1, rad_louver2, shelf, shelf_top, adapter]
    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=False)
    return r


# -------------------------------------------------------------------------
# Bus 7: deep (1.60 x 1.60 x 2.40)
# -------------------------------------------------------------------------
def build_deep(offset=(0.0, 0.0, 0.0)):
    ox, oy, oz = offset
    r = raiz("deep")
    r.location = offset
    dx, dy, dz = 1.60, 1.60, 2.40
    hx, hy, hz = dx / 2.0, dy / 2.0, dz / 2.0

    adap_h = 0.15
    prop_h = 0.85
    avionics_h = dz - adap_h - prop_h  # 1.40m

    adap_z = oz - hz + adap_h / 2.0
    adapter = cilindro("deep_adapter", 0.95 / 2.0, adap_h, (ox, oy, adap_z), "mat_aluminio", verts=32)

    prop_z = oz - hz + adap_h + prop_h / 2.0
    prop_mod = caja("deep_prop_module", (dx, dy, prop_h), (ox, oy, prop_z), "mat_mli_oro", bevel=0.03)

    prop_rad_xp = caja("deep_prop_rad_xp", (0.015, dy * 0.70, prop_h * 0.75), (ox + hx - 0.0075, oy, prop_z), "mat_blanco")
    prop_rad_xn = caja("deep_prop_rad_xn", (0.015, dy * 0.70, prop_h * 0.75), (ox - hx + 0.0075, oy, prop_z), "mat_blanco")

    av_w = 1.26
    av_z = oz + hz - avionics_h / 2.0
    av_mod = caja("deep_avionics_mod", (av_w, av_w, avionics_h), (ox, oy, av_z), "mat_mli_oro", bevel=0.02)

    av_silver_yp = caja("deep_av_silver_yp", (av_w * 0.80, 0.01, avionics_h * 0.75), (ox, oy + av_w / 2.0 - 0.005, av_z), "mat_mli_plata")
    av_silver_yn = caja("deep_av_silver_yn", (av_w * 0.80, 0.01, avionics_h * 0.75), (ox, oy - av_w / 2.0 + 0.005, av_z), "mat_mli_plata")

    transition = caja("deep_transition", (dx * 0.95, dy * 0.95, 0.03), (ox, oy, prop_z + prop_h / 2.0), "mat_aluminio")

    piezas = [adapter, prop_mod, prop_rad_xp, prop_rad_xn, av_mod, av_silver_yp, av_silver_yn, transition]
    emparentar(piezas, r)
    agregar_sockets_bus(r, dx, dy, dz, es_cube3u=False)
    return r


# -------------------------------------------------------------------------
# Ejecutor principal para Prompt 1
# -------------------------------------------------------------------------
def ejecutar_prompt_1():
    print("Iniciando Prompt 1: Modelado de los 7 buses...")

    buses = [
        ("cube3u", build_cube3u),
        ("cube6u", build_cube6u),
        ("cube12u", build_cube12u),
        ("espa", build_espa),
        ("leostar2", build_leostar2),
        ("leostar3", build_leostar3),
        ("deep", build_deep),
    ]

    reporte = []

    # PASO 1: Generar, exportar y registrar cada bus en su propia escena limpia.
    # Esto garantiza nombres de sockets exactos (sin .001) y origen en (0, 0, 0).
    for id_str, builder_func in buses:
        print(f"\n--- Construyendo y exportando bus: {id_str} ---")
        limpiar_escena()

        obj_r = builder_func(offset=(0.0, 0.0, 0.0))

        # Medir dimensiones y triángulos
        dim = bbox_m(obj_r)
        tris = contar_tris(obj_r)

        # Exportar a GLB individual
        glb_path = exportar_glb(obj_r, "buses", id_str)
        # Registrar en manifest.json
        entry = registrar("buses", id_str, obj_r)
        # Generar vista previa Workbench 512x512
        prev_path = preview(obj_r, id_str)

        info = {
            "id": id_str,
            "bbox_m": dim,
            "tris": tris,
            "sockets_count": len(entry["sockets"]),
            "sockets": entry["sockets"],
            "glb_path": glb_path,
            "glb_size": os.path.getsize(glb_path),
            "prev_path": prev_path,
            "prev_size": os.path.getsize(prev_path)
        }
        reporte.append(info)
        print(f"[{id_str}] Tris: {tris}, BBox: {dim}, Sockets: {len(entry['sockets'])}, GLB: {os.path.getsize(glb_path)}B, Preview: {os.path.getsize(prev_path)}B")

    # PASO 2: Construir la escena general para art/blender/buses.blend con todos los buses organizados
    print("\n--- Generando escena de trabajo art/blender/buses.blend ---")
    limpiar_escena()

    # Distribuir los 7 buses a lo largo del eje X para que puedan apreciarse juntos en Blender
    offsets_x = {
        "cube3u": 0.0,
        "cube6u": 0.6,
        "cube12u": 1.4,
        "espa": 2.5,
        "leostar2": 4.2,
        "leostar3": 7.0,
        "deep": 10.5
    }

    for id_str, builder_func in buses:
        ox = offsets_x[id_str]
        builder_func(offset=(ox, 0.0, 0.0))

    blend_path = os.path.join(ROOT, "art", "blender", "buses.blend")
    os.makedirs(os.path.dirname(blend_path), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Archivo blend guardado exitosamente: {blend_path}")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_1()
