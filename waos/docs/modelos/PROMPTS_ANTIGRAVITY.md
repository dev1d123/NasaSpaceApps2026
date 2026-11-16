# Modelos 3D de WAOS con Blender MCP

Este documento es para el agente de Antigravity que tenga conectado el MCP de Blender. Contiene un contrato técnico, que se aplica a todos los modelos, y ocho prompts para ejecutar en orden. Al terminar cada prompt, el agente se detiene y reporta.

El juego (Godot 4.7, renderer GL Compatibility) ya funciona con naves greybox hechas de primitivas en `scripts/greybox/spacecraft_model.gd`. Estos modelos las reemplazan pieza por pieza. La integración en Godot la hace otro agente (Claude Code) leyendo `assets/models/manifest.json`: **no modifiques nada dentro de `scripts/`, `scenes/` ni `data/`.**

---

## Contrato técnico (obligatorio en todos los prompts)

### Rutas

Todas las rutas son relativas a la carpeta del proyecto Godot, `waos/`.

| Qué | Dónde |
|---|---|
| Modelos exportados | `assets/models/<categoria>/<id>.glb` |
| Archivos de trabajo `.blend` | `art/blender/<categoria>.blend` |
| Vistas previas | `art/previews/<id>.png` |
| Script de ayudas de Blender | `art/blender/tools/waos_helpers.py` |
| Manifiesto | `assets/models/manifest.json` |
| Reporte final | `art/REPORTE_MODELOS.md` |

Crea un archivo vacío `art/.gdignore` para que Godot no intente importar los `.blend` ni las vistas previas.

Categorías: `buses`, `panels`, `propulsion`, `comms`, `instruments` y, opcional, `ground`.

El `<id>` es **exactamente** el id del catálogo `data/gdd_data.json`, por ejemplo `cube6u`, `pan1500` o `xhga`. El juego busca los archivos por ese nombre.

### Unidades y ejes

- 1 unidad de Blender = **1 metro**, a escala real. Aplica todas las transformaciones (Ctrl+A → All Transforms) antes de exportar.
- Blender trabaja con Z hacia arriba y el exportador glTF convierte a Y hacia arriba. **Modela en Blender con estas direcciones:**

| Dirección en Blender | Significado en la nave | En Godot |
|---|---|---|
| **+Z** | Eje largo del bus, «arriba»: antena de alta ganancia | +Y |
| **−Z** | Abajo: propulsión y tobera | −Y |
| **−Y** | Cara nadir: instrumentos que miran al planeta | +Z |
| **+Y** | Cara opuesta al nadir: antenas de parche | −Z |
| **±X** | Laterales: alas solares | ±X |

- **Buses:** el origen está en el centro geométrico del bus.
- **Componentes** (paneles, propulsión, antenas, instrumentos): el origen es **el punto de montaje** y la pieza crece hacia **+Z local** (hacia afuera de la cara donde se monta). El juego pone el componente como hijo del socket sin rotación, así que esta regla es lo que hace que todo encaje.

### Sockets (puntos de anclaje en los buses)

Cada bus lleva objetos **Empty** (Plain Axes, tamaño 0.05) emparentados al objeto raíz, con estos nombres exactos. **El eje +Z local de cada Empty apunta hacia afuera de la cara**, en la dirección en que crece el componente.

| Nombre | Posición | +Z local apunta hacia |
|---|---|---|
| `socket_panel_L` | centro de la cara −X | −X |
| `socket_panel_R` | centro de la cara +X | +X |
| `socket_top` | centro de la cara +Z | +Z |
| `socket_bottom` | centro de la cara −Z | −Z |
| `socket_back` | cara +Y, a 3/4 de la altura | +Y |
| `socket_payload_0` … `socket_payload_3` | cara −Y, en fila horizontal y repartidos | −Y |
| `socket_sar` | centro de la cara −Y | −Y |
| `socket_boom` | arista inferior entre −X y −Y | −X, inclinado 30° hacia −Z |

Un socket que apunta hacia −X se logra rotando el Empty −90° en Y. Para los demás, calcula la rotación y compruébala mirando el eje del Empty en el viewport.

### Geometría y materiales

- Estilo: **low-poly técnico, limpio y legible desde lejos**. Se aceptan bevels de 1 o 2 segmentos. Sin texturas de imagen.
- Presupuesto de triángulos:
  - bus: hasta 6 000;
  - panel: hasta 2 000;
  - instrumento, antena o propulsión: hasta 3 000;
  - estación terrena: hasta 5 000.
- Normales hacia afuera, sin caras duplicadas ni geometría interna escondida. Shade Auto Smooth a 30°.
- Solo **Principled BSDF**, con color base, metálico y rugosidad; nada de nodos procedurales, porque no se exportan. Usa la biblioteca de materiales compartida, con estos nombres exactos, para que el juego pueda cambiarlos en código:

| Material | Color base | Metálico | Rugosidad | Uso |
|---|---|---|---|---|
| `mat_aluminio` | #B9BEC8 | 1.0 | 0.35 | estructura, rieles |
| `mat_mli_oro` | #C9A23A | 1.0 | 0.25 | manta térmica dorada (MLI) |
| `mat_mli_plata` | #D9DCE2 | 1.0 | 0.2 | manta térmica plateada |
| `mat_blanco` | #E8E9EC | 0.0 | 0.6 | pintura térmica blanca, radiadores |
| `mat_negro` | #1E2128 | 0.2 | 0.5 | anodizado negro, aperturas |
| `mat_celdas` | #1F2F66 | 0.6 | 0.25 | celdas solares |
| `mat_celdas_marco` | #8A90A0 | 0.8 | 0.4 | marcos de panel, bisagras |
| `mat_cobre` | #B06A3B | 1.0 | 0.35 | toberas y bobinas |
| `mat_lente` | #0E1622 | 0.0 | 0.05 | ópticas |
| `mat_kapton` | #C47A1E | 0.0 | 0.45 | cinta y cableado |

- Para que una cara de celdas se lea como cuadrícula, usa geometría (inset por celda o loop cuts con marco de `mat_celdas_marco`), nunca texturas.
- **Nada de logos, banderas, textos ni marcas** de la NASA, SpaceX, ULA ni de nadie. Las misiones reales se usan solo como referencia de forma y tamaño.

### Jerarquía y exportación

- Un objeto raíz por modelo, llamado `<id>`; por ejemplo, un Empty `cube6u` con la malla `cube6u_mesh` y los sockets como hijos. Ningún nombre puede terminar en `-col`, `-noimp`, `-colonly`, `-navmesh` ni `-rigid`, porque Godot les da un significado especial.
- Exporta con:

```python
bpy.ops.export_scene.gltf(
    filepath=ruta, export_format='GLB', use_selection=True,
    export_apply=True, export_yup=True, export_materials='EXPORT',
    export_cameras=False, export_lights=False)
```

- Antes de exportar, selecciona el objeto raíz **con toda su descendencia**. De lo contrario, los sockets no salen en el archivo.

### Cómo trabajar con el MCP

- Usa la herramienta del MCP que ejecuta Python en Blender (normalmente `execute_blender_code`). Después de cada pieza, comprueba el resultado con `get_viewport_screenshot` o con `get_scene_info`.
- No dependas de que las variables sobrevivan entre llamadas. Pon todo lo reutilizable en `art/blender/tools/waos_helpers.py` y empieza cada llamada con:

```python
import bpy, os
ROOT = r"<ruta absoluta a waos>"
exec(open(os.path.join(ROOT, "art/blender/tools/waos_helpers.py"), encoding="utf-8").read())
```

- Una escena limpia por categoría: borra los objetos de la categoría anterior antes de empezar otra y guarda un `.blend` por categoría.

---

## Prompt 0 · Preparación

> Lee completo `docs/modelos/PROMPTS_ANTIGRAVITY.md`, en especial el **Contrato técnico**. Comprueba que el MCP de Blender responde con `get_scene_info`. Crea las carpetas del contrato y el archivo `art/.gdignore`.
>
> Escribe `art/blender/tools/waos_helpers.py` con estas funciones, todas en metros:
> - `limpiar_escena()`;
> - `material(nombre)`: crea o reutiliza los 10 materiales de la tabla del contrato con sus valores exactos;
> - `caja(nombre, tamano, pos, mat, bevel=0.0)`;
> - `cilindro(nombre, radio, alto, pos, mat, verts=24, rot=(0,0,0))`;
> - `esfera(nombre, radio, pos, mat, segs=24)`;
> - `cono(nombre, r1, r2, alto, pos, mat, rot=(0,0,0))`;
> - `plato(nombre, diametro, profundidad, pos, mat)`: paraboloide hecho con un círculo extruido y escalado;
> - `socket(nombre, pos, apunta)`: Empty de 0.05 cuyo +Z local apunta al vector `apunta`;
> - `raiz(id)`: Empty padre;
> - `emparentar(hijos, padre)`;
> - `contar_tris(obj_raiz)`;
> - `bbox_m(obj_raiz)`: dimensiones del AABB en metros, en ejes de Blender;
> - `exportar_glb(obj_raiz, categoria, id)`: selecciona la raíz con toda su descendencia, aplica transformaciones y exporta según el contrato;
> - `preview(obj_raiz, id)`: render Workbench de 512×512 a `art/previews/<id>.png`, con cámara isométrica que encuadre el AABB, fondo #0B1020 y luz de estudio;
> - `registrar(categoria, id, obj_raiz)`: actualiza `assets/models/manifest.json` (lo crea si no existe) con `{ "<id>": {"file": "res://assets/models/<categoria>/<id>.glb", "categoria", "bbox_m": [x, y, z], "tris", "sockets": [nombres], "materiales": [nombres]} }`.
>
> Pruébalo creando un cubo de 1 m con un socket, expórtalo como `assets/models/_prueba/cubo.glb`, registra el modelo y genera su vista previa. Después borra el cubo, el `.glb` y su entrada del manifiesto. Repórtame lo que hiciste y si algo falló.

## Prompt 1 · Buses (7 modelos, categoría `buses`)

> Siguiendo el Contrato técnico de `docs/modelos/PROMPTS_ANTIGRAVITY.md`, modela los 7 buses con estas medidas exteriores en Blender (X × Y × Z en metros, con Z como eje largo). Cada uno lleva **todos** los sockets de la tabla del contrato, colocados sobre sus caras.
>
> | id | Medidas X×Y×Z | Referencia de forma |
> |---|---|---|
> | `cube3u` | 0.100 × 0.100 × 0.340 | CubeSat 3U: 4 rieles de aluminio de 8.5 mm en las aristas y salientes de 7 mm en los extremos de los rieles. Caras laterales con estructura de `mat_negro` visible y una placa de circuito. |
> | `cube6u` | 0.226 × 0.100 × 0.366 | CubeSat 6U (2×3U): rieles, separación visible entre las dos columnas. |
> | `cube12u` | 0.226 × 0.226 × 0.366 | CubeSat 12U, como el de CAPSTONE: rieles y 4 columnas. |
> | `espa` | 0.60 × 0.60 × 0.80 | SmallSat clase ESPA: anillo de interfaz de 0.38 m de diámetro en la cara −Z, paneles laterales con `mat_mli_oro` y un radiador `mat_blanco` en +Y. |
> | `leostar2` | 1.00 × 1.00 × 1.50 | Bus pequeño hexagonal u octogonal, al estilo de TESS: MLI dorada, radiadores blancos y un adaptador de lanzamiento en −Z. |
> | `leostar3` | 1.90 × 1.90 × 3.00 | Bus mediano, al estilo de Landsat 9: caja con MLI plateada y dorada por paneles, radiadores y una plataforma de instrumentos en −Y. |
> | `deep` | 1.60 × 1.60 × 2.40 | Orbitador de espacio profundo, al estilo de LRO: caja con MLI dorada, un módulo de propulsión inferior más ancho y anillo de adaptador. |
>
> Para los CubeSat, los `socket_payload_*` van sobre la cara −Y dentro de la huella del bus: reparte 2 en `cube3u` y 4 en los demás, con los que sobren en la misma fila. Por cada bus: exporta, registra y genera la vista previa. Guarda `art/blender/buses.blend`. Repórtame una tabla con id, medidas reales del AABB, triángulos y sockets, y revisa tú mismo cada vista previa antes de reportar.

## Prompt 2 · Paneles solares (7 modelos, categoría `panels`)

> Siguiendo el Contrato técnico, modela **un ala** de cada tipo. El juego la refleja para el otro lado. El origen es el punto de unión con el bus y el ala crece hacia +Z local: primero el yugo (brazo), luego los paneles. Las celdas van en la cara −Y local y la estructura trasera en +Y, en `mat_celdas_marco`. El área de celdas sale de A = P / (1361 · η · 0.8). Respeta el área de celdas de esta tabla con una tolerancia del ±10 %.
>
> | id | Celdas por ala | Ancho W × largo L de celdas | Forma |
> |---|---|---|---|
> | `pan8` | 0.013 m² | 0.30 × 0.044 | **Placa adosada al cuerpo**, sin yugo: grosor 3 mm, origen en el centro de la placa. |
> | `pan30` | 0.047 m² | 0.34 × 0.137 | Panel desplegable de CubeSat, 1 hoja con bisagra de resorte. Yugo de 2 cm. |
> | `pan90` | 0.140 m² | 0.34 × 0.41 | 3 hojas desplegadas con bisagras visibles. Yugo de 3 cm. |
> | `pan400` | 0.61 m² | 0.60 × 1.02 | Ala SmallSat de 2 hojas, yugo de 0.15 m y motor de apuntado (cilindro) en la raíz. |
> | `pan1500` | 2.30 m² | 1.00 × 2.30 | Ala rígida de 3 hojas, yugo de 0.4 m y motor de apuntado. |
> | `pan4500` | 6.9 m² | 1.80 × 3.83 | Ala grande al estilo de Landsat: 4 hojas, yugo de 0.6 m y motor de apuntado. |
> | `rosa` | 9.5 m² | 1.60 × 5.90 | Ala enrollable al estilo de ROSA/DART: manta flexible de celdas tensada entre **dos mástiles laterales** delgados (tubos de 4 cm) y un **rollo cilíndrico** en el extremo, de 0.12 m de diámetro y 1.6 m de largo. |
>
> Las celdas se ven como cuadrícula: inset por celda de unos 4×4 cm en los CubeSat y de 10×10 cm en los paneles grandes, siempre que no pases de 2 000 triángulos. Si te pasas, agrupa las celdas en strings. Por cada ala: exporta, registra y genera la vista previa. Guarda `art/blender/panels.blend` y repórtame la tabla con el área de celdas medida.

## Prompt 3 · Propulsión (7 conjuntos, categoría `propulsion`)

> Siguiendo el Contrato técnico, cada modelo es el **conjunto visible** que se monta en `socket_bottom`: plataforma, tanque o tanques semiempotrados y tobera o propulsor. El origen está en la cara de montaje y el conjunto crece hacia +Z local, que en la nave apunta hacia abajo. El diámetro del tanque sale de su volumen, d = (6V/π)^(1/3).
>
> | id | Tipo | Tanques (diámetro) | Propulsor visible |
> |---|---|---|---|
> | `coldgas` | gas frío | 1 cilindro de 0.06 × 0.10 m | 4 microtoberas de 5 mm en las esquinas, en `mat_cobre` |
> | `mono_cube` | monopropelente miniatura | 1 esfera de 0.20 m | módulo de 0.10 × 0.10 × 0.05 con 4 toberas de 1 N |
> | `mono_small` | hidracina SmallSat | 1 esfera de 0.54 m | 4 propulsores de 22 N inclinados 10° y 4 de 1 N de control |
> | `mono_large` | hidracina grande (como LRO) | 2 esferas de 0.95 m | 4 motores de 90 N y 8 de 22 N |
> | `biprop` | MMH/NTO con motor de apogeo | 2 tanques de 1.26 m (combustible y oxidante) | motor de apogeo central con tobera de `mat_cobre` de 0.6 m de largo y 0.35 m de boca, más 8 propulsores de control |
> | `hall` | efecto Hall 600 W | 1 esfera de xenón de 0.36 m | propulsor Hall: anillo de 0.10 m de diámetro y 0.08 m de alto, con canal anular `mat_negro` y cátodo lateral |
> | `nextc` | iónico de rejillas, como NEXT-C | 1 esfera de xenón de 0.71 m | propulsor de 0.36 m de diámetro × 0.40 m, con **rejilla circular** frontal hecha de geometría (anillos concéntricos), cardán de 2 ejes y cátodo neutralizador |
>
> Los tanques van con `mat_blanco` o `mat_mli_plata`, con cintas de sujeción. En los buses grandes el tanque real va dentro; aquí basta con que asome la mitad inferior. Por cada conjunto: exporta, registra y genera la vista previa. Guarda `art/blender/propulsion.blend` y repórtame.

## Prompt 4 · Comunicaciones (5 modelos, categoría `comms`)

> Siguiendo el Contrato técnico, el origen es el punto de montaje y la pieza crece hacia +Z local.
>
> | id | Socket | Forma y medidas |
> |---|---|---|
> | `uhf` | `socket_top` | Soporte cuadrado de 0.10 × 0.10 × 0.01 con **4 antenas de cinta métrica** de 0.17 m × 6 mm × 0.3 mm, desplegadas en cruz a 90° entre sí y perpendiculares a +Z. Material `mat_mli_plata`. |
> | `sband` | `socket_back` | Antena de parche: placa de 0.08 × 0.08 × 0.004 en `mat_blanco` con un cuadrado de `mat_cobre` de 0.05 encima. |
> | `xpatch` | `socket_back` | Parche de 0.06 × 0.06 × 0.004, con dos parches iguales lado a lado separados 2 cm. |
> | `xhga` | `socket_top` | Plato parabólico de **0.60 m** de diámetro y 0.09 m de profundidad en `mat_blanco`, con subreflector sobre 3 puntales, un mástil de 0.30 m y un cardán de 2 ejes en la base. |
> | `ka` | `socket_top` | Plato orientable al estilo de la HGA de LRO: **0.75 m** de diámetro sobre un **mástil de 1.2 m** en `mat_aluminio`, con cardán de 2 ejes visible y un alimentador central. |
>
> Por cada antena: exporta, registra y genera la vista previa. Guarda `art/blender/comms.blend` y repórtame.

## Prompt 5 · Instrumentos (8 modelos, categoría `instruments`)

> Siguiendo el Contrato técnico, cada instrumento se monta en un `socket_payload_*`, salvo `sar` y `mag`. El origen está en la base de montaje y el instrumento crece hacia +Z local; **la apertura u óptica queda en el extremo +Z**, porque en la nave esa dirección mira al planeta. Las formas imitan la **clase** de instrumento real indicada, sin copiar detalles exactos.
>
> | id | Clase de referencia | Forma y medidas aproximadas |
> |---|---|---|
> | `cubecam` | cámara multiespectral de 1.5U | caja de 0.10 × 0.10 × 0.15 en `mat_negro` con tubo de lente de 0.06 de diámetro y apertura `mat_lente` |
> | `cam` | LROC (LRO) | **2 telescopios** cilíndricos de 0.27 m de diámetro × 0.70 m en paralelo, cada uno con parasol y apertura `mat_lente`, más una cámara gran angular pequeña de 0.15 m en el centro y una base común en `mat_mli_oro` |
> | `ir` | Diviner (LRO) | caja de 0.50 × 0.30 × 0.35 con dos aperturas rectangulares y un actuador de elevación en la base; radiador de enfriamiento en un costado, en `mat_blanco` |
> | `neut` | LEND (LRO) | cuerpo cilíndrico de 0.35 × 0.40 rodeado de **4 a 6 módulos cilíndricos** de moderador (polietileno, `mat_blanco`) y una cara superior con colimador |
> | `uv` | LAMP (LRO) | caja de 0.35 × 0.15 × 0.15 con apertura rectangular `mat_lente` en el extremo |
> | `rad` | CRaTER (LRO) | cilindro de 0.15 de diámetro × 0.25 sobre una placa de 0.20 × 0.20, con abertura en el extremo |
> | `sar` | radar de apertura sintética | **antena plana** de 3.0 × 0.70 × 0.06, con mosaico de 8×2 parches en `mat_blanco` y `mat_negro`, y caja de electrónica de 0.4 × 0.3 × 0.2 detrás (lado del origen). Se monta en `socket_sar` y queda paralela a la cara nadir: el lado largo sigue el eje Z del bus |
> | `mag` | magnetómetro fluxgate con mástil | **mástil desplegable** de 2.0 m en 3 segmentos de tubo de 2 cm con bisagras, un **sensor cúbico** de 0.08 m en la punta y un segundo sensor más pequeño a 2/3 del mástil (gradiómetro). Se monta en `socket_boom` y el mástil crece hacia +Z local |
>
> Por cada instrumento: exporta, registra y genera la vista previa. Guarda `art/blender/instruments.blend` y repórtame.

## Prompt 6 · Ensamble de prueba y verificación

> 1. En una escena nueva, **ensambla las 3 naves de referencia** del juego emparentando cada componente a su socket con transformación local identidad. Exporta cada nave a `art/ensambles/<nombre>.glb` (son solo para revisión; el juego no las usa) y genera su vista previa:
>    - `ref_s1`: `cube6u` + `pan30` (R y L reflejado) + `sband` + `cubecam` + `mag`.
>    - `ref_s2`: `leostar2` + `pan1500` (×2) + `mono_small` + `xhga` + `sar` + `ir`.
>    - `ref_s3`: `espa` + `pan400` (×2) + `mono_small` + `xhga` + `neut` + `ir` + `rad`.
> 2. Revisa en las vistas previas que nada quede al revés: los instrumentos miran hacia −Y, las alas salen por ±X, la tobera queda abajo y la antena arriba. Si algo se monta mal, **corrige el componente o el socket**, nunca el ensamble.
> 3. Valida el manifiesto: deben estar los 34 ids (7 buses, 7 paneles, 7 propulsiones, 5 antenas y 8 instrumentos), con rutas que existan y presupuestos de triángulos cumplidos.
> 4. Ejecuta `Godot --headless --path . --import` desde la carpeta del proyecto y comprueba que no hay errores al importar los `.glb`.
> 5. Escribe `art/REPORTE_MODELOS.md` con:
>    - la tabla de ids, medidas, triángulos y sockets;
>    - las desviaciones del contrato y su motivo;
>    - las vistas previas enlazadas.
>
> No hagas commits; el usuario decide cuándo hacerlos.

## Prompt 7 (opcional) · Estaciones terrenas (categoría `ground`)

> Siguiendo el Contrato técnico, con Z hacia arriba y el origen en la base sobre el suelo:
> - `dsn70`: antena de 70 m en montura de azimut y elevación, al estilo de los complejos DSN, con su pedestal;
> - `nsn11`: plato de 11 m con pedestal;
> - `yagi_uni`: antena Yagi cruzada de 3 m sobre un mástil en un techo pequeño, para la estación universitaria.
>
> En el juego se ven como marcadores sobre el planeta, así que importa más la silueta que el detalle. Exporta, registra, genera la vista previa y repórtame.

---

### Notas para quien revise

- Si una medida del contrato choca con algo físicamente imposible (por ejemplo, un socket que queda dentro de otra pieza), anótalo en el reporte y sigue adelante con la mejor aproximación.
- Si el MCP no ofrece captura del viewport, las vistas previas de Workbench sirven como verificación visual.

## Prompt 8 · Figura humana de escala (categoría `ref`)

> Siguiendo el Contrato técnico de `docs/modelos/PROMPTS_ANTIGRAVITY.md`, modela `person_ref`: una **figura humana de 1.80 m** que aparece junto a la nave en la pantalla de diseño para comparar tamaños.
>
> - **Qué representa:** un técnico de integración con **traje de sala limpia**: mono de cuerpo completo, capucha, mascarilla, guantes y botas cubrebotas. Sin rostro detallado: la cara es un óvalo con gafas de seguridad `mat_lente`.
> - **Pose:** de pie, neutra y relajada; brazos a los lados, separados unos 10° del cuerpo, y pies a la anchura de los hombros. Mira hacia **−Y**, igual que la cara nadir.
> - **Medidas:** altura total exacta de **1.80 m**, hombros de 0.45 m y profundidad de unos 0.28 m. Proporciones humanas realistas, sin estilo caricaturesco.
> - **Origen:** en el suelo, entre los dos pies (Z = 0); la figura crece hacia +Z.
> - **Estilo:** low-poly limpio, coherente con el resto de modelos. Como máximo 3 000 triángulos, con Shade Auto Smooth a 30°.
> - **Materiales** (solo de la biblioteca): mono, capucha y cubrebotas en `mat_blanco`; guantes y mascarilla en `mat_negro`; gafas en `mat_lente`; y una franja de `mat_kapton` en la cintura como cinturón, para dar contraste. Sin logos, nombres ni insignias.
> - **Jerarquía:** objeto raíz `person_ref` y malla `person_ref_mesh`. Sin esqueleto ni animaciones, porque es una figura estática.
>
> Exporta `assets/models/ref/person_ref.glb`, registra el modelo en el manifiesto con categoría `ref` y genera la vista previa `art/previews/person_ref.png`. Además, genera `art/previews/person_ref_vs_leostar2.png`, con la figura de pie junto al bus `leostar2` a 0.5 m de su cara +X, para comprobar la escala. Ejecuta `Godot --headless --path . --import` y comprueba que no hay errores. Añade la fila al final de `art/REPORTE_MODELOS.md`. No hagas commits y repórtame. 
