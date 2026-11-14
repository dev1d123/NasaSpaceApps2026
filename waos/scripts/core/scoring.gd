class_name Scoring
extends RefCounted
## Puntaje y debriefing (GDD sección 8).

## Puntaje = 100 · (0.50·C + 0.20·E + 0.15·R + 0.15·K)
static func compute(sim: MissionSim, design: Dictionary, players: int, major: int = 0, approved: int = 0) -> Dictionary:
	var ev: Dictionary = sim.ev
	var sc: Dictionary = sim.sc
	var budget := float(sc["presupuesto"])
	var spent := float(ev["cost"]) + sim.cost_extra
	var c := minf(1.2, sim.sp / float(sc["meta_sp"]))

	var unspent := clampf((budget - spent) / budget, 0.0, 0.25) * 4.0
	var bus_max := float(ev["bus"]["masa_max_kg"])
	var margin := (bus_max - float(ev["wet"])) / bus_max
	var margin_score := maxf(0.0, 1.0 - absf(margin - 0.15) / 0.15)
	var prop_score: float
	if sim.prop_loaded <= 0.0:
		prop_score = 1.0 if float(sim.pf["dv"]) <= 0.0 else 0.0
	else:
		prop_score = minf(0.3, sim.prop_kg / sim.prop_loaded) * 3.33
	var e := (unspent + margin_score + minf(prop_score, 1.0)) / 3.0

	var total_ev := sim.event_records.size()
	var good := 0
	for rec in sim.event_records:
		if rec["good"]:
			good += 1
	var r := (float(good) / total_ev) if total_ev > 0 else 1.0
	r = clampf(r - 0.25 * sim.avoidable_safe, 0.0, 1.0)

	var k := r
	if players > 1:
		k = (float(approved) / major) if major > 0 else 1.0

	var total := 100.0 * (0.50 * c + 0.20 * e + 0.15 * r + 0.15 * k)
	var failed := sim.lost or sim.sp < 0.4 * float(sc["meta_sp"])
	if failed:
		total = minf(total, 40.0)
	return {
		"total": total, "C": c, "E": e, "R": r, "K": k, "failed": failed,
		"unspent": unspent / 4.0, "margin": margin, "prop_frac": (sim.prop_kg / sim.prop_loaded) if sim.prop_loaded > 0.0 else 0.0,
		"events_good": good, "events_total": total_ev, "spent": spent,
	}

## Misión real más parecida: distancia ponderada (masa en escala log, régimen, instrumentos, propulsión).
static func match_mission(design: Dictionary, ev: Dictionary) -> Dictionary:
	var regime := str(ev["sc"]["regimen"])
	var regime_name := "cislunar" if regime == "lunar" else regime
	var prop_type := str(ev["prop"]["tipo"])
	var best := {}
	for m in GameData.list("misiones_reales"):
		var gap := 0.0
		if regime_name != m["regimen"]:
			gap = 1.0 if (regime_name == "leo" or m["regimen"] == "leo") else 0.5
		var a: Array = design["ins"]
		var b: Array = m["instrumentos"]
		var uni := {}
		for x in a:
			uni[x] = true
		for x in b:
			uni[x] = true
		var inter := 0
		for x in a:
			if b.has(x):
				inter += 1
		var jac := (1.0 - float(inter) / uni.size()) if uni.size() > 0 else 0.0
		var prop_match := 0.0 if (prop_type != "–" and str(m["propulsion"]).contains(prop_type.split(" ")[0])) else 1.0
		var d := 0.35 * minf(1.0, absf(log(float(ev["wet"]) / float(m["masa_kg"])) / log(10.0)) / 2.0) \
			+ 0.30 * gap + 0.25 * jac + 0.10 * prop_match
		if best.is_empty() or d < best["distancia"]:
			best = {"mision": m, "distancia": d, "parecido": int(round((1.0 - d) * 100.0))}
	return best

## Cuellos de botella ordenados por severidad, con la lección del GDD.
static func bottlenecks(sim: MissionSim) -> Array:
	var info := {}
	for c in GameData.list("cuellos"):
		info[c["contador"]] = c
	var days := maxf(sim.sci_time / 86400.0, 1.0)
	var mem_scale := maxf(sim.mb_gen, 1.0)
	# Severidad normalizada 0..1 para poder comparar contadores con unidades distintas.
	var sev := {
		"h_sin_energia": sim.ledger["h_sin_energia"] / (days * 24.0),
		"mb_perdidos": sim.ledger["mb_perdidos"] / mem_scale,
		"h_sin_contacto": sim.ledger["h_sin_contacto"] / (days * 24.0) * 0.5,
		"dv_faltante": minf(1.0, sim.ledger["dv_faltante"] / 50.0),
		"h_modo_seguro": sim.ledger["h_modo_seguro"] / (days * 24.0) * 3.0,
		"sp_fuera_objetivo": sim.ledger["sp_fuera_objetivo"] / maxf(sim.sp + sim.ledger["sp_fuera_objetivo"], 1.0),
	}
	var units := {"h_sin_energia": "h", "mb_perdidos": "MB", "h_sin_contacto": "h", "dv_faltante": "m/s", "h_modo_seguro": "h", "sp_fuera_objetivo": "pts"}
	var out: Array = []
	for k in sev:
		var c: Dictionary = info.get(k, {"que_mide": k, "causa_tipica": "", "leccion": ""})
		out.append({"contador": k, "valor": sim.ledger[k], "unidad": units[k], "severidad": clampf(sev[k], 0.0, 1.0),
			"que_mide": c["que_mide"], "causa": c["causa_tipica"], "leccion": c["leccion"]})
	out.sort_custom(func(a, b): return a["severidad"] > b["severidad"])
	return out
