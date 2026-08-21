class_name Flow_Shouzhuo
extends BaseFlow
## 守拙：血厚、移速略慢。成功格挡时积累「墨盾」层数。


var shield: int = 0


func _init() -> void:
	flow_name = "守拙"
	damage_mult = 1.0
	hp_mult = 1.4
	speed_mult = 0.9


func on_block() -> void:
	shield = min(shield + 1, 5)
	print("守拙·墨盾: %d" % shield)
