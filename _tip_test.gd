extends Node3D
## 技能悬停提示自测：attach + 悬停回调 + 数据查表

func _ready() -> void:
	var host := Control.new()
	add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 1) 数据查表
	assert(SkillDescriptions.get_effect("千山") != "")
	assert(SkillDescriptions.get_effect("墨引").contains("分裂"))
	assert(SkillDescriptions.get_effect("不存在的技能") == "")
	print("data OK")

	# 2) attach 一个模拟技能名 Label 并触发悬停回调
	var label := Label.new()
	label.text = "千山"
	host.add_child(label)
	SkillTooltip.attach(host, label)
	SkillTooltip._on_hover(host, label)        # 模拟鼠标进入
	print("tooltip visible=", SkillTooltip._instance.visible)
	assert(SkillTooltip._instance != null)
	assert(SkillTooltip._instance.visible)
	assert(SkillTooltip._label.text.contains("千山"))
	assert(SkillTooltip._label.text.contains("三段山影"))
	# 3) 移出即隐藏
	SkillTooltip._on_exit()
	assert(SkillTooltip._instance.visible == false)
	# 4) "未装备"不弹
	label.text = "未装备"
	SkillTooltip._on_hover(host, label)
	assert(SkillTooltip._instance.visible == false)
	# 5) 流派按钮：文本→查表→弹窗
	assert(SkillDescriptions.get_flow_desc("守拙") != "")
	assert(SkillDescriptions.get_flow_desc("藏锋").contains("残影"))
	var flow_btn := Button.new()
	flow_btn.text = "守拙"
	host.add_child(flow_btn)
	SkillTooltip.attach_button(host, flow_btn)
	SkillTooltip._on_button_hover(host, flow_btn)
	assert(SkillTooltip._instance.visible)
	assert(SkillTooltip._label.text.contains("守拙"))
	assert(SkillTooltip._label.text.contains("墨盾"))
	# 带锁定前缀也正确处理
	flow_btn.text = "🔒 归砚"
	SkillTooltip._on_button_hover(host, flow_btn)
	assert(SkillTooltip._instance.visible)
	assert(SkillTooltip._label.text.contains("归砚"))

	# 6) 方框尺寸随文字长度自适应：长文案 > 短文案
	SkillTooltip.show_text(host, Vector2(50, 50), "千山", SkillDescriptions.get_effect("千山"))
	var h_short: float = SkillTooltip._instance.size.y
	SkillTooltip.show_text(host, Vector2(50, 50), "守拙", SkillDescriptions.get_flow_desc("守拙"))
	var h_long: float = SkillTooltip._instance.size.y
	print("size: 短=%.0f 长=%.0f" % [h_short, h_long])
	assert(h_short >= 34.0)
	assert(h_long > h_short)
	print("TIP TESTS PASSED")
	get_tree().quit()
