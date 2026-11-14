extends Node
## Resultados y debriefing: puntaje, causa principal (libro de cuellos de botella),
## decisiones durante el vuelo y la misión real de la NASA más parecida.

var main: Node
var sim: MissionSim

func _ready() -> void:
	var score := Scoring.compute(sim, sim.design, GameState.players, GameState.major_decisions, GameState.approved_decisions)
	var ev := DesignEval.evaluate(sim.design)
	var match_m := Scoring.match_mission(sim.design, ev)
	var necks := Scoring.bottlenecks(sim)
	GameState.history.append({"intento": GameState.attempt, "puntaje": score["total"], "sp": sim.sp, "perdida": sim.lost})
	GameState.last_result = score

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
	var page := UIKit.vbox(14)
	var wrap := UIKit.margin(UIKit.scroll(page), 20)
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(wrap)

	# Cabecera
	var head := UIKit.hbox(20)
	page.add_child(head)
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.eyebrow("Resultados y debriefing · intento %d" % GameState.attempt, UIKit.ACCENT))
	hv.add_child(UIKit.label(sim.sc["nombre"], 28))
	var verdict := "Nave perdida: " + _cap(sim.lost_reason) if sim.lost else ("Meta científica cumplida" if sim.sp >= float(sim.sc["meta_sp"]) else "Misión completada sin llegar a la meta")
	hv.add_child(UIKit.label(verdict, 16, UIKit.BAD if score["failed"] else UIKit.GOOD, true))
	head.add_child(hv)
	var big := UIKit.vbox(0)
	big.add_child(UIKit.eyebrow("Puntaje"))
	big.add_child(UIKit.label("%.0f" % score["total"], 64, UIKit.BAD if score["failed"] else UIKit.ACCENT))
	if score["failed"]:
		big.add_child(UIKit.label("limitado a 40 por misión fallida", 12, UIKit.BAD))
	head.add_child(big)

	var cols := UIKit.hbox(14)
	page.add_child(cols)
	var left := UIKit.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.4
	var right := UIKit.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)

	# Componentes del puntaje
	var comp := UIKit.panel()
	var cv := UIKit.vbox(8)
	comp.add_child(cv)
	cv.add_child(UIKit.eyebrow("Puntaje = 100 · (0.50·C + 0.20·E + 0.15·R + 0.15·K)"))
	_bar(cv, "C · Ciencia (%.0f de %.0f pts)" % [sim.sp, float(sim.sc["meta_sp"])], score["C"] / 1.2, "%.2f" % score["C"])
	_bar(cv, "E · Eficiencia (sin gastar %.0f %% · margen de masa %.0f %% · propelente %.0f %%)" % [score["unspent"] * 100.0, score["margin"] * 100.0, score["prop_frac"] * 100.0], score["E"], "%.2f" % score["E"])
	_bar(cv, "R · Gestión de riesgo (%d de %d eventos bien resueltos, %d modo seguro evitable)" % [score["events_good"], score["events_total"], sim.avoidable_safe], score["R"], "%.2f" % score["R"])
	var k_txt := "K · Colaboración (en solitario K = R)" if GameState.players <= 1 else "K · Colaboración (%d de %d decisiones mayores con visto bueno)" % [GameState.approved_decisions, GameState.major_decisions]
	_bar(cv, k_txt, score["K"], "%.2f" % score["K"])
	cv.add_child(UIKit.label("Gasto total %s de %s (incluye %s por decisiones en vuelo)." % [UIKit.fmt_money(score["spent"]), UIKit.fmt_money(float(sim.sc["presupuesto"])), UIKit.fmt_money(sim.cost_extra)], 13, UIKit.MUTED, true))
	left.add_child(comp)

	# Cuellos de botella
	var np := UIKit.panel()
	var nv := UIKit.vbox(10)
	np.add_child(nv)
	nv.add_child(UIKit.eyebrow("Libro de cuellos de botella · causa principal primero"))
	var shown := 0
	for n in necks:
		if n["severidad"] < 0.01 and shown > 0:
			continue
		shown += 1
		var box := UIKit.vbox(3)
		var row := UIKit.hbox(8)
		var col := UIKit.BAD if n["severidad"] > 0.3 else UIKit.WARN if n["severidad"] > 0.05 else UIKit.GOOD
		var tl := UIKit.label(n["que_mide"], 16, col, true)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tl)
		row.add_child(UIKit.label(_val(n), 15, col))
		box.add_child(row)
		if n["severidad"] >= 0.01:
			box.add_child(UIKit.label("Tu decisión: " + _cause(n["contador"], ev), 13, UIKit.INK, true))
			box.add_child(UIKit.label("Lección: " + n["leccion"], 13, UIKit.GAME, true))
		nv.add_child(box)
		if shown >= 4:
			break
	if necks[0]["severidad"] < 0.01:
		nv.add_child(UIKit.label("Ningún subsistema frenó la ciencia de forma relevante. Prueba un diseño más barato o más ligero para subir la eficiencia.", 14, UIKit.GOOD, true))
	left.add_child(np)

	# Eventos
	var ep := UIKit.panel()
	var evv := UIKit.vbox(8)
	ep.add_child(evv)
	evv.add_child(UIKit.eyebrow("Eventos y decisiones en vuelo"))
	if sim.event_records.is_empty():
		evv.add_child(UIKit.label("No hubo eventos.", 13, UIKit.MUTED))
	for r in sim.event_records:
		var rv := UIKit.vbox(2)
		var rr := UIKit.hbox(8)
		rr.add_child(UIKit.label("Día %.0f" % (r["t"] / 86400.0), 13, UIKit.MUTED))
		var nl := UIKit.label(r["nombre"], 14, UIKit.INK, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rr.add_child(nl)
		rr.add_child(UIKit.pill("bien resuelto" if r["good"] else "con costo", UIKit.GOOD if r["good"] else UIKit.WARN))
		rv.add_child(rr)
		if r["action"] >= 0:
			rv.add_child(UIKit.label("→ %s. %s" % [r["acciones"][r["action"]], r["outcome"]], 12, UIKit.MUTED, true))
		evv.add_child(rv)
	left.add_child(ep)

	# Misión real más parecida
	var mp := UIKit.panel(UIKit.SURFACE, UIKit.REAL, 14)
	var mv := UIKit.vbox(6)
	mp.add_child(mv)
	var m: Dictionary = match_m["mision"]
	mv.add_child(UIKit.eyebrow("Misión real más parecida · %d %% de parecido" % match_m["parecido"], UIKit.REAL))
	mv.add_child(UIKit.label("%s (%d)" % [m["nombre"], m["anio"]], 24))
	mv.add_child(UIKit.label("%s kg · %s · %s" % [m["masa_kg"], m["orbita"], m["lanzador"]], 13, UIKit.MUTED, true))
	mv.add_child(UIKit.label(m["dato"], 14, UIKit.INK, true))
	mv.add_child(UIKit.label("Tu nave: %.0f kg · %s · %s." % [ev["wet"], ev["pf"]["nombre"], ev["lv"]["nombre"]], 13, UIKit.MUTED, true))
	if m["costo_musd"] != null:
		mv.add_child(UIKit.label("Costo real: %s · el tuyo: %s" % [UIKit.fmt_money(float(m["costo_musd"])), UIKit.fmt_money(score["spent"])], 13, UIKit.MUTED, true))
	right.add_child(mp)

	# Cifras del vuelo
	var fp := UIKit.panel()
	var fv := UIKit.vbox(4)
	fp.add_child(fv)
	fv.add_child(UIKit.eyebrow("Cifras del vuelo (simulación física)"))
	var s := sim.summary()
	for line in [
		"Contacto medio: %.1f min/día (CML 3 suponía %.0f)" % [s["contact_min_day"], ev["contact_min"]],
		"Tiempo al Sol: %.0f %% (GDD: %.0f %%)" % [s["sun_frac"] * 100.0, float(ev["pf"]["f_sol"]) * 100.0],
		"Datos generados %s · en tierra %s" % [DesignEval.fmt_mb(s["mb_gen"]), DesignEval.fmt_mb(s["mb_down"])],
		"Δv usado %.1f m/s · restante %.0f m/s" % [s["dv_used"], s["dv_left"]],
		"Capacidad de batería al final: %.0f %%" % (s["cap_frac"] * 100.0),
	]:
		fv.add_child(UIKit.label("• " + line, 13, UIKit.INK, true))
	right.add_child(fp)

	# Historial
	if GameState.history.size() > 1:
		var hp := UIKit.panel()
		var hvv := UIKit.vbox(4)
		hp.add_child(hvv)
		hvv.add_child(UIKit.eyebrow("Tus intentos en este contrato"))
		for h in GameState.history:
			hvv.add_child(UIKit.label("Intento %d · %.0f puntos · %.0f pts de ciencia%s" % [h["intento"], h["puntaje"], h["sp"], " · nave perdida" if h["perdida"] else ""], 13))
		right.add_child(hp)

	var btns := UIKit.hbox(8)
	var redo := UIKit.button("← Rediseñar (volver a CML 3)", true)
	redo.pressed.connect(func(): main.goto_design())
	var menu := UIKit.button("Nuevo contrato")
	menu.pressed.connect(func(): main.goto_menu())
	btns.add_child(redo)
	btns.add_child(menu)
	right.add_child(btns)
	right.add_child(UIKit.label("Iterar es parte del método: el JPL vuelve de CML 4 a CML 3 tras cada fallo.", 12, UIKit.MUTED, true))

func _bar(parent: Control, title: String, frac: float, text: String) -> void:
	var m := UIKit.meter(title)
	UIKit.set_meter(m, frac, text, UIKit.GOOD if frac >= 0.7 else UIKit.WARN if frac >= 0.4 else UIKit.BAD)
	parent.add_child(m["root"])

func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s.length() > 0 else s

func _val(n: Dictionary) -> String:
	var v := float(n["valor"])
	if n["unidad"] == "MB":
		return DesignEval.fmt_mb(v)
	return "%.0f %s" % [v, n["unidad"]]

## La decisión de diseño que originó cada cuello de botella.
func _cause(key: String, ev: Dictionary) -> String:
	var d: Dictionary = sim.design
	match key:
		"h_sin_energia":
			return "paneles «%s» (%d W) y batería «%s» (%d Wh) para una carga media de %.0f W." % [ev["pan"]["nombre"], ev["pan"]["potencia_w"], ev["bat"]["nombre"], ev["bat"]["capacidad_wh"], ev["load"]]
		"mb_perdidos":
			return "generas %s/día y la antena «%s» con %d bloque(s) de contacto baja %s/día en el mejor caso." % [DesignEval.fmt_mb(ev["gen_mb"]), ev["com"]["nombre"], d["bloques"], DesignEval.fmt_mb(ev["down"])]
		"h_sin_contacto":
			var names: Array = []
			for st in sim._stations:
				names.append(st["nombre"])
			return "estaciones contratadas: %s. Hubo %.1f min/día de contacto real." % [", ".join(PackedStringArray(names)), sim.summary()["contact_min_day"]]
		"dv_faltante":
			return "propulsión «%s» con %.1f kg de propelente (%.0f m/s)." % [ev["prop"]["nombre"], ev["prop_kg"], ev["dv"]]
		"h_modo_seguro":
			var ex: Array = d.get("extras", [])
			return "redundancia: %s; decisiones tomadas ante los eventos." % ("ninguna" if ex.is_empty() else ", ".join(PackedStringArray(ex)))
		"sp_fuera_objetivo":
			var rel := DesignEval.relevance(sim.sc, sim.pf)
			var low: Array = []
			for i in d["ins"]:
				if float(rel.get(i, 0.0)) < 1.0:
					low.append(GameData.by_id("instrumentos", i)["nombre"])
			return "instrumentos que no responden del todo a la pregunta científica: %s." % ", ".join(PackedStringArray(low))
	return ""
