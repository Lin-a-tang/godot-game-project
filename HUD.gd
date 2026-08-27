extends CanvasLayer
## 《墨渊》HUD。结构在 HUD.tscn 中摆放，样式在此程序化生成；
## 数值实时从 GlobalStats / FlowManager / Player 读取。

@onready var hp_bar: TextureProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var resource_bar: TextureProgressBar = $ResourceBar
@onready var resource_label: Label = $ResourceLabel
@onready var flow_name_label: Label = $FlowNameLabel
@onready var level_label: Label = $LevelLabel
@onready var skill_points_label: Label = $SkillPointsLabel
@onready var chapter_label: Label = $ChapterLabel
@onready var q_skill_panel: Panel = $QSkillPanel
@onready var q_skill_name: Label = $QSkillPanel/QSkillName
@onready var q_cooling_overlay: ColorRect = $QSkillPanel/QCoolingOverlay
@onready var q_cooling_label: Label = $QSkillPanel/QCoolingLabel
@onready var r_skill_panel: Panel = $RSkillPanel
@onready var r_skill_name: Label = $RSkillPanel/RSkillName
@onready var r_cooling_overlay: ColorRect = $RSkillPanel/RCoolingOverlay
@onready var r_cooling_label: Label = $RSkillPanel/RCoolingLabel
@onready var dodge_cooldown_overlay: ColorRect = $DodgeIcon/DodgeCooldownOverlay
@onready var dodge_cooldown_label: Label = $DodgeIcon/DodgeCooldownLabel

var _player: Node = null
var _refresh_accum: float = 0.0


func _ready() -> void:
	_apply_styling()
	GlobalStats.stats_updated.connect(_update_stats)
	FlowManager.flow_changed.connect(_on_flow_changed)
	FlowManager.skill_used.connect(_update_resources)
	_find_player.call_deferred()
	_update_all()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= 0.1:
		_refresh_accum = 0.0
		_update_skills()
		_update_dodge()


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.health_changed.connect(_on_health_changed)
		_update_all()


func _update_all() -> void:
	_update_hp()
	_update_resources()
	_update_stats()
	_update_skills()
	_update_dodge()


func _update_hp() -> void:
	if _player == null:
		return
	var cur: float = _player.player_health
	var mx: float = _player.player_max_health
	hp_bar.max_value = mx
	hp_bar.value = cur
	hp_label.text = "HP: %d/%d" % [int(cur), int(mx)]


func _update_resources() -> void:
	var flow: BaseFlow = FlowManager.get_current()
	var res: Dictionary = {}
	if _player != null:
		res = _player.get_current_resources()
	match flow.flow_name:
		"守拙":
			resource_bar.max_value = 5
			resource_bar.value = float(res.get("shield", 0))
			resource_label.text = "墨盾: %d/5" % int(res.get("shield", 0))
			resource_bar.tint_progress = Color("#4A6A8A")
		"点墨":
			resource_bar.max_value = 100
			resource_bar.value = float(res.get("pool", 0.0))
			resource_label.text = "砚池: %.0f%%" % float(res.get("pool", 0.0))
			resource_bar.tint_progress = Color("#8A7A4A")
		"藏锋":
			resource_bar.max_value = 3
			resource_bar.value = float(res.get("shadow", 0))
			resource_label.text = "残影: %d/3" % int(res.get("shadow", 0))
			resource_bar.tint_progress = Color("#6A4A7A")
		"归砚":
			resource_bar.max_value = 5
			resource_bar.value = float(res.get("motes", 0))
			resource_label.text = "墨魂: %d/5" % int(res.get("motes", 0))
			resource_bar.tint_progress = Color("#4A8A7A")
		"点睛":
			resource_bar.max_value = 100
			resource_bar.value = 0.0
			resource_label.text = "生命"
			resource_bar.tint_progress = Color("#8A4A4A")
	flow_name_label.text = "■ %s" % flow.flow_name


func _update_stats() -> void:
	level_label.text = "等级: %d" % GlobalStats.level
	skill_points_label.text = "技能点: %d" % GlobalStats.skill_points
	chapter_label.text = "第1章 · 枯禅寺"


func _update_skills() -> void:
	var flow: BaseFlow = FlowManager.get_current()
	if flow == null:
		return
	var q: Dictionary = flow.get_skill_status("q")
	q_skill_name.text = str(q.get("name", ""))
	_update_skill_display(q_skill_panel, q_cooling_overlay, q_cooling_label, bool(q.get("is_ready", false)), float(q.get("cooldown_remaining", 0.0)))
	var r: Dictionary = flow.get_skill_status("r")
	r_skill_name.text = str(r.get("name", ""))
	_update_skill_display(r_skill_panel, r_cooling_overlay, r_cooling_label, bool(r.get("is_ready", false)), float(r.get("cooldown_remaining", 0.0)))


func _update_dodge() -> void:
	if _player == null:
		return
	var remaining: float = _player.dodge_cooldown_remaining
	if remaining > 0.0:
		dodge_cooldown_overlay.visible = true
		dodge_cooldown_label.text = "%.1f" % remaining
	else:
		dodge_cooldown_overlay.visible = false


func _update_skill_display(panel: Panel, overlay: ColorRect, label: Label, ready: bool, remaining: float) -> void:
	if ready:
		overlay.visible = false
		_set_border(panel, Color(0.3, 0.8, 0.3))
	else:
		overlay.visible = true
		label.text = "%.1f" % remaining
		_set_border(panel, Color(0.4, 0.35, 0.25))


func _set_border(panel: Panel, color: Color) -> void:
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = color


func _on_flow_changed(_new_flow: BaseFlow) -> void:
	_update_resources()
	_update_skills()


func _on_health_changed(_cur: float, _max: float) -> void:
	_update_hp()


## ============ 样式 ============

func _apply_styling() -> void:
	# 字体
	var font := ThemeDB.fallback_font
	# 头像（圆形占位）
	_style_panel($Avatar, Color(0.2, 0.2, 0.3), Color(0.8, 0.7, 0.4), 2, 30)
	# 血量条（渐变填充）
	_style_bar_bg(hp_bar, Color(0.1, 0.05, 0.05), Color(0.3, 0.2, 0.15))
	hp_bar.texture_progress = _gradient_texture(Color("#8B0000"), Color("#FF2222"), 300, 20)
	# 资源条
	_style_bar_bg(resource_bar, Color(0.08, 0.08, 0.1), Color(0.3, 0.28, 0.2))
	resource_bar.texture_progress = _gradient_texture(Color.WHITE, Color.WHITE, 300, 16)
	# 技能面板
	_style_panel(q_skill_panel, Color(0.1, 0.1, 0.15, 0.85), Color(0.4, 0.35, 0.25), 1, 0)
	_style_panel(r_skill_panel, Color(0.1, 0.1, 0.15, 0.85), Color(0.4, 0.35, 0.25), 1, 0)
	# 闪避图标
	_style_panel($DodgeIcon, Color(0.15, 0.15, 0.2), Color(0.4, 0.35, 0.25), 2, 30)
	# 标签
	_style_label(hp_label, font, 14, Color.WHITE)
	_style_label(resource_label, font, 12, Color.WHITE)
	_style_label(flow_name_label, font, 20, Color("#D4C9A8"))
	_style_label(level_label, font, 16, Color("#CCCCCC"))
	_style_label(skill_points_label, font, 16, Color("#CCCCCC"))
	_style_label(chapter_label, font, 14, Color("#888888"))
	_style_label(q_skill_name, font, 12, Color("#DDDDDD"))
	_style_label(r_skill_name, font, 12, Color("#DDDDDD"))
	_style_label($QSkillPanel/QKeyLabel, font, 10, Color("#888888"))
	_style_label($RSkillPanel/RKeyLabel, font, 10, Color("#888888"))
	_style_label(q_cooling_label, font, 20, Color("#FF4444"))
	_style_label(r_cooling_label, font, 20, Color("#FF4444"))
	_style_label($DodgeIcon/DodgeTextLabel, font, 24, Color("#CCCCCC"))
	_style_label(dodge_cooldown_label, font, 20, Color("#FF4444"))
	# 冷却覆盖
	_style_overlay(q_cooling_overlay)
	_style_overlay(r_cooling_overlay)
	_style_overlay(dodge_cooldown_overlay)


func _style_panel(panel: Panel, bg: Color, border: Color, width: int, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	if radius > 0:
		sb.set_corner_radius_all(radius)
	panel.add_theme_stylebox_override("panel", sb)


func _style_bar_bg(bar: TextureProgressBar, bg: Color, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", sb)


func _gradient_texture(from: Color, to: Color, w: int, h: int) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([from, to])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = w
	tex.height = h
	return tex


func _style_label(label: Label, font: Font, size: int, color: Color) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


func _style_overlay(overlay: ColorRect) -> void:
	overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	overlay.visible = false
