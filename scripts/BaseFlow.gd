class_name BaseFlow
extends Node
## 《墨渊》流派基类（Node + 技能系统骨架）。
## 三个流派（守拙/点墨/藏锋）继承此基类，在 init_skills() 中填写技能数据。


@export var flow_name: String = ""
@export var damage_mult: float = 1.0
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0

## 技能数据：键 "q" / "r"，值为 {name, desc, damage_mult, cooldown_max, range, cost}
var skill_data: Dictionary = {}
var cooldown_timers: Dictionary = {"q": 0.0, "r": 0.0}


func _ready() -> void:
	init_skills()


func init_skills() -> void:
	pass


func get_skill_status(skill_id: String) -> Dictionary:
	var data: Dictionary = skill_data.get(skill_id, {})
	if data.is_empty():
		return {"is_ready": false, "cooldown_remaining": 0.0, "name": "未解锁", "desc": ""}
	var remaining := float(cooldown_timers.get(skill_id, 0.0))
	return {
		"is_ready": remaining <= 0.0,
		"cooldown_remaining": remaining,
		"name": str(data.get("name", "")),
		"desc": str(data.get("desc", "")),
	}


func can_cast(skill_id: String, player_resources: Dictionary) -> bool:
	if float(cooldown_timers.get(skill_id, 0.0)) > 0.0:
		return false
	var cost: Dictionary = skill_data.get(skill_id, {}).get("cost", {})
	for key in cost:
		if key == "hp_percent":
			continue
		if not player_resources.has(key):
			return false
		if float(player_resources[key]) < float(cost[key]):
			return false
	return true


func cast_skill(skill_id: String, player: Node) -> Dictionary:
	if float(cooldown_timers.get(skill_id, 0.0)) > 0.0:
		return {"success": false, "reason": "冷却中"}
	var resources: Dictionary = player.call("get_current_resources")
	if not can_cast(skill_id, resources):
		return {"success": false, "reason": "资源不足"}
	var data: Dictionary = skill_data[skill_id]
	player.call("deduct_resource", data["cost"])
	cooldown_timers[skill_id] = float(data["cooldown_max"])
	return {
		"success": true,
		"skill_id": skill_id,
		"damage_mult": float(data["damage_mult"]),
		"range": float(data["range"]),
	}


func update_cooldowns(delta: float) -> void:
	for key in cooldown_timers:
		if float(cooldown_timers[key]) > 0.0:
			cooldown_timers[key] = maxf(float(cooldown_timers[key]) - delta, 0.0)


func on_block() -> void:
	pass


func on_dodge() -> void:
	pass


func on_attack_hit() -> void:
	pass
