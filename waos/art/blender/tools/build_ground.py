# -*- coding: utf-8 -*-
"""
build_ground.py - Modela las 3 estaciones terrenas para WAOS según Prompt 7:
- dsn70: antena de 70 m en montura az/el, estilo DSN, con pedestal
- nsn11: plato de 11 m con pedestal
- yagi_uni: antena Yagi cruzada de 3 m sobre mástil en techo pequeño

Unidades: 1 unidad = 1 metro.
Z hacia arriba, origen en la base sobre el suelo (Z=0).
Límite de triángulos: hasta 5 000 por estación.
Materiales: solo Principled BSDF de la paleta estándar.
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


def modelar_dsn70():
    """
    dsn70: Antena de 70 metros de diámetro en montura azimut-elevación estilo DSN.
    Origen: Z=0 en la base sobre el suelo.
    """
    id_str = "dsn70"
    r = raiz(id_str)

    # 1. Base / Pedestal de hormigón
    # Plataforma inferior escalonada
    terrace = cilindro(f"{id_str}_terrace", radio=20.0, alto=1.5, pos=(0, 0, 0.75), mat="mat_blanco", verts=32)
    emparentar(terrace, r)

    # Torre cilíndrica principal (pedestal)
    pedestal = cilindro(f"{id_str}_pedestal", radio=16.0, alto=12.5, pos=(0, 0, 1.5 + 6.25), mat="mat_blanco", verts=32)
    emparentar(pedestal, r)

    # Anillo superior de hormigón / corona
    ring_top = cilindro(f"{id_str}_ring_top", radio=17.0, alto=1.0, pos=(0, 0, 14.5), mat="mat_aluminio", verts=32)
    emparentar(ring_top, r)

    # 8 columnas de refuerzo perimetrales en el pedestal
    for i in range(8):
        ang = i * (2.0 * math.pi / 8)
        px = 16.0 * math.cos(ang)
        py = 16.0 * math.sin(ang)
        col = caja(f"{id_str}_buttress_{i}", (2.0, 1.5, 12.0), (px, py, 7.5), "mat_blanco")
        col.rotation_euler = (0, 0, ang)
        emparentar(col, r)

    # 2. Mesa giratoria azimut (turntable)
    turntable = cilindro(f"{id_str}_turntable", radio=14.0, alto=1.2, pos=(0, 0, 15.6), mat="mat_negro", verts=32)
    emparentar(turntable, r)

    # 3. Alidada / Montura de elevación (horquilla con dos torres laterales en +/- X)
    # Altura del eje de elevación: Z = 32.0 m
    elev_z = 32.0
    tower_h = elev_z - 16.2

    for sign_x, name_x in [(-1, "L"), (1, "R")]:
        tx = sign_x * 10.0
        # Torre de soporte de muñón
        tower = caja(f"{id_str}_yoke_{name_x}", (4.0, 6.0, tower_h), (tx, 0, 16.2 + tower_h / 2.0), "mat_blanco", bevel=0.2)
        emparentar(tower, r)

        # Chumacera / rodamiento de elevación cilíndrico en el extremo
        bearing = cilindro(f"{id_str}_bearing_{name_x}", radio=2.2, alto=2.0, pos=(sign_x * 11.5, 0, elev_z), mat="mat_aluminio", verts=16, rot=(0, math.pi / 2.0, 0))
        emparentar(bearing, r)

    # Barra transversal inferior de la horquilla
    cross_beam = caja(f"{id_str}_yoke_cross", (20.0, 4.0, 2.5), (0, 0, 17.5), "mat_aluminio")
    emparentar(cross_beam, r)

    # Contrapeso y engranaje de elevación (bull gear)
    bull_gear = cilindro(f"{id_str}_gear", radio=6.0, alto=1.5, pos=(0, 2.5, elev_z - 3.0), mat="mat_negro", verts=24, rot=(0, math.pi / 2.0, 0))
    emparentar(bull_gear, r)

    # 4. Plato parabólico de 70 m
    # Inclinamos el plato 20° respecto a vertical (+Z) hacia -Y para dar la silueta icónica de antena rastreando
    dish_tilt = math.radians(20.0)  # rotación en X
    dish_center = (0, 0, elev_z)

    # Usamos plato parabólico de 70 m de diámetro y 8 m de profundidad
    dish = plato(f"{id_str}_reflector", diametro=70.0, profundidad=8.0, pos=(0, 0, 0), mat="mat_blanco")
    dish.parent = r
    dish.location = dish_center
    dish.rotation_euler = (dish_tilt, 0, 0)

    # Cono de alimentación central en el plato
    feed_cone = cilindro(f"{id_str}_feedcone", radio=3.0, alto=5.0, pos=(0, 0, 2.5), mat="mat_blanco", verts=16)
    feed_cone.parent = dish

    # Anillo de borde del reflector
    rim = cilindro(f"{id_str}_rim", radio=35.2, alto=0.8, pos=(0, 0, 8.0), mat="mat_aluminio", verts=36)
    rim.parent = dish

    # Cercha trasera de soporte (truss structure detrás del plato)
    hub_back = cilindro(f"{id_str}_hub_back", radio=6.0, alto=4.0, pos=(0, 0, -2.5), mat="mat_aluminio", verts=20)
    hub_back.parent = dish

    # 12 vigas radiales de celosía detrás del plato
    for i in range(12):
        ang = i * (2.0 * math.pi / 12)
        rx = 18.0 * math.cos(ang)
        ry = 18.0 * math.sin(ang)
        viga = caja(f"{id_str}_truss_rad_{i}", (0.8, 30.0, 0.8), (rx, ry, 2.0), "mat_aluminio")
        viga.parent = dish
        viga.rotation_euler = (0, 0, ang + math.pi / 2.0)

    # 5. Cuadripípode (4 puntales) y Subreflector hiperbólico
    focal_h = 20.0  # Altura del subreflector sobre el vértice
    subref = plato(f"{id_str}_subreflector", diametro=7.0, profundidad=1.2, pos=(0, 0, focal_h), mat="mat_blanco")
    subref.parent = dish
    subref.rotation_euler = (math.pi, 0, 0)

    # Cuatro patas de soporte hacia el subreflector
    strut_r = 20.0
    for i, ang_deg in enumerate([45, 135, 225, 315]):
        ang = math.radians(ang_deg)
        sx = strut_r * math.cos(ang)
        sy = strut_r * math.sin(ang)
        sz = 3.5

        p1 = mathutils.Vector((sx, sy, sz))
        p2 = mathutils.Vector((0, 0, focal_h - 0.5))
        vec = p2 - p1
        mid = (p1 + p2) / 2.0

        strut = cilindro(f"{id_str}_strut_{i}", radio=0.45, alto=vec.length, pos=(0, 0, 0), mat="mat_aluminio", verts=10)
        strut.parent = dish
        strut.location = mid
        rot_q = vec.normalized().to_track_quat('Z', 'Y')
        strut.rotation_euler = rot_q.to_euler()

    return r


def modelar_nsn11():
    """
    nsn11: Plato de 11 m de diámetro con pedestal para Near Space Network.
    Origen: Z=0 en la base sobre el suelo.
    """
    id_str = "nsn11"
    r = raiz(id_str)

    # 1. Base / Losa octogonal de hormigón
    pad = cilindro(f"{id_str}_pad", radio=4.0, alto=0.4, pos=(0, 0, 0.2), mat="mat_blanco", verts=16)
    emparentar(pad, r)

    # 2. Pedestal central tubular
    pedestal_h = 4.2
    pedestal = cilindro(f"{id_str}_pedestal", radio=1.3, alto=pedestal_h, pos=(0, 0, 0.4 + pedestal_h / 2.0), mat="mat_blanco", verts=20)
    emparentar(pedestal, r)

    # Cuello superior y brida
    flange = cilindro(f"{id_str}_flange", radio=1.5, alto=0.3, pos=(0, 0, 0.4 + pedestal_h), mat="mat_aluminio", verts=20)
    emparentar(flange, r)

    # Plataforma de mantenimiento circular
    platform = cilindro(f"{id_str}_platform", radio=2.2, alto=0.1, pos=(0, 0, 3.8), mat="mat_aluminio", verts=20)
    emparentar(platform, r)
    # Barandilla
    rail = cilindro(f"{id_str}_rail", radio=2.2, alto=0.8, pos=(0, 0, 4.2), mat="mat_aluminio", verts=16)
    emparentar(rail, r)

    # Escalera de acceso
    ladder_rail_1 = cilindro(f"{id_str}_lad_r1", radio=0.03, alto=pedestal_h, pos=(-0.2, -1.4, 0.4 + pedestal_h / 2.0), mat="mat_aluminio", verts=6)
    ladder_rail_2 = cilindro(f"{id_str}_lad_r2", radio=0.03, alto=pedestal_h, pos=(0.2, -1.4, 0.4 + pedestal_h / 2.0), mat="mat_aluminio", verts=6)
    emparentar(ladder_rail_1, r)
    emparentar(ladder_rail_2, r)
    for step_i in range(8):
        sz = 0.6 + step_i * 0.45
        rung = caja(f"{id_str}_rung_{step_i}", (0.4, 0.04, 0.03), (0, -1.4, sz), "mat_aluminio")
        emparentar(rung, r)

    # 3. Cabezal Az/El posicionador
    az_head = caja(f"{id_str}_az_head", (1.6, 1.6, 1.2), (0, 0, 5.3), "mat_aluminio", bevel=0.05)
    emparentar(az_head, r)

    elev_z = 6.2
    # Muñones laterales
    for sign_x, name_x in [(-1, "L"), (1, "R")]:
        yoke_arm = caja(f"{id_str}_arm_{name_x}", (0.4, 1.2, 1.4), (sign_x * 0.9, 0, 5.9), "mat_aluminio")
        emparentar(yoke_arm, r)
        bearing = cilindro(f"{id_str}_bear_{name_x}", radio=0.35, alto=0.4, pos=(sign_x * 1.15, 0, elev_z), mat="mat_negro", verts=12, rot=(0, math.pi / 2.0, 0))
        emparentar(bearing, r)

    # 4. Plato parabólico de 11 m
    # Inclinado a 25° respecto a vertical hacia -Y
    dish_tilt = math.radians(25.0)
    dish_center = (0, 0, elev_z)

    dish = plato(f"{id_str}_reflector", diametro=11.0, profundidad=1.5, pos=(0, 0, 0), mat="mat_blanco")
    dish.parent = r
    dish.location = dish_center
    dish.rotation_euler = (dish_tilt, 0, 0)

    # Borde exterior del plato
    rim = cilindro(f"{id_str}_rim", radio=5.55, alto=0.15, pos=(0, 0, 1.5), mat="mat_aluminio", verts=32)
    rim.parent = dish

    # Cubo central y cercha trasera
    hub_back = cilindro(f"{id_str}_hub", radio=1.2, alto=1.0, pos=(0, 0, -0.6), mat="mat_aluminio", verts=16)
    hub_back.parent = dish

    # 8 radios estructurales de refuerzo posterior
    for i in range(8):
        ang = i * (2.0 * math.pi / 8)
        rx = 3.0 * math.cos(ang)
        ry = 3.0 * math.sin(ang)
        viga = caja(f"{id_str}_rib_{i}", (0.15, 4.8, 0.2), (rx, ry, 0.4), "mat_aluminio")
        viga.parent = dish
        viga.rotation_euler = (0, 0, ang + math.pi / 2.0)

    # 5. Alimentador central (trípode)
    focal_h = 4.0
    feedhorn = cilindro(f"{id_str}_feedhorn", radio=0.4, alto=0.6, pos=(0, 0, focal_h), mat="mat_cobre", verts=12)
    feedhorn.parent = dish

    # 3 puntales hacia el foco
    tripod_r = 3.8
    for i in range(3):
        ang = i * (2.0 * math.pi / 3) + math.pi / 6.0
        sx = tripod_r * math.cos(ang)
        sy = tripod_r * math.sin(ang)
        sz = 0.6

        p1 = mathutils.Vector((sx, sy, sz))
        p2 = mathutils.Vector((0, 0, focal_h))
        vec = p2 - p1
        mid = (p1 + p2) / 2.0

        strut = cilindro(f"{id_str}_strut_{i}", radio=0.06, alto=vec.length, pos=(0, 0, 0), mat="mat_aluminio", verts=8)
        strut.parent = dish
        strut.location = mid
        rot_q = vec.normalized().to_track_quat('Z', 'Y')
        strut.rotation_euler = rot_q.to_euler()

    return r


def modelar_yagi_uni():
    """
    yagi_uni: Antena Yagi cruzada de 3 m sobre mástil en un techo pequeño (estación universitaria).
    Origen: Z=0 en la base sobre el suelo.
    """
    id_str = "yagi_uni"
    r = raiz(id_str)

    # 1. Caseta / Refugio de equipos universitarios en el tejado
    shack_w = 3.2
    shack_l = 3.2
    shack_h = 2.4

    shack = caja(f"{id_str}_shack", (shack_w, shack_l, shack_h), (0, 0, shack_h / 2.0), "mat_blanco", bevel=0.05)
    emparentar(shack, r)

    # Pretil del techo (parapet)
    parapet_l = caja(f"{id_str}_para_L", (0.15, shack_l, 0.25), (-shack_w / 2.0 + 0.075, 0, shack_h + 0.125), "mat_aluminio")
    parapet_r = caja(f"{id_str}_para_R", (0.15, shack_l, 0.25), (shack_w / 2.0 - 0.075, 0, shack_h + 0.125), "mat_aluminio")
    parapet_f = caja(f"{id_str}_para_F", (shack_w, 0.15, 0.25), (0, -shack_l / 2.0 + 0.075, shack_h + 0.125), "mat_aluminio")
    parapet_b = caja(f"{id_str}_para_B", (shack_w, 0.15, 0.25), (0, shack_l / 2.0 - 0.075, shack_h + 0.125), "mat_aluminio")
    for p in [parapet_l, parapet_r, parapet_f, parapet_b]:
        emparentar(p, r)

    # Puerta en cara frontal (-Y)
    door = caja(f"{id_str}_door", (0.9, 0.05, 1.9), (0.6, -shack_l / 2.0 - 0.025, 0.95), "mat_negro")
    emparentar(door, r)

    # Unidad de aire acondicionado / ventilación en pared lateral
    ac_unit = caja(f"{id_str}_ac", (0.4, 0.8, 0.6), (-shack_w / 2.0 - 0.2, 0.4, 1.4), "mat_aluminio")
    emparentar(ac_unit, r)

    # 2. Base de montaje y trípode de tejado
    roof_z = shack_h
    base_plate = caja(f"{id_str}_base_plate", (0.8, 0.8, 0.06), (0, 0, roof_z + 0.03), "mat_aluminio")
    emparentar(base_plate, r)

    # Puntales del trípode del mástil
    for i in range(3):
        ang = i * (2.0 * math.pi / 3)
        px = 0.5 * math.cos(ang)
        py = 0.5 * math.sin(ang)
        p1 = mathutils.Vector((px, py, roof_z + 0.04))
        p2 = mathutils.Vector((0, 0, roof_z + 0.7))
        vec = p2 - p1
        leg = cilindro(f"{id_str}_tripod_{i}", radio=0.025, alto=vec.length, pos=(0, 0, 0), mat="mat_aluminio", verts=6)
        leg.location = (p1 + p2) / 2.0
        leg.rotation_euler = vec.normalized().to_track_quat('Z', 'Y').to_euler()
        emparentar(leg, r)

    # 3. Mástil vertical
    mast_h = 3.2
    mast = cilindro(f"{id_str}_mast", radio=0.04, alto=mast_h, pos=(0, 0, roof_z + mast_h / 2.0), mat="mat_aluminio", verts=10)
    emparentar(mast, r)

    rotator_z = roof_z + mast_h  # Z = 2.4 + 3.2 = 5.6 m

    # 4. Rotor de azimut y elevación (Az/El Rotator)
    rotator_body = caja(f"{id_str}_rotator", (0.24, 0.24, 0.35), (0, 0, rotator_z), "mat_negro", bevel=0.02)
    emparentar(rotator_body, r)

    # Barra transversal horizontal (cross-boom) orientable
    # Inclinación de elevación de ~40° hacia el cielo
    boom_tilt = math.radians(40.0)

    cross_boom_obj = bpy.data.objects.new(f"{id_str}_cross_boom_pivot", None)
    cross_boom_obj.location = (0, 0, rotator_z + 0.15)
    cross_boom_obj.rotation_euler = (boom_tilt, 0, 0)
    bpy.context.collection.objects.link(cross_boom_obj)
    emparentar(cross_boom_obj, r)

    # Barra horizontal de montaje
    h_bar = cilindro(f"{id_str}_h_bar", radio=0.03, alto=2.0, pos=(0, 0, 0), mat="mat_aluminio", verts=8, rot=(0, math.pi / 2.0, 0))
    h_bar.parent = cross_boom_obj

    # 5. Antenas Yagi cruzadas (VHF/UHF crossed Yagi de 3 metros)
    yagi_len = 3.0

    # Boom longitudinal principal
    main_boom = cilindro(f"{id_str}_yagi_boom", radio=0.025, alto=yagi_len, pos=(0, yagi_len / 2.0 - 0.4, 0), mat="mat_aluminio", verts=8, rot=(math.pi / 2.0, 0, 0))
    main_boom.parent = cross_boom_obj

    element_positions = [
        (-0.35, 1.05, "mat_aluminio", "refl"),      # Reflector
        (0.00,  0.98, "mat_cobre",    "driven"),    # Elemento excitado / dipolo
        (0.35,  0.88, "mat_aluminio", "dir1"),      # Director 1
        (0.75,  0.85, "mat_aluminio", "dir2"),      # Director 2
        (1.20,  0.82, "mat_aluminio", "dir3"),      # Director 3
        (1.70,  0.80, "mat_aluminio", "dir4"),      # Director 4
        (2.20,  0.78, "mat_aluminio", "dir5"),      # Director 5
        (2.55,  0.76, "mat_aluminio", "dir6"),      # Director 6
    ]

    for y_pos, span, elem_mat, el_name in element_positions:
        # Elemento polarización horizontal
        el_h = cilindro(f"{id_str}_{el_name}_H", radio=0.008, alto=span, pos=(0, y_pos, 0), mat=elem_mat, verts=6, rot=(0, math.pi / 2.0, 0))
        el_h.parent = cross_boom_obj

        # Elemento polarización vertical
        el_v = cilindro(f"{id_str}_{el_name}_V", radio=0.008, alto=span, pos=(0, y_pos, 0), mat=elem_mat, verts=6, rot=(0, 0, 0))
        el_v.parent = cross_boom_obj

    return r


def ejecutar_prompt_7():
    print("=== Iniciando Prompt 7: Estaciones Terrenas (categoría ground) ===")

    modelos = [
        ("dsn70", modelar_dsn70),
        ("nsn11", modelar_nsn11),
        ("yagi_uni", modelar_yagi_uni),
    ]

    reporte = []

    for id_str, model_func in modelos:
        print(f"\n--- Modelando estación terrena: {id_str} ---")
        limpiar_escena()
        r = model_func()

        dim = bbox_m(r)
        tris = contar_tris(r)
        print(f"[{id_str}] Triángulos: {tris} (presupuesto <= 5 000)")
        print(f"[{id_str}] Dimensiones AABB: {dim} m")

        # Exportar GLB a assets/models/ground/<id>.glb
        glb_path = exportar_glb(r, "ground", id_str)
        glb_size = os.path.getsize(glb_path)
        print(f"[{id_str}] Exportado a {glb_path} ({glb_size} bytes)")

        # Registrar en manifest.json
        entry = registrar("ground", id_str, r)
        print(f"[{id_str}] Registrado en manifest.json: {entry}")

        # Generar vista previa con Workbench a art/previews/<id>.png
        prev_path = preview(r, id_str)
        prev_size = os.path.getsize(prev_path)
        print(f"[{id_str}] Vista previa: {prev_path} ({prev_size} bytes)")

        reporte.append({
            "id": id_str,
            "tris": tris,
            "bbox_m": dim,
            "glb_path": glb_path,
            "glb_size": glb_size,
            "prev_path": prev_path,
            "prev_size": prev_size
        })

    # Guardar art/blender/ground.blend con todos los modelos
    print("\n--- Guardando art/blender/ground.blend ---")
    limpiar_escena()
    r_dsn = modelar_dsn70()
    r_nsn = modelar_nsn11()
    r_yagi = modelar_yagi_uni()

    # Separar en el espacio para el .blend
    r_nsn.location = (60.0, 0, 0)
    r_yagi.location = (80.0, 0, 0)

    blend_path = os.path.join(ROOT, "art", "blender", "ground.blend")
    guardar_blend(blend_path)
    print(f"Guardado archivo de trabajo en: {blend_path}")

    return reporte


if __name__ == "__main__":
    rep = ejecutar_prompt_7()
    print("PROMPT 7 FINALIZADO:", rep)
