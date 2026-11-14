class_name DesignEval
extends RefCounted
## Evaluación de un diseño con promedios orbitales (GDD sección 7, CML 3).
## Port fiel de evaluate() del documento, más el segmento de usuario y las mejoras de redundancia.

const CHECK_ORDER := ["carga", "masa", "lanzador", "potencia", "eclipse", "dv", "costo", "plazo"]

static func evaluate(b: Dictionary) -> Dictionary:
	var sc := GameData.scenario(b["scn"])
	var pf := GameData.profile(sc, b["perfil"])
	var bus := GameData.by_id("estructuras", b["bus"])
	var pan := GameData.by_id("paneles", b["pan"])
	var bat := GameData.by_id("baterias", b["bat"])
	var prop := GameData.by_id("propulsion", b["prop"])
	var com := GameData.by_id("comunicaciones", b["com"])
	var lv := GameData.by_id("lanzadores", b["lv"])
	var usr := GameData.by_id("usuario", b.get("usuario", "l1"))
	var ins: Array = []
	for id in b["ins"]:
		ins.append(GameData.by_id("instrumentos", id))
	var duty: float = float(b["duty"]) / 100.0
	var years: float = float(sc["duracion_dias"]) / 365.0
	var prop_kg := minf(float(b["propKg"]), float(prop["tanque_kg"]))

	var extras_mass := 0.0
	var extras_cost := 0.0
	for e in b.get("extras", []):
		extras_mass += GameData.EXTRAS[e]["masa"]
		extras_cost += GameData.EXTRAS[e]["costo"]

	var payload := 0.0
	for i in ins:
		payload += float(i["masa"])
	var dry := float(bus["masa_seca"]) + payload + float(pan["masa"]) + float(bat["masa"]) + float(prop["masa_seca"]) + float(com["masa"]) + extras_mass
	var wet := dry + prop_kg
	var dv := Astro.delta_v(wet, dry, float(prop["isp_s"])) if float(prop["isp_s"]) > 0.0 and prop_kg > 0.0 else 0.0

	var contact_min := float(b["bloques"]) * float(sc["min_por_bloque"]) * float(pf["contacto"])
	var cf := contact_min / 1440.0
	var ins_load := 0.0
	for i in ins:
		var d := minf(duty, float(i["ciclo_max"]))
		ins_load += float(i["activo_w"]) * d + float(i["espera_w"]) * (1.0 - d)
	var load := float(bus["potencia_base_w"]) + ins_load + float(com["potencia_w"]) * cf
	var gen := float(pan["potencia_w"]) * float(pf["f_sol"]) * 0.85
	var ecl_wh := load * float(pf["eclipse_min"]) / 60.0
	var bat_wh := float(bat["capacidad_wh"]) * float(bat[pf["dod"]])

	var rate := float(com.get("mbps_" + str(sc["regimen"]), 0.0))
	var down := rate * contact_min * 60.0 / 8.0
	var rel := relevance(sc, pf)
	var shared := 0.85 if lv["clase"] == "compartido" and not pf["compartido_ok"] else 1.0
	var q: Array = []
	for i in ins:
		var d := minf(duty, float(i["ciclo_max"]))
		q.append({"id": i["id"], "mb": float(i["mb_h"]) * 24.0 * d, "sp": float(i["sp_h"]) * 24.0 * d * float(rel.get(i["id"], 0.0))})
	q.sort_custom(func(a, c): return a["sp"] / maxf(a["mb"], 1e-12) > c["sp"] / maxf(c["mb"], 1e-12))
	var left := down
	var sp_day := 0.0
	var gen_mb := 0.0
	for x in q:
		gen_mb += x["mb"]
		var f: float = minf(1.0, left / x["mb"]) if x["mb"] > 0.0 else 0.0
		left -= x["mb"] * f
		sp_day += x["sp"] * f
	var usr_mult := float(usr.get("mult_ciencia", 1.0))
	var sp := sp_day * float(sc["duracion_dias"]) * shared * usr_mult

	var cap_v: Variant = lv.get(sc["destino"])
	var cap: float = -1.0 if cap_v == null else float(cap_v)
	var lv_cost: float
	if lv.get("costo") != null:
		lv_cost = float(lv["costo"])
	else:
		lv_cost = maxf(float(lv["costo_min"]), wet * float(lv["costo_por_kg"]))
	var hard := float(sc["sobrecosto"]) if bus["clase"] != "large" else 0.0
	var hw := float(bus["costo"]) + float(pan["costo"]) + float(bat["costo"]) + float(prop["costo"]) + float(com["costo"]) + hard + extras_cost
	for i in ins:
		hw += float(i["costo"])
	var ops := float(sc["ops_anual"]) * years + float(sc["estacion_anual"]) * float(b["bloques"]) * years + float(usr.get("costo_anual", 0.0)) * years
	var cost := hw + lv_cost + ops
	var months := maxi(int(bus["desarrollo_meses"]), int(lv["espera_meses"])) + 6

	var misfit: Array = []
	for c in [pan, bat, prop, com]:
		if not GameData.fits(c, bus["clase"]):
			misfit.append(c["nombre"])
	var checks := {
		"carga": {"ok": payload <= float(bus["carga_max_kg"]), "txt": "Carga útil cabe en el bus"},
		"masa": {"ok": wet <= float(bus["masa_max_kg"]) and misfit.is_empty(), "txt": "Masa y compatibilidad"},
		"lanzador": {"ok": cap >= 0.0 and wet <= cap, "txt": "Lanzador llega al destino"},
		"potencia": {"ok": gen >= load, "txt": "Potencia media"},
		"eclipse": {"ok": ecl_wh <= bat_wh, "txt": "Batería cubre el eclipse"},
		"dv": {"ok": dv >= float(pf["dv"]), "txt": "Δv requerido"},
		"costo": {"ok": cost <= float(sc["presupuesto"]), "txt": "Presupuesto"},
		"plazo": {"ok": months <= int(sc["plazo_meses"]), "txt": "Fecha límite"},
	}
	var all_ok := true
	for k in checks:
		all_ok = all_ok and checks[k]["ok"]
	return {
		"sc": sc, "pf": pf, "bus": bus, "lv": lv, "pan": pan, "bat": bat, "prop": prop, "com": com, "ins": ins, "usr": usr,
		"payload": payload, "dry": dry, "wet": wet, "dv": dv, "prop_kg": prop_kg, "load": load, "gen": gen,
		"ecl_wh": ecl_wh, "bat_wh": bat_wh, "rate": rate, "contact_min": contact_min, "down": down, "gen_mb": gen_mb,
		"sp": sp, "sp_day": sp_day, "cap": cap, "lv_cost": lv_cost, "hw": hw, "ops": ops, "cost": cost, "months": months,
		"misfit": misfit, "checks": checks, "all_ok": all_ok, "shared": shared, "science": sp >= float(sc["meta_sp"]),
	}

static func relevance(sc: Dictionary, pf: Dictionary) -> Dictionary:
	var rel: Dictionary = (sc["relevancia"] as Dictionary).duplicate()
	if pf.has("relevancia"):
		for k in pf["relevancia"]:
			rel[k] = pf["relevancia"][k]
	return rel

## Explicaciones en lenguaje claro de por qué falla cada verificación (panel "Por qué").
static func explain(e: Dictionary) -> Array:
	var out: Array = []
	var c: Dictionary = e["checks"]
	var bus: Dictionary = e["bus"]
	if not c["carga"]["ok"]:
		out.append("La carga útil pesa %.1f kg y el bus admite %.0f kg. Quita instrumentos o sube de clase de bus." % [e["payload"], bus["carga_max_kg"]])
	if not e["misfit"].is_empty():
		out.append("No caben en un bus «%s»: %s." % [bus["clase"], ", ".join(e["misfit"])])
	if e["wet"] > float(bus["masa_max_kg"]):
		out.append("Masa húmeda %.1f kg por encima del máximo del bus (%.0f kg)." % [e["wet"], bus["masa_max_kg"]])
	if not c["lanzador"]["ok"]:
		if e["cap"] < 0.0:
			out.append("%s no llega a este destino." % e["lv"]["nombre"])
		else:
			out.append("%s lleva %.0f kg al destino y la nave pesa %.1f kg." % [e["lv"]["nombre"], e["cap"], e["wet"]])
	if not c["potencia"]["ok"]:
		out.append("Generas %.0f W de media y consumes %.0f W. Más paneles, menos ciclo de trabajo o instrumentos más eficientes." % [e["gen"], e["load"]])
	if not c["eclipse"]["ok"]:
		out.append("El eclipse pide %.0f Wh y la batería entrega %.0f Wh sin pasar su DoD segura." % [e["ecl_wh"], e["bat_wh"]])
	if not c["dv"]["ok"]:
		out.append("Tienes %.0f m/s de Δv y el perfil pide %.0f m/s. Carga más propelente o usa más Isp (Tsiolkovski)." % [e["dv"], e["pf"]["dv"]])
	if not c["costo"]["ok"]:
		out.append("Cuesta %.2f M$ y el presupuesto es %.2f M$ (lanzador %.2f, hardware %.2f, operaciones %.2f)." % [e["cost"], e["sc"]["presupuesto"], e["lv_cost"], e["hw"], e["ops"]])
	if not c["plazo"]["ok"]:
		out.append("Estaría lista en %d meses y el plazo es %d." % [e["months"], e["sc"]["plazo_meses"]])
	if e["gen_mb"] > e["down"] * 1.01 and e["down"] >= 0.0:
		out.append("Generas %s/día y bajas %s/día: el resto se pierde o espera en memoria." % [fmt_mb(e["gen_mb"]), fmt_mb(e["down"])])
	if not e["science"]:
		out.append("Ciencia estimada %.0f de %.0f puntos de meta." % [e["sp"], e["sc"]["meta_sp"]])
	if out.is_empty():
		out.append("Las ocho verificaciones pasan. Ciencia estimada: %.0f de %.0f puntos." % [e["sp"], e["sc"]["meta_sp"]])
	return out

static func fmt_mb(mb: float) -> String:
	if mb >= 1e6:
		return "%.1f TB" % (mb / 1e6)
	if mb >= 1000.0:
		return "%.1f GB" % (mb / 1000.0)
	return "%.1f MB" % mb
