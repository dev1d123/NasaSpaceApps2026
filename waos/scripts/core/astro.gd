class_name Astro
extends RefCounted
## Motor físico del GDD (sección 2), portado de JS a GDScript.
## Unidades: km, s, kg. Todo en float de 64 bits (escalares de GDScript);
## no usa Vector3 porque es de 32 bits y pierde precisión a distancias lunares.
## Los vectores son PackedFloat64Array de 3 elementos.

# --- 2.1 Constantes (JPL SSD / NSSDC) ---
const MU_E := 398600.4418
const MU_M := 4902.800066
const MU_S := 1.32712440018e11
const R_E := 6378.137
const R_M := 1737.4
const R_S := 695700.0
const D_EM := 384400.0
const AU := 149597870.7
const J2 := 1.08263e-3
const W_E := 7.2921159e-5
const G0_MS := 9.80665              # m/s²
const T_MOON := 27.321661 * 86400.0
const T_YEAR := 365.256363 * 86400.0
const OBLIQ := 23.4393 * PI / 180.0
const MU_CR3BP := 0.012150585
const CR3BP_L := 384400.0           # km por unidad de longitud
const CR3BP_T := 375190.0           # s por unidad de tiempo

# Atmósfera exponencial por tramos (Vallado): h0 km, rho0 kg/m³, H km
const ATM := [
	[400.0, 3.725e-12, 58.515], [450.0, 1.585e-12, 60.828], [500.0, 6.967e-13, 63.822],
	[600.0, 1.454e-13, 71.835], [700.0, 3.614e-14, 88.667], [800.0, 1.170e-14, 124.64],
]

# --- Álgebra mínima en 64 bits ---
static func v3(x: float, y: float, z: float) -> PackedFloat64Array:
	return PackedFloat64Array([x, y, z])

static func vsub(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[0] - b[0], a[1] - b[1], a[2] - b[2]])

static func vadd(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[0] + b[0], a[1] + b[1], a[2] + b[2]])

static func vmul(a: PackedFloat64Array, s: float) -> PackedFloat64Array:
	return PackedFloat64Array([a[0] * s, a[1] * s, a[2] * s])

static func vdot(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

static func vnorm(a: PackedFloat64Array) -> float:
	return sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2])

static func vcross(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]])

## Conversión a Vector3 de Godot (Y arriba) solo para dibujar, ya escalado.
static func to_godot(a: PackedFloat64Array, scale: float) -> Vector3:
	return Vector3(a[0] * scale, a[2] * scale, -a[1] * scale)

# --- Luna y Sol "sobre rieles" (ECI geocéntrico) ---
static func moon_pos(t: float) -> PackedFloat64Array:
	var th := TAU * t / T_MOON
	return v3(D_EM * cos(th), D_EM * sin(th), 0.0)

static func sun_pos(t: float) -> PackedFloat64Array:
	var th := TAU * t / T_YEAR
	return v3(AU * cos(th), AU * sin(th) * cos(OBLIQ), AU * sin(th) * sin(OBLIQ))

static func density(h_km: float) -> float:
	h_km = maxf(h_km, ATM[0][0])
	var row: Array = ATM[0]
	for r in ATM:
		if h_km >= r[0]:
			row = r
	return row[1] * exp(-(h_km - row[0]) / row[2])

## Aceleración de tercer cuerpo. rb = posición del cuerpo respecto del origen del marco.
static func _third(rx: float, ry: float, rz: float, b: PackedFloat64Array, mu: float, out: PackedFloat64Array) -> void:
	var dx := b[0] - rx
	var dy := b[1] - ry
	var dz := b[2] - rz
	var dr := sqrt(dx * dx + dy * dy + dz * dz)
	var db := sqrt(b[0] * b[0] + b[1] * b[1] + b[2] * b[2])
	var k1 := mu / (dr * dr * dr)
	var k2 := mu / (db * db * db)
	out[0] += dx * k1 - b[0] * k2
	out[1] += dy * k1 - b[1] * k2
	out[2] += dz * k1 - b[2] * k2

## 2.2 Aceleración total. y = [x,y,z,vx,vy,vz,m].
## env: { central:"earth"|"moon", j2, drag, moon, sun, earth, drag_factor, cd_a (m²), thrust_n, dir, isp }
static func accel(y: PackedFloat64Array, t: float, env: Dictionary) -> PackedFloat64Array:
	var rx := y[0]
	var ry := y[1]
	var rz := y[2]
	var d := sqrt(rx * rx + ry * ry + rz * rz)
	var a := PackedFloat64Array([0.0, 0.0, 0.0])
	var central: String = env.get("central", "earth")
	var mu := MU_E if central == "earth" else MU_M
	var k := -mu / (d * d * d)
	a[0] = rx * k
	a[1] = ry * k
	a[2] = rz * k
	if central == "earth":
		if env.get("moon", false):
			_third(rx, ry, rz, moon_pos(t), MU_M, a)
		if env.get("sun", false):
			_third(rx, ry, rz, sun_pos(t), MU_S, a)
		if env.get("j2", false):
			var kj := -1.5 * J2 * MU_E * R_E * R_E / pow(d, 5)
			var z2 := 5.0 * rz * rz / (d * d)
			a[0] += kj * rx * (1.0 - z2)
			a[1] += kj * ry * (1.0 - z2)
			a[2] += kj * rz * (3.0 - z2)
		if env.get("drag", false) and d - R_E < 1000.0:
			var vrx := y[3] + W_E * ry
			var vry := y[4] - W_E * rx
			var vrz := y[5]
			var vr := sqrt(vrx * vrx + vry * vry + vrz * vrz)
			var rho := density(d - R_E) * float(env.get("drag_factor", 1.0))
			var kd := -0.5 * rho * (float(env.get("cd_a", 0.1)) / y[6]) * vr * 1000.0
			a[0] += vrx * kd
			a[1] += vry * kd
			a[2] += vrz * kd
	else:
		# Marco selenocéntrico con ejes paralelos a ECI: la Tierra y el Sol son terceros cuerpos.
		var m := moon_pos(t)
		if env.get("earth", true):
			_third(rx, ry, rz, vmul(m, -1.0), MU_E, a)
		if env.get("sun", false):
			_third(rx, ry, rz, vsub(sun_pos(t), m), MU_S, a)
	var thrust: float = env.get("thrust_n", 0.0)
	if thrust > 0.0:
		var dir: PackedFloat64Array = env["dir"]
		var ka := thrust / y[6] / 1000.0
		a[0] += dir[0] * ka
		a[1] += dir[1] * ka
		a[2] += dir[2] * ka
	return a

static func deriv(y: PackedFloat64Array, t: float, env: Dictionary) -> PackedFloat64Array:
	var a := accel(y, t, env)
	var thrust: float = env.get("thrust_n", 0.0)
	var mdot := -thrust / (float(env.get("isp", 1.0)) * G0_MS) if thrust > 0.0 else 0.0
	return PackedFloat64Array([y[3], y[4], y[5], a[0], a[1], a[2], mdot])

static func _axpy(y: PackedFloat64Array, k: PackedFloat64Array, h: float) -> PackedFloat64Array:
	var o := y.duplicate()
	for i in o.size():
		o[i] += k[i] * h
	return o

## 2.3 RK4
static func rk4_step(y: PackedFloat64Array, t: float, dt: float, env: Dictionary) -> PackedFloat64Array:
	var k1 := deriv(y, t, env)
	var k2 := deriv(_axpy(y, k1, dt * 0.5), t + dt * 0.5, env)
	var k3 := deriv(_axpy(y, k2, dt * 0.5), t + dt * 0.5, env)
	var k4 := deriv(_axpy(y, k3, dt), t + dt, env)
	var o := y.duplicate()
	for i in o.size():
		o[i] += dt / 6.0 * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i])
	return o

## 2.3 Paso adaptativo respecto del cuerpo dominante más cercano (estado geocéntrico).
static func adaptive_dt(r: PackedFloat64Array, t: float, eta: float, dt_min: float, dt_max: float) -> float:
	var de := vnorm(r)
	var dm := vnorm(vsub(r, moon_pos(t)))
	var tau := minf(sqrt(de * de * de / MU_E), sqrt(dm * dm * dm / MU_M))
	return clampf(eta * tau, dt_min, dt_max)

# --- 2.4 CR3BP Tierra–Luna, marco rotante normalizado ---
static func cr3bp_deriv(s: PackedFloat64Array, mu: float) -> PackedFloat64Array:
	var x := s[0]
	var y := s[1]
	var z := s[2]
	var r1 := sqrt((x + mu) * (x + mu) + y * y + z * z)
	var r2 := sqrt((x - 1.0 + mu) * (x - 1.0 + mu) + y * y + z * z)
	var c1 := (1.0 - mu) / (r1 * r1 * r1)
	var c2 := mu / (r2 * r2 * r2)
	return PackedFloat64Array([s[3], s[4], s[5],
		2.0 * s[4] + x - c1 * (x + mu) - c2 * (x - 1.0 + mu),
		-2.0 * s[3] + y - c1 * y - c2 * y,
		-c1 * z - c2 * z])

static func cr3bp_rk4(s: PackedFloat64Array, h: float, mu: float) -> PackedFloat64Array:
	var k1 := cr3bp_deriv(s, mu)
	var k2 := cr3bp_deriv(_axpy(s, k1, h * 0.5), mu)
	var k3 := cr3bp_deriv(_axpy(s, k2, h * 0.5), mu)
	var k4 := cr3bp_deriv(_axpy(s, k3, h), mu)
	var o := s.duplicate()
	for i in 6:
		o[i] += h / 6.0 * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i])
	return o

## Paso CR3BP adaptativo según la distancia a la Luna (normalizado).
static func cr3bp_step_size(s: PackedFloat64Array, mu: float, eta: float) -> float:
	var r2 := sqrt((s[0] - 1.0 + mu) * (s[0] - 1.0 + mu) + s[1] * s[1] + s[2] * s[2])
	return clampf(eta * sqrt(r2 * r2 * r2 / mu), 1e-5, 2e-3)

static func jacobi(s: PackedFloat64Array, mu: float) -> float:
	var x := s[0]
	var y := s[1]
	var z := s[2]
	var r1 := sqrt((x + mu) * (x + mu) + y * y + z * z)
	var r2 := sqrt((x - 1.0 + mu) * (x - 1.0 + mu) + y * y + z * z)
	return x * x + y * y + 2.0 * (1.0 - mu) / r1 + 2.0 * mu / r2 - (s[3] * s[3] + s[4] * s[4] + s[5] * s[5])

## Propaga hasta el siguiente cruce de y = 0 (después de un tiempo mínimo). Devuelve [estado, tiempo].
static func cr3bp_to_y_crossing(s0: PackedFloat64Array, mu: float, t_min: float) -> Array:
	var s := s0.duplicate()
	var t := 0.0
	for _i in 400000:
		var h := cr3bp_step_size(s, mu, 0.01)
		var n := cr3bp_rk4(s, h, mu)
		if t + h > t_min and signf(n[1]) != signf(s[1]) and s[1] != 0.0:
			# Refinar el cruce con bisección sobre el paso.
			var lo := 0.0
			var hi := h
			for _j in 50:
				var mid := (lo + hi) * 0.5
				var m := cr3bp_rk4(s, mid, mu)
				if signf(m[1]) == signf(s[1]):
					lo = mid
				else:
					hi = mid
			return [cr3bp_rk4(s, hi, mu), t + hi]
		s = n
		t += h
	return [s, t]

## Corrector diferencial para órbitas halo/NRHO simétricas: fija z0, ajusta x0 y vy0
## para que vx = vz = 0 en el cruce de medio periodo. Devuelve {state, period, ok}.
static func correct_halo(x0: float, z0: float, vy0: float, mu: float) -> Dictionary:
	var x := x0
	var vy := vy0
	for _it in 25:
		var base := cr3bp_to_y_crossing(PackedFloat64Array([x, 0, z0, 0, vy, 0]), mu, 0.05)
		var f: PackedFloat64Array = base[0]
		if absf(f[3]) < 1e-10 and absf(f[5]) < 1e-10:
			return {"state": PackedFloat64Array([x, 0, z0, 0, vy, 0]), "period": 2.0 * base[1], "ok": true}
		var e := 1e-7
		var fx: PackedFloat64Array = cr3bp_to_y_crossing(PackedFloat64Array([x + e, 0, z0, 0, vy, 0]), mu, 0.05)[0]
		var fv: PackedFloat64Array = cr3bp_to_y_crossing(PackedFloat64Array([x, 0, z0, 0, vy + e, 0]), mu, 0.05)[0]
		var a11 := (fx[3] - f[3]) / e
		var a12 := (fv[3] - f[3]) / e
		var a21 := (fx[5] - f[5]) / e
		var a22 := (fv[5] - f[5]) / e
		var det := a11 * a22 - a12 * a21
		if absf(det) < 1e-14:
			break
		x -= (a22 * f[3] - a12 * f[5]) / det
		vy -= (-a21 * f[3] + a11 * f[5]) / det
	var last := cr3bp_to_y_crossing(PackedFloat64Array([x, 0, z0, 0, vy, 0]), mu, 0.05)
	var lf: PackedFloat64Array = last[0]
	return {"state": PackedFloat64Array([x, 0, z0, 0, vy, 0]), "period": 2.0 * last[1], "ok": absf(lf[3]) < 1e-6 and absf(lf[5]) < 1e-6}

# --- 2.5 Eclipse: fracción del disco solar visible ---
static func sunlit_fraction(r_sc: PackedFloat64Array, r_sun: PackedFloat64Array, r_body: PackedFloat64Array, r_b: float) -> float:
	var to_sun := vsub(r_sun, r_sc)
	var to_body := vsub(r_body, r_sc)
	var ds := vnorm(to_sun)
	var db := vnorm(to_body)
	if db <= r_b:
		return 0.0
	var a := asin(R_S / ds)
	var b := asin(r_b / db)
	var c := acos(clampf(vdot(to_sun, to_body) / (ds * db), -1.0, 1.0))
	if c >= a + b:
		return 1.0
	if c <= b - a:
		return 0.0
	if c <= a - b:
		return 1.0 - (b * b) / (a * a)
	var x := (c * c + a * a - b * b) / (2.0 * c)
	var yy := sqrt(maxf(0.0, a * a - x * x))
	var area := a * a * acos(clampf(x / a, -1.0, 1.0)) + b * b * acos(clampf((c - x) / b, -1.0, 1.0)) - c * yy
	return 1.0 - area / (PI * a * a)

static func segment_blocked(p: PackedFloat64Array, q: PackedFloat64Array, c: PackedFloat64Array, r: float) -> bool:
	var d := vsub(q, p)
	var f := vsub(p, c)
	var tt := clampf(-vdot(f, d) / vdot(d, d), 0.0, 1.0)
	return vnorm(vadd(f, vmul(d, tt))) < r

# --- 2.6 Línea de vista con estaciones ---
static func station_eci(lat_deg: float, lon_deg: float, t: float, theta0: float = 0.0) -> PackedFloat64Array:
	var lat := deg_to_rad(lat_deg)
	var lon := deg_to_rad(lon_deg) + theta0 + W_E * t
	return v3(R_E * cos(lat) * cos(lon), R_E * cos(lat) * sin(lon), R_E * sin(lat))

static func elevation_deg(r_sat: PackedFloat64Array, r_gs: PackedFloat64Array) -> float:
	var rho := vsub(r_sat, r_gs)
	return rad_to_deg(asin(clampf(vdot(rho, r_gs) / (vnorm(r_gs) * vnorm(rho)), -1.0, 1.0)))

static func link_rate(rate_ref: float, dist_ref: float, dist: float, rate_max: float) -> float:
	return minf(rate_max, rate_ref * (dist_ref / dist) * (dist_ref / dist))

# --- 2.7 Tsiolkovski (Δv en m/s, Isp en s) ---
static func delta_v(m0: float, mf: float, isp: float) -> float:
	if isp <= 0.0 or mf <= 0.0 or m0 <= mf:
		return 0.0
	return isp * G0_MS * log(m0 / mf)

static func propellant_for(m0: float, dv: float, isp: float) -> float:
	if isp <= 0.0:
		return INF
	return m0 * (1.0 - exp(-dv / (isp * G0_MS)))

static func burn_time(m_prop: float, isp: float, thrust_n: float) -> float:
	return m_prop * isp * G0_MS / thrust_n

# --- Utilidades de órbita ---
static func period(a_km: float, mu: float) -> float:
	return TAU * sqrt(a_km * a_km * a_km / mu)

static func max_eclipse(a_km: float, r_body: float, mu: float) -> float:
	return period(a_km, mu) / PI * asin(r_body / a_km)

static func sso_inclination_deg(a_km: float) -> float:
	var node_rate := TAU / T_YEAR
	var cosi := -2.0 * node_rate * pow(a_km, 3.5) / (3.0 * J2 * R_E * R_E * sqrt(MU_E))
	return rad_to_deg(acos(cosi))

## Estado de órbita circular. raan e inc en grados, u = argumento de latitud (rad).
static func circular_state(mu: float, a_km: float, inc_deg: float, raan_deg: float, u: float, mass: float) -> PackedFloat64Array:
	var i := deg_to_rad(inc_deg)
	var o := deg_to_rad(raan_deg)
	var v := sqrt(mu / a_km)
	var px := cos(u)
	var py := sin(u)
	# Rotación perifocal → inercial: Rz(Ω)·Rx(i)
	var r := v3(a_km * (cos(o) * px - sin(o) * cos(i) * py), a_km * (sin(o) * px + cos(o) * cos(i) * py), a_km * sin(i) * py)
	var vx := -sin(u)
	var vy := cos(u)
	var vv := v3(v * (cos(o) * vx - sin(o) * cos(i) * vy), v * (sin(o) * vx + cos(o) * cos(i) * vy), v * sin(i) * vy)
	return PackedFloat64Array([r[0], r[1], r[2], vv[0], vv[1], vv[2], mass])
