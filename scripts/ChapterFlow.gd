extends Node
## 《墨渊》章节事件编排（AutoLoad）。
## Boss 击败流程：闪回演出 → 记忆碎片入库 → 流派技能解锁（第2主动/第2被动）→ 词条 3选1
## 剧本出自《墨渊项目书V6.3》：击败嵯峨为砚画过一片竹林……“形状”是有温度的

const CHAPTER_FLASHBACKS: Dictionary = {
	"gougou": {
		"title": "记忆碎片「勾勒」",
		"lines": [
			"击败嵯峨——夺回记忆碎片「勾勒」。",
			"他曾用勾勒之笔，为砚画过一片竹林。",
			"竹叶在风中摆动，她站在竹影里笑。",
			"那是他第一次觉得，「形状」是有温度的。",
		],
	},
}

var _flashback_ui: FlashbackUI = null


func _ready() -> void:
	_flashback_ui = FlashbackUI.new()
	add_child(_flashback_ui)


## Boss 击败入口：第一时间夺回记忆碎片，再播放章节闪回，
## 闪回结束后解锁第2技能并进入词条 3选1。
## pause=true 时闪回期间冻结战斗（真实对局）；测试场景传 false 便于断言。
func boss_defeated(fragment_type: String, pause: bool = true) -> void:
	GlobalStats.add_fragment(1)
	var data: Dictionary = CHAPTER_FLASHBACKS.get(fragment_type, {})
	var lines: Array = data.get("lines", [])
	if lines.is_empty():
		_finish_victory(fragment_type, false)
		return
	if pause:
		Engine.time_scale = 0.0
		_flashback_ui.start(lines, func(): _finish_victory(fragment_type, true))
	else:
		_flashback_ui.start(lines, func(): _finish_victory(fragment_type, false))


func _finish_victory(fragment_type: String, was_paused: bool) -> void:
	if was_paused:
		Engine.time_scale = 1.0
	# 解锁所有流派的第2主动 + 第2被动（只补空槽，不覆盖手动配置）
	FlowManager.refresh_skill_unlocks()
	# 词条 3选1（内部会自行暂停/恢复时间）
	TalentManager.defeat_boss(fragment_type)


## 测试辅助：直接推进一帧闪回
func advance_flashback() -> void:
	if _flashback_ui != null:
		_flashback_ui.advance()


## 测试辅助：闪回是否正在播放
func is_flashback_running() -> bool:
	return _flashback_ui != null and _flashback_ui.visible
