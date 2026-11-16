extends Node
## Resultados y Debriefing Oficial estilo JPL / NASA Mission Directorate.
## Evaluación forense de cuellos de botella, desglose de colaboración y comparación histórica.

const UISound = preload("res://scripts/ui/ui_sound.gd")
const UIParticles = preload("res://scripts/ui/ui_particles.gd")

var main: Node
var sim: MissionSim

func _ready() -> void:
	var score := Scoring.compute(sim, sim.design, GameState.players, GameState.major_decisions, GameState.approved_decisions)
	var ev := DesignEval.evaluate(sim.design)
	var match_m := Scoring.match_mission(sim.design, ev)
	var necks := Scoring.bottlenecks(sim)
	GameState.history.append({"intento": GameState.attempt, "puntaje": score["total"], "sp": sim.sp, "perdida": sim.lost})
	GameState.last_result = score
	if score["failed"]:
		UISound.play_alert()
	else:
		UISound.play_success()

	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	ui.add_child(root)
	
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	
	# Polvo estelar sutil de fondo
	var dust := UIParticles.create_space_dust(Vector2(1600, 900), 30)
	root.add_child(dust)
	
	var page := UIKit.vbox(14)
	var wrap := UIKit.margin(UIKit.scroll(page), 22)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)

	# Cabecera Ejecutiva de Misión
	var head := UIKit.hbox(20)
	page.add_child(head)
	
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var top_eyebrow := UIKit.hbox(8)
	top_eyebrow.add_child(UIKit.eyebrow("Informe Oficial de Misión · Debriefing CML 4", UIKit.ACCENT))
	top_eyebrow.add_child(UIKit.pill("Intento %d" % GameState.attempt, UIKit.ACCENT))
	hv.add_child(top_eyebrow)
	
	var title_lbl := UIKit.label(sim.sc["nombre"], 26, UIKit.INK_BRIGHT)
	title_lbl.add_theme_font_override("font", UIKit.font_title())
	hv.add_child(title_lbl)
	
	var verdict := "Nave perdida: " + _cap(sim.lost_reason) if sim.lost else ("Meta científica cumplida con éxito" if sim.sp >= float(sim.sc["meta_sp"]) else "Misión completada (objetivo científico parcial)")
	hv.add_child(UIKit.label(verdict, 15, UIKit.BAD if score["failed"] else UIKit.GOOD, true))
	head.add_child(hv)
	
	# Sello de Puntuación Ejecutiva
	var big := UIKit.vbox(0)
	var grade_txt := "CLASE A" if score["total"] >= 90 else ("CLASE B" if score["total"] >= 75 else ("CLASE C" if score["total"] >= 50 else "ANOMALÍA"))
	big.add_child(UIKit.eyebrow("Puntuación Global · " + grade_txt, UIKit.GOOD if not score["failed"] else UIKit.BAD))
	
	var score_lbl := UIKit.label("%.0f" % score["total"], 60, UIKit.BAD if score["failed"] else UIKit.ACCENT, false, true)
	big.add_child(score_lbl)
	if score["failed"]:
		big.add_child(UIKit.label("Tope en 40 pts por pérdida de nave", 11, UIKit.BAD))
	head.add_child(big)

	var cols := UIKit.hbox(16)
	page.add_child(cols)
	
	var left := UIKit.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	var right := UIKit.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)

	# Desglose de Componentes del Puntaje (C, E, R, K)
	var comp := PanelContainer.new()
	comp.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, UIKit.ACCENT, 6, 12))
	var cv := UIKit.vbox(8)
	comp.add_child(cv)
	cv.add_child(UIKit.eyebrow("Ecuación de Evaluación: 100 · (0.50·C + 0.20·E + 0.15·R + 0.15·K)"))
	_bar(cv, "C · Retorno Científico (%.0f de %.0f SP meta)" % [sim.sp, float(sim.sc["meta_sp"])], score["C"] / 1.2, "%.2f" % score["C"])
	_bar(cv, "E · Eficiencia de Recursos (%.0f %% remanente · %.0f %% masa · %.0f %% prop)" % [score["unspent"] * 100.0, score["margin"] * 100.0, score["prop_frac"] * 100.0], score["E"], "%.2f" % score["E"])
	_bar(cv, "R · Mitigación de Riesgos (%d de %d eventos resueltos · %d modo seguro evitable)" % [score["events_good"], score["events_total"], sim.avoidable_safe], score["R"], "%.2f" % score["R"])
	var k_txt := "K · Colaboración de Equipo (en solitario K = R)" if GameState.players <= 1 else "K · Colaboración (%d de %d decisiones mayores consensuadas)" % [GameState.approved_decisions, GameState.major_decisions]
	_bar(cv, k_txt, score["K"], "%.2f" % score["K"])
	cv.add_child(UIKit.label("Inversión total: %s de %s autorizados (incluye %s por imprevistos en vuelo)." % [UIKit.fmt_money(score["spent"]), UIKit.fmt_money(float(sim.sc["presupuesto"])), UIKit.fmt_money(sim.cost_extra)], 12, UIKit.MUTED, true))
	left.add_child(comp)

	# Libro de Cuellos de Botella (Análisis de Causa Raíz)
	var np := PanelContainer.new()
	np.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, UIKit.GAME, 6, 12))
	var nv := UIKit.vbox(10)
	np.add_child(nv)
	nv.add_child(UIKit.eyebrow("Análisis de Cuellos de Botella · Causa Raíz"))
	var shown := 0
	for n in necks:
		if n["severidad"] < 0.01 and shown > 0:
			continue
		shown += 1
		var box := UIKit.vbox(3)
		var row := UIKit.hbox(8)
		var col := UIKit.BAD if n["severidad"] > 0.3 else UIKit.WARN if n["severidad"] > 0.05 else UIKit.GOOD
		var tl := UIKit.label(n["que_mide"], 15, col, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		row.add_child(UIKit.label(_val(n), 14, col, false, true))
		box.add_child(row)
		if n["severidad"] >= 0.01:
			box.add_child(UIKit.label("Decisión de diseño: " + _cause(n["contador"], ev), 12, UIKit.INK, true))
			box.add_child(UIKit.label("Lección de ingeniería: " + n["leccion"], 12, UIKit.GAME, true))
		nv.add_child(box)
		if shown >= 4:
			break
	if necks[0]["severidad"] < 0.01:
		nv.add_child(UIKit.label("Ningún subsistema estranguló la ciencia de forma crítica. Optimiza costo y masa para maximizar eficiencia.", 13, UIKit.GOOD, true))
	left.add_child(np)

	# Decisiones e Incidencias en Vuelo
	var ep := PanelContainer.new()
	ep.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, UIKit.REAL, 6, 12))
	var evv := UIKit.vbox(8)
	ep.add_child(evv)
	evv.add_child(UIKit.eyebrow("Resolución de Incidencias Operativas"))
	if sim.event_records.is_empty():
		evv.add_child(UIKit.label("Vuelo nominal sin incidencias de riesgo.", 12, UIKit.MUTED))
	for r in sim.event_records:
		var rv := UIKit.vbox(2)
		var rr := UIKit.hbox(8)
		rr.add_child(UIKit.label("Día %.0f" % (r["t"] / 86400.0), 12, UIKit.MUTED, false, true))
		var nl := UIKit.label(r["nombre"], 13, UIKit.INK_BRIGHT, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(nl)
		rr.add_child(UIKit.pill("Bien Resuelto" if r["good"] else "Con Costo", UIKit.GOOD if r["good"] else UIKit.WARN))
		rv.add_child(rr)
		if r["action"] >= 0:
			rv.add_child(UIKit.label("→ %s. %s" % [r["acciones"][r["action"]], r["outcome"]], 11, UIKit.MUTED, true))
		evv.add_child(rv)
	left.add_child(ep)

	# Misión Real de la NASA Más Parecida
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, UIKit.REAL, 6, 14))
	var mv := UIKit.vbox(6)
	mp.add_child(mv)
	var m: Dictionary = match_m["mision"]
	mv.add_child(UIKit.eyebrow("Misión Histórica de la NASA Más Parecida · %d %% Coincidencia" % match_m["parecido"], UIKit.REAL))
	
	var m_name := UIKit.label("%s (%d)" % [m["nombre"], m["anio"]], 22, UIKit.INK_BRIGHT)
	m_name.add_theme_font_override("font", UIKit.font_title())
	mv.add_child(m_name)
	mv.add_child(UIKit.label("%s kg · %s · %s" % [m["masa_kg"], m["orbita"], m["lanzador"]], 12, UIKit.MUTED, true, true))
	mv.add_child(UIKit.label(m["dato"], 13, UIKit.INK, true))
	mv.add_child(UIKit.label("Tu nave diseñada: %.0f kg · %s · %s." % [ev["wet"], ev["pf"]["nombre"], ev["lv"]["nombre"]], 12, UIKit.MUTED, true, true))
	if m["costo_musd"] != null:
		mv.add_child(UIKit.label("Costo real histórico: %s · Tu presupuesto: %s" % [UIKit.fmt_money(float(m["costo_musd"])), UIKit.fmt_money(score["spent"])], 12, UIKit.MUTED, true, true))
	right.add_child(mp)

	# Métricas del Vuelo Físico
	var fp := PanelContainer.new()
	fp.add_theme_stylebox_override("panel", UIKit.card_box(UIKit.SURFACE_GLASS, UIKit.LINE, 6, 10))
	var fv := UIKit.vbox(4)
	fp.add_child(fv)
	fv.add_child(UIKit.eyebrow("Telemetría Acumulada de la Simulación"))
	var s := sim.summary()
	for line in [
		"Pases de antena medios: %.1f min/día (CML 3 proyectaba %.0f min)" % [s["contact_min_day"], ev["contact_min"]],
		"Fracción solar media: %.0f %% (Proyección GDD: %.0f %%)" % [s["sun_frac"] * 100.0, float(ev["pf"]["f_sol"]) * 100.0],
		"Datos científicos: generados %s · en tierra %s" % [DesignEval.fmt_mb(s["mb_gen"]), DesignEval.fmt_mb(s["mb_down"])],
		"Maniobras orbitales: Δv usado %.1f m/s · restante %.0f m/s" % [s["dv_used"], s["dv_left"]],
		"Degradación de baterías al final: capacidad %.0f %%" % (s["cap_frac"] * 100.0),
	]:
		fv.add_child(UIKit.label("▸  " + line, 12, UIKit.INK, true, true))
	right.add_child(fp)

	# Historial de Intentos
	if GameState.history.size() > 1:
		var hp := PanelContainer.new()
		hp.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE_GLASS, UIKit.LINE, 6, 10))
		var hvv := UIKit.vbox(3)
		hp.add_child(hvv)
		hvv.add_child(UIKit.eyebrow("Historial de Iteraciones en este Contrato"))
		for h in GameState.history:
			hvv.add_child(UIKit.label("Intento %d: %.0f pts · %.0f SP ciencia%s" % [h["intento"], h["puntaje"], h["sp"], " (Nave perdida)" if h["perdida"] else ""], 12, UIKit.INK, false, true))
		right.add_child(hp)

	var btns := UIKit.hbox(10)
	var redo := UIKit.button("← Rediseñar (Regresar a CML 3)", true)
	redo.custom_minimum_size = Vector2(230, 42)
	redo.pressed.connect(func(): main.goto_design())
	
	var menu := UIKit.button("Nuevo Contrato de Misión")
	menu.custom_minimum_size = Vector2(200, 42)
	menu.pressed.connect(func(): main.goto_menu())
	
	btns.add_child(redo)
	btns.add_child(menu)
	right.add_child(btns)
	right.add_child(UIKit.label("El método JPL de Ingeniería Concurrente contempla la retroalimentación de CML 4 a CML 3 tras cada prueba de vuelo.", 11, UIKit.MUTED, true))

func _bar(parent: Control, title_txt: String, frac: float, text: String) -> void:
	var m := UIKit.meter(title_txt)
	UIKit.set_meter(m, frac, text, UIKit.GOOD if frac >= 0.7 else UIKit.WARN if frac >= 0.4 else UIKit.BAD)
	parent.add_child(m["root"])

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s.length() > 0 else s

func _val(n: Dictionary) -> String:
	var v := float(n["valor"])
	if n["unidad"] == "MB":
		return DesignEval.fmt_mb(v)
	return "%.0f %s" % [v, n["unidad"]]

func _cause(key: String, ev: Dictionary) -> String:
	var d: Dictionary = sim.design
	match key:
		"h_sin_energia":
			return "Paneles «%s» (%d W) y batería «%s» (%d Wh) para una carga media de %.0f W." % [ev["pan"]["nombre"], ev["pan"]["potencia_w"], ev["bat"]["nombre"], ev["bat"]["capacidad_wh"], ev["load"]]
		"mb_perdidos":
			return "Generas %s/día y la antena «%s» con %d bloque(s) descarga %s/día." % [DesignEval.fmt_mb(ev["gen_mb"]), ev["com"]["nombre"], d["bloques"], DesignEval.fmt_mb(ev["down"])]
		"h_sin_contacto":
			var names: Array = []
			for st in sim._stations:
				names.append(st["nombre"])
			return "Estaciones contratadas: %s. Contacto real: %.1f min/día." % [", ".join(PackedStringArray(names)), sim.summary()["contact_min_day"]]
		"dv_faltante":
			return "Propulsión «%s» con %.1f kg de propelente (Δv disponible %.0f m/s)." % [ev["prop"]["nombre"], ev["prop_kg"], ev["dv"]]
		"h_modo_seguro":
			var ex: Array = d.get("extras", [])
			return "Redundancia: %s; decisiones operativas ante eventos de vuelo." % ("ninguna" if ex.is_empty() else ", ".join(PackedStringArray(ex)))
		"sp_fuera_objetivo":
			var rel := DesignEval.relevance(sim.sc, sim.pf)
			var low: Array = []
			for i in d["ins"]:
				if float(rel.get(i, 0.0)) < 1.0:
					low.append(GameData.by_id("instrumentos", i)["nombre"])
			return "Instrumentos con baja relevancia para este contrato: %s." % ", ".join(PackedStringArray(low))
	return ""
