class_name Flow_Guiyan
extends BaseFlow
## 归砚：以墨魂驭蝶，可攻可辅。攻击命中时积累「墨魂」。


var motes: int = 0


func _init() -> void:
	flow_name = "归砚"
	damage_mult = 1.1
	hp_mult = 1.1
	speed_mult = 1.0


func init_skills() -> void:
	skill_data["q"] = {"name": "蝶潮", "desc": "消耗3墨魂，召唤5只墨蝶环绕攻击，每只40%伤害", "damage_mult": 0.4, "cooldown_max": 20.0, "range": 5.0, "cost": {"motes": 3}}
	skill_data["r"] = {"name": "共生", "desc": "消耗1墨魂，墨蝶附着友方，每秒回血2%，移速+10%，持续10秒", "damage_mult": 0.0, "cooldown_max": 8.0, "range": 0.0, "cost": {"motes": 1}}


func on_attack_hit() -> void:
	motes = min(motes + 1, 5)
	print("归砚·墨魂: %d" % motes)
