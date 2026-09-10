extends Node
## 词条管理器（AutoLoad）。管理已解锁碎片、已选词条，提供 3选1 逻辑与合并加成。

signal talents_changed()
signal talent_choice_requested(fragment_type: String)

var unlocked_fragments: Array = []
var selected_talents: Dictionary = {}  # fragment_type -> talent_id
var _is_choosing: bool = false
var _selection_ui: Control = null


func _ready() -> void:
	_selection_ui = TalentSelectionUI.new()
	add_child(_selection_ui)


func unlock_fragment(fragment_type: String) -> void:
	if fragment_type in unlocked_fragments:
		return
	unlocked_fragments.append(fragment_type)
	print("解锁碎片: %s" % fragment_type)
	request_choice(fragment_type)


func request_choice(fragment_type: String) -> void:
	if _is_choosing:
		return
	_is_choosing = true
	if _selection_ui != null:
		_selection_ui.show_for_fragment(fragment_type)
	talent_choice_requested.emit(fragment_type)


func finish_choice() -> void:
	_is_choosing = false


func select_talent(fragment_type: String, talent_id: String) -> void:
	selected_talents[fragment_type] = talent_id
	print("选择词条: %s -> %s" % [fragment_type, talent_id])
	talents_changed.emit()


func get_selected_talent(fragment_type: String) -> String:
	return selected_talents.get(fragment_type, "")


func get_active_bonuses() -> Dictionary:
	var merged: Dictionary = {}
	for talent_id in selected_talents.values():
		var t: Dictionary = TalentData.get_talent(talent_id)
		var bonuses: Dictionary = t.get("bonuses", {})
		for key in bonuses:
			if merged.has(key):
				merged[key] = merged[key] + bonuses[key]
			else:
				merged[key] = bonuses[key]
	return merged


func get_bonus(key: String) -> float:
	var bonuses: Dictionary = get_active_bonuses()
	return float(bonuses.get(key, 0.0))


## 击败 Boss：解锁对应碎片并弹出 3选1
func defeat_boss(fragment_type: String) -> void:
	unlock_fragment(fragment_type)
