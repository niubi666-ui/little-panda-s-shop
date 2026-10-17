extends RefCounted
## 剑上常驻的元素附魔选哪个元素：构筑里最先选到的元素（program.selections 按选取顺序排列）。
## 第二个元素暂时不顶替它，双元素附魔以后再做。只读已提交的构筑，不影响判定。

static func primary_element(program: Dictionary, catalog) -> String:
	if catalog == null:
		return ""
	for selected in program.get("selections", []):
		if not catalog.has_upgrade(selected.upgrade_id):
			continue
		var entry: Dictionary = catalog.upgrade(selected.upgrade_id)
		if entry.effect_type == "element":
			return String(entry.ranks[int(selected.rank) - 1].element_id)
	return ""
