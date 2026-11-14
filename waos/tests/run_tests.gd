extends Node
## Pruebas headless del núcleo. Ejecutar:
##   Godot --headless --path . res://tests/run_tests.tscn

var fails := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  OK   ", name, "  ", detail)
	else:
		fails += 1
		print("  FAIL ", name, "  ", detail)

func near(a: float, b: float, rel: float) -> bool:
	return absf(a - b) <= rel * maxf(absf(b), 1e-9)

func _ready() -> void:
	var gd = get_tree().root.get_node_or_null("GameData")
	if gd == null:
		print("FAIL: autoload GameData no disponible")
		get_tree().quit(1)
		return
	gd.load_data()
	var only := OS.get_environment("WAOS_TEST")
	if only == "" or only == "core":
		test_evaluator()
		test_physics()
	if only == "" or only == "sim":
		test_missions()
	print("\n", "TODO OK" if fails == 0 else "%d FALLOS" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func test_evaluator() -> void:
	print("\n[Evaluador vs JS del GDD]")
	# Valores calculados con evaluate() del documento original (Node).
	var golden := {
		"s1": {"wet": 8.0, "dv": 0.0, "load": 10.2444, "gen": 15.81, "ecl_wh": 6.1125, "bat_wh": 24.0, "down": 660.0, "sp": 950.4, "cost": 1.91726, "months": 20},
		"s2": {"wet": 299.5, "dv": 224.7147, "load": 224.5383, "gen": 816.0, "ecl_wh": 132.1034, "bat_wh": 150.0, "down": 247500.0, "sp": 78183.0, "cost": 115.3965, "months": 42},
		"s3": {"wet": 213.7, "dv": 875.6378, "load": 91.1, "gen": 207.4, "ecl_wh": 70.6025, "bat_wh": 150.0, "down": 1800.0, "sp": 113880.0, "cost": 71.5, "months": 30},
	}
	for id in golden:
		var d: Dictionary = GameData.reference_design(id)
		var e := DesignEval.evaluate(d)
		var g: Dictionary = golden[id]
		var years: float = float(e["sc"]["duracion_dias"]) / 365.0
		for k in g:
			var expected: float = float(g[k])
			if k == "cost":
				expected += 0.1 * years   # el juego suma el nivel L1 del segmento de usuario
			check("%s.%s" % [id, k], near(float(e[k]), expected, 1e-4), "%.4f vs %.4f" % [float(e[k]), expected])
		check("%s referencia pasa las 8" % id, e["all_ok"])
	# Diseño "con todo" no debe alcanzar (GDD sección 6).
	var full: Dictionary = GameData.reference_design("s2")
	full["ins"] = ["cam", "ir", "sar", "neut", "uv", "rad", "mag"]
	full["bus"] = "leostar3"
	full["pan"] = "pan4500"
	full["bat"] = "bat6000"
	full["prop"] = "mono_large"
	full["lv"] = "falcon9"
	full["com"] = "ka"
	check("s2 diseño con todo no cabe en presupuesto", not DesignEval.evaluate(full)["checks"]["costo"]["ok"])

func test_physics() -> void:
	print("\n[Física]")
	# Δv de LRO (GDD 2.7): 1916 → 1018 kg con Isp 220 s ≈ 1 365 m/s.
	var dv := Astro.delta_v(1916, 1018, 220)
	check("Tsiolkovski LRO", dv > 1300 and dv < 1400, "%.1f m/s" % dv)
	check("SSO 500 km", near(Astro.sso_inclination_deg(Astro.R_E + 500), 97.4015, 1e-5))

	# Eclipse en LEO: propagar una órbita ecuatorial en el plano de la eclíptica cercana
	# y comparar el tiempo en sombra con la solución analítica (máximo para beta = 0).
	var a := Astro.R_E + 500.0
	var t0 := 0.0
	# Sol en t=0 está en +x. Órbita en el plano que contiene al Sol (beta ≈ 0): inc = oblicuidad.
	var y := Astro.circular_state(Astro.MU_E, a, rad_to_deg(Astro.OBLIQ), 0.0, 0.0, 10.0)
	var env := {"central": "earth"}
	var dt := 5.0
	var per := Astro.period(a, Astro.MU_E)
	var shadow := 0.0
	var t := t0
	var start_ms := Time.get_ticks_usec()
	var steps := 0
	while t < per:
		var f := Astro.sunlit_fraction(Astro.v3(y[0], y[1], y[2]), Astro.sun_pos(t), Astro.v3(0, 0, 0), Astro.R_E)
		shadow += (1.0 - f) * dt
		y = Astro.rk4_step(y, t, dt, env)
		t += dt
		steps += 1
	var us_per_step := float(Time.get_ticks_usec() - start_ms) / steps
	var ana := Astro.max_eclipse(a, Astro.R_E, Astro.MU_E)
	check("Eclipse LEO vs analítico", near(shadow, ana, 0.02), "%.1f s vs %.1f s" % [shadow, ana])
	var r_end := Astro.vnorm(Astro.v3(y[0], y[1], y[2]))
	check("RK4 conserva el radio en 1 órbita", absf(r_end - a) < 0.01, "%.5f km" % (r_end - a))
	print("    coste: %.1f µs por paso RK4 (con eclipse)" % us_per_step)

	# J2 + arrastre: un CubeSat a 500 km debe perder altura lentamente.
	var yd := Astro.circular_state(Astro.MU_E, a, 97.4, 0.0, 0.0, 8.0)
	var envd := {"central": "earth", "j2": true, "drag": true, "cd_a": 0.066, "drag_factor": 1.0}
	t = 0.0
	var h_samples: Array = []
	start_ms = Time.get_ticks_usec()
	steps = 0
	while t < 86400.0 * 2:
		yd = Astro.rk4_step(yd, t, 30.0, envd)
		t += 30.0
		steps += 1
	print("    coste J2+arrastre: %.1f µs por paso" % (float(Time.get_ticks_usec() - start_ms) / steps))
	var hd := Astro.vnorm(Astro.v3(yd[0], yd[1], yd[2])) - Astro.R_E
	check("J2 + arrastre mantiene la órbita acotada en 2 días", hd > 470 and hd < 530, "h = %.2f km" % hd)

	# Deriva numérica: sin arrastre, el radio medio diario no debe caer con pasos de 30 s.
	var a525 := Astro.R_E + 525.0
	var yn := Astro.circular_state(Astro.MU_E, a525, Astro.sso_inclination_deg(a525), 0.0, 0.0, 300.0)
	var envn := {"central": "earth", "j2": true}
	var means: Array = []
	t = 0.0
	for dday in 5:
		var acc := 0.0
		var n := 0
		while t < (dday + 1) * 86400.0:
			yn = Astro.rk4_step(yn, t, 30.0, envn)
			t += 30.0
			acc += Astro.vnorm(Astro.v3(yn[0], yn[1], yn[2]))
			n += 1
		means.append(acc / n)
	check("RK4 30 s sin deriva secular (J2)", absf(means[4] - means[1]) < 0.1, "%.4f km en 3 días" % (means[4] - means[1]))

	# CR3BP: corrector NRHO y conservación de Jacobi.
	var mu := Astro.MU_CR3BP
	var res := Astro.correct_halo(1.0221, -0.1821, -0.1033, mu)
	var s: PackedFloat64Array = res["state"]
	check("Corrector NRHO converge", res["ok"], "x0=%.10f vy0=%.10f T=%.6f (%.2f d)" % [s[0], s[4], res["period"], res["period"] * Astro.CR3BP_T / 86400.0])
	var c0 := Astro.jacobi(s, mu)
	var ss := s.duplicate()
	var tt := 0.0
	var rmin := 1e9
	while tt < res["period"]:
		var h := Astro.cr3bp_step_size(ss, mu, 0.01)
		ss = Astro.cr3bp_rk4(ss, h, mu)
		tt += h
		rmin = minf(rmin, sqrt(pow(ss[0] - 1 + mu, 2) + ss[1] * ss[1] + ss[2] * ss[2]))
	check("Jacobi se conserva en un periodo", absf(Astro.jacobi(ss, mu) - c0) < 1e-8, "ΔC = " + str(Astro.jacobi(ss, mu) - c0))
	check("NRHO vuelve al inicio (periódica)", absf(ss[0] - s[0]) < 1e-4 and absf(ss[2] - s[2]) < 1e-4, "dx=" + str(ss[0] - s[0]) + " dz=" + str(ss[2] - s[2]))
	print("    periluna NRHO: %.0f km de radio" % (rmin * Astro.CR3BP_L))

func test_missions() -> void:
	print("\n[Simulación de misión completa, diseño de referencia, sin eventos]")
	for id in ["s1", "s2", "s3"]:
		var d: Dictionary = GameData.reference_design(id)
		var sim = load("res://scripts/core/mission_sim.gd").new()
		sim.setup(d, {"seed": 7, "events": false, "fast": true})
		var t0 := Time.get_ticks_msec()
		while not sim.finished:
			sim.advance(86400.0 * 5, 1e9)
		var ms := Time.get_ticks_msec() - t0
		var ev: Dictionary = DesignEval.evaluate(d)
		var r: Dictionary = sim.summary()
		print("    %s: %d ms · SP %.0f (estimado CML3 %.0f, meta %.0f) · contacto %.1f min/día · sol %.2f · perdido=%s" % [id, ms, r["sp"], ev["sp"], ev["sc"]["meta_sp"], r["contact_min_day"], r["sun_frac"], r["lost"]])
		print("       cuellos: ", r["ledger"])
		check("%s nave sobrevive" % id, not r["lost"], str(r.get("lost_reason", "")))
		check("%s alcanza la meta científica" % id, r["sp"] >= float(ev["sc"]["meta_sp"]), "%.0f" % r["sp"])
		check("%s fracción de sol coherente con el GDD" % id, absf(r["sun_frac"] - float(ev["pf"]["f_sol"])) < 0.08, "%.3f vs %.3f" % [r["sun_frac"], ev["pf"]["f_sol"]])
	print("\n[Con eventos y política automática]")
	for id in ["s1", "s2", "s3"]:
		var d: Dictionary = GameData.reference_design(id)
		var sim = load("res://scripts/core/mission_sim.gd").new()
		sim.setup(d, {"seed": 11, "events": true, "fast": true})
		var guard := 0
		while not sim.finished and guard < 100000:
			guard += 1
			sim.advance(86400.0 * 5, 1e9)
			if sim.pending_event != null and not sim.pending_event.is_empty():
				sim.resolve_event(0)
		var r: Dictionary = sim.summary()
		var score: Dictionary = load("res://scripts/core/scoring.gd").compute(sim, d, 1)
		print("    %s: SP %.0f · eventos %d · puntaje %.1f · perdido=%s %s" % [id, r["sp"], r["events_total"], score["total"], r["lost"], r.get("lost_reason", "")])
		check("%s termina" % id, sim.finished)
		var m: Dictionary = load("res://scripts/core/scoring.gd").match_mission(d, DesignEval.evaluate(d))
		print("       misión parecida: %s (%d %%)" % [m["mision"]["nombre"], m["parecido"]])
