# WAOS · Space Mission Design Game

Juego en Godot 4.7 para el reto *Space Mission Design Game* (NASA Space Apps 2026), construido a partir del GDD del equipo, con 37 modelos 3D de componentes de naves.

**Jugar en el navegador:** https://jcosmos.vercel.app (escritorio; la primera carga baja unos 80 MB).
**Video de demo (30 s, español con subtítulos en inglés):** [docs/entrega/WAOS_demo_30s.mp4](docs/entrega/WAOS_demo_30s.mp4)

## Cómo jugar

En el navegador, o abre el proyecto en Godot 4.7 y pulsa **F5**. El bucle sigue los Concept Maturity Levels del JPL:

1. **CML 1 · Contrato**: elige jugadores (1 a 4), reparte los cuatro roles y acepta uno de los tres escenarios.
2. **CML 2–3 · Diseño**: cada rol tiene su pestaña (Lanzamiento, Sistemas, Comunicaciones, Ciencia). Los medidores se recalculan con cada cambio. Solo se puede volar con las 8 verificaciones en verde. Con 2 o más jugadores, una compra que supere el 10 % del fondo necesita el visto bueno de otro rol.
3. **CML 4 · Vuelo**: simulación física acelerada (de 1× a «MÁX»). Los eventos pausan el juego y piden una decisión al rol responsable. Puedes apagar instrumentos, cambiar el ciclo de trabajo o mirar la nave de cerca.
4. **Debriefing**: puntaje C/E/R/K, libro de cuellos de botella con la decisión de diseño que causó cada uno, eventos, y la misión real de la NASA más parecida. Desde ahí se vuelve a CML 3 para iterar.

## Estructura

| Ruta | Qué hay |
|---|---|
| `data/gdd_data.json` | Catálogos del GDD (lanzadores, bus, paneles, baterías, propulsión, antenas, estaciones, instrumentos, misiones reales, escenarios y eventos), exportados del documento sin cambios |
| `scripts/core/astro.gd` | Motor físico del GDD §2: N-cuerpos restringido, J2, arrastre, RK4, CR3BP con corrector de órbitas halo/NRHO, eclipse por cono de sombra, línea de vista, Tsiolkovski |
| `scripts/core/design_eval.gd` | Evaluación CML 3 (GDD §7), port fiel de `evaluate()` |
| `scripts/core/mission_sim.gd` | Simulación CML 4: dinámica → geometría → potencia → carga útil → enlace → eventos → registro |
| `scripts/core/mission_events.gd` | Mecánica de los 15 eventos (GDD §6) |
| `scripts/core/scoring.gd` | Puntaje, cuellos de botella y emparejamiento con misiones reales (GDD §8) |
| `scripts/greybox/` | Biblioteca de modelos, nave armada por sockets (con greybox de respaldo), vista espacial, shader de retícula y cámara orbital |
| `scripts/screens/` | Menú, diseño, misión y debriefing (la interfaz se construye en código) |
| `scripts/autoload/` | `GameData` (catálogos) y `GameState` (partida, roles, colaboración) |
| `tests/` | Pruebas headless, prueba de humo de todas las pantallas y capturas |

El núcleo (`scripts/core`) no usa nodos: se puede probar sin abrir el juego.

## Modelos 3D

Los 37 modelos (7 buses, 7 paneles, 7 propulsiones, 5 antenas, 8 instrumentos y 3 estaciones terrenas) se hicieron en Blender con los prompts de [docs/modelos/PROMPTS_ANTIGRAVITY.md](docs/modelos/PROMPTS_ANTIGRAVITY.md). Están en `assets/models/<categoria>/<id>.glb` y se describen en `assets/models/manifest.json`. Los `.blend` y las vistas previas están en `art/`.

`ModelLibrary` lee el manifiesto. `SpacecraftModel` instancia el bus y cuelga cada componente del `socket_*` que le corresponde, con transformación identidad. Si falta cualquier modelo del diseño, la nave se arma con el greybox de primitivas (`ModelLibrary.enabled = false` lo fuerza). Las estaciones terrenas se dibujan ampliadas para verse sobre la Tierra.

**Regenerar los modelos:** `python art/blender/tools/rebuild_all.py` reconstruye todos los modelos desde los `build_*.py`, en el origen. Después:
- activa el descarte de caras traseras y da grosor a los planos de una sola cara;
- separa las piezas coplanares con los ajustes de `zfight_ajustes.json`;
- exporta y repite con `zfight_check.py` hasta que no quede z-fighting.

Los `.blend` guardan una escena por modelo. Si editas un modelo, cambia su `build_*.py` y vuelve a correr `rebuild_all.py`; no exportes a mano desde el `.blend`.

## Qué es física real y qué es modelo de juego

- **Integrado de verdad (RK4, 64 bits):**
  - LEO con J2 y arrastre;
  - órbita lunar baja con la Tierra como tercer cuerpo;
  - NRHO 9:2 obtenida con un corrector diferencial en el CR3BP (periodo de 6,56 días y periluna de unos 3 250 km);
  - eclipses, visibilidad de estaciones con máscara de 10°, oclusión lunar del enlace, Tsiolkovski en cada quemado y mantenimiento de altitud en LEO.
- **Modelos del GDD, sin simulación directa:**
  - la deriva por mascones en órbita lunar baja (≈4 km/mes, que se acelera si no se corrige);
  - el crecimiento del error en la NRHO (se duplica cada ≈7 días);
  - el crucero Tierra–Luna, cuyo trazo es ilustrativo (el Δv lo pone el lanzador);
  - las probabilidades de los eventos.
- Los números que el GDD no fija están marcados como «juego» en los comentarios de `mission_events.gd`.

La dinámica avanza en subpasos de 30 s como máximo. Con pasos de 120 s el RK4 pierde energía de forma artificial (unos 0,75 km/día de decaimiento falso en LEO). Hay una prueba que lo vigila.

## Pruebas

Ejecuta los comandos desde esta carpeta (`godot` es el ejecutable de Godot 4.7):

```
godot --headless --path . res://tests/run_tests.tscn                  # física, evaluador y 3 misiones completas
WAOS_SCN=s2 godot --headless --path . res://tests/smoke.tscn          # recorre todas las pantallas (s1, s2 o s3)
WAOS_SHOTS=<carpeta> godot --path . res://tests/screenshots.tscn      # capturas de cada pantalla
```

`WAOS_TEST=core` corre solo la física y el evaluador, que tardan segundos. Las tres misiones completas tardan unos 2 minutos.

Resultados actuales: el evaluador coincide con el JS del GDD en todas las cifras de los tres diseños de referencia. Volados con física completa, los tres alcanzan su meta científica:

| Escenario | Simulación | Estimado CML 3 |
|---|---|---|
| s1 | 909 pts | 950 |
| s2 | 78 180 pts | 78 183 |
| s3 | 113 776 pts | 113 880 |

## Pendiente o posible

- Guardar y cargar diseños; exportar el diseño a JSON.
- Mostrar la huella en tierra y la cobertura del instrumento.
- Modelos finales que reemplacen el greybox (`SpacecraftModel.build()` es el único punto de cambio).
- Multijugador en red; ahora es cooperativo en la misma pantalla.

## Versión web

`web/deploy.sh` exporta el preset **Web** (un solo hilo, así que no necesita cabeceras COOP/COEP) y lo publica en Vercel:

```
GODOT=/ruta/Godot_v4.7.1-stable_win64_console.exe web/deploy.sh
```

El navegador no tiene las fuentes del sistema, así que la interfaz usa DejaVu Sans (`assets/fonts`, licencia libre) para los símbolos que faltan.

## Créditos

- Texturas PBR: [ambientCG](https://ambientcg.com) (CC0).
- Fuente de respaldo: [DejaVu Fonts](https://dejavu-fonts.github.io) (licencia en `assets/fonts/DejaVu-LICENSE.txt`).
- Datos: catálogos del GDD con fuentes de la NASA (JPL SSD, NSSDCA, PDS, NTRS, DSN y Near Space Network).
