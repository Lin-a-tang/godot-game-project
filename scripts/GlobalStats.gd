extends Node
## 《墨渊》全局状态（等级 / 技能点 / 经验）。AutoLoad 单例。

signal stats_updated()

var level: int = 1
var skill_points: int = 2
var current_exp: int = 0
var exp_to_next: int = 50


func add_exp(amount: int) -> void:
	current_exp += amount
	while current_exp >= exp_to_next:
		current_exp -= exp_to_next
		level += 1
		skill_points += 1
		exp_to_next = int(exp_to_next * 1.2)
		print("升级！当前等级: ", level, "，技能点: ", skill_points)
	stats_updated.emit()


func use_skill_point() -> bool:
	if skill_points > 0:
		skill_points -= 1
		stats_updated.emit()
		return true
	return false
