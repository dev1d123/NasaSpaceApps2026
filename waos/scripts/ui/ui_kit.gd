class_name UIKit
extends RefCounted
## Tema y piezas de interfaz de alta fidelidad estilo Centro de Control NASA / JPL.
## Incorpora tipografía aeroespacial, glassmorphism, tarjetas con vista previa 3D,
## paneles anunciadores estilo cabina espacial y retroalimentación táctil procedimental.

const UISound = preload("res://scripts/ui/ui_sound.gd")
const UIParticles = preload("res://scripts/ui/ui_particles.gd")

# ---------- Paleta cromática oficial ----------
const BG := Color("#080c18")
const SURFACE := Color("#11182c")
const SUNKEN := Color("#0a0f1e")
const SURFACE_GLASS := Color(0.07, 0.10, 0.18, 0.92)
const INK := Color("#e8ecf6")
const INK_BRIGHT := Color("#ffffff")
const MUTED := Color("#8e9bb2")
const LINE := Color("#222c46")
const LINE_GLOW := Color("#394b75")
const ACCENT := Color("#ff6a3d")     # Naranja aerospacial NASA
const REAL := Color("#5aa2ff")       # Azul misiones reales
const GAME := Color("#f0b34a")       # Ámbar advertencias/juego
const GOOD := Color("#3dd68c")       # Verde GO / Nominal
const WARN := Color("#f5a742")       # Ámbar precaución
const BAD := Color("#ff5c5c")        # Rojo alarma / NO-GO

static var _theme: Theme
static var _previews_cache := {}
static var _font_main: SystemFont
static var _font_mono: SystemFont
static var _font_title: SystemFont
# Respaldo para símbolos (→ ▸ ← ✓) cuando no hay fuentes del sistema, como en la versión web.
const FALLBACK_SANS := preload("res://assets/fonts/DejaVuSans.ttf")
const FALLBACK_MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")

# ---------- Tipografía Aeroespacial ----------
static func font_main() -> SystemFont:
	if _font_main == null:
		_font_main = SystemFont.new()
		_font_main.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Inter", "Sans-Serif"])
		_font_main.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_font_main.fallbacks = [FALLBACK_SANS]
	return _font_main

static func font_mono() -> SystemFont:
	if _font_mono == null:
		_font_mono = SystemFont.new()
		_font_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "Monospace"])
		_font_mono.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_font_mono.fallbacks = [FALLBACK_MONO]
	return _font_mono

static func font_title() -> SystemFont:
	if _font_title == null:
		_font_title = SystemFont.new()
		_font_title.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Trebuchet MS", "Sans-Serif"])
		_font_title.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_font_title.fallbacks = [FALLBACK_SANS]
	return _font_title

# ---------- Constructores de Cajas y Estilos ----------
static func box(bg: Color, border: Color = LINE, radius: int = 6, pad: int = 10, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.75
	s.content_margin_bottom = pad * 0.75
	return s

static func card_box(bg: Color = SURFACE_GLASS, accent_border: Color = ACCENT, radius: int = 6, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = LINE
	s.set_border_width_all(1)
	s.border_width_top = 3
	s.border_color = accent_border
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font_main()
	t.default_font_size = 14
	t.set_color("font_color", "Label", INK)
	
	# Paneles principales
	t.set_stylebox("panel", "PanelContainer", box(SURFACE_GLASS, LINE, 6, 12))
	t.set_stylebox("panel", "Panel", box(SURFACE_GLASS, LINE, 6, 12))
	
	# Botones de comando
	t.set_stylebox("normal", "Button", box(SURFACE, LINE, 6, 14))
	t.set_stylebox("hover", "Button", box(SURFACE.lightened(0.08), ACCENT, 6, 14))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.3), ACCENT, 6, 14))
	t.set_stylebox("disabled", "Button", box(SUNKEN, LINE.darkened(0.3), 6, 14))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT.lightened(0.2), 6, 14, 1))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK_BRIGHT)
	t.set_color("font_pressed_color", "Button", INK_BRIGHT)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	
	# Desplegables
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(k, "OptionButton", t.get_stylebox(k, "Button"))
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("panel", "PopupMenu", box(SURFACE, LINE_GLOW, 6, 8, 1))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT.darkened(0.4), ACCENT, 4, 8))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_disabled_color", "PopupMenu", MUTED.darkened(0.3))
	t.set_color("font_hover_color", "PopupMenu", INK_BRIGHT)
	
	# Casillas y switches
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK_BRIGHT)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 3
		empty.content_margin_top = 2
		empty.content_margin_bottom = 2
		t.set_stylebox(k, "CheckBox", empty)
		t.set_stylebox(k, "CheckButton", empty)
	for kind in ["CheckBox"]:
		t.set_icon("unchecked", kind, _check_icon(false, false))
		t.set_icon("checked", kind, _check_icon(true, false))
		t.set_icon("unchecked_disabled", kind, _check_icon(false, true))
		t.set_icon("checked_disabled", kind, _check_icon(true, true))
		
	# Barras de telemetría
	t.set_stylebox("background", "ProgressBar", box(SUNKEN, LINE, 4, 0))
	t.set_stylebox("fill", "ProgressBar", box(GOOD, GOOD, 4, 0, 0))
	
	# Pestañas de rol
	t.set_stylebox("panel", "TabContainer", box(SURFACE_GLASS, LINE, 6, 12))
	t.set_stylebox("tab_selected", "TabContainer", box(SURFACE, ACCENT, 5, 12, 1))
	t.set_stylebox("tab_unselected", "TabContainer", box(SUNKEN, LINE, 5, 12))
	t.set_stylebox("tab_hovered", "TabContainer", box(SURFACE.lightened(0.06), LINE_GLOW, 5, 12))
	t.set_color("font_selected_color", "TabContainer", INK_BRIGHT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)
	
	# Deslizadores
	for k in [["slider", SUNKEN, LINE], ["grabber_area", ACCENT.darkened(0.2), ACCENT.darkened(0.2)], ["grabber_area_highlight", ACCENT, ACCENT]]:
		var sb := box(k[1], k[2], 3, 0)
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		t.set_stylebox(k[0], "HSlider", sb)
		
	# Scroll
	t.set_stylebox("scroll", "VScrollBar", box(SUNKEN, SUNKEN, 3, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, LINE, 3, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(MUTED, MUTED, 3, 2))
	t.set_stylebox("panel", "TooltipPanel", box(SUNKEN, ACCENT, 4, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	
	_theme = t
	return t

static func _check_icon(checked: bool, disabled: bool) -> ImageTexture:
	var n := 18
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var edge := MUTED if not disabled else LINE
	var fill := ACCENT if not disabled else MUTED.darkened(0.4)
	for yy in n:
		for xx in n:
			var border := xx < 2 or yy < 2 or xx >= n - 2 or yy >= n - 2
			if checked:
				img.set_pixel(xx, yy, fill)
			elif border:
				img.set_pixel(xx, yy, edge)
	if checked:
		var ink := Color("#1a0d07")
		for i in 4:
			for w in 2:
				img.set_pixel(4 + i, 8 + i + w, ink)
		for i in 7:
			for w in 2:
				img.set_pixel(7 + i, 11 - i + w, ink)
	return ImageTexture.create_from_image(img)

# ---------- Vistas Previas de Modelos 3D ----------
static func preview_texture(id: String) -> Texture2D:
	if _previews_cache.has(id):
		return _previews_cache[id]
	var path := "res://assets/previews/%s.png" % id
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_previews_cache[id] = tex
		return tex
	var fallback_path := "res://art/previews/%s.png" % id
	if ResourceLoader.exists(fallback_path):
		var tex: Texture2D = load(fallback_path)
		_previews_cache[id] = tex
		return tex
	return null

# ---------- Componentes de la Interfaz ----------
static func label(text: String, size: int = 14, color: Color = INK, wrap: bool = false, mono: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_mono() if mono else font_main())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 50
	return l

static func title(text: String, size: int = 24) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font_title())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK_BRIGHT)
	return l

static func eyebrow(text: String, color: Color = MUTED) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font_title())
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_main())
	if primary:
		b.add_theme_stylebox_override("normal", box(ACCENT, ACCENT, 6, 14))
		b.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.12), ACCENT.lightened(0.12), 6, 14))
		b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.2), ACCENT, 6, 14))
		b.add_theme_color_override("font_color", Color("#1a0d07"))
		b.add_theme_color_override("font_hover_color", Color("#1a0d07"))
	
	# Sonidos táctiles automáticos
	b.mouse_entered.connect(UISound.play_hover)
	b.pressed.connect(UISound.play_click)
	return b

static func panel(bg: Color = SURFACE_GLASS, border: Color = LINE, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 6, pad))
	return p

static func vbox(sep: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func margin(child: Control, m: int) -> MarginContainer:
	var c := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		c.add_theme_constant_override("margin_" + side, m)
	c.add_child(child)
	return c

static func spacer(expand: bool = true) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func sep() -> HSeparator:
	var s := HSeparator.new()
	var st := StyleBoxLine.new()
	st.color = LINE
	st.thickness = 1
	s.add_theme_stylebox_override("separator", st)
	return s

static func pill(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := box(Color(color, 0.14), color, 8, 8, 1)
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	var l := label(text, 11, color)
	l.add_theme_font_override("font", font_title())
	p.add_child(l)
	return p

## Panel anunciador estilo consola espacial (Master Warning / GO-NO GO status)
static func annunciator_tile(text: String, is_go: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var col := GOOD if is_go else BAD
	var bg_col := Color(col, 0.12)
	var st := box(bg_col, col, 4, 8, 1)
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", st)
	
	var h := hbox(6)
	p.add_child(h)
	
	var led := ColorRect.new()
	led.color = col
	led.custom_minimum_size = Vector2(6, 12)
	h.add_child(led)
	
	var l := label(text, 11, col)
	l.add_theme_font_override("font", font_title())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	
	var tag := label("GO" if is_go else "NO-GO", 10, col, false, true)
	h.add_child(tag)
	return p

## Medidor de telemetría de alta fidelidad con interpolación suave (Tween)
static func meter(title_text: String) -> Dictionary:
	var v := vbox(3)
	var row := hbox(6)
	var t := label(title_text, 12, MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := label("–", 12, INK, false, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(t)
	row.add_child(val)
	
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.max_value = 1.0
	bar.step = 0.0001
	v.add_child(row)
	v.add_child(bar)
	return {"root": v, "value": val, "bar": bar, "last_frac": 0.0}

static func set_meter(m: Dictionary, frac: float, text: String, color: Color = GOOD) -> void:
	m["value"].text = text
	var bar: ProgressBar = m["bar"]
	var target := clampf(frac, 0.0, 1.0)
	
	# Transición suave con Tween si el nodo está dentro del árbol activo
	if bar.is_inside_tree():
		var tw := bar.create_tween()
		tw.tween_property(bar, "value", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		bar.value = target
		
	var fill := box(color, color, 4, 0, 0)
	bar.add_theme_stylebox_override("fill", fill)

static func role_tag(role_id: String) -> PanelContainer:
	return pill(GameState.role_label(role_id), GameState.role_color(role_id))

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func fmt_money(m: float) -> String:
	if absf(m) >= 100.0:
		return "%.0f M$" % m
	if absf(m) >= 10.0:
		return "%.1f M$" % m
	return "%.2f M$" % m

static func fmt_time(seconds: float) -> String:
	var d := int(seconds / 86400.0)
	var h := int(fmod(seconds, 86400.0) / 3600.0)
	var m := int(fmod(seconds, 3600.0) / 60.0)
	return "Día %d · %02d:%02d" % [d, h, m]

## Formato oficial de Reloj de Misión NASA (MET: Mission Elapsed Time)
static func fmt_met(seconds: float) -> String:
	var d := int(seconds / 86400.0)
	var h := int(fmod(seconds, 86400.0) / 3600.0)
	var m := int(fmod(seconds, 3600.0) / 60.0)
	var s := int(fmod(seconds, 60.0))
	return "MET +%03dd %02dh %02dm %02ds" % [d, h, m, s]
