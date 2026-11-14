extends Node
## CML 1 · «servilleta»: elegir jugadores, repartir roles y aceptar un contrato.

var main: Node
var _players_row: HBoxContainer
var _roles_box: VBoxContainer
var _cam: OrbitCamera

func _ready() -> void:
	_build_backdrop()
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var cols := UIKit.hbox(28)
	var wrap := UIKit.margin(cols, 36)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)

	# Columna izquierda: título, jugadores y roles
	var left := UIKit.vbox(14)
	left.custom_minimum_size.x = 430
	cols.add_child(left)
	left.add_child(UIKit.eyebrow("NASA Space Apps Challenge 2026 · Space Mission Design Game", UIKit.MUTED))
	var t := UIKit.label("WAOS", 72, UIKit.INK)
	left.add_child(t)
	left.add_child(UIKit.label("Diseña una misión, vuélala y descubre por qué funcionó… o por qué no.", 18, UIKit.INK, true))
	left.add_child(UIKit.label("Recorres los Concept Maturity Levels del JPL: CML 1 contrato → CML 2–3 diseño concurrente → CML 4 vuelo → debriefing. Cada decisión cambia masa, potencia, presupuesto, datos, comunicaciones y tiempo.", 14, UIKit.MUTED, true))
	left.add_child(UIKit.sep())
	left.add_child(UIKit.eyebrow("Jugadores en esta pantalla (cooperativo asimétrico)"))
	_players_row = UIKit.hbox(6)
	left.add_child(_players_row)
	for n in [1, 2, 3, 4]:
		var b := UIKit.button(str(n))
		b.custom_minimum_size = Vector2(52, 40)
		b.toggle_mode = true
		b.button_pressed = GameState.players == n
		b.pressed.connect(_set_players.bind(n))
		_players_row.add_child(b)
	_roles_box = UIKit.vbox(6)
	left.add_child(_roles_box)
	_refresh_roles()
	left.add_child(UIKit.label("Con más de un jugador, cada compra que supere el 10 % del fondo común necesita el visto bueno de otro rol (regla de negociación del GDD). Eso alimenta el puntaje de colaboración.", 13, UIKit.MUTED, true))
	left.add_child(UIKit.spacer())
	left.add_child(UIKit.label("Prototipo greybox · los valores marcados JUEGO son de diseño, no datos de la NASA. La NASA no respalda este juego.", 11, UIKit.MUTED, true))

	# Columna derecha: contratos
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIKit.title("CML 1 · Elige un contrato", 24))
	var list := UIKit.vbox(12)
	right.add_child(UIKit.scroll(list))
	(list.get_parent() as ScrollContainer).size_flags_vertical = Control.SIZE_EXPAND_FILL
	for sc in GameData.list("escenarios"):
		list.add_child(_scenario_card(sc))

func _build_backdrop() -> void:
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#05070d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#3a4560")
	e.ambient_light_energy = 0.4
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.3, 0.9, 0)
	world.add_child(sun)
	var earth := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 6.378
	m.height = 12.756
	m.radial_segments = 96
	m.rings = 48
	earth.mesh = m
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://scripts/greybox/planet.gdshader")
	earth.material_override = sm
	world.add_child(earth)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 7.0
	tor.outer_radius = 7.03
	tor.rings = 128
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(UIKit.ACCENT, 0.8)
	ring.material_override = rm
	ring.rotation = Vector3(0.3, 0, 1.2)
	world.add_child(ring)
	_cam = OrbitCamera.new()
	_cam.auto_rotate = 0.05
	_cam.pitch = 0.25
	world.add_child(_cam)
	_cam.set_distance(19.0, true)
	_cam.target = Vector3(-6, 0, 0)

func _set_players(n: int) -> void:
	GameState.set_players(n)
	for i in _players_row.get_child_count():
		(_players_row.get_child(i) as Button).button_pressed = (i + 1) == n
	_refresh_roles()

func _refresh_roles() -> void:
	for c in _roles_box.get_children():
		c.queue_free()
	for i in GameState.ROLES.size():
		var r: Dictionary = GameState.ROLES[i]
		var row := UIKit.hbox(8)
		var dot := ColorRect.new()
		dot.color = r["color"]
		dot.custom_minimum_size = Vector2(6, 22)
		row.add_child(dot)
		var name_l := UIKit.label("%s · %s" % [r["nombre"], r["segmento"]], 14)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		if GameState.players > 1:
			var b := UIKit.button("J%d" % GameState.role_owner[i])
			b.tooltip_text = "Cambiar qué jugador controla este rol"
			b.pressed.connect(func():
				GameState.role_owner[i] = (GameState.role_owner[i] % GameState.players) + 1
				_refresh_roles())
			row.add_child(b)
		_roles_box.add_child(row)

func _scenario_card(sc: Dictionary) -> Control:
	var p := UIKit.panel(UIKit.SURFACE, UIKit.LINE, 16)
	var v := UIKit.vbox(8)
	p.add_child(v)
	v.add_child(UIKit.eyebrow(sc["nivel"], UIKit.ACCENT))
	v.add_child(UIKit.label(sc["nombre"], 24))
	v.add_child(UIKit.label(sc["objetivo"], 14, UIKit.INK, true))
	var facts := UIKit.hbox(18)
	for f in [["Presupuesto", UIKit.fmt_money(float(sc["presupuesto"]))], ["Meta científica", "%d pts" % int(sc["meta_sp"])],
			["Duración", "%d días" % int(sc["duracion_dias"])], ["Plazo", "%d meses" % int(sc["plazo_meses"])], ["Destino", str(sc["regimen"]).to_upper()]]:
		var fv := UIKit.vbox(0)
		fv.add_child(UIKit.eyebrow(f[0]))
		fv.add_child(UIKit.label(f[1], 18))
		facts.add_child(fv)
	v.add_child(facts)
	var rest := UIKit.vbox(2)
	for r in sc["restricciones"]:
		rest.add_child(UIKit.label("• " + r, 13, UIKit.MUTED, true))
	v.add_child(rest)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.spacer())
	var b := UIKit.button("Aceptar contrato →", true)
	b.pressed.connect(_accept.bind(sc["id"]))
	row.add_child(b)
	v.add_child(row)
	return p

func _accept(id: String) -> void:
	GameState.start_contract(id)
	main.goto_design()
