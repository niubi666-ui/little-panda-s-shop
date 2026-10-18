extends Control
const Style = preload("res://presentation/attributes/character_sheet_style.tres")
signal close_requested
var heading: Label
var mode: Label
var vitals: Label
var rows: Dictionary = {}
var previews: RichTextLabel
var description: Label
var close_button: Button
var content: VBoxContainer
func configure(shared_theme: Theme, stat_keys: Array) -> void:
	theme = shared_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Style.overlay
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var surface := PanelContainer.new()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.offset_left = Style.margin.x
	surface.offset_right = -Style.margin.x
	surface.offset_top = Style.margin.y
	surface.offset_bottom = -Style.margin.y
	surface.add_theme_stylebox_override("panel", Style.surface)
	var margin := MarginContainer.new()
	surface.add_child(margin)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side, Style.padding)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", Style.gap)
	margin.add_child(content)
	heading = label(content, Style.title_size, Style.gold)
	mode = label(content, Style.muted_size, Style.muted)
	vitals = label(content, Style.body_size, Style.gold)
	content.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", Style.padding)
	scroll.add_child(columns)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_theme_constant_override("v_separation", Style.gap)
	grid.add_theme_constant_override("h_separation", Style.padding)
	columns.add_child(grid)
	for key in stat_keys + ["physical_reduction", "magical_reduction"]:
		var name_label := label(grid,Style.body_size,Style.muted)
		var value_label := label(grid,Style.body_size,Style.gold)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rows[key] = [name_label,value_label]
	previews = RichTextLabel.new()
	previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previews.add_theme_font_size_override("normal_font_size",Style.body_size)
	previews.add_theme_color_override("default_color",Style.gold)
	previews.bbcode_enabled = false
	previews.fit_content = true
	previews.scroll_active = false
	columns.add_child(previews)
	description = label(content,Style.muted_size,Style.muted)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_button = Button.new()
	close_button.add_theme_font_size_override("font_size",Style.body_size)
	content.add_child(close_button)
	close_button.pressed.connect(func():close_requested.emit())
func label(parent: Node, font_size: int, color: Color) -> Label:
	var item := Label.new()
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	parent.add_child(item)
	return item
func display(data: Dictionary) -> void:
	heading.text = tr("stats.title")
	mode.text = tr("stats.base_preview") if data.preview else tr("stats.live")
	vitals.text = tr("stats.vitals").format({"hp":number(data.hp),"max":number(data.stats.max_health),"shield":number(data.shield)})
	for key in rows:
		rows[key][0].text = tr("stats." + key)
		var value: float = data.stats[key] if data.stats.has(key) else data[key]
		rows[key][1].text = number(value * 100.0) + "%" if key in ["crit_chance","cooldown_haste","physical_reduction","magical_reduction"] else number(value)
	var lines: Array[String] = [tr("stats.skill_preview"), ""]
	for skill in data.skills:
		lines.append(tr("stats.skill." + skill.id) + "   " + number(skill.amount) + "  " + tr("stats.type." + skill.type))
	lines.append("")
	lines.append(tr("stats.weapon_bonus").format({"bonus":number(data.weapon_bonus * 100.0)}))
	for action in ["primary", "special", "skill"]:
		lines.append(tr("stats.action." + action) + "  +" + number(data.action_bonus[action]*100.0) + "%")
	for effect in data.effects:
		var action_name := tr("stats.binding." + effect.action)
		if effect.has("element"): lines.append(tr("stats.element").format({"action":action_name,"element":tr("element."+effect.element+".name")}))
		else: lines.append(tr("stats.conditional").format({"action":action_name,"bonus":number(effect.bonus*100.0)}))
	lines.append("")
	lines.append(tr("stats.preview_note"))
	previews.text = "\n".join(lines)
	description.text = tr("stats.footer")
	close_button.text = tr("stats.close")
func number(value: float) -> String:
	return str(int(round(value))) if is_equal_approx(value, round(value)) else "%.2f" % value
