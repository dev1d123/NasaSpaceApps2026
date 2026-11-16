extends Node
## CML 2–3 · Ingeniería concurrente de alta fidelidad.
## Cada rol tiene su pestaña especializada; los medidores y el panel anunciador
## se recalculan con cada cambio y la puerta a CML 4 son las ocho verificaciones GO.

const UISound = preload("res://scripts/ui/ui_sound.gd")
const UIParticles = preload("res://scripts/ui/ui_particles.gd")

var main: Node
var d: Dictionary            # = GameState.design
var sc: Dictionary
var e: Dictionary            # evaluación actual

var _tabs: TabContainer
var _pills: GridContainer
var _meters := {}
var _why: VBoxContainer
var _fly: Button
var _model: SpacecraftModel
var _preview_cam: OrbitCamera
var _ficha: Label
var _dimensions_lbl: Label
var _dialog_layer: Control
var _root: Control
var _was_ready := false

# Contenedores de vista previa visual de componentes
var _previews := {}

func _ready() -> void:
	d = GameState.design
	sc = GameData.scenario(GameState.scn_id)
	var ui := CanvasLayer.new()
	add_child(ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.theme()
	ui.add_child(_root)
	
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var page := UIKit.vbox(10)
	var wrap := UIKit.margin(page, 14)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wrap)
	
	page.add_child(_header())
	var body := UIKit.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.x = 480
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	body.add_child(_center())
	body.add_child(_right())
	_build_tabs()

	_dialog_layer = Control.new()
	_dialog_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dialog_layer)
	_refresh()

# ---------------- Cabecera ----------------
func _header() -> Control:
	var row := UIKit.hbox(14)
	var back := UIKit.button("← Contratos")
	back.custom_minimum_size = Vector2(120, 36)
	back.pressed.connect(func(): main.goto_menu())
	row.add_child(back)
	
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var top_badge := UIKit.hbox(8)
	top_badge.add_child(UIKit.eyebrow("CML 2–3 · Mesa de Diseño Concurrente", UIKit.ACCENT))
	top_badge.add_child(UIKit.pill("Intento %d" % (GameState.attempt + 1), UIKit.ACCENT))
	top_badge.add_child(UIKit.pill(str(sc["regimen"]).to_upper(), UIKit.REAL))
	v.add_child(top_badge)
	
	var title_lbl := UIKit.label(sc["nombre"], 22, UIKit.INK_BRIGHT)
	title_lbl.add_theme_font_override("font", UIKit.font_title())
	v.add_child(title_lbl)
	
	var obj := UIKit.label(sc["objetivo"], 12, UIKit.MUTED, true)
	obj.tooltip_text = "Restricciones de misión:\n• " + "\n• ".join(PackedStringArray(sc["restricciones"]))
	obj.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(obj)
	row.add_child(v)
	
	var ref := UIKit.button("Cargar Diseño de Referencia")
	ref.tooltip_text = "Carga el diseño de referencia del GDD (cumple las 8 verificaciones). Útil para análisis y calibración."
	ref.pressed.connect(func():
		UISound.play_toggle(true)
		GameState.load_reference()
		d = GameState.design
		_build_tabs()
		_refresh())
	row.add_child(ref)
	return row

# ---------------- Centro: Visor 3D y HUD de Ensamblaje ----------------
func _center() -> Control:
	var v := UIKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.box(UIKit.SUNKEN, UIKit.LINE, 6, 0))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(frame)
	
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(svc)
	
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	svc.add_child(vp)
	
	var world := Node3D.new()
	vp.add_child(world)
	
	var env := WorldEnvironment.new()
	env.environment = SpacecraftModel.space_environment(Color("#080c16"), Color("#4a5570"), 0.65)
	world.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_energy = 1.3
	world.add_child(sun)
	
	var grid := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	grid.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#0f1526")
	gm.roughness = 0.95
	grid.material_override = gm
	grid.position.y = -3.5
	grid.name = "Suelo"
	world.add_child(grid)
	
	_model = SpacecraftModel.new()
	world.add_child(_model)
	
	# Técnico humano de 1.8 m como referencia de escala en sala limpia
	# Modelo de Blender (person_ref, origen en los pies); si falta, cápsula greybox.
	var person: Node3D = ModelLibrary.instance("person_ref")
	if person == null:
		var mi := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.22
		cap.height = 1.8
		mi.mesh = cap
		mi.position.y = 0.9
		mi.material_override = SpacecraftModel.mat(Color("#748099"))
		person = Node3D.new()
		person.add_child(mi)
	person.name = "Persona"
	world.add_child(person)
	
	_preview_cam = OrbitCamera.new()
	_preview_cam.auto_rotate = 0.22
	_preview_cam.pitch = 0.28
	_preview_cam.min_distance = 0.3
	world.add_child(_preview_cam)
	
	# HUD overlay flotante en el visor 3D
	var hud_bar := UIKit.hbox(12)
	hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dimensions_lbl = UIKit.label("CAD: – m", 11, UIKit.REAL, false, true)
	hud_bar.add_child(_dimensions_lbl)
	hud_bar.add_child(UIKit.spacer())
	hud_bar.add_child(UIKit.label("● ESCALA: TÉCNICO 1.8 m (ISO 7)", 11, UIKit.MUTED, false, true))
	var reticle_box := UIKit.margin(hud_bar, 10)
	reticle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reticle_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.add_child(reticle_box)
	
	var hint := UIKit.label("Arrastra para orbitar cámara · Rueda para zoom", 11, UIKit.MUTED)
	v.add_child(hint)
	
	_ficha = UIKit.label("", 12, UIKit.INK, true, true)
	v.add_child(_ficha)
	return v

func _update_preview() -> void:
	_model.build(d)
	var b := _model.bounds
	var size := maxf(b.get_longest_axis_size(), 0.3)
	var person: Node3D = _model.get_parent().get_node("Persona")
	person.position = Vector3(b.end.x + 0.6 + size * 0.1, minf(b.position.y, 0.0) - 0.05, 0)
	(_model.get_parent().get_node("Suelo") as Node3D).position.y = minf(b.position.y, 0.0) - 0.05
	_preview_cam.target = Vector3(b.get_center().x * 0.5 + (person.position.x * 0.2), b.get_center().y, 0)
	_preview_cam.set_distance(maxf(size, 2.0) * 1.9)
	
	if _dimensions_lbl != null:
		var sz := b.size
		_dimensions_lbl.text = "DIMENSIONES CAD: %.2f × %.2f × %.2f m" % [sz.x, sz.y, sz.z]

# ---------------- Derecha: Panel Anunciador de Verificaciones CML 3 ----------------
func _right() -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size.x = 420
	var v := UIKit.vbox(8)
	var sc_box := UIKit.scroll(v)
	sc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var outer := UIKit.vbox(10)
	outer.add_child(sc_box)
	p.add_child(outer)
	
	v.add_child(UIKit.eyebrow("Puerta de CML 3 · Panel Anunciador de Vuelo", UIKit.ACCENT))
	
	_pills = GridContainer.new()
	_pills.columns = 2
	_pills.add_theme_constant_override("h_separation", 6)
	_pills.add_theme_constant_override("v_separation", 6)
	v.add_child(_pills)
	v.add_child(UIKit.sep())
	
	for k in [["masa", "Masa húmeda / máximo del bus"], ["potencia", "Potencia media: carga / generación"],
			["eclipse", "Eclipse: energía / batería útil"], ["dv", "Δv: requerido / disponible"],
			["costo", "Costo / presupuesto"], ["plazo", "Plazo: meses / límite"],
			["datos", "Datos: bajada / generados por día"], ["ciencia", "Ciencia estimada / meta"]]:
		var m := UIKit.meter(k[1])
		v.add_child(m["root"])
		_meters[k[0]] = m
		
	v.add_child(UIKit.sep())
	v.add_child(UIKit.eyebrow("Diagnóstico de Ingeniería"))
	_why = UIKit.vbox(3)
	v.add_child(_why)
	
	_fly = UIKit.button("CONGELAR DISEÑO Y VOLAR → CML 4", true)
	_fly.custom_minimum_size.y = 48
	_fly.pressed.connect(_freeze)
	outer.add_child(_fly)
	return p

# ---------------- Pestañas por Rol ----------------
func _build_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_previews.clear()
	_add_tab("launch", "Lanzamiento", _tab_launch())
	_add_tab("space", "Sistemas", _tab_space())
	_add_tab("ground", "Comunicaciones", _tab_ground())
	_add_tab("user", "Ciencia", _tab_user())

func _add_tab(role: String, title_txt: String, content: Control) -> void:
	var v := UIKit.vbox(10)
	
	# Cabecera de la pestaña con rol y asignación de jugador
	var header_row := UIKit.hbox(8)
	header_row.add_child(UIKit.role_tag(role))
	var role_name := GameState.role_label(role)
	var title_lbl := UIKit.label(title_txt.to_upper(), 13, UIKit.INK_BRIGHT)
	title_lbl.add_theme_font_override("font", UIKit.font_title())
	header_row.add_child(title_lbl)
	header_row.add_child(UIKit.spacer())
	v.add_child(header_row)
	v.add_child(content)
	
	var s := UIKit.scroll(UIKit.margin(v, 4))
	s.name = title_txt
	_tabs.add_child(s)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title_txt)

func _field(title_txt: String, help: String = "") -> VBoxContainer:
	var v := UIKit.vbox(3)
	v.add_child(UIKit.eyebrow(title_txt))
	if help != "":
		v.add_child(UIKit.label(help, 11, UIKit.MUTED, true))
	return v

## Desplegable de catálogo con visor de miniatura 3D integrado
func _option_with_preview(items: Array, current: String, preview_key: String, on_change: Callable) -> Control:
	var h := UIKit.hbox(8)
	
	# Miniatura 3D
	var thumb := TextureRect.new()
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(44, 34)
	var tex := UIKit.preview_texture(current)
	if tex:
		thumb.texture = tex
	var thumb_box := UIKit.panel(UIKit.SUNKEN, UIKit.LINE, 2)
	thumb_box.add_child(thumb)
	h.add_child(thumb_box)
	_previews[preview_key] = thumb
	
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		o.add_item(items[i]["text"], i)
		o.set_item_tooltip(i, items[i].get("tip", ""))
		if items[i]["id"] == current:
			o.select(i)
	o.item_selected.connect(func(idx):
		var selected_id: String = items[idx]["id"]
		var new_tex := UIKit.preview_texture(selected_id)
		if new_tex and _previews.has(preview_key):
			(_previews[preview_key] as TextureRect).texture = new_tex
		UISound.play_relay()
		on_change.call(selected_id))
	h.add_child(o)
	return h

func _option(items: Array, current: String, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.fit_to_longest_item = false
	o.clip_text = true
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in items.size():
		o.add_item(items[i]["text"], i)
		o.set_item_tooltip(i, items[i].get("tip", ""))
		if items[i]["id"] == current:
			o.select(i)
	o.item_selected.connect(func(idx):
		UISound.play_relay()
		on_change.call(items[idx]["id"]))
	return o

func _fits_tag(item: Dictionary) -> String:
	var bus := GameData.by_id("estructuras", d["bus"])
	return "" if GameData.fits(item, bus["clase"]) else "  ✕ no cabe en " + str(bus["clase"])

# ---------- Pestaña: Lanzamiento ----------
func _tab_launch() -> Control:
	var v := UIKit.vbox(12)
	var f := _field("Perfil de Órbita o Trayectoria")
	var items: Array = []
	for p in sc["perfiles"]:
		items.append({"id": p["id"], "text": p["nombre"], "tip": "Δv %d m/s · sol %.0f %% · eclipse %.0f min" % [p["dv"], p["f_sol"] * 100.0, p["eclipse_min"]]})
	f.add_child(_option(items, d["perfil"], func(id): _change(func(): d["perfil"] = id)))
	var pf := GameData.profile(sc, d["perfil"])
	f.add_child(UIKit.label("Δv requerido: %d m/s · %.0f %% del tiempo al Sol · eclipse máximo: %.1f min" % [pf["dv"], pf["f_sol"] * 100.0, pf["eclipse_min"]], 11, UIKit.MUTED, true, true))
	v.add_child(f)

	var f2 := _field("Vehículo de Lanzamiento", "Capacidad hasta el destino (%s)." % str(sc["destino"]).replace("_kg", "").to_upper())
	var lvs: Array = []
	for id in sc["lanzadores"]:
		var lv := GameData.by_id("lanzadores", id)
		var cap: Variant = lv.get(sc["destino"])
		var cost_txt := UIKit.fmt_money(float(lv["costo"])) if lv.get("costo") != null else "%.0f $/kg" % (float(lv["costo_por_kg"]) * 1e6)
		var cap_txt := ("%s kg" % _thousands(float(cap))) if cap != null else "no llega"
		lvs.append({"id": id, "text": "%s · %s · %s" % [lv["nombre"], cap_txt, cost_txt], "tip": lv["nota"]})
	f2.add_child(_option(lvs, d["lv"], func(id): _change(func(): d["lv"] = id)))
	var lv_sel := GameData.by_id("lanzadores", d["lv"])
	f2.add_child(UIKit.label("%s Fiabilidad %d %% · espera %d meses." % [lv_sel["nota"], lv_sel["fiabilidad"], lv_sel["espera_meses"]], 11, UIKit.MUTED, true))
	v.add_child(f2)
	v.add_child(UIKit.label("El Director de Lanzamiento busca minimizar la masa total para garantizar margen de empuje (Tsiolkovski).", 11, UIKit.GAME, true))
	return v

# ---------- Pestaña: Sistemas ----------
func _tab_space() -> Control:
	var v := UIKit.vbox(12)
	
	var f := _field("Estructura de la Nave (Bus)")
	var items: Array = []
	for b in GameData.list("estructuras"):
		items.append({"id": b["id"], "text": "%s · carga ≤ %s kg · %s" % [b["nombre"], _thousands(float(b["carga_max_kg"])), UIKit.fmt_money(float(b["costo"]))],
			"tip": "%s\nSeca %s kg · máx. %s kg · %d W base · %d GB · %d meses" % [b["ancla"], b["masa_seca"], b["masa_max_kg"], b["potencia_base_w"], b["memoria_gb"], b["desarrollo_meses"]]})
	f.add_child(_option_with_preview(items, d["bus"], "bus", func(id): _change(func(): d["bus"] = id, true)))
	v.add_child(f)

	var f2 := _field("Arreglo Solar Fotovoltaico", "Generación eléctrica a 1 UA; decaimiento de −2 % anual.")
	items = []
	for p in GameData.list("paneles"):
		items.append({"id": p["id"], "text": "%s · %d W · %s%s" % [p["nombre"], p["potencia_w"], UIKit.fmt_money(float(p["costo"])), _fits_tag(p)], "tip": "%.2f kg · eficiencia %.1f %%" % [p["masa"], float(p["eficiencia"]) * 100.0]})
	f2.add_child(_option_with_preview(items, d["pan"], "pan", func(id): _change(func(): d["pan"] = id)))
	v.add_child(f2)

	var f3 := _field("Banco de Baterías Li-ion", "La profundidad de descarga (DoD) segura protege la vida útil de las celdas.")
	items = []
	for b in GameData.list("baterias"):
		items.append({"id": b["id"], "text": "%s · %.1f kg · %s%s" % [b["nombre"], b["masa"], UIKit.fmt_money(float(b["costo"])), _fits_tag(b)], "tip": "DoD LEO %d %% · DoD alto %d %%" % [b["dod_leo"] * 100, b["dod_alto"] * 100]})
	f3.add_child(_option(items, d["bat"], func(id): _change(func(): d["bat"] = id)))
	v.add_child(f3)

	var f4 := _field("Sistema de Propulsión y Maniobra Orbital")
	items = []
	for p in GameData.list("propulsion"):
		var t: String = p["nombre"] if p["id"] == "none" else "%s · Isp %d s · %s%s" % [p["nombre"], p["isp_s"], UIKit.fmt_money(float(p["costo"])), _fits_tag(p)]
		items.append({"id": p["id"], "text": t, "tip": "%s · empuje %s N · tanque %s kg · %d W" % [p["tipo"], p["empuje_n"], p["tanque_kg"], p["potencia_w"]]})
	f4.add_child(_option_with_preview(items, d["prop"], "prop", func(id): _change(func():
		d["prop"] = id
		d["propKg"] = minf(float(d["propKg"]), float(GameData.by_id("propulsion", id)["tanque_kg"])), true)))
	var prop := GameData.by_id("propulsion", d["prop"])
	if float(prop["tanque_kg"]) > 0.0:
		var lbl := UIKit.label("", 12, UIKit.INK, false, true)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = float(prop["tanque_kg"])
		sl.step = 0.5 if float(prop["tanque_kg"]) >= 10.0 else 0.05
		sl.value = float(d["propKg"])
		var upd := func(val: float):
			lbl.text = "Propelente cargado: %.2f kg de %s kg tanque" % [val, prop["tanque_kg"]]
		upd.call(sl.value)
		sl.value_changed.connect(func(val):
			upd.call(val)
			_change(func(): d["propKg"] = val))
		f4.add_child(lbl)
		f4.add_child(sl)
	v.add_child(f4)

	var f5 := _field("Redundancia de Subsistemas (Opcional)")
	for k in GameData.EXTRAS:
		var x: Dictionary = GameData.EXTRAS[k]
		var cb := CheckBox.new()
		cb.text = "%s · +%s · +%.0f kg" % [x["nombre"], UIKit.fmt_money(x["costo"]), x["masa"]]
		cb.tooltip_text = x["nota"]
		cb.button_pressed = (d["extras"] as Array).has(k)
		cb.toggled.connect(func(on): _change(func():
			var arr: Array = d["extras"]
			if on and not arr.has(k):
				arr.append(k)
			elif not on:
				arr.erase(k)))
		f5.add_child(cb)
	v.add_child(f5)
	v.add_child(UIKit.label("El Ingeniero de Sistemas defiende los márgenes de energía y masa.", 11, UIKit.GAME, true))
	return v

# ---------- Pestaña: Comunicaciones ----------
func _tab_ground() -> Control:
	var v := UIKit.vbox(12)
	var f := _field("Antena de Telecomunicaciones de la Nave")
	var items: Array = []
	var rk := "mbps_" + str(sc["regimen"])
	for c in GameData.list("comunicaciones"):
		var r := float(c.get(rk, 0.0))
		items.append({"id": c["id"], "text": "%s · %s · %s%s" % [c["nombre"], _rate(r), UIKit.fmt_money(float(c["costo"])), _fits_tag(c)],
			"tip": "Banda %s · %d W · %.1f kg · antena terrena: %s" % [c["banda"], c["potencia_w"], c["masa"], c["antena_tierra"]]})
	f.add_child(_option_with_preview(items, d["com"], "com", func(id): _change(func(): d["com"] = id, true)))
	v.add_child(f)

	var f2 := _field("Contacto Contratado: %s" % sc["bloque"], "Cada bloque añade estaciones o pases de antena con máscara de 10°.")
	var plan: Array = GameData.STATION_PLAN[sc["id"]]
	var lbl := UIKit.label("", 12, UIKit.INK, true, true)
	var sl := HSlider.new()
	sl.min_value = 1
	sl.max_value = 4
	sl.step = 1
	sl.value = int(d["bloques"])
	var upd := func(n: int):
		if sc["regimen"] == "lunar":
			lbl.text = "%d bloque(s) DSN de 2 h/día · %s/año" % [n, UIKit.fmt_money(float(sc["estacion_anual"]) * n)]
		else:
			var names: Array = []
			for i in n:
				names.append("Univ. Propia" if plan[i] == "uni" else GameData.by_id("estaciones", plan[i])["nombre"])
			lbl.text = "%d bloque(s): %s · %s/año" % [n, ", ".join(PackedStringArray(names)), UIKit.fmt_money(float(sc["estacion_anual"]) * n)]
	upd.call(int(sl.value))
	sl.value_changed.connect(func(val):
		upd.call(int(val))
		_change(func(): d["bloques"] = int(val)))
	f2.add_child(lbl)
	f2.add_child(sl)
	v.add_child(f2)

	if plan.has("uni"):
		var f3 := _field("Latitud de la Estación Terrena Universitaria", "Las estaciones en altas latitudes tienen más pases en órbitas polares.")
		var l3 := UIKit.label("", 12, UIKit.INK, false, true)
		var s3 := HSlider.new()
		s3.min_value = -70
		s3.max_value = 70
		s3.step = 1
		s3.value = float(d.get("uni_lat", 40.4))
		var u3 := func(val: float): l3.text = "Latitud de la estación: %.0f°" % val
		u3.call(s3.value)
		s3.value_changed.connect(func(val):
			u3.call(val)
			d["uni_lat"] = val)
		f3.add_child(l3)
		f3.add_child(s3)
		v.add_child(f3)
	v.add_child(UIKit.label("El Oficial de Comunicaciones evita que la memoria de a bordo se sature con datos sin descargar.", 11, UIKit.GAME, true))
	return v

# ---------- Pestaña: Ciencia ----------
func _tab_user() -> Control:
	var v := UIKit.vbox(10)
	var pf := GameData.profile(sc, d["perfil"])
	var rel := DesignEval.relevance(sc, pf)
	var f := _field("Instrumentos Científicos", "Solo otorgan puntos los datos que se descargan con éxito en las estaciones.")
	
	for i in GameData.list("instrumentos"):
		var card := UIKit.panel(UIKit.SUNKEN, UIKit.LINE, 6)
		var row := UIKit.hbox(8)
		card.add_child(row)
		
		# Miniatura del instrumento
		var inst_tex := UIKit.preview_texture(i["id"])
		if inst_tex:
			var tr := TextureRect.new()
			tr.texture = inst_tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(36, 28)
			row.add_child(tr)
			
		var info_v := UIKit.vbox(1)
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_v)
		
		var cb := CheckBox.new()
		var r := float(rel.get(i["id"], 0.0))
		cb.text = "%s  %s" % [i["nombre"], _stars(r)]
		cb.button_pressed = (d["ins"] as Array).has(i["id"])
		cb.tooltip_text = "%s\nObjetivos: %s" % [i["ref_real"], i["objetivos"]]
		var id: String = i["id"]
		cb.toggled.connect(func(on): _change(func():
			var arr: Array = d["ins"]
			if on and not arr.has(id):
				arr.append(id)
			elif not on:
				arr.erase(id), true))
		info_v.add_child(cb)
		info_v.add_child(UIKit.label("%.1f kg · %.1f W · %s/h · %s pts/h · ciclo máx. %d %% · %s" % [i["masa"], i["activo_w"], DesignEval.fmt_mb(float(i["mb_h"])), i["sp_h"], float(i["ciclo_max"]) * 100.0, UIKit.fmt_money(float(i["costo"]))], 10, UIKit.MUTED, false, true))
		f.add_child(card)
	v.add_child(f)

	var f2 := _field("Ciclo de Trabajo de los Instrumentos (Duty Cycle)")
	var l2 := UIKit.label("", 12, UIKit.INK, false, true)
	var s2 := HSlider.new()
	s2.min_value = 5
	s2.max_value = 100
	s2.step = 5
	s2.value = float(d["duty"])
	var u2 := func(val: float): l2.text = "%d %% del tiempo activos (limitado por el ciclo máx. individual)" % int(val)
	u2.call(s2.value)
	s2.value_changed.connect(func(val):
		u2.call(val)
		_change(func(): d["duty"] = val))
	f2.add_child(l2)
	f2.add_child(s2)
	v.add_child(f2)

	var f3 := _field("Nivel de Procesamiento de Datos Científicos")
	var items: Array = []
	for u in GameData.list("usuario"):
		items.append({"id": u["id"], "text": "%s · ×%.2f ciencia · %s/año" % [u["nombre"], u["mult_ciencia"], UIKit.fmt_money(float(u["costo_anual"]))], "tip": u["efecto"]})
	f3.add_child(_option(items, d.get("usuario", "l1"), func(id): _change(func(): d["usuario"] = id)))
	v.add_child(f3)
	v.add_child(UIKit.label("★ = Relevancia para las metas científicas del contrato.", 11, UIKit.MUTED, true))
	return v

func _stars(r: float) -> String:
	if r >= 1.0:
		return "★★★"
	if r >= 0.5:
		return "★★☆"
	if r > 0.0:
		return "★☆☆"
	return "☆☆☆"

func _rate(mbps: float) -> String:
	if mbps <= 0.0:
		return "sin enlace aquí"
	if mbps >= 1.0:
		return "%s Mbps" % _thousands(mbps)
	return "%.1f kbps" % (mbps * 1000.0)

func _thousands(x: float) -> String:
	var s := str(int(round(x)))
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var left := n - 1 - i
		if left > 0 and left % 3 == 0:
			out += " "
	return out

# ---------------- Cambios y Negociación ----------------
func _change(mutate: Callable, rebuild: bool = false) -> void:
	var before := d.duplicate(true)
	var cost_before: float = DesignEval.evaluate(d)["cost"]
	mutate.call()
	var cost_after: float = DesignEval.evaluate(d)["cost"]
	var budget := float(sc["presupuesto"])
	if GameState.players > 1 and cost_after - cost_before > 0.10 * budget:
		_ask_approval(before, cost_after - cost_before, rebuild)
		return
	if rebuild:
		_build_tabs_keep()
	_refresh()

func _build_tabs_keep() -> void:
	var idx := _tabs.current_tab
	_build_tabs()
	_tabs.current_tab = idx

func _ask_approval(before: Dictionary, delta: float, rebuild: bool) -> void:
	UISound.play_alert()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(dim)
	
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE, UIKit.ACCENT, 8, 20))
	p.custom_minimum_size = Vector2(540, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	dim.add_child(p)
	
	var v := UIKit.vbox(12)
	p.add_child(v)
	v.add_child(UIKit.eyebrow("Regla de Ingeniería Concurrente · Decisión Mayor", UIKit.ACCENT))
	
	var alert_title := UIKit.label("Compra Mayor al 10 % del Presupuesto", 20, UIKit.INK_BRIGHT)
	alert_title.add_theme_font_override("font", UIKit.font_title())
	v.add_child(alert_title)
	
	v.add_child(UIKit.label("Este cambio suma %s, superando el 10 %% del fondo común (%s)." % [UIKit.fmt_money(delta), UIKit.fmt_money(float(sc["presupuesto"]))], 15, UIKit.INK, true, true))
	v.add_child(UIKit.label("Debate en el equipo: ¿qué gana la misión y qué subsistemas deben ceder margen? Otro rol debe otorgar el visto bueno.", 13, UIKit.MUTED, true))
	
	var row := UIKit.hbox(8)
	var ok := UIKit.button("Consenso de Roles (Aprobar)", true)
	var solo := UIKit.button("Aplicar sin Consenso")
	var cancel := UIKit.button("Cancelar Cambio")
	row.add_child(ok)
	row.add_child(solo)
	row.add_child(UIKit.spacer())
	row.add_child(cancel)
	v.add_child(row)
	
	p.reset_size()
	p.position = (_root.size - p.size) * 0.5
	
	var close := func(apply: bool, approved: bool):
		dim.queue_free()
		if apply:
			GameState.major_decisions += 1
			if approved:
				GameState.approved_decisions += 1
		else:
			d.clear()
			d.merge(before)
		_build_tabs_keep()
		_refresh()
	ok.pressed.connect(func(): close.call(true, true))
	solo.pressed.connect(func(): close.call(true, false))
	cancel.pressed.connect(func(): close.call(false, false))

# ---------------- Refresco y Evaluación de la Puerta CML 3 ----------------
func _refresh() -> void:
	e = DesignEval.evaluate(d)
	GameState.design = d
	
	for c in _pills.get_children():
		c.queue_free()
	for k in DesignEval.CHECK_ORDER:
		var ck: Dictionary = e["checks"][k]
		_pills.add_child(UIKit.annunciator_tile(ck["txt"], ck["ok"]))
		
	var c: Dictionary = e["checks"]
	var bus: Dictionary = e["bus"]
	var cap_txt := "" if e["cap"] < 0 else " · lanzador %s kg" % _thousands(e["cap"])
	var mass_frac: float = e["wet"] / float(bus["masa_max_kg"])
	if e["cap"] > 0.0:
		mass_frac = maxf(mass_frac, e["wet"] / e["cap"])
	_m("masa", mass_frac, "%.1f / %s kg%s" % [e["wet"], _thousands(float(bus["masa_max_kg"])), cap_txt], c["masa"]["ok"] and c["lanzador"]["ok"])
	_m("potencia", e["load"] / maxf(e["gen"], 0.001), "%.0f / %.0f W" % [e["load"], e["gen"]], c["potencia"]["ok"])
	_m("eclipse", e["ecl_wh"] / maxf(e["bat_wh"], 0.001), "%.0f / %.0f Wh" % [e["ecl_wh"], e["bat_wh"]], c["eclipse"]["ok"])
	var dvreq := float(e["pf"]["dv"])
	_m("dv", (dvreq / e["dv"]) if e["dv"] > 0 else (0.0 if dvreq <= 0 else 1.0), "%.0f / %.0f m/s" % [dvreq, e["dv"]], c["dv"]["ok"])
	_m("costo", e["cost"] / float(sc["presupuesto"]), "%s / %s" % [UIKit.fmt_money(e["cost"]), UIKit.fmt_money(float(sc["presupuesto"]))], c["costo"]["ok"])
	_m("plazo", float(e["months"]) / float(sc["plazo_meses"]), "%d / %d meses" % [e["months"], sc["plazo_meses"]], c["plazo"]["ok"])
	var ratio: float = (e["down"] / e["gen_mb"]) if e["gen_mb"] > 0 else 1.0
	UIKit.set_meter(_meters["datos"], ratio, "%s / %s" % [DesignEval.fmt_mb(e["down"]), DesignEval.fmt_mb(e["gen_mb"])], UIKit.GOOD if ratio >= 1.0 else UIKit.WARN)
	var sci: float = e["sp"] / float(sc["meta_sp"])
	UIKit.set_meter(_meters["ciencia"], sci, "%s / %s pts" % [_thousands(e["sp"]), _thousands(float(sc["meta_sp"]))], UIKit.GOOD if sci >= 1.0 else UIKit.WARN)
	
	for w in _why.get_children():
		w.queue_free()
	for line in DesignEval.explain(e):
		_why.add_child(UIKit.label("▸  " + line, 12, UIKit.INK, true))
		
	var is_ready: bool = e["all_ok"] and not (d["ins"] as Array).is_empty()
	if is_ready and not _was_ready:
		UISound.play_success()
	_was_ready = is_ready
	
	_fly.disabled = not is_ready
	_fly.tooltip_text = "" if not _fly.disabled else "Requiere las 8 verificaciones GO en verde y al menos un instrumento montado."
	
	_ficha.text = "Seca %.1f kg · Propelente %.1f kg · Δv %.0f m/s · Hardware %s · Lanzamiento %s · Operaciones %s · Listo en %d meses" % [e["dry"], e["prop_kg"], e["dv"], UIKit.fmt_money(e["hw"]), UIKit.fmt_money(e["lv_cost"]), UIKit.fmt_money(e["ops"]), e["months"]]
	_update_preview()

func _m(key: String, frac: float, text: String, ok: bool) -> void:
	var col := UIKit.GOOD if ok else UIKit.BAD
	if ok and frac > 0.9:
		col = UIKit.WARN
	UIKit.set_meter(_meters[key], frac, text, col)

func _freeze() -> void:
	UISound.play_success()
	GameState.design = d.duplicate(true)
	GameState.attempt += 1
	main.goto_mission()
