extends CanvasLayer
## 《墨渊》HUD。结构在 HUD.tscn 中摆放，样式在此程序化生成；
## 墨量 / 资源 / 冷却数值实时从 Player / FlowManager / GlobalStats 读取。

@onready var ink_bar: TextureProgressBar = $InkBar
@onready var ink_label: Label = $InkLabel
@onready var ink_warning: ColorRect = $InkWarning
@onready var resource_bar: TextureProgressBar = $ResourceBar
@onready var resource_label: Label = $ResourceLabel
@onready var level_label: Label = $LevelLabel
@onready var skill_points_label: Label = $SkillPointsLabel
@onready var q_panel: Panel = $QPanel
@onready var q_name: Label = $QPanel/QName
@onready var q_status: Label = $QPanel/QStatus
@onready var r_panel: Panel = $RPanel
@onready var r_name: Label = $RPanel/RName
@onready var r_status: Label = $RPanel/RStatus
@onready var dodge_cooldown: ColorRect = $DodgeIcon/DodgeCooldown
@onready var dodge_label: Label = $DodgeIcon/DodgeLabel

var _player: Node = null
var _refresh_accum: float = 0.0


func _ready() -> void:
	_apply_styling()
	GlobalStats.stats_updated.connect(_on_stats_updated)
	FlowManager.flow_changed.connect(_on_flow_changed)
	FlowManager.skill_used.connect(_update_all)
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
		_player.ink_changed.connect(_on_ink_changed)
		_update_all()


func _on_ink_changed(_current: float, _max: float) -> void:
	if _player == null:
		return
	var cur: float = _player.current_ink
	var mx: float = _player.max_ink
	ink_bar.value = cur
	ink_bar.max_value = mx
	ink_label.text = "墨量: %.0f/%.0f" % [cur, mx]
	ink_warning.visible = (cur / mx) < 0.3


func _on_flow_changed(_new_flow: BaseFlow) -> void:
	_update_resources()
	_update_skills()


func _update_all() -> void:
	_on_ink_changed(0.0, 0.0)
	_update_resources()
	_on_stats_updated()
	_update_skills()
	_update_dodge()


func _update_resources() -> void:
	var flow: BaseFlow = FlowManager.get_current()
	var res: Dictionary = {}
	if _player != null:
		res = _player.get_current_resources()
	match flow.flow_name:
		"守拙":
			resource_bar.max_value = 5
			resource_bar.value = float(res.get("shield", 0))
			resource_label.text = "守拙·墨盾: %d/5" % int(res.get("shield", 0))
			resource_bar.tint_progress = Color("#4A6A8A")
		"点墨":
			resource_bar.max_value = 100
			resource_bar.value = float(res.get("pool", 0.0))
			resource_label.text = "点墨·砚池: %.0f%%" % float(res.get("pool", 0.0))
			resource_bar.tint_progress = Color("#8A7A4A")
		"藏锋":
			resource_bar.max_value = 3
			resource_bar.value = float(res.get("shadow", 0))
			resource_label.text = "藏锋·残影: %d/3" % int(res.get("shadow", 0))
			resource_bar.tint_progress = Color("#6A4A7A")
		"归砚":
			resource_bar.max_value = 5
			resource_bar.value = float(res.get("motes", 0))
			resource_label.text = "归砚·墨魂: %d/5" % int(res.get("motes", 0))
			resource_bar.tint_progress = Color("#4A8A6A")
		"点睛":
			resource_bar.max_value = 100
			if _player != null:
				var pct: float = 100.0 * _player.current_ink / _player.max_ink
				resource_bar.value = pct
				resource_label.text = "点睛·泪痕: %.0f%%" % pct
			resource_bar.tint_progress = Color("#8A3A3A")


func _on_stats_updated() -> void:
	level_label.text = "等级: %d" % GlobalStats.level
	skill_points_label.text = "技能点: %d" % GlobalStats.skill_points


func _update_skills() -> void:
	var flow: BaseFlow = FlowManager.get_current()
	if flow == null:
		return
	var q: Dictionary = flow.get_skill_status("q")
	var r: Dictionary = flow.get_skill_status("r")
	_update_skill_display(q_name, q_status, q_panel, q)
	_update_skill_display(r_name, r_status, r_panel, r)


func _update_skill_display(name_label: Label, status_label: Label, panel: Panel, status: Dictionary) -> void:
	var skill_name := str(status.get("name", ""))
	if skill_name == "" or skill_name == "未解锁":
		name_label.text = "--"
		status_label.text = "未解锁"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		_set_border(panel, Color(0.4, 0.4, 0.4))
		return
	name_label.text = skill_name
	if bool(status.get("is_ready", false)):
		status_label.text = "就绪"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		_set_border(panel, Color(0.3, 0.8, 0.3))
	else:
		status_label.text = "冷却 %.1fs" % float(status.get("cooldown_remaining", 0.0))
		status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		_set_border(panel, Color(0.9, 0.3, 0.3))


func _update_dodge() -> void:
	if _player == null:
		return
	var remaining: float = _player.dodge_cooldown_remaining
	if remaining > 0.0:
		dodge_cooldown.visible = true
		dodge_label.text = "%.1f" % remaining
	else:
		dodge_cooldown.visible = false


func _set_border(panel: Panel, color: Color) -> void:
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = color


## ============ 样式 ============

func _apply_styling() -> void:
	var font := ThemeDB.fallback_font
	# 墨量条（墨色到金色渐变填充）
	_style_bar_bg(ink_bar, Color(0.1, 0.05, 0.05), Color(0.3, 0.2, 0.15))
	ink_bar.texture_progress = _gradient_texture(Color(0.1, 0.1, 0.2), Color(0.9, 0.85, 0.7), 280, 18)
	# 资源条
	_style_bar_bg(resource_bar, Color(0.08, 0.08, 0.1), Color(0.3, 0.28, 0.2))
	resource_bar.texture_progress = _gradient_texture(Color.WHITE, Color.WHITE, 280, 14)
	# 低墨量警告（红色覆盖）
	ink_warning.color = Color(1.0, 0.2, 0.2, 0.35)
	ink_warning.visible = false
	# 技能面板
	_style_panel(q_panel, Color(0.1, 0.1, 0.15, 0.85), Color(0.4, 0.35, 0.25), 1, 0)
	_style_panel(r_panel, Color(0.1, 0.1, 0.15, 0.85), Color(0.4, 0.35, 0.25), 1, 0)
	# 闪避图标（圆形）
	_style_panel($DodgeIcon, Color(0.15, 0.15, 0.2), Color(0.4, 0.35, 0.25), 2, 25)
	dodge_cooldown.color = Color(0.0, 0.0, 0.0, 0.6)
	dodge_cooldown.visible = false
	# 标签
	_style_label(ink_label, font, 12, Color.WHITE)
	_style_label(resource_label, font, 11, Color.WHITE)
	_style_label(level_label, font, 16, Color("#CCCCCC"))
	_style_label(skill_points_label, font, 16, Color("#CCCCCC"))
	_style_label(q_name, font, 12, Color("#DDDDDD"))
	_style_label(q_status, font, 11, Color("#888888"))
	_style_label(r_name, font, 12, Color("#DDDDDD"))
	_style_label(r_status, font, 11, Color("#888888"))
	_style_label($DodgeIcon/DodgeText, font, 22, Color("#CCCCCC"))
	_style_label(dodge_label, font, 18, Color("#FF4444"))


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
