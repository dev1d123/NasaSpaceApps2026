extends Node
## CML 4 · Misión en curso: el diseño está congelado y se vuela. Simulación acelerada
## con eventos que piden decisiones al rol responsable.

const WARPS := [
	{"label": "⏸", "x": 0.0, "tip": "Pausa"},
	{"label": "1×", "x": 1.0, "tip": "Tiempo real"},
	{"label": "1m", "x": 60.0, "tip": "1 minuto por segundo"},
	{"label": "10m", "x": 600.0, "tip": "10 minutos por segundo"},
	{"label": "1h", "x": 3600.0, "tip": "1 hora por segundo"},
	{"label": "6h", "x": 21600.0, "tip": "6 horas por segundo"},
	{"label": "1d", "x": 86400.0, "tip": "1 día por segundo"},
	{"label": "MÁX", "x": -1.0, "tip": "Tan rápido como lo permita el equipo"},
]

var main: Node
var sim: MissionSim
var view: SpaceView
var warp := 600.0
var _root: Control
var _warp_row: HBoxContainer
var _time_l: Label
var _phase_l: Label
var _speed_l: Label
var _log: RichTextLabel
var _hud := {}
var _ins_checks := {}
var _modal: Control
var _hud_timer := 0.0
var _speed_acc := 0.0
var _speed_t := 0.0

func _ready() -> void:
	sim = MissionSim.new()
	sim.setup(GameState.design, {"seed": Time.get_ticks_usec(), "events": true})
	view = SpaceView.new()
	add_child(view)
	view.setup(sim)
	var ui := CanvasLayer.new()
	add_child(ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_root)
	var page := UIKit.vbox(10)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := UIKit.margin(page, 12)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(wrap)
	page.add_child(_top_bar())
	var body := UIKit.hbox(10)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)
	body.add_child(_left_panels())
	var mid := Control.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid)
	body.add_child(_log_panel())
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_modal)
	for e in sim.logs:
		_on_log(e)
	sim.log_added.connect(_on_log)
	_set_warp(warp)
	_refresh_hud()

# ---------------- Barra superior ----------------
func _top_bar() -> Control:
	var p := UIKit.panel(Color(UIKit.SURFACE, 0.92))
	var row := UIKit.hbox(14)
	p.add_child(row)
	var v := UIKit.vbox(0)
	v.add_child(UIKit.eyebrow("CML 4 · Misión en curso", UIKit.ACCENT))
	var name_l := UIKit.label(GameData.scenario(GameState.scn_id)["nombre"], 17)
	name_l.clip_text = true
	name_l.custom_minimum_size.x = 200
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(name_l)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var tv := UIKit.vbox(0)
	_time_l = UIKit.label("", 20)
	_phase_l = UIKit.label("", 12, UIKit.MUTED)
	tv.add_child(_time_l)
	tv.add_child(_phase_l)
	row.add_child(tv)
	_warp_row = UIKit.hbox(4)
	for w in WARPS:
		var b := UIKit.button(w["label"])
		b.toggle_mode = true
		b.tooltip_text = w["tip"]
		b.pressed.connect(_set_warp.bind(w["x"]))
		_warp_row.add_child(b)
	row.add_child(_warp_row)
	_speed_l = UIKit.label("", 12, UIKit.MUTED)
	_speed_l.custom_minimum_size.x = 84
	row.add_child(_speed_l)
	var focus := UIKit.button("Ver nave")
	focus.tooltip_text = "Alterna la cámara entre la órbita completa y la nave"
	focus.pressed.connect(func():
		view.toggle_focus()
		focus.text = "Ver órbita" if view.focus_craft else "Ver nave")
	row.add_child(focus)
	var abort := UIKit.button("Abortar")
	abort.tooltip_text = "Vuelve a CML 3 sin terminar el vuelo"
	abort.pressed.connect(func(): main.goto_design())
	row.add_child(abort)
	return p

func _set_warp(x: float) -> void:
	warp = x
	for i in WARPS.size():
		(_warp_row.get_child(i) as Button).button_pressed = WARPS[i]["x"] == x

# ---------------- Paneles por rol ----------------
func _role_panel(role: String) -> VBoxContainer:
	var p := UIKit.panel(Color(UIKit.SURFACE, 0.92), GameState.role_color(role).darkened(0.3), 10)
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.role_tag(role))
	_hud["panel_" + role] = p
	return v

func _left_panels() -> Control:
	var col := UIKit.vbox(8)
	var s := UIKit.scroll(col)
	s.custom_minimum_size.x = 360
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Lanzamiento
	var l := _role_panel("launch")
	_hud["orbit"] = UIKit.label("", 13, UIKit.INK, true)
	_hud["dv"] = UIKit.meter("Δv restante")
	l.add_child(_hud["orbit"])
	l.add_child(_hud["dv"]["root"])
	col.add_child(_hud["panel_launch"])
	# Sistemas
	var sy := _role_panel("space")
	_hud["bat"] = UIKit.meter("Batería")
	_hud["power"] = UIKit.label("", 13)
	_hud["state"] = UIKit.label("", 13)
	sy.add_child(_hud["bat"]["root"])
	sy.add_child(_hud["power"])
	sy.add_child(_hud["state"])
	col.add_child(_hud["panel_space"])
	# Comunicaciones
	var g := _role_panel("ground")
	_hud["link"] = UIKit.label("", 13, UIKit.INK, true)
	_hud["mem"] = UIKit.meter("Memoria a bordo")
	_hud["down"] = UIKit.label("", 13)
	g.add_child(_hud["link"])
	g.add_child(_hud["mem"]["root"])
	g.add_child(_hud["down"])
	col.add_child(_hud["panel_ground"])
	# Ciencia
	var u := _role_panel("user")
	_hud["sp"] = UIKit.meter("Ciencia en tierra / meta")
	u.add_child(_hud["sp"]["root"])
	for id in sim.design["ins"]:
		var cb := CheckButton.new()
		cb.text = GameData.by_id("instrumentos", id)["nombre"]
		cb.button_pressed = true
		cb.add_theme_font_size_override("font_size", 13)
		cb.toggled.connect(func(on): sim.ins_on[id] = on)
		_ins_checks[id] = cb
		u.add_child(cb)
	var dl := UIKit.label("", 12, UIKit.MUTED)
	var ds := HSlider.new()
	ds.min_value = 5
	ds.max_value = 100
	ds.step = 5
	ds.value = sim.duty * 100.0
	var upd := func(val: float): dl.text = "Ciclo de trabajo: %d %%" % int(val)
	upd.call(ds.value)
	ds.value_changed.connect(func(val):
		upd.call(val)
		sim.duty = val / 100.0)
	u.add_child(dl)
	u.add_child(ds)
	var gate := CheckBox.new()
	gate.text = "Instrumentos en espera durante eclipses"
	gate.add_theme_font_size_override("font_size", 13)
	gate.toggled.connect(func(on): sim.eclipse_gate = on)
	_hud["gate"] = gate
	u.add_child(gate)
	col.add_child(_hud["panel_user"])
	return s

func _log_panel() -> Control:
	var p := UIKit.panel(Color(UIKit.SURFACE, 0.92))
	p.custom_minimum_size.x = 360
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.eyebrow("Bitácora de misión"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	v.add_child(_log)
	return p

func _on_log(e: Dictionary) -> void:
	var col: Color = {"info": UIKit.MUTED, "good": UIKit.GOOD, "warn": UIKit.WARN, "bad": UIKit.BAD, "event": UIKit.ACCENT, "decision": UIKit.REAL}.get(e["kind"], UIKit.INK)
	_log.append_text("[color=#%s]%s[/color]  [color=#%s]%s[/color]\n" % [UIKit.MUTED.to_html(false), "D%.1f" % (e["t"] / 86400.0), (col as Color).to_html(false), e["text"]])

# ---------------- Bucle ----------------
func _process(delta: float) -> void:
	if sim.finished:
		if _modal.get_child_count() == 0:
			_show_end()
	elif not sim.pending_event.is_empty():
		if _modal.get_child_count() == 0:
			_show_event()
	elif warp != 0.0:
		var want := warp * delta if warp > 0.0 else 1e9
		var budget := 12000.0 if warp > 0.0 else 22000.0
		var done := sim.advance(want, budget)
		_speed_acc += done
	_speed_t += delta
	if _speed_t >= 0.5:
		var rate := _speed_acc / _speed_t
		_speed_l.text = "≈ %s" % _rate_text(rate)
		_speed_acc = 0.0
		_speed_t = 0.0
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.1
		_refresh_hud()

func _rate_text(r: float) -> String:
	if r <= 0.0:
		return "en pausa"
	if r >= 86400.0:
		return "%.1f días/s" % (r / 86400.0)
	if r >= 3600.0:
		return "%.1f h/s" % (r / 3600.0)
	if r >= 60.0:
		return "%.0f min/s" % (r / 60.0)
	return "%.0f×" % r

func _refresh_hud() -> void:
	var total := sim.t_end / 86400.0
	_time_l.text = UIKit.fmt_time(sim.t) + " / %d días" % int(total)
	var ph: String = {"crucero": "Crucero a la Luna", "ciencia": "Operaciones científicas", "fin": "Misión terminada"}.get(sim.phase, sim.phase)
	_phase_l.text = "%s · %s" % [ph, {"leo": "órbita terrestre baja", "llo": "órbita lunar baja polar", "nrho": "NRHO 9:2"}[sim.regime]]
	# Lanzamiento
	var orb := ""
	match sim.regime:
		"leo":
			orb = "Altitud %.1f km (objetivo %.0f km) · inclinación heliosíncrona" % [sim.altitude, sim.alt_target]
		"llo":
			if sim.phase == "crucero":
				orb = "Crucero: %s km de la Tierra · inserción en %.1f días" % [_k(sim.altitude), (sim.cruise_end - sim.t) / 86400.0]
			else:
				orb = "Altitud %.1f km · caída del periluna por mascones %.1f km · próximo mantenimiento en %.0f días" % [sim.altitude, sim.maint["drop_km"], (sim.maint["next"] - sim.t) / 86400.0]
		"nrho":
			if sim.phase == "crucero":
				orb = "Crucero: %s km de la Tierra · inserción en %.1f días" % [_k(sim.altitude), (sim.cruise_end - sim.t) / 86400.0]
			else:
				orb = "Distancia a la Luna %s km · error de órbita %.1f km (se duplica cada ≈7 días sin mantenimiento)" % [_k(sim.altitude + Astro.R_M), sim.maint["err_km"]]
	_hud["orbit"].text = orb
	var dvl := sim.dv_left()
	var dv0 := float(sim.ev["dv"])
	UIKit.set_meter(_hud["dv"], (dvl / dv0) if dv0 > 0 else 0.0, "%.0f m/s · %.2f kg" % [dvl, sim.prop_kg], UIKit.GOOD if dvl > 50 or dv0 == 0 else UIKit.WARN)
	# Sistemas
	var frac := sim.energy / maxf(sim.cap_wh, 0.001)
	var dod := sim.dod_override if sim.dod_override > 0.0 else sim.dod_max
	UIKit.set_meter(_hud["bat"], frac, "%.0f / %.0f Wh" % [sim.energy, sim.cap_wh], UIKit.GOOD if frac > 1.0 - dod + 0.05 else UIKit.WARN if frac > 1.0 - dod else UIKit.BAD)
	var sun_txt := "al Sol" if sim.sun_f > 0.99 else ("en eclipse" if sim.sun_f < 0.01 else "penumbra %.0f %%" % (sim.sun_f * 100.0))
	_hud["power"].text = "Generación %.0f W · carga %.0f W · %s" % [sim.gen_w, sim.load_w, sun_txt]
	var st := "Normal"
	var st_col := UIKit.GOOD
	if sim.in_safe():
		st = "MODO SEGURO: " + sim.safe_reason
		st_col = UIKit.BAD
	elif sim.shed:
		st = "Corte de carga: instrumentos en espera"
		st_col = UIKit.WARN
	_hud["state"].text = "Estado: %s · capacidad %.0f %%" % [st, sim.cap_wh / sim.cap_wh0 * 100.0]
	_hud["state"].add_theme_color_override("font_color", st_col)
	# Comunicaciones
	if sim.in_contact:
		_hud["link"].text = "● En contacto con %s · %s" % [sim.contact_station, _mbps(sim.link_mbps)]
		_hud["link"].add_theme_color_override("font_color", UIKit.GOOD)
	else:
		_hud["link"].text = "○ Sin contacto" + (" · antena sin desplegar" if sim.mod_active("antenna_stowed") else "")
		_hud["link"].add_theme_color_override("font_color", UIKit.MUTED)
	var mu := sim.mem_used() / maxf(sim.mem_max, 1.0)
	UIKit.set_meter(_hud["mem"], mu, "%s / %s" % [DesignEval.fmt_mb(sim.mem_used()), DesignEval.fmt_mb(sim.mem_max)], UIKit.GOOD if mu < 0.7 else UIKit.WARN if mu < 0.98 else UIKit.BAD)
	_hud["down"].text = "En tierra %s · perdidos %s" % [DesignEval.fmt_mb(sim.mb_down), DesignEval.fmt_mb(sim.ledger["mb_perdidos"])]
	# Ciencia
	var meta := float(sim.sc["meta_sp"])
	UIKit.set_meter(_hud["sp"], sim.sp / meta, "%.0f / %.0f pts" % [sim.sp, meta], UIKit.GOOD if sim.sp >= meta else UIKit.REAL)
	for id in _ins_checks:
		var cb: CheckButton = _ins_checks[id]
		var active := sim._instrument_active(id)
		cb.add_theme_color_override("font_color", UIKit.INK if active else UIKit.MUTED)
		cb.add_theme_color_override("font_pressed_color", UIKit.INK if active else UIKit.MUTED)
	(_hud["gate"] as CheckBox).set_pressed_no_signal(sim.eclipse_gate)

func _k(km: float) -> String:
	return "%.0f" % km if km < 10000.0 else "%.0f mil" % (km / 1000.0)

func _mbps(r: float) -> String:
	return "%.0f Mbps" % r if r >= 1.0 else "%.1f kbps" % (r * 1000.0)

# ---------------- Modales ----------------
func _modal_panel(border: Color) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := UIKit.panel(UIKit.SURFACE, border, 22)
	p.custom_minimum_size.x = 640
	center.add_child(p)
	var v := UIKit.vbox(10)
	p.add_child(v)
	return v

func _close_modal() -> void:
	for c in _modal.get_children():
		c.queue_free()

func _show_event() -> void:
	var rec := sim.pending_event
	var v := _modal_panel(UIKit.ACCENT)
	var top := UIKit.hbox(8)
	top.add_child(UIKit.eyebrow("Evento · %s" % UIKit.fmt_time(sim.t), UIKit.ACCENT))
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.label("Decide:", 12, UIKit.MUTED))
	top.add_child(UIKit.role_tag(rec["role"]))
	v.add_child(top)
	v.add_child(UIKit.label(rec["nombre"], 26, UIKit.INK, true))
	v.add_child(UIKit.label("Cuándo: " + rec["cuando"], 13, UIKit.MUTED, true))
	v.add_child(UIKit.label("Impacto: " + rec["impacto"], 15, UIKit.INK, true))
	v.add_child(UIKit.sep())
	var acts := MissionEvents.actions(sim, rec)
	for i in acts.size():
		var a: Dictionary = acts[i]
		var b := UIKit.button(a["text"] if a["ok"] else a["text"] + "   (" + a["why"] + ")", i == 0 and a["ok"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 40
		b.disabled = not a["ok"]
		b.pressed.connect(func():
			sim.resolve_event(i)
			_close_modal())
		v.add_child(b)

func _show_end() -> void:
	var v := _modal_panel(UIKit.BAD if sim.lost else UIKit.GOOD)
	v.add_child(UIKit.eyebrow("Fin de CML 4", UIKit.BAD if sim.lost else UIKit.GOOD))
	v.add_child(UIKit.label("Nave perdida" if sim.lost else "Misión completada", 30))
	if sim.lost:
		v.add_child(UIKit.label(sim.lost_reason.substr(0, 1).to_upper() + sim.lost_reason.substr(1) + ".", 16, UIKit.BAD, true))
	v.add_child(UIKit.label("Ciencia en tierra: %.0f de %.0f puntos de meta · %s descargados." % [sim.sp, float(sim.sc["meta_sp"]), DesignEval.fmt_mb(sim.mb_down)], 16, UIKit.INK, true))
	var row := UIKit.hbox(8)
	row.add_child(UIKit.spacer())
	var b := UIKit.button("Ver debriefing →", true)
	b.pressed.connect(func(): main.goto_debrief(sim))
	row.add_child(b)
	v.add_child(row)
