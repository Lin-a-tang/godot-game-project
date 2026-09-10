class_name TalentData
extends RefCounted
## 词条静态数据（纯静态类，非 Resource，避免 Callable 序列化问题）。
## 六个记忆碎片（勾勒/赋色/晕染/留白/点睛/落款），每个碎片对应三个词条。

const FRAGMENT_TYPES: Array = ["gougou", "fuse", "yunran", "liubai", "dianjing", "luokuan"]

const FRAGMENT_NAMES: Dictionary = {
	"gougou": "勾勒",
	"fuse": "赋色",
	"yunran": "晕染",
	"liubai": "留白",
	"dianjing": "点睛",
	"luokuan": "落款",
}

const TALENTS: Dictionary = {
	# 勾勒（守拙）
	"gougou_heavy": {"name": "重墨勾勒", "desc": "所有攻击墨耗+50%，伤害+30%", "fragment_type": "gougou", "talent_type": "numerical", "bonuses": {"damage_mult": 0.30, "ink_cost_mult": 0.50}},
	"gougou_break": {"name": "破锋勾勒", "desc": "攻击附带破甲减速", "fragment_type": "gougou", "talent_type": "mechanical", "bonuses": {"has_break": true, "break_slow": 0.30, "break_duration": 3.0}},
	"gougou_youling": {"name": "游丝勾勒", "desc": "格挡窗口扩大，格挡回墨", "fragment_type": "gougou", "talent_type": "tactical", "bonuses": {"block_window_bonus": 0.1, "block_restore_ink": 5.0}},
	# 赋色（点墨）
	"fuse_dense": {"name": "浓墨赋色", "desc": "砚池伤害加成提升", "fragment_type": "fuse", "talent_type": "numerical", "bonuses": {"pool_bonus_mult": 1.5}},
	"fuse_fivecolor": {"name": "五色赋色", "desc": "攻击附加五色减益", "fragment_type": "fuse", "talent_type": "mechanical", "bonuses": {"has_color_debuff": true}},
	"fuse_light": {"name": "淡彩赋色", "desc": "砚池获取提升，伤害加成略降", "fragment_type": "fuse", "talent_type": "tactical", "bonuses": {"pool_gain_mult": 1.4, "pool_bonus_penalty": 0.2}},
	# 晕染（藏锋）
	"yunran_dense": {"name": "浓墨晕染", "desc": "残影伤害提升", "fragment_type": "yunran", "talent_type": "numerical", "bonuses": {"shadow_damage_mult": 1.333}},
	"yunran_seep": {"name": "渗墨晕染", "desc": "攻击附带渗墨持续伤害", "fragment_type": "yunran", "talent_type": "mechanical", "bonuses": {"has_seep": true, "seep_damage": 0.02, "seep_duration": 3.0}},
	"yunran_light": {"name": "淡墨晕染", "desc": "残影持续时间提升，伤害略降", "fragment_type": "yunran", "talent_type": "tactical", "bonuses": {"shadow_duration_mult": 1.667, "shadow_damage_penalty": 0.3}},
	# 留白（归砚）
	"liubai_deepsky": {"name": "深空留白", "desc": "召唤物伤害与持续时间提升", "fragment_type": "liubai", "talent_type": "numerical", "bonuses": {"summon_damage_mult": 1.3, "summon_duration_bonus": 3.0}},
	"liubai_void": {"name": "虚境留白", "desc": "召唤物命中几率眩晕", "fragment_type": "liubai", "talent_type": "mechanical", "bonuses": {"has_void_stun": true, "stun_chance": 0.15, "stun_duration": 1.0}},
	"liubai_traceless": {"name": "无痕留白", "desc": "墨魂获取提升，召唤伤害略降", "fragment_type": "liubai", "talent_type": "tactical", "bonuses": {"mote_gain_mult": 1.5, "summon_damage_penalty": 0.2}},
	# 点睛
	"dianjing_red": {"name": "赤景点睛", "desc": "墨泪伤害提升", "fragment_type": "dianjing", "talent_type": "numerical", "bonuses": {"tear_damage_mult": 1.25}},
	"dianjing_lingxi": {"name": "灵犀点睛", "desc": "暴击回墨提升", "fragment_type": "dianjing", "talent_type": "mechanical", "bonuses": {"crit_restore_bonus": 0.03}},
	"dianjing_cangfeng": {"name": "藏锋点睛", "desc": "墨泪消耗降低，伤害略降", "fragment_type": "dianjing", "talent_type": "tactical", "bonuses": {"tear_cost_reduction": 0.3, "tear_damage_penalty": 0.15}},
	# 落款（全流派）
	"luokuan_name": {"name": "定名落款", "desc": "所有伤害提升15%", "fragment_type": "luokuan", "talent_type": "numerical", "bonuses": {"all_damage_mult": 1.15}},
	"luokuan_seal": {"name": "封印发", "desc": "攻击几率封印敌人", "fragment_type": "luokuan", "talent_type": "mechanical", "bonuses": {"has_seal": true, "seal_chance": 0.20, "seal_duration": 2.0}},
	"luokuan_mark": {"name": "留印落款", "desc": "所有墨耗降低，墨量上限略降", "fragment_type": "luokuan", "talent_type": "tactical", "bonuses": {"all_ink_cost_reduction": 0.15, "max_ink_penalty": 0.1}},
}


static func get_talent(talent_id: String) -> Dictionary:
	return TALENTS.get(talent_id, {})


static func get_fragment_talents(fragment_type: String) -> Array:
	var result: Array = []
	for key in TALENTS.keys():
		if TALENTS[key].get("fragment_type", "") == fragment_type:
			result.append(key)
	return result
