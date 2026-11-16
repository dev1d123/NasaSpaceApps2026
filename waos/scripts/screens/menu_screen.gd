extends Node
## CML 1 · «servilleta»: elegir jugadores, repartir roles y aceptar un contrato.
## Interfaz de alta fidelidad con ambiente estelar y fichas técnicas de misión.

const UISound = preload("res://scripts/ui/ui_sound.gd")
const UIParticles = preload("res://scripts/ui/ui_particles.gd")

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
	
	# Partículas 2D de polvo estelar sutil
	var dust := UIParticles.create_space_dust(Vector2(1600, 900), 45)
	root.add_child(dust)
	
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b, 0.65)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var cols := UIKit.hbox(32)
	var wrap := UIKit.margin(cols, 36)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)

	# Columna izquierda: título, jugadores y roles
	var left := UIKit.vbox(14)
	left.custom_minimum_size.x = 450
	cols.add_child(left)
	
	left.add_child(UIKit.eyebrow("NASA Space Apps Challenge 2026 · Space Mission Design Game", UIKit.ACCENT))
	var t := UIKit.title("WAOS", 64)
	left.add_child(t)
	left.add_child(UIKit.label("Diseña una misión espacial, vuélala y descubre por qué funcionó… o por qué no.", 17, UIKit.INK, true))
	left.add_child(UIKit.label("Recorres los Concept Maturity Levels del JPL: CML 1 contrato → CML 2–3 diseño concurrente → CML 4 vuelo → debriefing. Cada subsistema afecta a los demás en masa, potencia, presupuesto, enlace y tiempo.", 13, UIKit.MUTED, true))
	left.add_child(UIKit.sep())
	
	left.add_child(UIKit.eyebrow("Equipo en esta terminal (cooperativo asimétrico)"))
	_players_row = UIKit.hbox(8)
	left.add_child(_players_row)
	for n in [1, 2, 3, 4]:
		var b := UIKit.button("%d %s" % [n, "Jugador" if n == 1 else "Jugadores"])
		b.custom_minimum_size = Vector2(98, 38)
		b.toggle_mode = true
		b.button_pressed = GameState.players == n
		b.pressed.connect(_set_players.bind(n))
		_players_row.add_child(b)
		
	_roles_box = UIKit.vbox(8)
	left.add_child(_roles_box)
	_refresh_roles()
	
	left.add_child(UIKit.label("Con más de un jugador, toda compra que supere el 10 % del fondo común necesita consenso con otro rol (regla de ingeniería concurrente).", 12, UIKit.MUTED, true))
	left.add_child(UIKit.spacer())
	
	var audio_box := UIKit.hbox(8)
	var mute_btn := UIKit.button("AUDIO: ON  [Tecla M]")
	mute_btn.custom_minimum_size = Vector2(180, 32)
	mute_btn.pressed.connect(func():
		var muted := UISound.toggle_mute()
		mute_btn.text = "AUDIO: SILENCIADO [M]" if muted else "AUDIO: ON  [Tecla M]"
	)
	audio_box.add_child(mute_btn)
	left.add_child(audio_box)
	
	left.add_child(UIKit.label("Prototipo para NASA Space Apps Challenge · Datos basados en catálogo JPL/NASA y GDD.", 11, UIKit.MUTED.darkened(0.2), true))

	# Columna derecha: contratos disponibles
	var right := UIKit.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIKit.title("CML 1 · Selecciona un Contrato de Misión", 22))
	var list := UIKit.vbox(14)
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
	e.background_color = Color("#04060c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#2d3952")
	e.ambient_light_energy = 0.5
	env.environment = e
	world.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.35, 0.95, 0)
	sun.light_energy = 1.3
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
	sm.set_shader_parameter("base_color", Color(0.24, 0.35, 0.52))
	sm.set_shader_parameter("line_color", Color(0.55, 0.68, 0.85))
	earth.material_override = sm
	world.add_child(earth)
	
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 7.0
	tor.outer_radius = 7.035
	tor.rings = 128
	ring.mesh = tor
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(UIKit.ACCENT, 0.75)
	ring.material_override = rm
	ring.rotation = Vector3(0.3, 0, 1.2)
	world.add_child(ring)
	
	_cam = OrbitCamera.new()
	_cam.auto_rotate = 0.04
	_cam.pitch = 0.22
	world.add_child(_cam)
	_cam.set_distance(19.0, true)
	_cam.target = Vector3(-5.5, 0, 0)

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
		var col: Color = r["color"]
		var card := UIKit.panel(Color(col, 0.08), col.darkened(0.2), 8)
		var row := UIKit.hbox(10)
		card.add_child(row)
		
		var led := ColorRect.new()
		led.color = col
		led.custom_minimum_size = Vector2(5, 24)
		row.add_child(led)
		
		var text_col := UIKit.vbox(1)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title_lbl := UIKit.label(r["nombre"], 14, UIKit.INK_BRIGHT)
		title_lbl.add_theme_font_override("font", UIKit.font_title())
		text_col.add_child(title_lbl)
		text_col.add_child(UIKit.label("Segmento %s · Decisiones clave de diseño" % r["segmento"], 11, UIKit.MUTED))
		row.add_child(text_col)
		
		if GameState.players > 1:
			var b := UIKit.button("J%d" % GameState.role_owner[i])
			b.custom_minimum_size = Vector2(44, 30)
			b.tooltip_text = "Clic para reasignar este rol a otro jugador"
			b.pressed.connect(func():
				GameState.role_owner[i] = (GameState.role_owner[i] % GameState.players) + 1
				UISound.play_toggle(true)
				_refresh_roles())
			row.add_child(b)
		else:
			row.add_child(UIKit.pill("Asignado", col))
		_roles_box.add_child(card)

func _scenario_card(sc: Dictionary) -> Control:
	var accent_col := UIKit.ACCENT if sc["id"] == "s1" else (UIKit.REAL if sc["id"] == "s2" else UIKit.GAME)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, accent_col, 8, 16))
	
	var main_v := UIKit.vbox(10)
	p.add_child(main_v)
	
	# Fila superior: Nivel, Título y Vista previa de nave
	var top_row := UIKit.hbox(14)
	main_v.add_child(top_row)
	
	var left_v := UIKit.vbox(4)
	left_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(left_v)
	
	var badge_row := UIKit.hbox(8)
	badge_row.add_child(UIKit.eyebrow(sc["nivel"], accent_col))
	badge_row.add_child(UIKit.pill(str(sc["regimen"]).to_upper(), accent_col))
	left_v.add_child(badge_row)
	
	var name_lbl := UIKit.label(sc["nombre"], 22, UIKit.INK_BRIGHT)
	name_lbl.add_theme_font_override("font", UIKit.font_title())
	left_v.add_child(name_lbl)
	left_v.add_child(UIKit.label(sc["objetivo"], 13, UIKit.INK, true))
	
	# Vista previa 3D renderizada si existe
	var ref_tex := UIKit.preview_texture("ref_" + sc["id"])
	if ref_tex != null:
		var thumb_panel := UIKit.panel(UIKit.SUNKEN, UIKit.LINE, 4)
		var tex_rect := TextureRect.new()
		tex_rect.texture = ref_tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(120, 80)
		thumb_panel.add_child(tex_rect)
		top_row.add_child(thumb_panel)
	
	# Bloque de estadísticas con fuente monospace tabular
	var facts := UIKit.hbox(20)
	main_v.add_child(facts)
	for f in [["Presupuesto", UIKit.fmt_money(float(sc["presupuesto"]))],
			["Meta científica", "%d pts" % int(sc["meta_sp"])],
			["Duración de vuelo", "%d días" % int(sc["duracion_dias"])],
			["Plazo máximo", "%d meses" % int(sc["plazo_meses"])]]:
		var fv := UIKit.vbox(1)
		fv.add_child(UIKit.eyebrow(f[0]))
		var val_l := UIKit.label(f[1], 16, UIKit.INK_BRIGHT, false, true)
		fv.add_child(val_l)
		facts.add_child(fv)
	
	main_v.add_child(UIKit.sep())
	
	# Restricciones
	var rest := UIKit.vbox(3)
	for r in sc["restricciones"]:
		rest.add_child(UIKit.label("▸  " + r, 12, UIKit.MUTED, true))
	main_v.add_child(rest)
	
	# Botón de aceptación de contrato
	var row := UIKit.hbox(8)
	row.add_child(UIKit.spacer())
	var b := UIKit.button("Aceptar Contrato de Misión → CML 2", true)
	b.custom_minimum_size = Vector2(240, 42)
	b.pressed.connect(_accept.bind(sc["id"]))
	row.add_child(b)
	main_v.add_child(row)
	return p

func _accept(id: String) -> void:
	UISound.play_success()
	GameState.start_contract(id)
	main.goto_design()
