extends Control
signal new_layout_requested
func configure(shared_theme: Theme) -> void:
	theme = shared_theme
	$Panel/Rows/NewLayout.pressed.connect(func(): new_layout_requested.emit())
func display(seed_text: String, loot_text: String, prompt_text: String, can_interact: bool) -> void:
	$Panel/Rows/Seed.text = seed_text
	$Panel/Rows/NewLayout.text = tr("room.new_layout")
	$Panel/Rows/NewLayout.disabled = not can_interact
	$Panel/Rows/Loot.text = loot_text
	$Panel/Rows/Prompt.text = prompt_text if can_interact else ""
