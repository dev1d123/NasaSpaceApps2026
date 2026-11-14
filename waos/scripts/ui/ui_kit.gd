class_name UIKit
extends RefCounted
## Tema y piezas de interfaz construidas en código (paleta del GDD, modo oscuro).

const BG := Color("#0b1020")
const SURFACE := Color("#121a30")
const SUNKEN := Color("#0e152a")
const INK := Color("#e7ebf4")
const MUTED := Color("#98a3b8")
const LINE := Color("#27324f")
const ACCENT := Color("#ff6a3d")
const REAL := Color("#6db3ff")
const GAME := Color("#f0b34a")
const GOOD := Color("#4cc38a")
const WARN := Color("#f0b34a")
const BAD := Color("#ff7b6b")

static var _theme: Theme

static func box(bg: Color, border: Color = LINE, radius: int = 6, pad: int = 10, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	t.set_stylebox("panel", "PanelContainer", box(SURFACE))
	t.set_stylebox("panel", "Panel", box(SURFACE))
	# Botones
	t.set_stylebox("normal", "Button", box(SURFACE, LINE, 6, 12))
	t.set_stylebox("hover", "Button", box(SURFACE.lightened(0.06), ACCENT, 6, 12))
	t.set_stylebox("pressed", "Button", box(ACCENT.darkened(0.35), ACCENT, 6, 12))
	t.set_stylebox("disabled", "Button", box(SUNKEN, LINE.darkened(0.2), 6, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT, 6, 12))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	# Desplegables
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(k, "OptionButton", t.get_stylebox(k, "Button"))
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("panel", "PopupMenu", box(SURFACE, LINE, 4, 6))
	t.set_stylebox("hover", "PopupMenu", box(ACCENT.darkened(0.4), ACCENT.darkened(0.4), 3, 6))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_disabled_color", "PopupMenu", MUTED.darkened(0.2))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	# Casillas
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_pressed_color", "CheckBox", INK)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 2
		empty.content_margin_top = 2
		empty.content_margin_bottom = 2
		t.set_stylebox(k, "CheckBox", empty)
		t.set_stylebox(k, "CheckButton", empty)
	for kind in ["CheckBox"]:
		t.set_icon("unchecked", kind, _check_icon(false, false))
		t.set_icon("checked", kind, _check_icon(true, false))
		t.set_icon("unchecked_disabled", kind, _check_icon(false, true))
		t.set_icon("checked_disabled", kind, _check_icon(true, true))
	# Barras
	t.set_stylebox("background", "ProgressBar", box(SUNKEN, LINE, 3, 0))
	t.set_stylebox("fill", "ProgressBar", box(GOOD, GOOD, 3, 0, 0))
	# Pestañas
	t.set_stylebox("panel", "TabContainer", box(SURFACE, LINE, 6, 12))
	t.set_stylebox("tab_selected", "TabContainer", box(SURFACE, ACCENT, 4, 10))
	t.set_stylebox("tab_unselected", "TabContainer", box(SUNKEN, LINE, 4, 10))
	t.set_stylebox("tab_hovered", "TabContainer", box(SURFACE.lightened(0.05), LINE, 4, 10))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)
	# Deslizadores
	# La pista toma su alto de los márgenes de contenido: sin ellos solo se ve el punto.
	for k in [["slider", SUNKEN, LINE], ["grabber_area", ACCENT.darkened(0.2), ACCENT.darkened(0.2)], ["grabber_area_highlight", ACCENT, ACCENT]]:
		var sb := box(k[1], k[2], 3, 0)
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		t.set_stylebox(k[0], "HSlider", sb)
	# Texto enriquecido
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	# Barras de desplazamiento discretas
	t.set_stylebox("scroll", "VScrollBar", box(SUNKEN, SUNKEN, 3, 2))
	t.set_stylebox("grabber", "VScrollBar", box(LINE, LINE, 3, 2))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(MUTED, MUTED, 3, 2))
	t.set_stylebox("panel", "TooltipPanel", box(SUNKEN, ACCENT, 4, 8))
	t.set_color("font_color", "TooltipLabel", INK)
	_theme = t
	return t

## Casilla dibujada a mano: el icono por defecto apenas se ve sobre fondo oscuro.
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
		for i in 4:   # trazo corto de la marca
			for w in 2:
				img.set_pixel(4 + i, 8 + i + w, ink)
		for i in 7:   # trazo largo
			for w in 2:
				img.set_pixel(7 + i, 11 - i + w, ink)
	return ImageTexture.create_from_image(img)

# ---------- Piezas ----------
static func label(text: String, size: int = 15, color: Color = INK, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 50
	return l

static func title(text: String, size: int = 26) -> Label:
	var l := label(text.to_upper(), size, INK)
	return l

static func eyebrow(text: String, color: Color = MUTED) -> Label:
	return label(text.to_upper(), 12, color)

static func button(text: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", box(ACCENT, ACCENT, 6, 14))
		b.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.12), ACCENT.lightened(0.12), 6, 14))
		b.add_theme_stylebox_override("pressed", box(ACCENT.darkened(0.2), ACCENT, 6, 14))
		b.add_theme_color_override("font_color", Color("#1a0d07"))
		b.add_theme_color_override("font_hover_color", Color("#1a0d07"))
	return b

static func panel(bg: Color = SURFACE, border: Color = LINE, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 8, pad))
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

## Píldora de estado (verificaciones, roles).
static func pill(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := box(Color(color, 0.12), color, 10, 8)
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", st)
	p.add_child(label(text, 12, color))
	return p

## Medidor: título, valor y barra. Devuelve un diccionario con las piezas para actualizar.
static func meter(title_text: String) -> Dictionary:
	var v := vbox(2)
	var row := hbox(6)
	var t := label(title_text, 13, MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := label("–", 13, INK)
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
	return {"root": v, "value": val, "bar": bar}

static func set_meter(m: Dictionary, frac: float, text: String, color: Color = GOOD) -> void:
	m["value"].text = text
	var bar: ProgressBar = m["bar"]
	bar.value = clampf(frac, 0.0, 1.0)
	var fill := box(color, color, 3, 0, 0)
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
