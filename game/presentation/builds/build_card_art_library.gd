extends Resource
## One record per catalog ID. Images, UI layers and text keys are independent.
@export var cards: Dictionary
@export var rarity_skins: Dictionary

func card(id: String) -> Dictionary:
	assert(cards.has(id), "Missing authored build-card art: " + id)
	return cards[id]

func skin(rarity_id: String) -> Dictionary:
	assert(rarity_skins.has(rarity_id), "Missing build-card rarity skin: " + rarity_id)
	return rarity_skins[rarity_id]

