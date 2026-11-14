extends Node
## CML 2–3 · Ingeniería concurrente. Cada rol tiene su pestaña; los medidores se
## recalculan con cada cambio y la puerta a CML 4 son las ocho verificaciones en verde.

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
var _dialog_layer: Control
var _root: Control

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

	var page := UIKit.vbox(12)
	var wrap := UIKit.margin(page, 16)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wrap)
	page.add_child(_header())
	var body := UIKit.hbox(14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.x = 450
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
	var row := UIKit.hbox(16)
	var back := UIKit.button("← Contratos")
	back.pressed.connect(func(): main.goto_menu())
	row.add_child(back)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.eyebrow("CML 2–3 · Ingeniería concurrente · intento %d" % (GameState.attempt + 1), UIKit.ACCENT))
	v.add_child(UIKit.label(sc["nombre"], 24))
	var obj := UIKit.label(sc["objetivo"], 13, UIKit.MUTED, true)
	obj.tooltip_text = "Restricciones:\n• " + "\n• ".join(PackedStringArray(sc["restricciones"]))
	obj.mouse_filter = Control.MOUSE_FILTER_STOP
	v.add_child(obj)
	row.add_child(v)
	var ref := UIKit.button("Cargar diseño de referencia")
	ref.tooltip_text = "Diseño de referencia del GDD: pasa las 8 verificaciones. Útil para aprender; luego mejóralo."
	ref.pressed.connect(func():
		GameState.load_reference()
		d = GameState.design
		_build_tabs()
		_refresh())
	row.add_child(ref)
	return row

# ---------------- Centro: vista previa 3D ----------------
func _center() -> Control:
	var v := UIKit.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := UIKit.panel(UIKit.SUNKEN, UIKit.LINE, 0)
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
	var en := Environment.new()
	en.background_mode = Environment.BG_COLOR
	en.background_color = Color("#0a0e1a")
	en.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	en.ambient_light_color = Color("#56627e")
	en.ambient_light_energy = 0.6
	env.environment = en
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.6, 0)
	sun.light_energy = 1.2
	world.add_child(sun)
	var grid := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	grid.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#141b2e")
	gm.roughness = 1.0
	grid.material_override = gm
	grid.position.y = -3.5
	grid.name = "Suelo"
	world.add_child(grid)
	_model = SpacecraftModel.new()
	world.add_child(_model)
	# Persona de 1.8 m como referencia de escala (greybox).
	var person := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.22
	cap.height = 1.8
	person.mesh = cap
	person.material_override = SpacecraftModel.mat(Color("#6b7385"))
	person.name = "Persona"
	world.add_child(person)
	_preview_cam = OrbitCamera.new()
	_preview_cam.auto_rotate = 0.25
	_preview_cam.pitch = 0.3
	_preview_cam.min_distance = 0.3
	world.add_child(_preview_cam)
	var hint := UIKit.label("Arrastra para girar · rueda para acercar · la figura gris mide 1.8 m", 12, UIKit.MUTED)
	v.add_child(hint)
	_ficha = UIKit.label("", 13, UIKit.INK, true)
	v.add_child(_ficha)
	return v

func _update_preview() -> void:
	_model.build(d)
	var b := _model.bounds
	var size := maxf(b.get_longest_axis_size(), 0.3)
	var person: Node3D = _model.get_parent().get_node("Persona")
	person.position = Vector3(b.end.x + 0.6 + size * 0.1, b.position.y + 0.9, 0)
	(_model.get_parent().get_node("Suelo") as Node3D).position.y = minf(b.position.y, 0.0) - 0.05
	_preview_cam.target = Vector3(b.get_center().x * 0.5 + (person.position.x * 0.2), b.get_center().y, 0)
	_preview_cam.set_distance(maxf(size, 2.0) * 1.9)

# ---------------- Derecha: verificaciones ----------------
func _right() -> Control:
	var p := UIKit.panel()
	p.custom_minimum_size.x = 410
	var v := UIKit.vbox(10)
	var sc_box := UIKit.scroll(v)
	sc_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var outer := UIKit.vbox(10)
	outer.add_child(sc_box)
	p.add_child(outer)
	v.add_child(UIKit.eyebrow("Puerta de CML 3: las 8 verificaciones"))
	_pills = GridContainer.new()
	_pills.columns = 2
	_pills.add_theme_constant_override("h_separation", 6)
	_pills.add_theme_constant_override("v_separation", 6)
	v.add_child(_pills)
	v.add_child(UIKit.sep())
	for k in [["masa", "Masa húmeda / máximo del bus"], ["potencia", "Potencia media: carga / generación"], ["eclipse", "Eclipse: energía / batería útil"],
			["dv", "Δv: requerido / disponible"], ["costo", "Costo / presupuesto"], ["plazo", "Plazo: meses / límite"],
			["datos", "Datos: bajada / generados por día"], ["ciencia", "Ciencia estimada / meta"]]:
		var m := UIKit.meter(k[1])
		v.add_child(m["root"])
		_meters[k[0]] = m
	v.add_child(UIKit.sep())
	v.add_child(UIKit.eyebrow("Por qué"))
	_why = UIKit.vbox(4)
	v.add_child(_why)
	_fly = UIKit.button("Congelar diseño y volar → CML 4", true)
	_fly.custom_minimum_size.y = 46
	_fly.pressed.connect(_freeze)
	outer.add_child(_fly)
	return p

# ---------------- Pestañas por rol ----------------
func _build_tabs() -> void:
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_add_tab("launch", "Lanzamiento", _tab_launch())
	_add_tab("space", "Sistemas", _tab_space())
	_add_tab("ground", "Comunicaciones", _tab_ground())
	_add_tab("user", "Ciencia", _tab_user())

func _add_tab(role: String, title: String, content: Control) -> void:
	var v := UIKit.vbox(10)
	v.add_child(UIKit.role_tag(role))
	v.add_child(content)
	var s := UIKit.scroll(UIKit.margin(v, 4))
	s.name = title
	_tabs.add_child(s)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)

func _field(title: String, help: String = "") -> VBoxContainer:
	var v := UIKit.vbox(4)
	v.add_child(UIKit.eyebrow(title))
	if help != "":
		v.add_child(UIKit.label(help, 12, UIKit.MUTED, true))
	return v

## Desplegable de catálogo. items: [{id, text, tip}]
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
	o.item_selected.connect(func(idx): on_change.call(items[idx]["id"]))
	return o

func _fits_tag(item: Dictionary) -> String:
	var bus := GameData.by_id("estructuras", d["bus"])
	return "" if GameData.fits(item, bus["clase"]) else "  ✕ no cabe en " + str(bus["clase"])

func _tab_launch() -> Control:
	var v := UIKit.vbox(14)
	var f := _field("Perfil de órbita o trayectoria")
	var items: Array = []
	for p in sc["perfiles"]:
		items.append({"id": p["id"], "text": p["nombre"], "tip": "Δv %d m/s · sol %.0f %% · eclipse %.0f min" % [p["dv"], p["f_sol"] * 100.0, p["eclipse_min"]]})
	f.add_child(_option(items, d["perfil"], func(id): _change(func(): d["perfil"] = id)))
	var pf := GameData.profile(sc, d["perfil"])
	f.add_child(UIKit.label("Δv requerido %d m/s · %.0f %% del tiempo al sol · eclipse más largo %.1f min" % [pf["dv"], pf["f_sol"] * 100.0, pf["eclipse_min"]], 12, UIKit.MUTED, true))
	v.add_child(f)

	var f2 := _field("Lanzador", "Capacidad hasta el destino del contrato (%s)." % str(sc["destino"]).replace("_kg", "").to_upper())
	var lvs: Array = []
	for id in sc["lanzadores"]:
		var lv := GameData.by_id("lanzadores", id)
		var cap: Variant = lv.get(sc["destino"])
		var cost_txt := UIKit.fmt_money(float(lv["costo"])) if lv.get("costo") != null else "%.0f $/kg" % (float(lv["costo_por_kg"]) * 1e6)
		var cap_txt := ("%s kg" % _thousands(float(cap))) if cap != null else "no llega"
		lvs.append({"id": id, "text": "%s · %s · %s" % [lv["nombre"], cap_txt, cost_txt], "tip": lv["nota"]})
	f2.add_child(_option(lvs, d["lv"], func(id): _change(func(): d["lv"] = id)))
	var lv_sel := GameData.by_id("lanzadores", d["lv"])
	f2.add_child(UIKit.label("%s Fiabilidad %d %% · espera %d meses." % [lv_sel["nota"], lv_sel["fiabilidad"], lv_sel["espera_meses"]], 12, UIKit.MUTED, true))
	v.add_child(f2)
	v.add_child(UIKit.label("Tú quieres menos masa; todos los demás roles añaden masa. Cada kg extra cuesta propelente (Tsiolkovski) y capacidad del lanzador.", 12, UIKit.GAME, true))
	return v

func _tab_space() -> Control:
	var v := UIKit.vbox(14)
	var f := _field("Estructura (bus)")
	var items: Array = []
	for b in GameData.list("estructuras"):
		items.append({"id": b["id"], "text": "%s · carga ≤ %s kg · %s" % [b["nombre"], _thousands(float(b["carga_max_kg"])), UIKit.fmt_money(float(b["costo"]))],
			"tip": "%s\nSeca %s kg · máx. %s kg · %d W base · %d GB · %d meses" % [b["ancla"], b["masa_seca"], b["masa_max_kg"], b["potencia_base_w"], b["memoria_gb"], b["desarrollo_meses"]]})
	f.add_child(_option(items, d["bus"], func(id): _change(func(): d["bus"] = id, true)))
	v.add_child(f)

	var f2 := _field("Paneles solares", "Potencia al inicio de vida a 1 UA; −2 % por año.")
	items = []
	for p in GameData.list("paneles"):
		items.append({"id": p["id"], "text": "%s · %d W · %s%s" % [p["nombre"], p["potencia_w"], UIKit.fmt_money(float(p["costo"])), _fits_tag(p)], "tip": "%.2f kg · eficiencia %.1f %%" % [p["masa"], float(p["eficiencia"]) * 100.0]})
	f2.add_child(_option(items, d["pan"], func(id): _change(func(): d["pan"] = id)))
	v.add_child(f2)

	var f3 := _field("Batería Li-ion", "La DoD segura depende de los ciclos: ≈5 500 eclipses al año en LEO.")
	items = []
	for b in GameData.list("baterias"):
		items.append({"id": b["id"], "text": "%s · %.1f kg · %s%s" % [b["nombre"], b["masa"], UIKit.fmt_money(float(b["costo"])), _fits_tag(b)], "tip": "DoD LEO %d %% · DoD alto %d %%" % [b["dod_leo"] * 100, b["dod_alto"] * 100]})
	f3.add_child(_option(items, d["bat"], func(id): _change(func(): d["bat"] = id)))
	v.add_child(f3)

	var f4 := _field("Propulsión")
	items = []
	for p in GameData.list("propulsion"):
		var t: String = p["nombre"] if p["id"] == "none" else "%s · Isp %d s · %s%s" % [p["nombre"], p["isp_s"], UIKit.fmt_money(float(p["costo"])), _fits_tag(p)]
		items.append({"id": p["id"], "text": t, "tip": "%s · empuje %s N · tanque %s kg · %d W" % [p["tipo"], p["empuje_n"], p["tanque_kg"], p["potencia_w"]]})
	f4.add_child(_option(items, d["prop"], func(id): _change(func():
		d["prop"] = id
		d["propKg"] = minf(float(d["propKg"]), float(GameData.by_id("propulsion", id)["tanque_kg"])), true)))
	var prop := GameData.by_id("propulsion", d["prop"])
	if float(prop["tanque_kg"]) > 0.0:
		var lbl := UIKit.label("", 13)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = float(prop["tanque_kg"])
		sl.step = 0.5 if float(prop["tanque_kg"]) >= 10.0 else 0.05
		sl.value = float(d["propKg"])
		var upd := func(val: float):
			lbl.text = "Propelente cargado: %.2f kg de %s kg" % [val, prop["tanque_kg"]]
		upd.call(sl.value)
		sl.value_changed.connect(func(val):
			upd.call(val)
			_change(func(): d["propKg"] = val))
		f4.add_child(lbl)
		f4.add_child(sl)
	v.add_child(f4)

	var f5 := _field("Redundancia (opcional)")
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
	v.add_child(UIKit.label("Tú quieres margen; el investigador principal quiere encenderlo todo.", 12, UIKit.GAME, true))
	return v

func _tab_ground() -> Control:
	var v := UIKit.vbox(14)
	var f := _field("Antena de la nave")
	var items: Array = []
	var rk := "mbps_" + str(sc["regimen"])
	for c in GameData.list("comunicaciones"):
		var r := float(c.get(rk, 0.0))
		items.append({"id": c["id"], "text": "%s · %s · %s%s" % [c["nombre"], _rate(r), UIKit.fmt_money(float(c["costo"])), _fits_tag(c)],
			"tip": "Banda %s · %d W · %.1f kg · antena terrena: %s" % [c["banda"], c["potencia_w"], c["masa"], c["antena_tierra"]]})
	f.add_child(_option(items, d["com"], func(id): _change(func(): d["com"] = id, true)))
	v.add_child(f)

	var f2 := _field("Contacto contratado: %s" % sc["bloque"], "Cada bloque suma estaciones o tiempo de antena. El simulador calcula la visibilidad real con la geometría de la órbita (máscara de 10°).")
	var plan: Array = GameData.STATION_PLAN[sc["id"]]
	var lbl := UIKit.label("", 13, UIKit.INK, true)
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
				names.append("Universidad propia" if plan[i] == "uni" else GameData.by_id("estaciones", plan[i])["nombre"])
			lbl.text = "%d bloque(s): %s · %s/año" % [n, ", ".join(PackedStringArray(names)), UIKit.fmt_money(float(sc["estacion_anual"]) * n)]
	upd.call(int(sl.value))
	sl.value_changed.connect(func(val):
		upd.call(int(val))
		_change(func(): d["bloques"] = int(val)))
	f2.add_child(lbl)
	f2.add_child(sl)
	v.add_child(f2)

	if plan.has("uni"):
		var f3 := _field("Latitud de tu estación universitaria", "Las estaciones polares ven casi todas las órbitas polares; las de latitud media, pocas pasadas.")
		var l3 := UIKit.label("", 13)
		var s3 := HSlider.new()
		s3.min_value = -70
		s3.max_value = 70
		s3.step = 1
		s3.value = float(d.get("uni_lat", 40.4))
		var u3 := func(val: float): l3.text = "Latitud %.0f°" % val
		u3.call(s3.value)
		s3.value_changed.connect(func(val):
			u3.call(val)
			d["uni_lat"] = val)
		f3.add_child(l3)
		f3.add_child(s3)
		v.add_child(f3)
	v.add_child(UIKit.label("Tú quieres menos datos o más antena; el investigador principal quiere más instrumentos.", 12, UIKit.GAME, true))
	return v

func _tab_user() -> Control:
	var v := UIKit.vbox(12)
	var pf := GameData.profile(sc, d["perfil"])
	var rel := DesignEval.relevance(sc, pf)
	var f := _field("Instrumentos", "Puntos por MB = pts/h ÷ MB/h. Solo cuentan los datos que llegan a tierra.")
	for i in GameData.list("instrumentos"):
		var row := UIKit.vbox(0)
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
		row.add_child(cb)
		row.add_child(UIKit.label("     %.1f kg · %.1f W · %s/h · %s pts/h · ciclo máx. %d %% · %s" % [i["masa"], i["activo_w"], DesignEval.fmt_mb(float(i["mb_h"])), i["sp_h"], float(i["ciclo_max"]) * 100.0, UIKit.fmt_money(float(i["costo"]))], 11, UIKit.MUTED))
		f.add_child(row)
	v.add_child(f)
	var f2 := _field("Ciclo de trabajo de los instrumentos")
	var l2 := UIKit.label("", 13)
	var s2 := HSlider.new()
	s2.min_value = 5
	s2.max_value = 100
	s2.step = 5
	s2.value = float(d["duty"])
	var u2 := func(val: float): l2.text = "%d %% del tiempo activos (sin pasar el máximo de cada uno)" % int(val)
	u2.call(s2.value)
	s2.value_changed.connect(func(val):
		u2.call(val)
		_change(func(): d["duty"] = val))
	f2.add_child(l2)
	f2.add_child(s2)
	v.add_child(f2)
	var f3 := _field("Segmento de usuario: nivel de procesamiento")
	var items: Array = []
	for u in GameData.list("usuario"):
		items.append({"id": u["id"], "text": "%s · ×%.2f ciencia · %s/año" % [u["nombre"], u["mult_ciencia"], UIKit.fmt_money(float(u["costo_anual"]))], "tip": u["efecto"]})
	f3.add_child(_option(items, d.get("usuario", "l1"), func(id): _change(func(): d["usuario"] = id)))
	v.add_child(f3)
	v.add_child(UIKit.label("★ = relevancia del instrumento para la pregunta científica de este contrato.", 12, UIKit.MUTED, true))
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

# ---------------- Cambios y negociación ----------------
## Aplica un cambio. Si con varios jugadores sube el costo más de un 10 % del fondo,
## pide el visto bueno de otro rol (GDD, regla de negociación).
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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(dim)
	var p := UIKit.panel(UIKit.SURFACE, UIKit.ACCENT, 20)
	p.custom_minimum_size = Vector2(520, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	dim.add_child(p)
	var v := UIKit.vbox(12)
	p.add_child(v)
	v.add_child(UIKit.eyebrow("Decisión mayor", UIKit.ACCENT))
	v.add_child(UIKit.label("Este cambio suma %s, más del 10 %% del fondo común (%s)." % [UIKit.fmt_money(delta), UIKit.fmt_money(float(sc["presupuesto"]))], 18, UIKit.INK, true))
	v.add_child(UIKit.label("Explíquenlo en voz alta: ¿qué gana la misión? Otro rol debe dar el visto bueno.", 14, UIKit.MUTED, true))
	var row := UIKit.hbox(8)
	var ok := UIKit.button("Otro rol lo aprueba", true)
	var solo := UIKit.button("Aplicar sin consenso")
	var cancel := UIKit.button("Cancelar")
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

# ---------------- Refresco ----------------
func _refresh() -> void:
	e = DesignEval.evaluate(d)
	GameState.design = d
	for c in _pills.get_children():
		c.queue_free()
	for k in DesignEval.CHECK_ORDER:
		var ck: Dictionary = e["checks"][k]
		_pills.add_child(UIKit.pill(("✓ " if ck["ok"] else "✕ ") + ck["txt"], UIKit.GOOD if ck["ok"] else UIKit.BAD))
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
		_why.add_child(UIKit.label("• " + line, 13, UIKit.INK, true))
	_fly.disabled = not e["all_ok"] or (d["ins"] as Array).is_empty()
	_fly.tooltip_text = "" if not _fly.disabled else "Necesitas las 8 verificaciones en verde y al menos un instrumento."
	_ficha.text = "Seca %.1f kg · propelente %.1f kg · Δv %.0f m/s · hardware %s · lanzamiento %s · operaciones %s · lista en %d meses" % [e["dry"], e["prop_kg"], e["dv"], UIKit.fmt_money(e["hw"]), UIKit.fmt_money(e["lv_cost"]), UIKit.fmt_money(e["ops"]), e["months"]]
	_update_preview()

## Medidor donde el valor es «uso / capacidad»: rojo si la verificación falla.
func _m(key: String, frac: float, text: String, ok: bool) -> void:
	var col := UIKit.GOOD if ok else UIKit.BAD
	if ok and frac > 0.9:
		col = UIKit.WARN
	UIKit.set_meter(_meters[key], frac, text, col)

func _freeze() -> void:
	GameState.design = d.duplicate(true)
	GameState.attempt += 1
	main.goto_mission()
