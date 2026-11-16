class_name MissionSim
extends RefCounted
## Simulación de CML 4 (GDD 2.8): en cada tick, dinámica → geometría → potencia →
## carga útil → enlace → eventos → registro. Sin nodos: se puede correr headless.

signal log_added(entry: Dictionary)

const DAY := 86400.0

# --- Configuración ---
var design: Dictionary
var ev: Dictionary          # evaluación CML 3 del diseño
var sc: Dictionary
var pf: Dictionary
var rng := RandomNumberGenerator.new()
var events_enabled := true
var fast := false

# --- Régimen y órbita ---
var regime := "leo"         # leo | llo | nrho
var central := "earth"      # cuerpo en el origen del marco
var phase := "ciencia"      # crucero | ciencia | fin
var y := PackedFloat64Array()
var env := {}
var alt_target := 0.0       # km, LEO
var nrho_table: Array = []  # [PackedFloat64Array estado rotante normalizado]
var nrho_period := 0.0      # s
var nrho_t := 0.0
var cruise_end := 0.0
var loi_dv := 0.0
var t := 0.0
var t_end := 0.0
var science_days := 0.0

# --- Nave ---
var dry_mass := 0.0
var prop_kg := 0.0
var prop_loaded := 0.0
var isp := 0.0
var has_prop := false
var cap_wh := 0.0
var cap_wh0 := 0.0
var energy := 0.0
var dod_max := 0.3
var dod_override := -1.0
var panel_mult := 1.0
var quality := 1.0          # apuntado / calidad de imagen
var ins_quality := {}       # daño por instrumento
var mem := {}               # id → {mb, sp}
var mem_max := 0.0
var ins_on := {}
var duty := 1.0
var eclipse_gate := false   # instrumentos en espera durante el eclipse
var eclipse_gate_ids: Array = []
var shed := false
var safe_until := -1.0
var safe_reason := ""
var rate_perm_mult := 1.0
var cd_a := 0.1

# --- Estado instantáneo (para HUD y vista) ---
var sun_f := 1.0
var in_contact := false
var contact_station := ""
var link_mbps := 0.0
var gen_w := 0.0
var load_w := 0.0
var altitude := 0.0

# --- Acumuladores ---
var sp := 0.0
var mb_down := 0.0
var mb_gen := 0.0
var cost_extra := 0.0
var sun_time := 0.0
var sci_time := 0.0
var contact_time := 0.0
var dv_used := 0.0
var ledger := {"h_sin_energia": 0.0, "mb_perdidos": 0.0, "h_sin_contacto": 0.0, "dv_faltante": 0.0, "h_modo_seguro": 0.0, "sp_fuera_objetivo": 0.0}
var avoidable_safe := 0
var lost := false
var lost_reason := ""
var finished := false
var logs: Array = []

# --- Eventos ---
var schedule: Array = []          # [{id, t, ...}]
var pending_event: Dictionary = {}
var event_records: Array = []
var mods: Array = []              # [{kind, value, until, ids}]
var processes: Array = []         # procesos diarios (reintentos, mantenimiento)
var maint := {"policy": "periodic", "skip": 0, "next": 0.0, "drop_km": 0.0, "err_km": 1.0, "frozen": false}
var _mean_r_acc := 0.0
var _mean_t_acc := 0.0
var _mean_a_ref := -1.0
var _ecl_min_e := INF
var _was_eclipse := false
var _month_max_dod := 0.0
var _month_next := 30.0 * DAY
var _stations: Array = []        # [{id, nombre, lat, lon}] contratadas (LEO) o DSN (lunar)
var _rel := {}
var _prune_t := 0.0

func setup(d: Dictionary, opts: Dictionary = {}) -> void:
	design = d.duplicate(true)
	rng.seed = int(opts.get("seed", Time.get_ticks_usec()))
	events_enabled = bool(opts.get("events", true))
	fast = bool(opts.get("fast", false))
	ev = DesignEval.evaluate(design)
	sc = ev["sc"]
	pf = ev["pf"]
	var bus: Dictionary = ev["bus"]
	var prop: Dictionary = ev["prop"]
	dry_mass = ev["dry"]
	prop_kg = ev["prop_kg"]
	prop_loaded = prop_kg
	isp = float(prop["isp_s"])
	has_prop = isp > 0.0 and prop_kg > 0.0
	cap_wh0 = float(ev["bat"]["capacidad_wh"])
	cap_wh = cap_wh0
	energy = cap_wh
	dod_max = float(ev["bat"][pf["dod"]])
	mem_max = float(bus["memoria_gb"]) * 1000.0
	duty = float(design["duty"]) / 100.0
	for id in design["ins"]:
		ins_on[id] = true
		mem[id] = {"mb": 0.0, "sp": 0.0}
		ins_quality[id] = 1.0
	science_days = float(sc["duracion_dias"])
	# Área de arrastre: cuerpo + mitad del área de paneles (orientación media).
	var bus_area := {"cube": 0.06, "small": 1.2, "large": 6.0}
	var pan_area := float(ev["pan"]["potencia_w"]) / (1361.0 * float(ev["pan"]["eficiencia"]) * 0.8)
	cd_a = 2.2 * (float(bus_area.get(bus["clase"], 1.0)) * (0.5 if bus["id"] == "cube3u" else (2.0 if bus["id"] == "cube12u" else 1.0)) + 0.5 * pan_area)

	if sc["regimen"] == "leo":
		regime = "leo"
		central = "earth"
		phase = "ciencia"
		var h := 500.0 if pf["id"] == "sso500" else 705.0
		if ev["shared"] < 1.0:
			h = 525.0
		alt_target = h
		var a := Astro.R_E + h
		y = Astro.circular_state(Astro.MU_E, a, Astro.sso_inclination_deg(a), 0.0, 0.0, ev["wet"])
		env = {"central": "earth", "j2": true, "drag": true, "cd_a": cd_a, "drag_factor": 1.0}
		t_end = science_days * DAY
	else:
		regime = "nrho" if pf["id"] == "nrho" else "llo"
		central = "earth"
		phase = "crucero"
		var cruise_days := 4.5 + float(pf.get("dias_extra", 0.0))
		cruise_end = cruise_days * DAY
		loi_dv = {"llo_dir": 850.0, "llo_blt": 650.0, "nrho": 200.0}.get(pf["id"], 850.0)
		t_end = cruise_end + science_days * DAY
		y = PackedFloat64Array([Astro.R_E + 300.0, 0, 0, 0, 0, 0, ev["wet"]])
		if regime == "nrho":
			_build_nrho()
	_rel = DesignEval.relevance(sc, pf)
	var ids: Array = []
	if regime == "leo":
		var plan: Array = GameData.STATION_PLAN[sc["id"]]
		ids = plan.slice(0, mini(int(design["bloques"]), plan.size()))
	else:
		ids = ["gds", "mad", "cbr"]
	for sid in ids:
		var st := GameData.by_id("estaciones", sid)
		if sid == "uni":
			_stations.append({"id": sid, "nombre": "Estación universitaria", "lat": float(design.get("uni_lat", 40.4)), "lon": float(design.get("uni_lon", -3.7))})
		else:
			_stations.append({"id": sid, "nombre": st["nombre"], "lat": float(st["lat"]), "lon": float(st["lon"])})
	if events_enabled:
		schedule = MissionEvents.build_schedule(self)
	add_log("Lanzamiento con %s. Masa %.1f kg, %.0f m/s de Δv." % [ev["lv"]["nombre"], ev["wet"], ev["dv"]], "info")
	if phase == "crucero":
		add_log("Inicio del crucero a la Luna: %.0f días hasta la inserción." % (cruise_end / DAY), "info")

func _build_nrho() -> void:
	var res := Astro.correct_halo(1.0220261840, -0.1821, -0.1032665287, Astro.MU_CR3BP)
	var s: PackedFloat64Array = res["state"]
	var per: float = res["period"]
	var n := 3000
	var h := per / float(n * 8)
	nrho_table.clear()
	for i in n * 8 + 1:
		if i % 8 == 0:
			nrho_table.append(s.duplicate())
		s = Astro.cr3bp_rk4(s, h, Astro.MU_CR3BP)
	nrho_period = per * Astro.CR3BP_T

func add_log(text: String, kind: String = "info") -> void:
	var e := {"t": t, "text": text, "kind": kind}
	logs.append(e)
	log_added.emit(e)

func day() -> float:
	return t / DAY

func science_day() -> float:
	return (t - cruise_end) / DAY if regime != "leo" else t / DAY

func current_mass() -> float:
	return dry_mass + prop_kg

func dv_left() -> float:
	return Astro.delta_v(current_mass(), dry_mass, isp) if has_prop else 0.0

## Gasta Δv (m/s). Devuelve false si no alcanza el propelente.
func spend_dv(dv: float, why: String) -> bool:
	if dv <= 0.0:
		return true
	if not has_prop:
		ledger["dv_faltante"] += dv
		add_log("Sin propulsión para %s (%.1f m/s)." % [why, dv], "bad")
		return false
	var need := Astro.propellant_for(current_mass(), dv, isp)
	if need > prop_kg + 1e-9:
		ledger["dv_faltante"] += dv
		add_log("Propelente insuficiente para %s: faltan %.2f kg." % [why, need - prop_kg], "bad")
		return false
	prop_kg -= need
	dv_used += dv
	return true

func lose(reason: String) -> void:
	if lost:
		return
	lost = true
	lost_reason = reason
	add_log("PÉRDIDA DE LA NAVE: " + reason, "bad")
	_finish()

func _finish() -> void:
	if finished:
		return
	finished = true
	phase = "fin"
	if not lost:
		add_log("Fin de la misión. Ciencia en tierra: %.0f puntos." % sp, "good")

func mod_value(kind: String, default: float = 1.0) -> float:
	var v := default
	for m in mods:
		if m["kind"] == kind and t < m["until"]:
			v *= float(m["value"])
	return v

func mod_active(kind: String) -> bool:
	for m in mods:
		if m["kind"] == kind and t < m["until"]:
			return true
	return false

func add_mod(kind: String, value: float, hours: float, extra: Dictionary = {}) -> void:
	var m := {"kind": kind, "value": value, "until": t + hours * 3600.0}
	m.merge(extra)
	mods.append(m)

func enter_safe(hours: float, reason: String, avoidable: bool) -> void:
	safe_until = maxf(safe_until, t + hours * 3600.0)
	safe_reason = reason
	if avoidable:
		avoidable_safe += 1
	add_log("Modo seguro %.0f h: %s" % [hours, reason], "warn")

func in_safe() -> bool:
	return t < safe_until

## Avanza la simulación hasta `seconds` o hasta agotar `budget_usec`. Devuelve el tiempo avanzado.
func advance(seconds: float, budget_usec: float) -> float:
	if finished or not pending_event.is_empty():
		return 0.0
	var start := Time.get_ticks_usec()
	var done := 0.0
	while done < seconds and not finished and pending_event.is_empty():
		# Con mucha aceleración se agranda el paso, sin pasar del máximo estable del régimen.
		# Se recalcula en cada tick porque el régimen cambia (crucero → órbita lunar).
		var dt := clampf(seconds / 200.0, _base_dt(), _max_dt()) if not fast else _max_dt()
		var h := minf(dt, seconds - done)
		if h <= 0.0:
			break
		_tick(h)
		done += h
		if Time.get_ticks_usec() - start > budget_usec:
			break
	return done

func _base_dt() -> float:
	if phase == "crucero":
		return 300.0
	return 10.0 if regime != "nrho" else 30.0

func _max_dt() -> float:
	if phase == "crucero":
		return 1800.0
	return 120.0 if regime != "nrho" else 600.0

func _tick(dt: float) -> void:
	# 0) Transición crucero → órbita
	if phase == "crucero" and t + dt >= cruise_end:
		dt = maxf(cruise_end - t, 1.0)
	_dynamics(dt)
	if finished:
		return
	_geometry()
	_power(dt)
	_payload_and_link(dt)
	t += dt
	if phase == "crucero" and t >= cruise_end - 0.5:
		_lunar_orbit_insertion()
	_maintenance()
	if events_enabled:
		MissionEvents.tick(self, dt)
	if t >= _prune_t:
		_prune_t = t + DAY
		mods = mods.filter(func(m): return t < m["until"])
	_stats(dt)
	if t >= t_end and not finished:
		_finish()

# ---------------- 1) Dinámica ----------------
func _dynamics(dt: float) -> void:
	match regime:
		"leo":
			env["drag_factor"] = mod_value("drag", 1.0)
			y = _propagate(y, t, dt)
			var r := sqrt(y[0] * y[0] + y[1] * y[1] + y[2] * y[2])
			altitude = r - Astro.R_E
			_mean_r_acc += r * dt
			_mean_t_acc += dt
			if altitude < 150.0:
				lose("reentrada atmosférica")
		"llo":
			if phase == "crucero":
				_cruise_position()
			else:
				y = _propagate(y, t, dt)
				altitude = sqrt(y[0] * y[0] + y[1] * y[1] + y[2] * y[2]) - Astro.R_M - maint["drop_km"]
				if altitude <= 0.0:
					lose("impacto con la superficie lunar: la órbita decayó por los mascones")
		"nrho":
			if phase == "crucero":
				_cruise_position()
			else:
				nrho_t = fmod(nrho_t + dt, nrho_period)
				var p := _nrho_state(nrho_t)
				# Selenocéntrico, ejes inerciales (rotar el marco sinódico con la Luna).
				var th := TAU * t / Astro.T_MOON
				var xr := (p[0] - 1.0 + Astro.MU_CR3BP) * Astro.CR3BP_L
				var yr := p[1] * Astro.CR3BP_L
				y[0] = xr * cos(th) - yr * sin(th)
				y[1] = xr * sin(th) + yr * cos(th)
				y[2] = p[2] * Astro.CR3BP_L
				altitude = sqrt(y[0] * y[0] + y[1] * y[1] + y[2] * y[2]) - Astro.R_M
				if maint["err_km"] > 8000.0:
					lose("la NRHO divergió sin mantenimiento y la nave escapó")

## RK4 con subpasos de ≤ 30 s: con pasos de 120 s el RK4 disipa energía (≈0.75 km/día
## de decaimiento falso en LEO, medido en tests/run_tests.gd). Los subsistemas sí usan ticks largos.
const MAX_DYN_STEP := 30.0

func _propagate(state: PackedFloat64Array, t0: float, dt: float) -> PackedFloat64Array:
	var n := maxi(1, int(ceil(dt / MAX_DYN_STEP)))
	var h := dt / float(n)
	var s := state
	for i in n:
		s = Astro.rk4_step(s, t0 + h * i, h, env)
	return s

func _nrho_state(ts: float) -> PackedFloat64Array:
	var f := ts / nrho_period * float(nrho_table.size() - 1)
	var i := clampi(int(f), 0, nrho_table.size() - 2)
	var w := f - float(i)
	var a: PackedFloat64Array = nrho_table[i]
	var b: PackedFloat64Array = nrho_table[i + 1]
	return PackedFloat64Array([lerpf(a[0], b[0], w), lerpf(a[1], b[1], w), lerpf(a[2], b[2], w)])

## Crucero: trayecto ilustrativo Tierra → Luna (el Δv lo pone el lanzador; GDD tabla Δv).
func _cruise_position() -> void:
	var u := clampf(t / cruise_end, 0.0, 1.0)
	var m := Astro.moon_pos(cruise_end)
	var s := sin(u * PI)
	var side := Astro.v3(-m[1], m[0], 0.0)
	var k := 0.35 if pf.get("dias_extra", 0) > 0 else 0.1  # la transferencia balística sale lejos
	var p := Astro.vadd(Astro.vmul(m, u), Astro.vmul(side, k * s * (2.5 if k > 0.2 else 1.0)))
	y[0] = p[0]
	y[1] = p[1]
	y[2] = p[2]
	altitude = Astro.vnorm(p) - Astro.R_E

func _lunar_orbit_insertion() -> void:
	var dv := loi_dv * mod_value("loi_dv", 1.0) + float(maint.get("loi_extra", 0.0))
	add_log("Inserción en órbita lunar: quemado de %.0f m/s." % dv, "info")
	if not spend_dv(dv, "la inserción lunar"):
		lose("sin Δv para la inserción: la nave siguió de largo")
		return
	phase = "ciencia"
	central = "moon"
	if regime == "llo":
		y = Astro.circular_state(Astro.MU_M, Astro.R_M + 100.0, 90.0, 0.0, 0.0, current_mass())
		env = {"central": "moon", "earth": true, "sun": false}
	else:
		nrho_t = 0.0
	maint["next"] = t + 28.0 * DAY if regime == "llo" else t + nrho_period
	add_log("En órbita. Empieza el año de ciencia.", "good")
	if events_enabled:
		MissionEvents.on_orbit(self)

# ---------------- Mantenimiento de órbita ----------------
func _maintenance() -> void:
	if phase != "ciencia" or finished:
		return
	match regime:
		"leo":
			# Radio medio de un día (≈15 órbitas): J2 hace oscilar el radio osculador ±10 km
			# y una sola órbita da una media demasiado ruidosa para decidir quemados.
			if _mean_t_acc >= DAY:
				var mean_r := _mean_r_acc / _mean_t_acc
				_mean_r_acc = 0.0
				_mean_t_acc = 0.0
				if _mean_a_ref < 0.0:
					_mean_a_ref = mean_r
				elif _mean_a_ref - mean_r > 0.5:
					var v := sqrt(y[3] * y[3] + y[4] * y[4] + y[5] * y[5])
					var dv_kms := v / (2.0 * mean_r) * (_mean_a_ref - mean_r)
					if has_prop and spend_dv(dv_kms * 1000.0, "mantener la altitud"):
						for i in 3:
							y[3 + i] += y[3 + i] / v * dv_kms
					else:
						# Sin propelente: se anota una vez el Δv que faltó y la órbita sigue cayendo.
						if not has_prop and float(pf["dv"]) > 0.0:
							ledger["dv_faltante"] += dv_kms * 1000.0
						_mean_a_ref = mean_r
		"llo":
			# La deriva por mascones se integra en _drift(); aquí solo se corrige.
			if t >= maint["next"]:
				_llo_maintenance()
		"nrho":
			if t >= maint["next"]:
				maint["next"] = t + nrho_period
				if maint["skip"] > 0:
					maint["skip"] -= 1
					add_log("Mantenimiento NRHO omitido: el error crece (se duplica cada ≈7 días).", "warn")
				else:
					var dv: float = 0.25 + maint["err_km"] * 0.002
					if spend_dv(dv, "mantener la NRHO"):
						maint["err_km"] = 1.0
					else:
						add_log("Sin propelente para mantener la NRHO.", "bad")

func _llo_maintenance() -> void:
	maint["next"] = t + 28.0 * DAY
	if maint["skip"] > 0:
		maint["skip"] -= 1
		add_log("Mantenimiento omitido: el periluna sigue cayendo (%.0f km perdidos)." % maint["drop_km"], "warn")
		return
	var dv: float = 10.0 * (1.0 / 3.0 if maint["frozen"] else 1.0) * (1.0 + maint["drop_km"] / 20.0)
	if spend_dv(dv, "mantener la órbita lunar"):
		maint["drop_km"] = 0.0

func _drift(dt: float) -> void:
	if phase != "ciencia":
		return
	if regime == "llo":
		var rate := 4.0 * (1.0 / 3.0 if maint["frozen"] else 1.0) * exp(maint["drop_km"] / 25.0)
		maint["drop_km"] += rate * dt / (30.0 * DAY)
	elif regime == "nrho":
		maint["err_km"] *= pow(2.0, dt / (7.0 * DAY))

# ---------------- 2) Geometría ----------------
func sc_eci() -> PackedFloat64Array:
	if central == "moon" or (phase == "ciencia" and regime != "leo"):
		return Astro.vadd(Astro.moon_pos(t), Astro.v3(y[0], y[1], y[2]))
	return Astro.v3(y[0], y[1], y[2])

func _geometry() -> void:
	var r := sc_eci()
	var sun := Astro.sun_pos(t)
	var moon := Astro.moon_pos(t)
	if phase == "crucero":
		sun_f = 1.0
	else:
		sun_f = Astro.sunlit_fraction(r, sun, Astro.v3(0, 0, 0), Astro.R_E)
		if regime != "leo":
			sun_f = minf(sun_f, Astro.sunlit_fraction(r, sun, moon, Astro.R_M))
	if mod_active("lunar_eclipse"):
		sun_f = 0.0
	# Enlace
	in_contact = false
	contact_station = ""
	link_mbps = 0.0
	if mod_active("antenna_stowed"):
		return
	var rate_key := "mbps_" + str(sc["regimen"])
	var base_rate := float(ev["com"].get(rate_key, 0.0))
	if regime == "leo":
		for st in _stations:
			if mod_active("station_out_" + st["id"]):
				continue
			var gs := Astro.station_eci(st["lat"], st["lon"], t)
			if Astro.elevation_deg(r, gs) >= 10.0:
				in_contact = true
				contact_station = st["nombre"]
				break
	else:
		# DSN: bloques de 2 h/día contratados; hace falta línea de vista y que la Luna no tape.
		var hour := fmod(t / 3600.0, 24.0)
		var in_block := false
		var block_len := 2.0 * mod_value("contact", 1.0)
		for k in int(design["bloques"]):
			var h0 := fmod(2.0 + 8.0 * k, 24.0)
			if hour >= h0 and hour < h0 + block_len:
				in_block = true
		if in_block:
			var best := -90.0
			var best_name := ""
			for st in _stations:
				var gs := Astro.station_eci(st["lat"], st["lon"], t)
				var el := Astro.elevation_deg(r, gs)
				if el > best:
					best = el
					best_name = st["nombre"]
			var blocked := phase == "ciencia" and Astro.segment_blocked(r, Astro.v3(0, 0, 0), moon, Astro.R_M)
			if best >= 10.0 and not blocked:
				in_contact = true
				contact_station = best_name
	if in_contact:
		var rate := base_rate
		if regime != "leo" and phase == "ciencia":
			rate = Astro.link_rate(base_rate, Astro.D_EM, Astro.vnorm(r), base_rate * 1.2)
		link_mbps = rate * mod_value("link", 1.0) * rate_perm_mult

# ---------------- 3) Potencia ----------------
func _instrument_active(id: String) -> bool:
	if phase != "ciencia" or in_safe() or shed or not ins_on.get(id, false):
		return false
	if mod_active("ins_off_" + id):
		return false
	if sun_f < 0.5 and (eclipse_gate or eclipse_gate_ids.has(id)):
		return false
	return true

func _power(dt: float) -> void:
	var years := t / (365.0 * DAY)
	var pan: Dictionary = ev["pan"]
	gen_w = float(pan["potencia_w"]) * sun_f * 0.85 * pow(1.0 - float(pan["degradacion_anual"]), years) * panel_mult
	var bus: Dictionary = ev["bus"]
	var load := float(bus["potencia_base_w"])
	for i in ev["ins"]:
		var d := minf(duty, float(i["ciclo_max"]))
		if _instrument_active(i["id"]):
			load += float(i["activo_w"]) * d + float(i["espera_w"]) * (1.0 - d)
		else:
			load += float(i["espera_w"])
	if in_contact:
		load += float(ev["com"]["potencia_w"])
	load_w = load
	var de := (gen_w - load) * dt / 3600.0
	if de > 0.0:
		de *= 0.9
	energy = clampf(energy + de, 0.0, cap_wh)
	var dod := dod_override if dod_override > 0.0 else dod_max
	if mod_active("dod_relax"):
		dod = 0.8
	var floor_e := cap_wh * (1.0 - dod)
	# Corte de cargas con histéresis.
	if not shed and energy < floor_e:
		shed = true
		add_log("Batería bajo el límite de DoD: instrumentos a espera.", "warn")
	elif shed and energy > floor_e + 0.15 * cap_wh:
		shed = false
	if shed and phase == "ciencia" and not in_safe():
		ledger["h_sin_energia"] += dt / 3600.0
	if energy <= 0.0 and not in_safe():
		if mod_active("lunar_eclipse") and rng.randf() < 0.3:
			lose("bajo voltaje durante el eclipse lunar total")
			return
		enter_safe(6.0, "batería agotada", true)
	# Seguimiento de DoD por eclipse y por mes (eventos de degradación).
	if sun_f < 0.5:
		_ecl_min_e = minf(_ecl_min_e, energy)
		_was_eclipse = true
	elif _was_eclipse:
		_was_eclipse = false
		var depth := 1.0 - _ecl_min_e / cap_wh
		_month_max_dod = maxf(_month_max_dod, depth)
		if dod_override > 0.0 and depth > 0.30:
			cap_wh *= 0.995  # s1e3 «operar igual»: 0.5 % por eclipse sobre el límite
			energy = minf(energy, cap_wh)
			if cap_wh < cap_wh0 * 0.77 and maint.has("s1e3_rec"):
				maint["s1e3_rec"]["good"] = false
		_ecl_min_e = INF
	if t >= _month_next:
		_month_next += 30.0 * DAY
		if maint.get("watch_dod", false) and _month_max_dod > 0.30:
			cap_wh *= 0.99
			add_log("DoD por encima del 30 % este mes: −1 % de capacidad.", "warn")
		_month_max_dod = 0.0

# ---------------- 4–5) Carga útil y enlace ----------------
func _payload_and_link(dt: float) -> void:
	var hours := dt / 3600.0
	var rel := _rel
	var mult := float(ev["usr"]["mult_ciencia"]) * float(ev["shared"]) * quality * mod_value("science", 1.0)
	if phase == "ciencia" and in_safe():
		ledger["h_modo_seguro"] += hours
	for i in ev["ins"]:
		var id: String = i["id"]
		if not _instrument_active(id):
			continue
		var d := minf(duty, float(i["ciclo_max"]))
		var mbh := float(i["mb_h"]) * mod_value("data_" + id, 1.0) * mod_value("data", 1.0)
		var sph := float(i["sp_h"]) * mod_value("sp_" + id, 1.0)
		var mb := mbh * d * hours
		var r := float(rel.get(id, 0.0))
		var value := sph * d * hours * r * mult * float(ins_quality.get(id, 1.0))
		ledger["sp_fuera_objetivo"] += sph * d * hours * (1.0 - r) * mult
		mb_gen += mb
		if mb <= 0.0:
			continue
		var room := maxf(0.0, mem_max - mem_used())
		if room < mb:
			room += _evict(mb - room, value / mb, id)
		var keep := minf(mb, room)
		mem[id]["mb"] += keep
		mem[id]["sp"] += value * keep / mb
		if keep < mb:
			ledger["mb_perdidos"] += mb - keep
	# Enlace: primero los datos con más puntos por MB.
	var used_now := mem_used()
	if in_contact:
		var cap := link_mbps * dt / 8.0
		var ids: Array = mem.keys()
		ids.sort_custom(func(a, b): return _sp_per_mb(a) > _sp_per_mb(b))
		for id in ids:
			if cap <= 0.0:
				break
			var m: Dictionary = mem[id]
			if m["mb"] <= 0.0:
				continue
			var take := minf(cap, m["mb"])
			var f: float = take / m["mb"]
			var spv: float = m["sp"] * f
			sp += spv
			mb_down += take
			m["mb"] -= take
			m["sp"] -= spv
			cap -= take
	elif phase == "ciencia" and used_now > 0.25 * mem_max:
		ledger["h_sin_contacto"] += hours

## Memoria llena: borra datos de menor valor por MB que el entrante. Devuelve los MB liberados.
func _evict(need: float, value_per_mb: float, incoming: String) -> float:
	var freed := 0.0
	var ids: Array = mem.keys()
	ids.sort_custom(func(a, b): return _sp_per_mb(a) < _sp_per_mb(b))
	for id in ids:
		if freed >= need or id == incoming:
			continue
		var m: Dictionary = mem[id]
		if m["mb"] <= 0.0 or _sp_per_mb(id) >= value_per_mb:
			continue
		var take := minf(need - freed, m["mb"])
		m["sp"] -= m["sp"] * take / m["mb"]
		m["mb"] -= take
		freed += take
		ledger["mb_perdidos"] += take
	return freed

func _sp_per_mb(id: String) -> float:
	var m: Dictionary = mem[id]
	return m["sp"] / m["mb"] if m["mb"] > 0.0 else 0.0

func mem_used() -> float:
	var s := 0.0
	for id in mem:
		s += mem[id]["mb"]
	return s

func _stats(dt: float) -> void:
	if phase == "ciencia":
		sci_time += dt
		sun_time += sun_f * dt
		if in_contact:
			contact_time += dt
		_drift(dt)

## Posición de la nave respecto del cuerpo central (km, ejes inerciales).
func sc_rel() -> PackedFloat64Array:
	return Astro.v3(y[0], y[1], y[2])

## Puntos de la órbita a dibujar, respecto del cuerpo central (km).
func orbit_points(n: int = 180) -> Array:
	var pts: Array = []
	if phase == "crucero":
		var keep := t
		for i in n + 1:
			t = cruise_end * float(i) / n
			_cruise_position()
			pts.append(Astro.v3(y[0], y[1], y[2]))
		t = keep
		_cruise_position()
		return pts
	if regime == "nrho":
		var th := TAU * t / Astro.T_MOON
		var step := maxi(1, nrho_table.size() / n)
		for i in range(0, nrho_table.size(), step):
			var p: PackedFloat64Array = nrho_table[i]
			var xr := (p[0] - 1.0 + Astro.MU_CR3BP) * Astro.CR3BP_L
			var yr := p[1] * Astro.CR3BP_L
			pts.append(Astro.v3(xr * cos(th) - yr * sin(th), xr * sin(th) + yr * cos(th), p[2] * Astro.CR3BP_L))
		pts.append(pts[0])
		return pts
	# Cónica osculadora a partir de (r, v).
	var mu := Astro.MU_E if regime == "leo" else Astro.MU_M
	var r := Astro.v3(y[0], y[1], y[2])
	var v := Astro.v3(y[3], y[4], y[5])
	var h := Astro.vcross(r, v)
	var rn := Astro.vnorm(r)
	var e_vec := Astro.vsub(Astro.vmul(Astro.vcross(v, h), 1.0 / mu), Astro.vmul(r, 1.0 / rn))
	var e := Astro.vnorm(e_vec)
	var a := 1.0 / (2.0 / rn - Astro.vdot(v, v) / mu)
	if e >= 0.99 or a <= 0.0:
		return pts
	var P := Astro.vmul(e_vec, 1.0 / e) if e > 1e-6 else Astro.vmul(r, 1.0 / rn)
	var Q := Astro.vcross(h, P)
	Q = Astro.vmul(Q, 1.0 / Astro.vnorm(Q))
	var p_semi := a * (1.0 - e * e)
	for i in n + 1:
		var nu := TAU * float(i) / n
		var rr := p_semi / (1.0 + e * cos(nu))
		pts.append(Astro.vadd(Astro.vmul(P, rr * cos(nu)), Astro.vmul(Q, rr * sin(nu))))
	return pts

## Estaciones contratadas para dibujar (solo LEO): [{nombre, eci}]
func station_points() -> Array:
	var out: Array = []
	if regime != "leo":
		return out
	for st in _stations:
		out.append({"id": st["id"], "nombre": st["nombre"], "eci": Astro.station_eci(st["lat"], st["lon"], t), "out": mod_active("station_out_" + st["id"])})
	return out

func resolve_event(idx: int) -> void:
	MissionEvents.resolve(self, idx)

func summary() -> Dictionary:
	var days := maxf(sci_time / DAY, 1e-6)
	return {
		"sp": sp, "meta": float(sc["meta_sp"]), "lost": lost, "lost_reason": lost_reason, "finished": finished,
		"sun_frac": sun_time / maxf(sci_time, 1.0), "contact_min_day": contact_time / 60.0 / days,
		"mb_down": mb_down, "mb_gen": mb_gen, "ledger": ledger.duplicate(), "dv_used": dv_used, "dv_left": dv_left(),
		"prop_left": prop_kg, "prop_loaded": prop_loaded, "cost_extra": cost_extra, "days": t / DAY,
		"events_total": event_records.size(), "cap_frac": cap_wh / cap_wh0,
	}
