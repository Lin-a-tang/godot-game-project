class_name BaseFlow
extends Resource
## 《墨渊》流派基类。三个流派（守拙/点墨/藏锋）继承此基类。
## 子类在 _init() 中设定固定系数，并按需重写 on_block / on_dodge / on_attack_hit。


@export var flow_name: String = ""
@export var damage_mult: float = 1.0
@export var hp_mult: float = 1.0
@export var speed_mult: float = 1.0


func on_block() -> void:
	pass


func on_dodge() -> void:
	pass


func on_attack_hit() -> void:
	pass
