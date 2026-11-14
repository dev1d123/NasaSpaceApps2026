class_name SpacecraftModel
extends Node3D
## Nave en greybox armada con primitivas a partir del diseño. Medidas en metros,
## aproximadas a la clase real de cada componente para que la escala enseñe algo.

const BUS_SIZE := {
	"cube3u": Vector3(0.10, 0.34, 0.10), "cube6u": Vector3(0.22, 0.34, 0.10), "cube12u": Vector3(0.22, 0.34, 0.22),
	"espa": Vector3(0.6, 0.8, 0.6), "leostar2": Vector3(1.0, 1.5, 1.0), "leostar3": Vector3(1.9, 3.0, 1.9),
	"deep": Vector3(1.6, 2.4, 1.6),
}
const INS_COLOR := {
	"cubecam": Color("#7fa7c9"), "cam": Color("#7fa7c9"), "ir": Color("#c98a7f"), "sar": Color("#a9a9a9"),
	"mag": Color("#c9b87f"), "neut": Color("#8fc97f"), "uv": Color("#a07fc9"), "rad": Color("#c97fa9"),
}

var bounds := AABB()

static func mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

func _part(mesh: Mesh, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat(c)
	add_child(mi)
	var ab := mesh.get_aabb()
	var xf := Transform3D(Basis.from_euler(rot), pos)
	bounds = bounds.merge(xf * ab) if bounds.size != Vector3.ZERO else xf * ab
	return mi

func _box(size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _part(b, pos, c, rot)

func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 24
	return _part(m, pos, c, rot)

func _sphere(r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return _part(m, pos, c)

func build(design: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	bounds = AABB()
	var bus_id: String = design["bus"]
	var s: Vector3 = BUS_SIZE.get(bus_id, Vector3.ONE)
	var grey := Color("#b9bec8")
	var dark := Color("#5d6372")
	# Bus: eje Y = eje largo; +Z = cara nadir (instrumentos); -Y = propulsión.
	_box(s, Vector3.ZERO, grey)
	# Rieles de CubeSat o aristas del bus
	if bus_id.begins_with("cube"):
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(Vector3(0.008, s.y + 0.012, 0.008), Vector3(sx * s.x / 2, 0, sz * s.z / 2), dark)
	else:
		_box(Vector3(s.x * 1.02, 0.03, s.z * 1.02), Vector3(0, -s.y / 2, 0), dark)
		_box(Vector3(s.x * 1.02, 0.03, s.z * 1.02), Vector3(0, s.y / 2, 0), dark)

	# Paneles: área = P / (1361 · η · 0.8). Dos alas en ±X, salvo los montados en cuerpo.
	var pan := GameData.by_id("paneles", design["pan"])
	var area := float(pan["potencia_w"]) / (1361.0 * float(pan["eficiencia"]) * 0.8)
	var cell := Color("#2c3f73")
	if design["pan"] == "pan8":
		for sx in [-1, 1]:
			_box(Vector3(0.004, s.y * 0.9, s.z * 0.9), Vector3(sx * (s.x / 2 + 0.003), 0, 0), cell)
	elif design["pan"] == "rosa":
		var w := sqrt(area / 2.0 / 3.0)
		for sx in [-1, 1]:
			var len := area / 2.0 / w
			_cyl(0.04 * w + 0.02, 0.04 * w + 0.02, w, Vector3(sx * (s.x / 2 + 0.15), 0, 0), dark, Vector3(PI / 2, 0, 0))
			_box(Vector3(len, 0.01, w), Vector3(sx * (s.x / 2 + 0.2 + len / 2), 0, 0), cell)
	else:
		var wing := area / 2.0
		var w := minf(sqrt(wing / 2.5), s.y * 1.2)
		var len := wing / w
		for sx in [-1, 1]:
			_box(Vector3(0.12 * w + 0.05, 0.02, 0.02), Vector3(sx * (s.x / 2 + 0.06 * w + 0.025), 0, 0), dark)
			_box(Vector3(len, w, 0.012), Vector3(sx * (s.x / 2 + 0.12 * w + 0.05 + len / 2), 0, 0), cell)

	# Propulsión: tanque (hidracina ≈ 1 t/m³) y tobera o rejilla iónica.
	var prop := GameData.by_id("propulsion", design["prop"])
	if design["prop"] != "none":
		var vol := maxf(float(prop["tanque_kg"]), 0.2) / 1000.0
		var r := clampf(pow(vol * 3.0 / (4.0 * PI), 1.0 / 3.0), 0.02, s.x * 0.45)
		_sphere(r, Vector3(0, -s.y / 2 - r * 0.6, 0), Color("#9aa4b5"))
		var noz := clampf(s.x * 0.12, 0.012, 0.3)
		if prop["tipo"] == "eléctrica":
			_cyl(noz * 1.6, noz * 1.6, noz * 0.5, Vector3(0, -s.y / 2 - r * 1.2 - noz * 0.3, 0), Color("#6e88b8"))
		else:
			_cyl(noz * 0.4, noz, noz * 2.0, Vector3(0, -s.y / 2 - r * 1.2 - noz, 0), dark)

	# Comunicaciones en la cara -Z (apunta a Tierra cuando no hay ciencia).
	var com: String = design["com"]
	match com:
		"uhf":
			for k in 4:
				var ang := k * PI / 2.0
				_box(Vector3(0.004, 0.17, 0.002), Vector3(cos(ang) * s.x * 0.5, s.y / 2 + 0.085, sin(ang) * s.z * 0.5), Color("#d7c27a"))
		"sband", "xpatch":
			var p := minf(s.x, s.z) * 0.6
			_box(Vector3(p, p, 0.01), Vector3(0, s.y * 0.25, -s.z / 2 - 0.005), Color("#d7c27a"), Vector3(PI / 2, 0, 0))
		"xhga", "ka":
			var d := 0.6 if com == "xhga" else 1.0
			if bus_id.begins_with("cube"):
				d = 0.3
			var boom := d * 0.5
			_cyl(0.015, 0.015, boom, Vector3(0, s.y / 2 + boom / 2, 0), dark)
			_cyl(d / 2, d * 0.12, d * 0.18, Vector3(0, s.y / 2 + boom + d * 0.09, 0), Color("#e2e4ea"))
			_cyl(0.01, 0.02, d * 0.25, Vector3(0, s.y / 2 + boom + d * 0.2, 0), dark)

	# Instrumentos en la cara +Z (nadir). Tamaño ∝ ∛masa.
	var ins: Array = design["ins"]
	var n := ins.size()
	for i in n:
		var id: String = ins[i]
		var item := GameData.by_id("instrumentos", id)
		var c: Color = INS_COLOR.get(id, grey)
		var u := (float(i) + 0.5) / maxf(n, 1) - 0.5
		var px := u * s.x * 0.8
		match id:
			"sar":
				var L := 3.0 if not bus_id.begins_with("cube") else 0.3
				_box(Vector3(L * 0.25, L, 0.05), Vector3(0, 0, s.z / 2 + 0.05), c)
			"mag":
				var boom := clampf(s.y * 1.5, 0.3, 3.0)
				_cyl(0.008, 0.008, boom, Vector3(-s.x / 2 - 0.02, -s.y / 2 - boom / 2 + s.y * 0.2, s.z / 2), dark)
				_box(Vector3(0.05, 0.05, 0.05) * clampf(s.x * 3.0, 0.5, 1.5), Vector3(-s.x / 2 - 0.02, -s.y / 2 - boom + s.y * 0.2, s.z / 2), c)
			_:
				var k := clampf(pow(float(item["masa"]) / 1000.0, 1.0 / 3.0) * 1.2, 0.035, s.x * 0.6)
				_box(Vector3(k, k, k * 1.3), Vector3(px, s.y * 0.15, s.z / 2 + k * 0.65), c)
				_cyl(k * 0.3, k * 0.3, k * 0.25, Vector3(px, s.y * 0.15, s.z / 2 + k * 1.4), Color("#202430"), Vector3(PI / 2, 0, 0))
