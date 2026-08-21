class_name Flow_Dianmo
extends BaseFlow
## 点墨：高伤、脆皮。攻击命中时积累「砚池」。


var pool: float = 0.0


func _init() -> void:
	flow_name = "点墨"
	damage_mult = 1.3
	hp_mult = 0.9
	speed_mult = 1.0


func on_attack_hit() -> void:
	pool = min(pool + 8.0, 100.0)
	print("点墨·砚池: %.1f" % pool)
