class_name Flow_Dianmo
extends BaseFlow
## 点墨：高伤、脆皮。攻击命中时积累「砚池」。


var pool: float = 0.0


func _init() -> void:
	flow_name = "点墨"
	damage_mult = 1.3
	hp_mult = 0.9
	speed_mult = 1.0


func init_skills() -> void:
	skill_data["q"] = {"name": "墨引", "desc": "标记地面，持续5秒，路过墨弹分裂", "damage_mult": 0.0, "cooldown_max": 6.0, "range": 0.0, "cost": {}}
	skill_data["r"] = {"name": "墨雨", "desc": "消耗50%砚池，10滴墨滴每滴40%伤害", "damage_mult": 0.4, "cooldown_max": 8.0, "range": 5.0, "cost": {"pool": 50}}


func on_attack_hit() -> void:
	pool = min(pool + 8.0, 100.0)
	print("点墨·砚池: %.1f" % pool)
