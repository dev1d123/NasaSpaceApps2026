extends Node
## Generador de partículas de polvo estelar y micro-destellos para la interfaz.

static func create_space_dust(rect: Vector2 = Vector2(1600, 900), count: int = 40) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "SpaceDustParticles"
	p.amount = count
	p.lifetime = 12.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = rect * 0.5
	p.position = rect * 0.5
	p.gravity = Vector2(-2.0, -1.0)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.7, 0.85, 1.0, 0.25)
	
	var grad := Gradient.new()
	grad.set_color(0, Color(0.8, 0.9, 1.0, 0.0))
	grad.add_point(0.2, Color(0.8, 0.9, 1.0, 0.35))
	grad.add_point(0.8, Color(0.6, 0.8, 1.0, 0.35))
	grad.set_color(1, Color(0.6, 0.8, 1.0, 0.0))
	p.color_ramp = grad
	return p

static func create_telemetry_sparkle(pos: Vector2, color: Color = Color("#4cc38a")) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.85
	p.position = pos
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.finished.connect(p.queue_free)
	return p
