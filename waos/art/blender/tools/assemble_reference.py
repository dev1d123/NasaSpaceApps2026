# -*- coding: utf-8 -*-
"""
assemble_reference.py - Ensambla y verifica las 3 naves de referencia según Prompt 6.
"""

import os
import sys
import math
import bpy
import mathutils

ROOT = r"c:\Users\DCONN\OneDrive\Escritorio\JUEGO\NSAC\NasaSpaceApps2026\waos"
helpers_path = os.path.join(ROOT, "art", "blender", "tools", "waos_helpers.py")
exec(open(helpers_path, encoding="utf-8").read())


def importar_componente(categoria, id_str):
    """Importa un archivo .glb de assets/models/<categoria>/<id>.glb y retorna su objeto raíz."""
    glb_path = os.path.join(ROOT, "assets", "models", categoria, f"{id_str}.glb")
    if not os.path.exists(glb_path):
        raise FileNotFoundError(f"No existe el archivo {glb_path}")

    # Registrar objetos antes de importar para identificar los recién importados
    prev_objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=glb_path)
    new_objs = [o for o in bpy.data.objects if o not in prev_objs]

    # Encontrar el objeto raíz (aquel sin padre o padre None)
    root_candidates = [o for o in new_objs if o.parent is None]
    if not root_candidates:
        raise RuntimeError(f"No se encontró objeto raíz al importar {glb_path}")

    # El candidato preferido es el que coincida con id_str o sea Empty
    root_obj = None
    for cand in root_candidates:
        if cand.name.startswith(id_str):
            root_obj = cand
            break
    if not root_obj:
        root_obj = root_candidates[0]

    return root_obj, new_objs


def buscar_socket(bus_root, socket_name):
    """Busca un socket por nombre dentro de la jerarquía de un bus."""
    desc = _todos_los_descendientes(bus_root)
    for o in desc:
        if o.name == socket_name or o.name.startswith(socket_name + "."):
            return o
    return None


def montar(comp_root, socket_obj, reflejar_x=False):
    """Emparenta comp_root al socket_obj con transformación local identidad (o reflejado si se solicita)."""
    comp_root.parent = socket_obj
    if reflejar_x:
        # Reflejar a lo largo del eje X local
        mat = mathutils.Matrix.Scale(-1.0, 4, mathutils.Vector((1, 0, 0)))
        comp_root.matrix_local = mat
    else:
        comp_root.matrix_local = mathutils.Matrix.Identity(4)


def ensamblar_ref_s1():
    """
    ref_s1: cube6u + pan30 (R y L reflejado) + sband + cubecam + mag
    """
    limpiar_escena()

    # Bus
    bus_root, _ = importar_componente("buses", "cube6u")

    # Sockets
    s_panel_r = buscar_socket(bus_root, "socket_panel_R")
    s_panel_l = buscar_socket(bus_root, "socket_panel_L")
    s_back = buscar_socket(bus_root, "socket_back")
    s_p0 = buscar_socket(bus_root, "socket_payload_0")
    s_boom = buscar_socket(bus_root, "socket_boom")

    # Paneles
    pan_r, _ = importar_componente("panels", "pan30")
    montar(pan_r, s_panel_r, reflejar_x=False)

    pan_l, _ = importar_componente("panels", "pan30")
    montar(pan_l, s_panel_l, reflejar_x=True)

    # Comms
    sband, _ = importar_componente("comms", "sband")
    montar(sband, s_back)

    # Instrumentos
    cubecam, _ = importar_componente("instruments", "cubecam")
    montar(cubecam, s_p0)

    mag, _ = importar_componente("instruments", "mag")
    montar(mag, s_boom)

    return bus_root


def ensamblar_ref_s2():
    """
    ref_s2: leostar2 + pan1500 (x2) + mono_small + xhga + sar + ir
    """
    limpiar_escena()

    # Bus
    bus_root, _ = importar_componente("buses", "leostar2")

    # Sockets
    s_panel_r = buscar_socket(bus_root, "socket_panel_R")
    s_panel_l = buscar_socket(bus_root, "socket_panel_L")
    s_bottom = buscar_socket(bus_root, "socket_bottom")
    s_top = buscar_socket(bus_root, "socket_top")
    s_sar = buscar_socket(bus_root, "socket_sar")
    s_p0 = buscar_socket(bus_root, "socket_payload_0")

    # Paneles
    pan_r, _ = importar_componente("panels", "pan1500")
    montar(pan_r, s_panel_r, reflejar_x=False)

    pan_l, _ = importar_componente("panels", "pan1500")
    montar(pan_l, s_panel_l, reflejar_x=True)

    # Propulsión
    prop, _ = importar_componente("propulsion", "mono_small")
    montar(prop, s_bottom)

    # Comms
    xhga, _ = importar_componente("comms", "xhga")
    montar(xhga, s_top)

    # Instrumentos
    sar, _ = importar_componente("instruments", "sar")
    montar(sar, s_sar)

    ir, _ = importar_componente("instruments", "ir")
    montar(ir, s_p0)

    return bus_root


def ensamblar_ref_s3():
    """
    ref_s3: espa + pan400 (x2) + mono_small + xhga + neut + ir + rad
    """
    limpiar_escena()

    # Bus
    bus_root, _ = importar_componente("buses", "espa")

    # Sockets
    s_panel_r = buscar_socket(bus_root, "socket_panel_R")
    s_panel_l = buscar_socket(bus_root, "socket_panel_L")
    s_bottom = buscar_socket(bus_root, "socket_bottom")
    s_top = buscar_socket(bus_root, "socket_top")
    s_p0 = buscar_socket(bus_root, "socket_payload_0")
    s_p1 = buscar_socket(bus_root, "socket_payload_1")
    s_p2 = buscar_socket(bus_root, "socket_payload_2")

    # Paneles
    pan_r, _ = importar_componente("panels", "pan400")
    montar(pan_r, s_panel_r, reflejar_x=False)

    pan_l, _ = importar_componente("panels", "pan400")
    montar(pan_l, s_panel_l, reflejar_x=True)

    # Propulsión
    prop, _ = importar_componente("propulsion", "mono_small")
    montar(prop, s_bottom)

    # Comms
    xhga, _ = importar_componente("comms", "xhga")
    montar(xhga, s_top)

    # Instrumentos
    neut, _ = importar_componente("instruments", "neut")
    montar(neut, s_p0)

    ir, _ = importar_componente("instruments", "ir")
    montar(ir, s_p1)

    rad, _ = importar_componente("instruments", "rad")
    montar(rad, s_p2)

    return bus_root


def ejecutar_prompt_6_ensambles():
    print("Iniciando Prompt 6: Ensamble de las 3 naves de referencia...")

    ensambles_dir = os.path.join(ROOT, "art", "ensambles")
    os.makedirs(ensambles_dir, exist_ok=True)

    naves = [
        ("ref_s1", ensamblar_ref_s1),
        ("ref_s2", ensamblar_ref_s2),
        ("ref_s3", ensamblar_ref_s3),
    ]

    reporte = []

    for name, assemble_func in naves:
        print(f"\n--- Ensamblando nave: {name} ---")
        bus_root = assemble_func()

        dim = bbox_m(bus_root)
        tris = contar_tris(bus_root)

        # Exportar a art/ensambles/<nombre>.glb
        glb_path = os.path.join(ensambles_dir, f"{name}.glb")

        bpy.ops.object.select_all(action='DESELECT')
        for o in _todos_los_descendientes(bus_root):
            o.select_set(True)
        bpy.context.view_layer.objects.active = bus_root

        bpy.ops.export_scene.gltf(
            filepath=glb_path,
            export_format='GLB',
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_materials='EXPORT',
            export_cameras=False,
            export_lights=False
        )

        # Generar vista previa con Workbench
        prev_path = preview(bus_root, name)

        info = {
            "name": name,
            "bbox_m": dim,
            "tris": tris,
            "glb_path": glb_path,
            "glb_size": os.path.getsize(glb_path),
            "prev_path": prev_path,
            "prev_size": os.path.getsize(prev_path)
        }
        reporte.append(info)
        print(f"[{name}] Tris: {tris}, BBox: {dim}, GLB: {os.path.getsize(glb_path)}B, Prev: {os.path.getsize(prev_path)}B")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_6_ensambles()
