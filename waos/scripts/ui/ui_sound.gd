extends Node
## Gestor de audio táctil y banda sonora aeroespacial NASA.
## Utiliza grabaciones reales mecánicas de switches, relés, alarmas Apollo y música ambiental.

static var _instance: Node

const SFX_CLICK := preload("res://assets/audio/sfx/click_mechanical.wav")
const SFX_HOVER := preload("res://assets/audio/sfx/hover_tick.wav")
const SFX_SWITCH_HEAVY := preload("res://assets/audio/sfx/switch_heavy.wav")
const SFX_SWITCH_TOGGLE := preload("res://assets/audio/sfx/switch_toggle.wav")
const SFX_CONFIRM := preload("res://assets/audio/sfx/confirm_chime.wav")
const SFX_ALARM := preload("res://assets/audio/sfx/alarm-1202.wav")
const SFX_QUINDAR := preload("res://assets/audio/sfx/quindar-beep.wav")
const SFX_RELAY := preload("res://assets/audio/sfx/relay-latch.wav")
const SFX_SHUTTER := preload("res://assets/audio/sfx/shutter.wav")

var _bgm_menu: AudioStream = preload("res://assets/audio/music/space_menu.ogg")
var _bgm_space: AudioStream = preload("res://assets/audio/music/space_ambient.ogg")

const SFX_POOL_SIZE := 8
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0

var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _current_music_path: String = ""
var _is_muted := false
var _music_volume_db := -15.0
var _sfx_volume_db := -4.0

static func instance() -> Node:
	if _instance == null:
		var script: Script = load("res://scripts/ui/ui_sound.gd")
		_instance = script.new()
		_instance.name = "UISound"
		if Engine.get_main_loop() is SceneTree:
			var tree := Engine.get_main_loop() as SceneTree
			if tree.root:
				tree.root.call_deferred("add_child", _instance)
	return _instance

func _ready() -> void:
	# Configurar bucle de repetición en pistas de música OGG
	if _bgm_menu is AudioStreamOggVorbis:
		var o := _bgm_menu as AudioStreamOggVorbis
		o.loop = true
	if _bgm_space is AudioStreamOggVorbis:
		var o := _bgm_space as AudioStreamOggVorbis
		o.loop = true

	# Inicializar pool de reproductores SFX para evitar cortes en pulsaciones rápidas
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = _sfx_volume_db
		add_child(p)
		_sfx_players.append(p)

	# Reproductor de música dedicado con crossfade
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	_music_player.volume_db = -80.0
	add_child(_music_player)

func _play_sfx(stream: AudioStream, base_volume_db: float = -4.0, pitch_variance: float = 0.03) -> void:
	if _is_muted or stream == null:
		return
	if _sfx_players.is_empty():
		return

	# Buscar reproductor libre en el pool
	var player: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _sfx_players[_sfx_index % _sfx_players.size()]
		_sfx_index += 1

	player.stream = stream
	player.volume_db = base_volume_db + _sfx_volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	player.play()

func _play_music_stream(stream: AudioStream, path_id: String, fade_sec: float = 1.2, target_vol_db: float = -15.0) -> void:
	if stream == null or _music_player == null:
		return
	if _current_music_path == path_id and _music_player.playing:
		return

	_current_music_path = path_id
	_music_volume_db = target_vol_db

	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()

	if _music_player.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -60.0, fade_sec * 0.5)
		_music_tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.play()
		)
		var target := -60.0 if _is_muted else target_vol_db
		_music_tween.tween_property(_music_player, "volume_db", target, fade_sec * 0.5)
	else:
		_music_player.stream = stream
		_music_player.volume_db = -60.0
		_music_player.play()
		var target := -60.0 if _is_muted else target_vol_db
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", target, fade_sec)

# ---------- API Pública de Efectos Sonoros (SFX) ----------

static func play_click() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_CLICK, -6.0, 0.04)

static func play_hover() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_HOVER, -14.0, 0.03)

static func play_toggle(on: bool) -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		if on:
			s._play_sfx(SFX_SWITCH_HEAVY, -7.0, 0.02)
		else:
			s._play_sfx(SFX_SWITCH_TOGGLE, -8.0, 0.02)

static func play_success() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_CONFIRM, -5.0, 0.01)

static func play_alert() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_ALARM, -4.0, 0.0)

static func play_warning() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_RELAY, -6.0, 0.02)

static func play_quindar() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_QUINDAR, -7.0, 0.0)

static func play_camera() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_SHUTTER, -6.0, 0.03)

static func play_relay() -> void:
	var s: Node = instance()
	if s and s.has_method("_play_sfx"):
		s._play_sfx(SFX_RELAY, -7.0, 0.02)

# ---------- API Pública de Música de Fondo (BGM) ----------

static func play_menu_music(fade_sec: float = 1.2) -> void:
	var s: Node = instance()
	if s and s.has_method("_play_music_stream"):
		s._play_music_stream(s._bgm_menu, "menu", fade_sec, -14.0)

static func play_space_music(fade_sec: float = 1.5) -> void:
	var s: Node = instance()
	if s and s.has_method("_play_music_stream"):
		s._play_music_stream(s._bgm_space, "space", fade_sec, -15.0)

static func stop_music(fade_sec: float = 1.0) -> void:
	var s: Node = instance()
	if s and s._music_player and s._music_player.playing:
		if s._music_tween and s._music_tween.is_valid():
			s._music_tween.kill()
		s._music_tween = s.create_tween()
		s._music_tween.tween_property(s._music_player, "volume_db", -60.0, fade_sec)
		s._music_tween.tween_callback(func():
			s._music_player.stop()
			s._current_music_path = ""
		)

static func toggle_mute() -> bool:
	var s: Node = instance()
	if s:
		s._is_muted = not s._is_muted
		if s._music_player:
			if s._is_muted:
				s._music_player.volume_db = -80.0
			else:
				s._music_player.volume_db = s._music_volume_db
		return s._is_muted
	return false

static func is_muted() -> bool:
	var s: Node = instance()
	return s._is_muted if s else false
