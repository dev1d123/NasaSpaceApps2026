class_name MissionEvents
extends RefCounted
## Eventos dinámicos de los tres escenarios (GDD sección 6). El texto viene del JSON;
## aquí está la mecánica de cada acción. Cuando el GDD no fija un número, se marca «juego».

const DAY := 86400.0
const ROLE := {
	"s1e1": "ground", "s1e2": "space", "s1e3": "space", "s1e4": "ground", "s1e5": "launch",
	"s2e1": "space", "s2e2": "launch", "s2e3": "ground", "s2e4": "space", "s2e5": "space",
	"s3e1": "launch", "s3e2": "user", "s3e3": "space", "s3e4": "ground", "s3e5": "launch",
}

static func _ev(sim: MissionSim, id: String) -> Dictionary:
	for e in sim.sc["eventos"]:
		if e["id"] == id:
			return e
	return {}

static func _at(id: String, t: float) -> Dictionary:
	return {"id": id, "t": t, "fired": false}

static func build_schedule(sim: MissionSim) -> Array:
	var r := sim.rng
	var s: Array = []
	var dur := sim.science_days
	match sim.sc["id"]:
		"s1":
			if r.randf() < 0.20:
				s.append(_at("s1e1", 1.0 * DAY))
			s.append(_at("s1e2", r.randf_range(30, 150) * DAY))
			s.append(_at("s1e3", r.randf_range(70, 110) * DAY))
			s.append(_at("s1e4", r.randf_range(10, dur - 10) * DAY))
			s.append(_at("s1e5", r.randf_range(10, dur - 5) * DAY))
		"s2":
			for yv in int(ceil(dur / 365.0)):
				s.append(_at("s2e1", (yv * 365 + r.randf_range(20, 340)) * DAY))
				for _k in 2:
					s.append(_at("s2e2", (yv * 365 + r.randf_range(5, 360)) * DAY))
			s.append(_at("s2e3", r.randf_range(15, dur - 15) * DAY))
			s.append(_at("s2e4", r.randf_range(240, 360) * DAY))
			if r.randf() < 0.60:
				s.append(_at("s2e5", r.randf_range(360, 540) * DAY))
		"s3":
			# Corrección de trayectoria 2: a un tercio del crucero.
			if r.randf() < 0.35:
				s.append(_at("s3e1", sim.cruise_end * 0.35))
			s.append(_at("s3e2", r.randf_range(0.2, 0.8) * sim.cruise_end))
	s.sort_custom(func(a, b): return a["t"] < b["t"])
	return s

## Eventos que dependen de estar ya en órbita lunar.
static func on_orbit(sim: MissionSim) -> void:
	var r := sim.rng
	var t0 := sim.t
	sim.schedule.append(_at("s3e5", t0 + 600.0))
	sim.schedule.append(_at("s3e3", t0 + 120.0 * DAY))
	sim.schedule.append(_at("s3e4", t0 + r.randf_range(20, 330) * DAY))
	sim.schedule.append(_at("s3e2", t0 + r.randf_range(150, 340) * DAY))
	sim.schedule.sort_custom(func(a, b): return a["t"] < b["t"])

static func tick(sim: MissionSim, _dt: float) -> void:
	# Procesos en curso (reintentos, tiradas diferidas).
	for p in sim.processes.duplicate():
		if sim.t >= p["at"]:
			sim.processes.erase(p)
			_run_process(sim, p)
			if sim.finished:
				return
	if not sim.pending_event.is_empty():
		return
	for item in sim.schedule:
		if not item["fired"] and sim.t >= item["t"]:
			item["fired"] = true
			_fire(sim, item["id"])
			return

static func _fire(sim: MissionSim, id: String) -> void:
	var e := _ev(sim, id)
	var rec := {"id": id, "nombre": e["nombre"], "t": sim.t, "cuando": e["cuando"], "impacto": e["impacto"],
		"acciones": e["acciones"], "role": ROLE.get(id, "space"), "action": -1, "good": true, "outcome": ""}
	# Efectos inmediatos al dispararse.
	match id:
		"s1e1":
			sim.add_mod("antenna_stowed", 1.0, 1e9)
		"s1e2":
			sim.add_mod("drag", 3.0, 72.0)
		"s1e3":
			sim.cap_wh *= 0.8
			sim.energy = minf(sim.energy, sim.cap_wh)
		"s2e1":
			sim.panel_mult *= 0.98
		"s2e4":
			sim.cap_wh *= 0.875
			sim.energy = minf(sim.energy, sim.cap_wh)
		"s3e2":
			sim.panel_mult *= 0.97
	sim.event_records.append(rec)
	sim.pending_event = rec
	sim.add_log("EVENTO: %s. %s" % [e["nombre"], e["impacto"]], "event")

## Disponibilidad de cada acción: [{text, ok, why}]
static func actions(sim: MissionSim, rec: Dictionary) -> Array:
	var out: Array = []
	var texts: Array = rec["acciones"]
	for i in texts.size():
		var ok := true
		var why := ""
		match [rec["id"], i]:
			["s1e2", 2], ["s1e5", 0], ["s2e2", 0]:
				ok = sim.has_prop and sim.prop_kg > 0.0
				why = "Requiere propulsión con propelente"
			["s2e3", 0]:
				ok = str(sim.ev["com"]["banda"]) == "X"
				why = "Tu antena no es de banda X"
			["s2e5", 0]:
				ok = (sim.design.get("extras", []) as Array).has("rueda")
				why = "No compraste la cuarta rueda en el diseño"
			["s3e1", 1]:
				ok = (sim.design.get("extras", []) as Array).has("valvula")
				why = "No compraste la rama redundante en el diseño"
			["s3e1", 2]:
				ok = sim.pf["id"] == "llo_dir"
				why = "Ya vuelas una transferencia balística"
			["s3e3", 2]:
				ok = sim.regime == "nrho" and sim.has_prop
				why = "Solo en NRHO y con propulsión"
			["s3e5", 2]:
				ok = sim.regime == "llo" and sim.has_prop
				why = "Solo en órbita baja y con propulsión"
		out.append({"text": texts[i], "ok": ok, "why": "" if ok else why})
	return out

static func default_action(sim: MissionSim, rec: Dictionary) -> int:
	var a := actions(sim, rec)
	for i in a.size():
		if a[i]["ok"]:
			return i
	return 0

static func resolve(sim: MissionSim, idx: int) -> void:
	var rec := sim.pending_event
	if rec.is_empty():
		return
	var avail := actions(sim, rec)
	if idx < 0 or idx >= avail.size() or not avail[idx]["ok"]:
		idx = default_action(sim, rec)
	rec["action"] = idx
	sim.pending_event = {}
	var r := sim.rng
	var out := ""
	match [rec["id"], idx]:
		# ---------- s1 ----------
		["s1e1", 0]:
			sim.processes.append({"kind": "antenna", "at": sim.t + DAY, "p": 0.7, "risk": 0.05, "rec": rec})
			out = "Reintentos diarios con 70 % de éxito (juego: 5 % de dañar la antena por intento)."
		["s1e1", 1]:
			sim.processes.append({"kind": "antenna", "at": sim.t + DAY, "p": 0.4, "risk": 0.0, "rec": rec})
			out = "Esperando al Sol: 40 % por día."
		["s1e2", 0]:
			sim.enter_safe(72.0, "tormenta geomagnética", false)
			out = "Tres días sin ciencia, sin riesgo."
		["s1e2", 1], ["s1e2", 2]:
			if r.randf() < 0.25:
				sim.enter_safe(6.0, "reinicio del computador por la tormenta", false)
				rec["good"] = false
				out = "El computador se reinició: 6 h sin ciencia."
			else:
				out = "La nave aguantó la tormenta."
			if idx == 2:
				sim.processes.append({"kind": "reboost", "at": sim.t + 72.0 * 3600.0, "dv": 0.3, "rec": rec})
				out += " Se recuperará altitud al terminar."
		["s1e3", 0]:
			sim.eclipse_gate = true
			out = "Instrumentos en espera durante los eclipses."
		["s1e3", 1]:
			sim.dod_override = 0.6
			sim.maint["s1e3_rec"] = rec
			out = "Operación normal: cada eclipse sobre 30 % de DoD resta 0.5 % de capacidad."
		["s1e4", 0]:
			sim.add_mod("station_out_" + GameData.STATION_PLAN["s1"][0], 1.0, 120.0)
			out = "La memoria absorbe los datos durante 5 días."
		["s1e4", 1]:
			sim.cost_extra += 0.05
			out = "Pases comerciales contratados: 0.05 M$."
		["s1e4", 2]:
			sim.add_mod("station_out_" + GameData.STATION_PLAN["s1"][0], 1.0, 120.0)
			for i in sim.ev["ins"]:
				if i["id"] != "mag":
					sim.add_mod("ins_off_" + i["id"], 1.0, 120.0)
			out = "Solo el magnetómetro opera 5 días: más puntos por MB."
		["s1e5", 0]:
			sim.spend_dv(0.2, "evasión de basura")
			out = "Evasión con 0.2 m/s. Riesgo 0."
		["s1e5", 1]:
			sim.enter_safe(24.0, "maniobra por arrastre diferencial", false)
			sim.processes.append({"kind": "risk", "at": sim.t + 48.0 * 3600.0, "p": 0.003, "why": "colisión con basura espacial", "rec": rec})
			out = "Un día girando la nave para cambiar el arrastre. Riesgo 0.3 %."
		["s1e5", 2]:
			sim.processes.append({"kind": "risk", "at": sim.t + 48.0 * 3600.0, "p": 0.02, "why": "colisión con basura espacial", "rec": rec})
			out = "Se acepta el 2 % de riesgo."
		# ---------- s2 ----------
		["s2e1", 0]:
			sim.enter_safe(36.0, "eyección de masa coronal", false)
			out = "36 h en modo seguro, sin daño."
		["s2e1", 1]:
			sim.add_mod("ins_off_sar", 1.0, 36.0)
			out = "Radar apagado 36 h; el infrarrojo sigue."
		["s2e1", 2]:
			if sim.ins_on.get("sar", false) and r.randf() < 0.20:
				sim.add_mod("sp_sar", 0.5, 48.0)
				rec["good"] = false
				out = "Latch-up en el radar: −50 % de rendimiento 48 h."
			else:
				out = "Sin daños."
		["s2e2", 0]:
			sim.spend_dv(0.5, "evasión de fragmento")
			sim.add_mod("ins_off_sar", 1.0, 3.3)
			sim.add_mod("ins_off_cam", 1.0, 3.3)
			out = "Maniobra de 0.5 m/s; dos órbitas sin imagen."
		["s2e2", 1]:
			sim.processes.append({"kind": "conj_wait", "at": sim.t + 24.0 * 3600.0, "rec": rec})
			out = "Esperando un mejor rastreo 24 h."
		["s2e3", 0]:
			sim.add_mod("link", 0.9, 72.0)
			out = "Enlace en banda X: −10 % durante 3 días."
		["s2e3", 1]:
			var band := str(sim.ev["com"]["banda"])
			sim.add_mod("link", 0.2 if band == "Ka" else 0.9, 72.0)
			out = "Grabando en memoria con el enlace degradado."
			rec["good"] = band != "Ka"
		["s2e3", 2]:
			sim.cost_extra += 0.4
			out = "McMurdo contratado por el evento: 0.4 M$."
		["s2e4", 0]:
			sim.eclipse_gate_ids.append("sar")
			out = "El radar no opera en eclipse."
		["s2e4", 1]:
			sim.maint["watch_dod"] = true
			out = "Operación normal vigilando la DoD."
		["s2e5", 0]:
			sim.enter_safe(6.0, "conmutación a la rueda redundante", false)
			out = "Conmutado en 6 h, sin penalidad."
		["s2e5", 1]:
			sim.enter_safe(240.0, "diagnóstico de la rueda de reacción", false)
			sim.quality *= 0.85
			rec["good"] = false
			out = "10 días en modo seguro y −15 % de calidad permanente."
		# ---------- s3 ----------
		["s3e1", 0]:
			sim.add_mod("loi_dv", 1.06, 1e9)
			out = "Quemado largo: +6 % de Δv en la inserción."
		["s3e1", 1]:
			out = "Rama redundante: sin penalidad."
		["s3e1", 2]:
			sim.cruise_end += 90.0 * DAY
			sim.t_end += 90.0 * DAY
			sim.maint["loi_extra"] = -150.0
			out = "Replanificado a transferencia balística: +90 días, −150 m/s en la inserción."
		["s3e2", 0]:
			sim.enter_safe(36.0, "evento de partículas solares", false)
			out = "Modo seguro durante el evento."
		["s3e2", 1]:
			for i in sim.ev["ins"]:
				if i["id"] != "rad":
					sim.add_mod("ins_off_" + i["id"], 1.0, 36.0)
			sim.add_mod("sp_rad", 5.0, 36.0)
			sim.add_mod("data_rad", 160.0, 36.0)
			if r.randf() < 0.05:
				sim.enter_safe(6.0, "reinicio durante el evento solar", false)
				rec["good"] = false
			out = "Solo el detector de radiación: ×5 puntos durante el evento."
		["s3e2", 2]:
			sim.add_mod("sp_rad", 5.0, 36.0)
			sim.add_mod("data_rad", 160.0, 36.0)
			if r.randf() < 0.15 and not sim.ins_quality.is_empty():
				var ids: Array = sim.ins_quality.keys()
				var hit: String = ids[r.randi() % ids.size()]
				sim.ins_quality[hit] *= 0.7
				rec["good"] = false
				out = "Daño en %s: −30 %% permanente." % GameData.by_id("instrumentos", hit)["nombre"]
			else:
				out = "Todo siguió encendido y sin daños."
		["s3e3", 0], ["s3e3", 1], ["s3e3", 2]:
			var hours := 1.3 if idx == 2 else 3.0
			if idx == 2:
				sim.spend_dv(2.0, "ajustar la fase de la NRHO")
			var start := sim.t + 24.0 * 3600.0
			sim.processes.append({"kind": "lunar_eclipse", "at": start, "hours": hours, "rec": rec})
			if idx == 0:
				sim.processes.append({"kind": "precool", "at": start - 2.0 * 3600.0, "hours": hours + 2.0})
			out = "Eclipse total en 24 h (%.1f h de sombra)." % hours
		["s3e4", 0]:
			sim.add_mod("contact", 0.75, 336.0)
			out = "Pases nocturnos: se recupera la mitad de lo perdido."
		["s3e4", 1]:
			sim.cost_extra += 0.6
			out = "Red comercial lunar: 0.6 M$."
		["s3e4", 2]:
			sim.add_mod("contact", 0.5, 336.0)
			sim.add_mod("data", 0.4, 336.0)
			sim.add_mod("science", 0.85, 336.0)
			out = "Compresión a bordo 14 días."
		["s3e5", 0]:
			sim.maint["policy"] = "periodic"
			out = "Mantenimiento periódico de la órbita."
		["s3e5", 1]:
			sim.maint["skip"] = 2
			out = "Se omiten dos ciclos de mantenimiento."
		["s3e5", 2]:
			if sim.spend_dv(12.0, "pasar a órbita congelada"):
				sim.maint["frozen"] = true
				out = "Órbita congelada: el mantenimiento cuesta ≈1/3."
		_:
			out = "Sin efecto."
	rec["outcome"] = out
	sim.add_log("Decisión: %s → %s" % [rec["acciones"][idx], out], "decision")

static func _run_process(sim: MissionSim, p: Dictionary) -> void:
	var r := sim.rng
	match p["kind"]:
		"antenna":
			if p["risk"] > 0.0 and r.randf() < p["risk"]:
				sim.rate_perm_mult *= 0.5
				p["rec"]["good"] = false
				sim.add_log("El intento dañó el mecanismo: la antena queda a media ganancia.", "bad")
			if r.randf() < p["p"]:
				for m in sim.mods:
					if m["kind"] == "antenna_stowed":
						m["until"] = sim.t
				sim.add_log("¡Antena desplegada!", "good")
			else:
				p["at"] = sim.t + DAY
				sim.processes.append(p)
		"reboost":
			sim.spend_dv(p["dv"], "recuperar altitud")
		"risk":
			if r.randf() < p["p"]:
				p["rec"]["good"] = false
				sim.lose(p["why"])
			else:
				sim.add_log("El objeto pasó sin impacto.", "good")
		"conj_wait":
			if r.randf() < 0.5:
				sim.add_log("El rastreo canceló la alerta de conjunción.", "good")
			elif sim.spend_dv(1.5, "evasión tardía"):
				sim.add_log("Evasión tardía con 1.5 m/s.", "warn")
			else:
				sim.processes.append({"kind": "risk", "at": sim.t + 48.0 * 3600.0, "p": 0.05, "why": "colisión con un fragmento", "rec": p["rec"]})
		"precool":
			for i in sim.ev["ins"]:
				sim.add_mod("ins_off_" + i["id"], 1.0, p["hours"])
			sim.add_mod("dod_relax", 1.0, p["hours"])
			sim.energy = sim.cap_wh
			sim.add_log("Batería al 100 %, precalentamiento e instrumentos apagados.", "info")
		"lunar_eclipse":
			sim.add_mod("lunar_eclipse", 1.0, p["hours"])
			sim.add_mod("dod_relax", 1.0, p["hours"])
			sim.add_log("Comienza el eclipse lunar total.", "warn")
