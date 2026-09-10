class_name BaseFlow
extends Node
## 《墨渊》流派基类（Node + 技能系统骨架）。
## 三个流派（守拙/点墨/藏锋）继承此基类，在 init_skills() 中填写技能数据。


@export var flow_name: String = ""
@export var damage_mult: float = 1.0
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0

## 技能数据：键为技能 ID，值为 {name, desc, damage_mult, cooldown_max, range, cost, type}
## type: "active" 或 "passive"
var skill_data: Dictionary = {}
var cooldown_timers: Dictionary = {"q": 0.0, "r": 0.0}

## 当前装备配置
var equipped_skills: Dictionary = {"q": "", "r": "", "passive": ""}


func _ready() -> void:
	init_skills()
	_auto_equip_defaults()


func init_skills() -> void:
	pass


func get_skill_status(skill_id: String) -> Dictionary:
	var data: Dictionary = skill_data.get(skill_id, {})
	if data.is_empty() or not is_skill_unlocked(skill_id):
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


func get_equipped_skill(slot: String) -> Dictionary:
	var skill_id: String = equipped_skills.get(slot, "")
	if skill_id == "" or not skill_data.has(skill_id):
		return {}
	return skill_data[skill_id]


func equip_skill(slot: String, skill_id: String) -> bool:
	if not skill_data.has(skill_id):
		print("技能不存在: ", skill_id)
		return false
	var skill_type: String = skill_data[skill_id].get("type", "")
	if slot == "passive" and skill_type != "passive":
		print("被动槽只能装备被动技能")
		return false
	if slot != "passive" and skill_type != "active":
		print("主动槽只能装备主动技能")
		return false
	equipped_skills[slot] = skill_id
	print("装备技能: %s -> %s" % [slot, skill_id])
	return true


func unequip_skill(slot: String) -> void:
	equipped_skills[slot] = ""
	print("清空槽位: ", slot)


## 当前解锁阶：初始 1 阶（第1主动 + 第1被动）；
## 获得「勾勒」碎片后升到 2 阶（再加第2主动 + 第2被动）。
## 用 get_node_or_null 访问，避免与 TalentManager 的加载顺序耦合。
func _unlock_tier() -> int:
	var tm := get_tree().root.get_node_or_null("TalentManager")
	if tm != null and "gougou" in tm.unlocked_fragments:
		return 2
	return 1


func is_skill_unlocked(skill_id: String) -> bool:
	var skill_type: String = skill_data.get(skill_id, {}).get("type", "")
	if skill_type == "active":
		return get_unlocked_active_skills().has(skill_id)
	if skill_type == "passive":
		return get_unlocked_passive_skills().has(skill_id)
	return false


func get_unlocked_active_skills() -> Array:
	var tier := _unlock_tier()
	var seen := 0
	var result: Array = []
	for key in skill_data.keys():
		if skill_data[key].get("type", "") == "active":
			seen += 1
			if seen <= tier:
				result.append(key)
	return result


func get_unlocked_passive_skills() -> Array:
	var tier := _unlock_tier()
	var seen := 0
	var result: Array = []
	for key in skill_data.keys():
		if skill_data[key].get("type", "") == "passive":
			seen += 1
			if seen <= tier:
				result.append(key)
	return result


func _auto_equip_defaults() -> void:
	var active_skills: Array = get_unlocked_active_skills()
	var passive_skills: Array = get_unlocked_passive_skills()
	if equipped_skills.get("q", "") == "" and active_skills.size() >= 1:
		equip_skill("q", active_skills[0])
	if equipped_skills.get("r", "") == "" and active_skills.size() >= 2:
		equip_skill("r", active_skills[1])
	if equipped_skills.get("passive", "") == "" and passive_skills.size() >= 1:
		equip_skill("passive", passive_skills[0])


## 碎片解锁等变化后重新评估解锁/补默认装备（仅填补空槽位，不覆盖手动配置）
func reevaluate_unlocks() -> void:
	_auto_equip_defaults()


func on_block() -> void:
	pass


func on_dodge() -> void:
	pass


func on_attack_hit() -> void:
	pass
