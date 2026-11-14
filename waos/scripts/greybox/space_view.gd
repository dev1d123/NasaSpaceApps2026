class_name SpaceView
extends Node3D
## Vista 3D greybox de la misión. Escala: 1 unidad = 1 000 km. Todo se dibuja respecto
## del cuerpo central (Tierra en LEO y crucero, Luna en órbita lunar).

const S := 1.0 / 1000.0
const PLANET_SHADER := preload("res://scripts/greybox/planet.gdshader")

var sim: MissionSim
var cam: OrbitCamera
var sun: DirectionalLight3D
var earth: MeshInstance3D
var moon: MeshInstance3D
var craft: SpacecraftModel
var craft_pivot: Node3D
var orbit_mesh: ImmediateMesh
var link_mesh: ImmediateMesh
var station_root: Node3D
var focus_craft := false
var _central := ""
var _orbit_timer := 0.0

func setup(s: MissionSim) -> void:
	sim = s
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#05070d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#3a4560")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.4
	add_child(sun)
	earth = _planet(Astro.R_E * S, Color(0.28, 0.38, 0.55), Color(0.62, 0.70, 0.84))
	moon = _planet(Astro.R_M * S, Color(0.42, 0.42, 0.44), Color(0.66, 0.66, 0.68))
	_label3d(earth, "Tierra", Astro.R_E * S * 1.15)
	_label3d(moon, "Luna", Astro.R_M * S * 1.2)
	craft_pivot = Node3D.new()
	add_child(craft_pivot)
	craft = SpacecraftModel.new()
	craft_pivot.add_child(craft)
	craft.build(s.design)
	orbit_mesh = _line_instance(Color(UIKit.ACCENT, 0.9))
	link_mesh = _line_instance(UIKit.GOOD)
	station_root = Node3D.new()
	add_child(station_root)
	_stars()
	cam = OrbitCamera.new()
	add_child(cam)
	cam.current = true
	_refocus(true)

func _planet(r: float, base: Color, line: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 96
	m.rings = 48
	mi.mesh = m
	var sm := ShaderMaterial.new()
	sm.shader = PLANET_SHADER
	sm.set_shader_parameter("base_color", base)
	sm.set_shader_parameter("line_color", line)
	mi.material_override = sm
	add_child(mi)
	return mi

func _label3d(parent: Node3D, text: String, height: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0007
	l.font_size = 26
	l.modulate = UIKit.MUTED
	l.no_depth_test = true
	l.position = Vector3(0, height, 0)
	parent.add_child(l)

func _line_instance(c: Color) -> ImmediateMesh:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return im

## Fondo de estrellas fijo (puntos), para leer la rotación de cámara.
func _stars() -> void:
	var mi := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	im.surface_begin(Mesh.PRIMITIVE_POINTS)
	for i in 1500:
		var v := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized() * 9000.0
		im.surface_add_vertex(v)
	im.surface_end()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.9)
	m.use_point_size = true
	m.point_size = 1.5
	mi.material_override = m
	add_child(mi)

func _origin_eci() -> PackedFloat64Array:
	if sim.phase != "crucero" and sim.regime != "leo":
		return Astro.moon_pos(sim.t)
	return Astro.v3(0, 0, 0)

func _refocus(instant: bool) -> void:
	_central = "moon" if (sim.phase != "crucero" and sim.regime != "leo") else "earth"
	if focus_craft:
		# Una nave real mide ~1e-6 unidades: imposible de mostrar a escala junto al planeta
		# con floats de 32 bits. En modo enfoque se dibuja a 0.05 unidades (ampliada).
		cam.min_distance = 0.03
		cam.set_distance(0.25, instant)
		return
	cam.min_distance = 0.5
	var pts := sim.orbit_points(60)
	var rmax := 0.0
	for p in pts:
		rmax = maxf(rmax, Astro.vnorm(p) * S)
	if rmax <= 0.0:
		rmax = 10.0
	# Que la órbita entera quepa en el encuadre (fov 50°) con margen.
	cam.set_distance(maxf(rmax * 3.6, 6.0), instant)

func toggle_focus() -> void:
	focus_craft = not focus_craft
	_refocus(false)

func _process(delta: float) -> void:
	if sim == null:
		return
	var central := "moon" if (sim.phase != "crucero" and sim.regime != "leo") else "earth"
	if central != _central:
		_refocus(false)
	var o := _origin_eci()
	var rel := Astro.vsub(sim.sc_eci(), o)
	var craft_pos := Astro.to_godot(rel, S)
	earth.position = Astro.to_godot(Astro.vsub(Astro.v3(0, 0, 0), o), S)
	moon.position = Astro.to_godot(Astro.vsub(Astro.moon_pos(sim.t), o), S)
	earth.rotation = Vector3(0, Astro.W_E * sim.t, 0)
	# La Luna muestra siempre la misma cara a la Tierra.
	moon.rotation = Vector3(0, TAU * sim.t / Astro.T_MOON + PI, 0)
	var sun_dir := Astro.to_godot(Astro.vsub(Astro.sun_pos(sim.t), o), 1.0).normalized()
	sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT)
	# Nave: modelo real, ampliado para verse desde lejos (a menos que se enfoque).
	craft_pivot.position = craft_pos
	var longest := maxf(craft.bounds.get_longest_axis_size(), 0.3)
	if focus_craft:
		craft_pivot.scale = Vector3.ONE * (0.05 / longest)
		cam.target = craft_pos
	else:
		var dist := cam.global_position.distance_to(craft_pos)
		craft_pivot.scale = Vector3.ONE * (dist * 0.025 / longest)
		cam.target = Vector3.ZERO
	# Nadir hacia el cuerpo central
	if craft_pos.length() > 0.001:
		var up := Vector3.UP if absf(craft_pos.normalized().y) < 0.95 else Vector3.RIGHT
		craft_pivot.look_at(craft_pos * 2.0, up)
	# Órbita (se recalcula unas veces por segundo; la cónica cambia despacio).
	_orbit_timer -= delta
	if _orbit_timer <= 0.0:
		_orbit_timer = 0.2
		_draw_orbit()
		_draw_stations()
	_draw_link(craft_pos, o)

func _draw_orbit() -> void:
	orbit_mesh.clear_surfaces()
	var pts := sim.orbit_points(200)
	if pts.size() < 2:
		return
	orbit_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in pts:
		orbit_mesh.surface_add_vertex(Astro.to_godot(p, S))
	orbit_mesh.surface_end()

func _draw_stations() -> void:
	for c in station_root.get_children():
		c.queue_free()
	var o := _origin_eci()
	for st in sim.station_points():
		var p := Astro.to_godot(Astro.vsub(st["eci"], o), S)
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3.ONE * 0.12
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = UIKit.BAD if st["out"] else UIKit.GAME
		mi.material_override = mat
		mi.position = p * 1.01
		station_root.add_child(mi)
		var l := Label3D.new()
		l.text = st["nombre"]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.fixed_size = true
		l.pixel_size = 0.0009
		l.font_size = 24
		l.modulate = UIKit.GAME
		l.position = p * 1.04
		station_root.add_child(l)

func _draw_link(craft_pos: Vector3, o: PackedFloat64Array) -> void:
	link_mesh.clear_surfaces()
	if not sim.in_contact:
		return
	var target := Vector3.ZERO
	if sim.regime == "leo":
		var best := 1e12
		for st in sim.station_points():
			var p := Astro.to_godot(Astro.vsub(st["eci"], o), S)
			var d := p.distance_to(craft_pos)
			if d < best and not st["out"]:
				best = d
				target = p
	else:
		target = earth.position
	link_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	link_mesh.surface_add_vertex(craft_pos)
	link_mesh.surface_add_vertex(target)
	link_mesh.surface_end()
