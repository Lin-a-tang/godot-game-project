class_name Flow_Shouzhuo
extends BaseFlow
## 守拙：血厚、移速略慢。成功格挡时积累「墨盾」层数。


var shield: int = 0


func _init() -> void:
	flow_name = "守拙"
	damage_mult = 1.0
	hp_mult = 1.4
	speed_mult = 0.9


func init_skills() -> void:
	skill_data["q"] = {"name": "扫墨", "desc": "消耗1层墨盾，造成150%范围伤害", "damage_mult": 1.5, "cooldown_max": 3.0, "range": 4.0, "cost": {"shield": 1}}
	skill_data["r"] = {"name": "千山", "desc": "消耗3层墨盾，三段山影共造成840%伤害", "damage_mult": 2.8, "cooldown_max": 20.0, "range": 5.0, "cost": {"shield": 3}}


func on_block() -> void:
	shield = min(shield + 1, 5)
	print("守拙·墨盾: %d" % shield)
