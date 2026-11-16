extends Node
## CML 4 · Centro de Operaciones de Misión y Telemetría de Vuelo en Tiempo Real.
## Consola de teleoperaciones estilo JPL: reloj MET digital, indicadores de subsistemas
## con código de color por rol, enlace con estaciones terrestres y alarmas de vuelo.

const WARPS := [
	{"label": "❚❚", "x": 0.0, "tip": "Pausa"},
	{"label": "1×", "x": 1.0, "tip": "Tiempo real"},
	{"label": "1m", "x": 60.0, "tip": "1 minuto por segundo"},
	{"label": "10m", "x": 600.0, "tip": "10 minutos por segundo"},
	{"label": "1h", "x": 3600.0, "tip": "1 hora por segundo"},
	{"label": "6h", "x": 21600.0, "tip": "6 horas por segundo"},
	{"label": "1d", "x": 86400.0, "tip": "1 día por segundo"},
	{"label": "MÁX", "x": -1.0, "tip": "Velocidad máxima de cómputo"},
]

const UISound = preload("res://scripts/ui/ui_sound.gd")
const UIParticles = preload("res://scripts/ui/ui_particles.gd")

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
var _in_alarm := false

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
	
	var page := UIKit.vbox(8)
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
	
	# Espacio central transparente para el visor 3D
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

# ---------------- Barra Superior de Teleoperaciones ----------------
func _top_bar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE_GLASS, UIKit.LINE, 6, 10))
	var row := UIKit.hbox(14)
	p.add_child(row)
	
	var v := UIKit.vbox(1)
	v.add_child(UIKit.eyebrow("Centro de Operaciones de Vuelo · CML 4", UIKit.ACCENT))
	var name_l := UIKit.label(GameData.scenario(GameState.scn_id)["nombre"], 18, UIKit.INK_BRIGHT)
	name_l.add_theme_font_override("font", UIKit.font_title())
	name_l.clip_text = true
	name_l.custom_minimum_size.x = 220
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(name_l)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	
	# Reloj Digital MET (Mission Elapsed Time)
	var tv := UIKit.vbox(1)
	_time_l = UIKit.label("", 19, UIKit.INK_BRIGHT, false, true)
	_phase_l = UIKit.label("", 11, UIKit.MUTED)
	tv.add_child(_time_l)
	tv.add_child(_phase_l)
	row.add_child(tv)
	
	# Selector de Compresión Temporal (Warp)
	_warp_row = UIKit.hbox(3)
	for w in WARPS:
		var b := UIKit.button(w["label"])
		b.custom_minimum_size = Vector2(40, 34)
		b.toggle_mode = true
		b.tooltip_text = w["tip"]
		b.pressed.connect(func():
			_set_warp(w["x"])
			UISound.play_toggle(w["x"] > 0.0))
		_warp_row.add_child(b)
	row.add_child(_warp_row)
	
	_speed_l = UIKit.label("", 11, UIKit.MUTED, false, true)
	_speed_l.custom_minimum_size.x = 88
	row.add_child(_speed_l)
	
	var focus := UIKit.button("Ver Nave")
	focus.custom_minimum_size = Vector2(96, 34)
	focus.tooltip_text = "Alterna la cámara entre la trayectoria orbital global y la nave espacial"
	focus.pressed.connect(func():
		view.toggle_focus()
		focus.text = "Ver Órbita" if view.focus_craft else "Ver Nave")
	row.add_child(focus)
	
	var abort := UIKit.button("Abortar")
	abort.custom_minimum_size = Vector2(80, 34)
	abort.tooltip_text = "Regresa a la mesa de diseño CML 3 sin concluir el vuelo"
	abort.pressed.connect(func():
		if main and main.has_method("trigger_alarm"):
			main.trigger_alarm(false)
		main.goto_design())
	row.add_child(abort)
	return p

func _set_warp(x: float) -> void:
	warp = x
	for i in WARPS.size():
		(_warp_row.get_child(i) as Button).button_pressed = WARPS[i]["x"] == x

# ---------------- Paneles de Telemetría por Rol ----------------
func _role_panel(role: String) -> VBoxContainer:
	var col: Color = GameState.role_color(role)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, col, 6, 10))
	var v := UIKit.vbox(5)
	p.add_child(v)
	v.add_child(UIKit.role_tag(role))
	_hud["panel_" + role] = p
	return v

func _left_panels() -> Control:
	var col := UIKit.vbox(8)
	var s := UIKit.scroll(col)
	s.custom_minimum_size.x = 380
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Subsistema: Lanzamiento / Dinámica Orbital
	var l := _role_panel("launch")
	_hud["orbit"] = UIKit.label("", 12, UIKit.INK, true, true)
	_hud["dv"] = UIKit.meter("Δv y Propelente Restante")
	l.add_child(_hud["orbit"])
	l.add_child(_hud["dv"]["root"])
	col.add_child(_hud["panel_launch"])
	
	# Subsistema: Sistemas y Energía
	var sy := _role_panel("space")
	_hud["bat"] = UIKit.meter("Batería de a Bordo (Wh)")
	_hud["power"] = UIKit.label("", 12, UIKit.INK, true, true)
	_hud["state"] = UIKit.label("", 12, UIKit.GOOD, true)
	sy.add_child(_hud["bat"]["root"])
	sy.add_child(_hud["power"])
	sy.add_child(_hud["state"])
	col.add_child(_hud["panel_space"])
	
	# Subsistema: Comunicaciones Terrestres
	var g := _role_panel("ground")
	_hud["link"] = UIKit.label("", 12, UIKit.INK, true)
	_hud["mem"] = UIKit.meter("Buffer de Memoria SSR")
	_hud["down"] = UIKit.label("", 12, UIKit.INK, false, true)
	g.add_child(_hud["link"])
	g.add_child(_hud["mem"]["root"])
	g.add_child(_hud["down"])
	col.add_child(_hud["panel_ground"])
	
	# Subsistema: Carga Útil y Ciencia
	var u := _role_panel("user")
	_hud["sp"] = UIKit.meter("Ciencia en Tierra / Meta SP")
	u.add_child(_hud["sp"]["root"])
	
	var ins_box := UIKit.vbox(2)
	u.add_child(ins_box)
	for id in sim.design["ins"]:
		var cb := CheckButton.new()
		cb.text = GameData.by_id("instrumentos", id)["nombre"]
		cb.button_pressed = true
		cb.add_theme_font_size_override("font_size", 12)
		cb.toggled.connect(func(on):
			sim.ins_on[id] = on
			UISound.play_toggle(on))
		_ins_checks[id] = cb
		ins_box.add_child(cb)
		
	var dl := UIKit.label("", 11, UIKit.MUTED, false, true)
	var ds := HSlider.new()
	ds.min_value = 5
	ds.max_value = 100
	ds.step = 5
	ds.value = sim.duty * 100.0
	var upd := func(val: float): dl.text = "Ciclo de trabajo activo: %d %%" % int(val)
	upd.call(ds.value)
	ds.value_changed.connect(func(val):
		upd.call(val)
		sim.duty = val / 100.0)
	u.add_child(dl)
	u.add_child(ds)
	
	var gate := CheckBox.new()
	gate.text = "Modo reposo durante eclipses (ahorro de batería)"
	gate.add_theme_font_size_override("font_size", 11)
	gate.toggled.connect(func(on):
		sim.eclipse_gate = on
		UISound.play_toggle(on))
	_hud["gate"] = gate
	u.add_child(gate)
	col.add_child(_hud["panel_user"])
	return s

# ---------------- Bitácora de Misión ----------------
func _log_panel() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE_GLASS, UIKit.LINE, 6, 10))
	p.custom_minimum_size.x = 380
	var v := UIKit.vbox(6)
	p.add_child(v)
	v.add_child(UIKit.eyebrow("Bitácora de Telemetría"))
	
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_override("normal_font", UIKit.font_mono())
	_log.add_theme_font_size_override("normal_font_size", 11)
	_log.add_theme_font_size_override("bold_font_size", 11)
	v.add_child(_log)
	return p

func _on_log(e: Dictionary) -> void:
	var kind: String = e.get("kind", "")
	if kind == "bad":
		UISound.play_alert()
	elif kind == "warn":
		UISound.play_warning()
	elif kind == "good":
		UISound.play_quindar()
	elif kind == "event":
		UISound.play_relay()
	var col: Color = {"info": UIKit.MUTED, "good": UIKit.GOOD, "warn": UIKit.WARN, "bad": UIKit.BAD, "event": UIKit.ACCENT, "decision": UIKit.REAL}.get(e["kind"], UIKit.INK)
	_log.append_text("[color=#%s]%s[/color]  [color=#%s]%s[/color]\n" % [UIKit.MUTED.to_html(false), "D%.1f" % (e["t"] / 86400.0), (col as Color).to_html(false), e["text"]])

# ---------------- Bucle Principal de Simulación ----------------
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
	_time_l.text = UIKit.fmt_met(sim.t) + " · META: %d d" % int(total)
	
	var ph: String = {"crucero": "Crucero a la Luna", "ciencia": "Operaciones Científicas Nominales", "fin": "Misión Finalizada"}.get(sim.phase, sim.phase)
	_phase_l.text = "%s · %s" % [ph.to_upper(), {"leo": "Órbita Terrestre Baja (LEO)", "llo": "Órbita Lunar Baja Polar", "nrho": "Órbita NRHO Lunar 9:2"}.get(sim.regime, sim.regime)]
	
	# Dinámica Orbital y Propelente
	var orb := ""
	match sim.regime:
		"leo":
			orb = "Altitud: %.1f km (Objetivo %.0f km) · Inclinación heliosíncrona" % [sim.altitude, sim.alt_target]
		"llo":
			if sim.phase == "crucero":
				orb = "Crucero: %s km de la Tierra · Inserción lunar en %.1f días" % [_k(sim.altitude), (sim.cruise_end - sim.t) / 86400.0]
			else:
				orb = "Altitud: %.1f km · Descenso por mascones: %.1f km · Mantenimiento en %.0f d" % [sim.altitude, sim.maint["drop_km"], (sim.maint["next"] - sim.t) / 86400.0]
		"nrho":
			if sim.phase == "crucero":
				orb = "Crucero: %s km de la Tierra · Inserción en %.1f días" % [_k(sim.altitude), (sim.cruise_end - sim.t) / 86400.0]
			else:
				orb = "Distancia lunar: %s km · Error orbital: %.1f km" % [_k(sim.altitude + Astro.R_M), sim.maint["err_km"]]
	_hud["orbit"].text = orb
	
	var dvl := sim.dv_left()
	var dv0 := float(sim.ev["dv"])
	UIKit.set_meter(_hud["dv"], (dvl / dv0) if dv0 > 0 else 0.0, "%.0f m/s (%.2f kg)" % [dvl, sim.prop_kg], UIKit.GOOD if dvl > 50 or dv0 == 0 else UIKit.WARN)
	
	# Energía y Baterías
	var frac := sim.energy / maxf(sim.cap_wh, 0.001)
	var dod := sim.dod_override if sim.dod_override > 0.0 else sim.dod_max
	UIKit.set_meter(_hud["bat"], frac, "%.0f / %.0f Wh" % [sim.energy, sim.cap_wh], UIKit.GOOD if frac > 1.0 - dod + 0.05 else UIKit.WARN if frac > 1.0 - dod else UIKit.BAD)
	
	var sun_txt := "☀ Al Sol" if sim.sun_f > 0.99 else ("● En eclipse" if sim.sun_f < 0.01 else "◐ Penumbra %.0f %%" % (sim.sun_f * 100.0))
	_hud["power"].text = "Generación %.0f W · Consumo %.0f W · %s" % [sim.gen_w, sim.load_w, sun_txt]
	
	var st := "NOMINAL"
	var st_col := UIKit.GOOD
	var is_alarm := false
	if sim.in_safe():
		st = "ALERTA MODO SEGURO: " + sim.safe_reason.to_upper()
		st_col = UIKit.BAD
		is_alarm = true
	elif sim.shed:
		st = "PRECAUCIÓN: Corte de carga instrumental activo"
		st_col = UIKit.WARN
		
	if is_alarm != _in_alarm:
		_in_alarm = is_alarm
		if main and main.has_method("trigger_alarm"):
			main.trigger_alarm(is_alarm)
		if is_alarm:
			UISound.play_warning()
			
	_hud["state"].text = "Estado: %s · Salud celda %.0f %%" % [st, sim.cap_wh / sim.cap_wh0 * 100.0]
	_hud["state"].add_theme_color_override("font_color", st_col)
	
	# Comunicaciones y Enlace
	if sim.in_contact:
		_hud["link"].text = "● EN CONTACTO: %s · %s" % [sim.contact_station.to_upper(), _mbps(sim.link_mbps)]
		_hud["link"].add_theme_color_override("font_color", UIKit.GOOD)
	else:
		_hud["link"].text = "○ FUERA DE COBERTURA TERRESTRE" + (" (Antena no desplegada)" if sim.mod_active("antenna_stowed") else "")
		_hud["link"].add_theme_color_override("font_color", UIKit.MUTED)
		
	var mu := sim.mem_used() / maxf(sim.mem_max, 1.0)
	UIKit.set_meter(_hud["mem"], mu, "%s / %s" % [DesignEval.fmt_mb(sim.mem_used()), DesignEval.fmt_mb(sim.mem_max)], UIKit.GOOD if mu < 0.7 else UIKit.WARN if mu < 0.98 else UIKit.BAD)
	_hud["down"].text = "Descargados: %s · Sobrescritos: %s" % [DesignEval.fmt_mb(sim.mb_down), DesignEval.fmt_mb(sim.ledger["mb_perdidos"])]
	
	# Ciencia y Puntos SP
	var meta := float(sim.sc["meta_sp"])
	UIKit.set_meter(_hud["sp"], sim.sp / meta, "%.0f / %.0f SP" % [sim.sp, meta], UIKit.GOOD if sim.sp >= meta else UIKit.REAL)
	
	for id in _ins_checks:
		var cb: CheckButton = _ins_checks[id]
		var active := sim._instrument_active(id)
		cb.add_theme_color_override("font_color", UIKit.INK_BRIGHT if active else UIKit.MUTED)
		cb.add_theme_color_override("font_pressed_color", UIKit.INK_BRIGHT if active else UIKit.MUTED)
	(_hud["gate"] as CheckBox).set_pressed_no_signal(sim.eclipse_gate)

func _k(km: float) -> String:
	return "%.0f" % km if km < 10000.0 else "%.0f mil" % (km / 1000.0)

func _mbps(r: float) -> String:
	return "%.0f Mbps" % r if r >= 1.0 else "%.1f kbps" % (r * 1000.0)

# ---------------- Ventanas Modales de Eventos y Fin de Vuelo ----------------
func _modal_panel(border: Color) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE, border, 8, 22))
	p.custom_minimum_size.x = 640
	center.add_child(p)
	var v := UIKit.vbox(10)
	p.add_child(v)
	return v

func _close_modal() -> void:
	for c in _modal.get_children():
		c.queue_free()

func _show_event() -> void:
	UISound.play_alert()
	var rec := sim.pending_event
	var v := _modal_panel(UIKit.ACCENT)
	
	var top := UIKit.hbox(8)
	top.add_child(UIKit.eyebrow("Incidencia en Vuelo · %s" % UIKit.fmt_met(sim.t), UIKit.ACCENT))
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.label("Rol Responsable:", 12, UIKit.MUTED))
	top.add_child(UIKit.role_tag(rec["role"]))
	v.add_child(top)
	
	var title_lbl := UIKit.label(rec["nombre"], 24, UIKit.INK_BRIGHT)
	title_lbl.add_theme_font_override("font", UIKit.font_title())
	v.add_child(title_lbl)
	
	v.add_child(UIKit.label("Contexto de vuelo: " + rec["cuando"], 12, UIKit.MUTED, true))
	v.add_child(UIKit.label("Impacto en subsistemas: " + rec["impacto"], 14, UIKit.INK, true))
	v.add_child(UIKit.sep())
	
	var acts := MissionEvents.actions(sim, rec)
	for i in acts.size():
		var a: Dictionary = acts[i]
		var b := UIKit.button(a["text"] if a["ok"] else a["text"] + "   (" + a["why"] + ")", i == 0 and a["ok"])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.y = 44
		b.disabled = not a["ok"]
		b.pressed.connect(func():
			sim.resolve_event(i)
			_close_modal())
		v.add_child(b)

func _show_end() -> void:
	if sim.lost:
		UISound.play_warning()
	else:
		UISound.play_success()
		
	if main and main.has_method("trigger_alarm"):
		main.trigger_alarm(false)
		
	var v := _modal_panel(UIKit.BAD if sim.lost else UIKit.GOOD)
	v.add_child(UIKit.eyebrow("Fase de Operaciones Concluida", UIKit.BAD if sim.lost else UIKit.GOOD))
	
	var title_lbl := UIKit.label("Nave Perdida" if sim.lost else "Misión de Vuelo Exitosa", 28, UIKit.BAD if sim.lost else UIKit.GOOD)
	title_lbl.add_theme_font_override("font", UIKit.font_title())
	v.add_child(title_lbl)
	
	if sim.lost:
		v.add_child(UIKit.label(sim.lost_reason.substr(0, 1).to_upper() + sim.lost_reason.substr(1) + ".", 15, UIKit.BAD, true))
	v.add_child(UIKit.label("Ciencia descargada: %.0f de %.0f puntos de meta · %s recibidos en estaciones terrestres." % [sim.sp, float(sim.sc["meta_sp"]), DesignEval.fmt_mb(sim.mb_down)], 15, UIKit.INK, true, true))
	
	var row := UIKit.hbox(8)
	row.add_child(UIKit.spacer())
	var b := UIKit.button("Ver Informe y Debriefing Oficial →", true)
	b.custom_minimum_size = Vector2(260, 42)
	b.pressed.connect(func(): main.goto_debrief(sim))
	row.add_child(b)
	v.add_child(row)
